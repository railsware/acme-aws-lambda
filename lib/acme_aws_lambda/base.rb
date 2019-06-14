# frozen_string_literal: true

require 'logger'

module AcmeAwsLambda
  module Base

    extend self

    attr_writer :log_level, :log_formatter, :production_mode, :key_size, :contact_email,
                :domains, :common_name, :renew,
                :dns_retry_timeout, :dns_retry_count, :cert_retry_timeout, :cert_retry_count,
                :aws_access_key_id, :aws_secret_access_key, :aws_session_token, :aws_region,
                :s3_aws_access_key_id, :s3_aws_secret_access_key, :s3_aws_session_token,
                :s3_aws_region, :s3_bucket, :s3_client_key, :s3_certificates_key,
                :route53_aws_access_key_id, :route53_aws_secret_access_key, :route53_aws_session_token,
                :route53_aws_region, :route53_domain, :route53_hosted_zone_id

    def configure
      yield self
    end

    def log_level
      @log_level || :info
    end

    def log_formatter
      @log_formatter || Logger::Formatter.new
    end

    def production_mode
      @production_mode || false
    end

    def key_size
      @key_size || 2048
    end

    def contact_email
      @contact_email || raise('contact_email should be defined')
    end

    def domains
      @domains || raise('domains should be defined')
    end

    def common_name
      @common_name
    end

    def renew
      @renew || 30
    end

    def dns_retry_timeout
      @dns_retry_timeout || 4
    end

    def dns_retry_count
      @dns_retry_count || 15
    end

    def cert_retry_timeout
      @cert_retry_timeout || 1
    end

    def cert_retry_count
      @cert_retry_count || 10
    end

    def acme_directory
      if production_mode
        'https://acme-v02.api.letsencrypt.org/directory'
      else
        'https://acme-staging-v02.api.letsencrypt.org/directory'
      end
    end

    def aws_access_key_id
      @aws_access_key_id || ENV['AWS_ACCESS_KEY_ID']
    end

    def aws_secret_access_key
      @aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY']
    end

    def aws_session_token
      @aws_session_token || ENV['AWS_SESSION_TOKEN']
    end

    def aws_region
      @aws_region || ENV['AWS_REGION']
    end

    def s3_aws_access_key_id
      @s3_aws_access_key_id || aws_access_key_id
    end

    def s3_aws_secret_access_key
      @s3_aws_secret_access_key || aws_secret_access_key
    end

    def s3_aws_region
      @s3_aws_region || aws_region
    end

    def s3_aws_session_token
      @s3_aws_session_token || aws_session_token
    end

    def s3_bucket
      @s3_bucket || raise('s3_bucket should be defined')
    end

    def s3_client_key
      @s3_client_key || 'acme/client.pem'
    end

    def s3_certificates_key
      @s3_certificates_key || raise('s3_certificates_key should be defined')
    end

    def certificate_private_key
      "#{s3_certificates_key}.key"
    end

    def certificate_pem_key
      "#{s3_certificates_key}.crt"
    end

    def route53_aws_access_key_id
      @route53_aws_access_key_id || aws_access_key_id
    end

    def route53_aws_secret_access_key
      @route53_aws_secret_access_key || aws_secret_access_key
    end

    def route53_aws_session_token
      @route53_aws_session_token || aws_session_token
    end

    def route53_aws_region
      @route53_aws_region || aws_region
    end

    def route53_domain
      @route53_domain
    end

    def route53_hosted_zone_id
      @route53_hosted_zone_id
    end

  end
end
