# frozen_string_literal: true

require 'openssl'
require 'logger'
require 'tempfile'
require 'resolv'
require 'addressable/idna'
require 'acme-client'
require 'aws-sdk-s3'
require 'aws-sdk-route53'

module AcmeAwsLambda
  class KeyManager

    RESOLVE_TIMEOUT = 3 # 3 seconds to resolve dns requests

    RESOLVE_ERRORS = [
      Resolv::ResolvError,
      Resolv::ResolvTimeout
    ].freeze

    attr_reader :client, :account, :csr

    def initialize
      @domains_txt_records = []

      aws_config = {
        credentials: ::Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
        region: ENV['AWS_REGION'],
        # log_level: :info,
        logger: Logger.new($stdout),
        log_level: :debug,
        http_wire_trace: true
      }

      ::Aws.config.update(aws_config)
    end

    def generate_client_key
      private_key = OpenSSL::PKey::RSA.new(4096)
      file = Tempfile.new('client_key')
      file.write(private_key.to_pem)
      file.rewind
      obj = s3_resource.bucket('testing-staging-certs').object('client_key.pem')
      obj.upload_file(file)
    ensure
      file&.close
      file&.unlink
    end

    def new_account
      private_key_content = s3_client.get_object(
        bucket: 'testing-staging-certs',
        key: 'client_key.pem'
      )

      private_key = OpenSSL::PKey::RSA.new(private_key_content.body.read)
      @client = Acme::Client.new(private_key: private_key, directory: 'https://acme-staging-v02.api.letsencrypt.org/directory')
      @account = client.new_account(contact: 'mailto:a.v@rw.rw', terms_of_service_agreed: true)
    end

    def wait_for_route53_change(change_id)
      status = ''
      until status == 'INSYNC'
        resp = route53_client.get_change(id: change_id)
        status = resp.change_info.status
        if status != 'INSYNC'
          puts 'Waiting for dns change to complete'
          sleep 5
        end
      end
    end

    def updated_dns_record?(dns_record, resource_records)
      all_records_updated = false

      txt_records = begin
        Resolv::DNS.open do |dns|
          dns.timeouts = RESOLVE_TIMEOUT
          records = dns.getresources(Addressable::IDNA.to_ascii(dns_record), Resolv::DNS::Resource::IN::TXT)
          records.empty? ? [] : records.map(&:data)
        end
      rescue *RESOLVE_ERRORS
        []
      end

      unless txt_records.empty?
        all_records_updated = resource_records.all? do |resource_record|
          txt_records.any? do |txt_record|
            txt_record.include? resource_record
          end
        end
      end

      all_records_updated
    end

    def update_dns_records(domain, dns_record, resource_records)
      hosted_zone = route53_client.list_hosted_zones_by_name(dns_name: "#{domain}.").hosted_zones[0]

      resp = route53_client.change_resource_record_sets(
        change_batch: {
          changes: [
            {
              action: 'UPSERT',
              resource_record_set: {
                name: dns_record,
                resource_records: resource_records.map { |rr| { value: rr.inspect } },
                ttl: 60,
                type: 'TXT'
              }
            }
          ],
          comment: 'TXT records for ACME validation'
        },
        hosted_zone_id: 'Z2LXT5HMDHJE6L' # hosted_zone.id
      )

      wait_for_route53_change(resp.change_info.id)

      sleep(4) until updated_dns_record?(dns_record, resource_records)
    end

    def new_order(domains)
      order = client.new_order(identifiers: domains)

      authorizations = order.authorizations

      dns_challengers = authorizations.map do |authorization|
        domain = authorization.domain
        next unless authorization.status == 'pending'

        challenge = authorization.dns
        {
          challenge: challenge,
          domain: domain
        }
      end.compact

      dns_challengers.group_by { |dns| "#{dns[:challenge].record_name}.#{dns[:domain]}" }.each do |dns_record, records|
        domain = records.first[:domain]
        resource_records = records.map { |dns| dns[:challenge].record_content }
        update_dns_records(domain, dns_record, resource_records)
      end

      dns_challengers.each do |dns_challenger|
        challenge = dns_challenger[:challenge]

        challenge.request_validation

        while challenge.status == 'pending'
          sleep(0.25)
          challenge.reload
        end

        if challenge.status == 'invalid'
          puts 'retry invalid'
          retry_count = 0
          while challenge.status == 'invalid' && retry_count < 5
            sleep(2)
            challenge.reload
            retry_count += 1
            puts "retry invalid: #{challenge.status}, #{retry_count}"
          end
        end

        puts challenge.error unless challenge.status == 'valid'
      end

      @csr = Acme::Client::CertificateRequest.new(
        common_name: domains[0],
        names: domains
      )
      order.finalize(csr: csr)

      sleep(1) while order.status == 'processing'

      [order.certificate, csr]
    end

    def revoke_certificate(certificate)
      client.revoke(certificate: certificate)
    end

    private

    def s3_client
      @s3_client ||= Aws::S3::Client.new
    end

    def s3_resource
      @s3_resource ||= Aws::S3::Resource.new
    end

    def route53_client
      @route53_client ||= Aws::Route53::Client.new
    end

  end
end
