# frozen_string_literal: true

require 'openssl'
require 'logger'
require 'acme-client'

module AcmeAwsLambda
  class KeyManager

    LOG_LEVELS = {
      fatal: Logger::FATAL,
      error: Logger::ERROR,
      warn: Logger::WARN,
      info: Logger::INFO,
      debug: Logger::DEBUG
    }.freeze

    attr_reader :logger, :route53, :s3

    def initialize
      @logger = Logger.new($stdout)
      @logger.level = LOG_LEVELS[AcmeAwsLambda.log_level]
      @logger.formatter = AcmeAwsLambda.log_formatter
      @route53 = AcmeAwsLambda::Route53.new(logger)
      @s3 = AcmeAwsLambda::S3.new(logger)
      init_aws_client
    end

    def create_or_renew_cert
      if certificate_valid?
        logger.info "Certificate #{AcmeAwsLambda.s3_certificate_key} is still valid. Exiting..."
        return false
      end

      new_order
    end

    def revoke_certificate
      certificate = s3.certificate
      return false if certificate.nil?

      client.revoke(certificate: certificate)
    end

    private

    def certificate_valid?
      certificate = s3.certificate
      return false if certificate.nil?

      logger.debug 'Certificate downloaded for validation check'
      logger.debug "Certificate not_after: #{certificate.not_after.strftime('%Y-%m-%d %H:%M:%S %z')}"

      renew_at = ::Time.now + 60 * 60 * 24 * AcmeAwsLambda.renew
      certificate.not_after > renew_at
    end

    def new_order
      create_account

      order = client.new_order(identifiers: AcmeAwsLambda.domains)

      dns_challengers = get_all_dns_challengers(order)
      update_dns_records(dns_challengers)
      order_request_validation(dns_challengers)

      certificate = certificate_request(order)
      s3.save_certificate(certificate)
    end

    def get_all_dns_challengers(order)
      order.authorizations.map do |authorization|
        domain = authorization.domain
        next unless authorization.status == 'pending'

        challenge = authorization.dns
        {
          challenge: challenge,
          domain: domain
        }
      end.compact
    end

    def update_dns_records(dns_challengers)
      dns_challengers.group_by { |dns| "#{dns[:challenge].record_name}.#{dns[:domain]}" }.each do |dns_record, records|
        domain = AcmeAwsLambda.route53_domain || records.first[:domain]
        resource_records = records.map { |dns| dns[:challenge].record_content }
        route53.update_dns_records(domain, dns_record, resource_records)
      end
    end

    def order_request_validation(dns_challengers)
      dns_challengers.each do |dns_challenger|
        challenge = dns_challenger[:challenge]

        challenge.request_validation

        while challenge.status == 'pending'
          sleep(0.25)
          challenge.reload
        end

        next if challenge.status == 'valid'

        raise_challenge_error(challenge)
      end
    end

    def raise_challenge_error(challenge)
      logger.error 'Error to validate dns challenger'
      logger.error challenge.error
      raise('Cannot validate dns challenger')
    end

    def certificate_request(order)
      csr = Acme::Client::CertificateRequest.new(
        common_name: AcmeAwsLambda.common_name || AcmeAwsLambda.domains[0],
        names: AcmeAwsLambda.domains
      )
      order.finalize(csr: csr)

      wait_order_to_complete(order)

      order.certificate
    end

    def wait_order_to_complete(order)
      check_count = 0
      while order.status == 'processing'
        raise('certificate request timeout') if check_count > AcmeAwsLambda.cert_retry_count

        check_count += 1
        sleep(AcmeAwsLambda.cert_retry_timeout)
      end
    end

    def init_aws_client
      aws_config = {
        credentials: ::Aws::Credentials.new(
          AcmeAwsLambda.aws_access_key_id,
          AcmeAwsLambda.aws_secret_access_key,
          AcmeAwsLambda.aws_session_token
        ),
        region: AcmeAwsLambda.aws_region,
        logger: logger,
        log_level: AcmeAwsLambda.log_level
      }

      aws_config[:http_wire_trace] = true if :debug == AcmeAwsLambda.log_level

      ::Aws.config.update(aws_config)
    end

    def client
      @client ||= begin
        private_key = s3.client_key
        if private_key.nil?
          private_key = s3.create_and_save_client_key
          raise('Error to create private key for client') if private_key.nil?
        end
        Acme::Client.new(private_key: private_key, directory: AcmeAwsLambda.acme_directory)
      end
    end

    def create_account
      client.new_account(
        contact: "mailto:#{AcmeAwsLambda.contact_email}",
        terms_of_service_agreed: true
      )
    end

  end
end
