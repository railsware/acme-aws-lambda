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

You need create file `function.rb` and add this to it:

```ruby
# this two lines fix problem with require gems in AWS lambda
load_paths = Dir["./vendor/bundle/ruby/2.5.0/bundler/gems/**/lib"]
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/railsware/acme-aws-lambda. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Acme::Aws::Lambda project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/railsware/acme-aws-lambda/blob/master/CODE_OF_CONDUCT.md).
