# frozen_string_literal: true

require 'resolv'
require 'addressable/idna'
require 'aws-sdk-route53'

module AcmeAwsLambda
  class Route53

    RESOLVE_TIMEOUT = 5 # 5 seconds to resolve dns requests

    RESOLVE_ERRORS = [
      Resolv::ResolvError,
      Resolv::ResolvTimeout
    ].freeze

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def update_dns_records(domain, dns_record, resource_records)
      hosted_zone_id = AcmeAwsLambda.route53_hosted_zone_id || route53_client.list_hosted_zones_by_name(
        dns_name: "#{domain}."
      ).hosted_zones[0]&.id

      raise('cannot find hosted zone id at route53') if hosted_zone_id.nil?

      resp = update_route53_record(hosted_zone_id, dns_record, resource_records)
      wait_for_route53_sync(resp.change_info.id)
      check_dns_records(dns_record, resource_records)
    end

    private

    def update_route53_record(hosted_zone_id, dns_record, resource_records)
      route53_client.change_resource_record_sets(
        hosted_zone_id: hosted_zone_id,
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
        }
      )
    end

    def wait_for_route53_sync(change_id)
      status = ''
      check_count = 0

      until status == 'INSYNC'
        resp = route53_client.get_change(id: change_id)
        status = resp.change_info.status
        next unless status != 'INSYNC'

        logger.info "Waiting for dns change to complete on route53. check #{check_count}"

        raise('route53 not completed dns change') if check_count > AcmeAwsLambda.dns_retry_count

        check_count += 1
        sleep(AcmeAwsLambda.dns_retry_timeout)
      end
    end

    def check_dns_records(dns_record, resource_records)
      all_records_updated = false
      check_count = 0

      until all_records_updated == true

        txt_records = get_all_txt_from_record(dns_record)

        unless txt_records.empty?
          all_records_updated = resource_records.all? do |resource_record|
            txt_records.any? do |txt_record|
              txt_record.include? resource_record
            end
          end
        end

        next unless all_records_updated != true

        logger.info "Waiting for dns change to start working. check #{check_count}"

        raise('cannot completed dns check') if check_count > AcmeAwsLambda.dns_retry_count

        check_count += 1
        sleep(AcmeAwsLambda.dns_retry_timeout)

      end
    end

    def get_all_txt_from_record(dns_record)
      Resolv::DNS.open do |dns|
        dns.timeouts = RESOLVE_TIMEOUT
        records = dns.getresources(Addressable::IDNA.to_ascii(dns_record), Resolv::DNS::Resource::IN::TXT)
        records.empty? ? [] : records.map(&:data)
      end
    rescue *RESOLVE_ERRORS
      []
    end

    def route53_client
      @route53_client ||= Aws::Route53::Client.new(
        credentials: Aws::Credentials.new(
          AcmeAwsLambda.route53_aws_access_key_id,
          AcmeAwsLambda.route53_aws_secret_access_key,
          AcmeAwsLambda.route53_aws_session_token
        ),
        region: AcmeAwsLambda.route53_aws_region
      )
    end

  end
end
