# frozen_string_literal: true

require 'acme_aws_lambda/version'
require 'acme_aws_lambda/base'
require 'acme_aws_lambda/key_manager'
require 'acme_aws_lambda/s3'
require 'acme_aws_lambda/route53'

module AcmeAwsLambda

  extend Base

  class << self

    def create_or_renew_cert
      AcmeAwsLambda::KeyManager.new.create_or_renew_cert
    end

    def revoke_certificate
      AcmeAwsLambda::KeyManager.new.revoke_certificate
    end

  end

end
