# frozen_string_literal: true

require 'openssl'
require 'aws-sdk-s3'

module AcmeAwsLambda
  class S3

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def create_and_save_client_key
      private_key = OpenSSL::PKey::RSA.new(AcmeAwsLambda.key_size)
      obj = s3_resource.bucket(AcmeAwsLambda.s3_bucket).object(AcmeAwsLambda.s3_client_key)
      obj.put(
        acl: 'private',
        body: private_key.to_pem,
        content_disposition: 'attachment; filename="key.pem"',
        content_type: 'application/x-pem-file'
      )
      private_key
    end

    def client_key
      response = s3_client.get_object(
        bucket: AcmeAwsLambda.s3_bucket,
        key: AcmeAwsLambda.s3_client_key
      )
      ::OpenSSL::PKey::RSA.new(response.body.read)
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound => e
      logger.error 'Not found client key on s3'
      logger.error e
      nil
    end

    def certificate
      response = s3_client.get_object(
        bucket: AcmeAwsLambda.s3_bucket,
        key: AcmeAwsLambda.s3_certificate_key
      )
      ::OpenSSL::X509::Certificate.new(response.body.read)
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound => e
      logger.error 'Not found certificate on s3'
      logger.error e
      nil
    end

    def save_certificate(certificate)
      obj = s3_resource.bucket(AcmeAwsLambda.s3_bucket).object(AcmeAwsLambda.s3_certificate_key)
      obj.put(
        acl: 'private',
        body: certificate,
        content_disposition: 'attachment; filename="key.pem"',
        content_type: 'application/x-pem-file'
      )
    end

    private

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        credentials: Aws::Credentials.new(
          AcmeAwsLambda.s3_aws_access_key_id,
          AcmeAwsLambda.s3_aws_secret_access_key,
          AcmeAwsLambda.s3_aws_session_token
        ),
        region: AcmeAwsLambda.s3_aws_region
      )
    end

    def s3_resource
      @s3_resource ||= Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(
          AcmeAwsLambda.s3_aws_access_key_id,
          AcmeAwsLambda.s3_aws_secret_access_key,
          AcmeAwsLambda.s3_aws_session_token
        ),
        region: AcmeAwsLambda.s3_aws_region
      )
    end

  end
end
