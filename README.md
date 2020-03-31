# Acme Aws Lambda

This gem allow to create, renew or revoke Letsencrypt certificate by using AWS Lambda, AWS Route53 and AWS S3.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'acme-aws-lambda'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install acme-aws-lambda

## Usage

You need create file `function.rb` and add this to it (runtime: Ruby 2.7):

```ruby
# this two lines fix problem with require gems in AWS lambda
load_paths = Dir["./vendor/bundle/ruby/2.7.0/bundler/gems/**/lib"]
$LOAD_PATH.unshift(*load_paths)
# require gem
require 'acme_aws_lambda'

AcmeAwsLambda.configure do |config|
  config.production_mode = true
  config.contact_email = 'admin@example.com'
  config.domains = ['example.com', '*.example.com']
  config.common_name = '*.example.com'
  config.s3_bucket = 'example.com-certificates'
  config.s3_certificates_key = 'certificates/example.com'
  config.route53_domain = 'example.com'
  config.after_success = -> (data) {
    puts data[:cert] # certificate
    puts data[:key] # private key
  }
end

def handler(event:, context:)
  AcmeAwsLambda.create_or_renew_cert
end
```

Next you need run in terminal:

```bash
$ bundle install --path vendor/bundle --clean
$ zip -r function.zip function.rb vendor
```

File `function.zip` need to be uploaded to AWS lambda.

In result AWS S3 will contain private key `certificates/example.com.key` and certificate `certificates/example.com.crt`

## Configuration

Configuration params:

| **Name**                      | _Default_                                    | _Variants_                                         | **Description**                                                                                                                                                                    |
|-------------------------------|----------------------------------------------|----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| log_level                     | `:info`                                      | `:info`, `:debug`, `:warn`, `:error`               | Log lever for app                                                                                                                                                                  |
| log_formatter                 | `Logger::Formatter.new`                      | Any custom log formater                            | Log formater                                                                                                                                                                       |
| production_mode               | `false`                                      | `true` or `false`                                  | For testing purpose better to use staging acme server and only after success activate production                                                                                   |
| key_size                      | 2048                                         | 2048, 4096, etc                                    | Size for generated RSA private key                                                                                                                                                 |
| contact_email                 |                                              | email address                                      | Email address for letsencrypt account                                                                                                                                              |
| domains                       | []                                           | array of strings                                   | List of a domains for certificate                                                                                                                                                  |
| common_name                   |                                              | domain, which should match one from `domains` list | Common name for certificate                                                                                                                                                        |
| renew                         | 30                                           | days                                               | Max days for certificate expiration, when app start renew process                                                                                                                  |
| same_private_key_on_renew     | `false`                                      | `true` or `false`                                  | Use same private key for certificate renew                                                                                                                                         |
| dns_retry_timeout             | `4`                                          | seconds                                            | Timeout between check dns changes                                                                                                                                                  |
| dns_retry_count               | `15`                                         | count                                              | Max amount of DNS records check, before fail                                                                                                                                       |
| cert_retry_timeout            | `1`                                          | seconds                                            | Timeout between check certificates is ready                                                                                                                                        |
| cert_retry_count              | `10`                                         | count                                              | Max amount of certification ready check, before fail                                                                                                                               |
| after_success                 | `nil`                                        | function                                           | Hook, which will be executed, if function generated new or renew certificate                                                                                                       |
| aws_access_key_id             | `AWS_ACCESS_KEY_ID` environment variable     |                                                    | AWS access key for AWS S3 and Route53 access                                                                                                                                       |
| aws_secret_access_key         | `AWS_SECRET_ACCESS_KEY` environment variable |                                                    | AWS secret access key for AWS S3 and Route53 access                                                                                                                                |
| aws_session_token             | `AWS_SESSION_TOKEN` environment variable     |                                                    | AWS session token for AWS S3 and Route53 access (not required)                                                                                                                     |
| aws_region                    | `AWS_REGION` environment variable            |                                                    | AWS Region                                                                                                                                                                         |
| s3_aws_access_key_id          | fallback to `aws_access_key_id`              |                                                    | Change AWS access key for AWS S3                                                                                                                                                   |
| s3_aws_secret_access_key      | fallback to `aws_secret_access_key`          |                                                    | Change AWS secret access key for AWS S3                                                                                                                                            |
| s3_aws_session_token          | fallback to `aws_session_token`              |                                                    | Change AWS session token for AWS S3                                                                                                                                                |
| s3_aws_region                 | fallback to `aws_region`                     |                                                    | Change AWS region for AWS S3                                                                                                                                                       |
| s3_bucket                     |                                              |                                                    | AWS S3 bucket name to store acme client key and certificate                                                                                                                        |
| s3_client_key                 | `acme/client.pem`                            |                                                    | Path on AWS S3 where to store and get Acme client key                                                                                                                              |
| s3_certificates_key           |                                              |                                                    | Path on AWS S3 where to store and get private key and certificate. Private key will get path `<s3_certificates_key>.key` and certificate will get path `<s3_certificates_key>.crt` |
| route53_aws_access_key_id     | fallback to `aws_access_key_id`              |                                                    | Change AWS access key for AWS Route53                                                                                                                                              |
| route53_aws_secret_access_key | fallback to `aws_secret_access_key`          |                                                    | Change AWS secret access key for AWS Route53                                                                                                                                       |
| route53_aws_session_token     | fallback to `aws_session_token`              |                                                    | Change AWS session token for AWS Route53                                                                                                                                           |
| route53_aws_region            | fallback to `aws_region`                     |                                                    | Change AWS region for AWS Route53                                                                                                                                                  |
| route53_domain                |                                              |                                                    | Name for domain in AWS Route53, where will added records for Acme verification process. Ignored, if set `route53_hosted_zone_id`                                                   |
| route53_hosted_zone_id        |                                              |                                                    | Hosted Zone ID inside AWS Route53, where will added records for Acme verification process                                                                                          |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/railsware/acme-aws-lambda. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Acme Aws Lambda project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/railsware/acme-aws-lambda/blob/master/CODE_OF_CONDUCT.md).
