# frozen_string_literal: true

require 'digest'
require 'aws-sdk-s3'

module AcmeAwsLambda
  class S3

    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def save_client_key(private_key)
      obj = s3_resource.bucket(AcmeAwsLambda.s3_bucket).object(AcmeAwsLambda.s3_client_key)
      obj.put(
        acl: 'private',
        body: private_key,
        content_disposition: 'attachment; filename="key.pem"',
        content_type: 'application/x-pem-file',
        metadata: {
          'sha256' => Digest::SHA256.hexdigest(private_key)
        }
      )
    end

    def client_key
      response = s3_client.get_object(
        bucket: AcmeAwsLambda.s3_bucket,
        key: AcmeAwsLambda.s3_client_key
      )
      response.body.read
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound => e
      logger.error 'Not found client key on s3'
      logger.error e
      nil
    end

    def private_key
      response = s3_client.get_object(
        bucket: AcmeAwsLambda.s3_bucket,
        key: AcmeAwsLambda.certificate_private_key
      )
      response.body.read
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound => e
      logger.error 'Not found private key on s3'
      logger.error e
      nil
    end

    def pem_certificate
      response = s3_client.get_object(
        bucket: AcmeAwsLambda.s3_bucket,
        key: AcmeAwsLambda.certificate_pem_key
      )
      response.body.read
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound => e
      logger.error 'Not found certificate on s3'
      logger.error e
      nil
    end

    def save_certificates(common_name, key, crt)
      filename = common_name || 'cert'
      bucket = s3_resource.bucket(AcmeAwsLambda.s3_bucket)
      # upload private key
      obj = bucket.object(AcmeAwsLambda.certificate_private_key)
      obj.put(
        acl: 'private',
        body: key,
        content_disposition: "attachment; filename=\"#{filename}.key\"",
        content_type: 'application/x-pem-file',
        metadata: {
          'sha256' => Digest::SHA256.hexdigest(key)
        }
      )
      # upload pem certificate
      obj = bucket.object(AcmeAwsLambda.certificate_pem_key)
      obj.put(
        acl: 'private',
        body: crt,
        content_disposition: "attachment; filename=\"#{filename}.crt\"",
        content_type: 'application/x-pem-file',
        metadata: {
          'sha256' => Digest::SHA256.hexdigest(crt)
        }
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
