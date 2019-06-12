# frozen_string_literal: true

require 'resolv'
require 'addressable/idna'
require 'aws-sdk-route53'

module AcmeAwsLambda
  class Dns

    RESOLVE_TIMEOUT = 3 # 3 seconds to resolve dns requests

    RESOLVE_ERRORS = [
      Resolv::ResolvError,
      Resolv::ResolvTimeout
    ].freeze

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

    private

    def route53_client
      @route53_client ||= Aws::Route53::Client.new
    end

  end
end
