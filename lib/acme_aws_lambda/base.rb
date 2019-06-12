# frozen_string_literal: true

module AcmeAwsLambda
  module Base

    module_function

    attr_writer :log_level,
                :aws_access_key_id, :aws_secret_access_key, :aws_region,
                :s3_aws_access_key_id, :s3_aws_secret_access_key, :s3_aws_region, :s3_bucket, :s3_client_key,
                :route53_aws_access_key_id, :route53_aws_secret_access_key, :route53_aws_region, :route53_domain

    def configure
      yield self
    end

    def log_level
      @log_level || :info
    end

    def aws_access_key_id
      @aws_access_key_id || ENV['AWS_ACCESS_KEY_ID']
    end

    def aws_secret_access_key
      @aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY']
    end

    def aws_region
      @aws_region
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

    def s3_bucket
      @s3_bucket || raise('s3_bucket should be defined')
    end

    def s3_client_key
      @s3_client_key || 'acme/client.pem'
    end

    def route53_aws_access_key_id
      @route53_aws_access_key_id || aws_access_key_id
    end

    def route53_aws_secret_access_key
      @route53_aws_secret_access_key || aws_secret_access_key
    end

    def route53_aws_region
      @route53_aws_region || aws_region
    end

    def route53_domain
      @route53_domain
    end

  end
end
