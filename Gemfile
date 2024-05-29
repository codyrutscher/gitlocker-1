source "https://rubygems.org"

ruby "3.3.0"

gem "activerecord-import"
gem "bootsnap", require: false # Reduces boot times through caching; required in config/boot.rb
gem "devise", "~> 4.9"
gem "fog-aws"
gem "friendly_id", "~> 5.5.0"
gem "good_job"
gem "jbuilder"
gem "jsonapi-serializer"
gem "image_processing", "~> 1.2" # Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "importmap-rails"
gem "money-rails", "~> 1.12"
gem "octokit"
gem "omniauth-github", "~> 2.0.0" #Install omniauth-github
gem "omniauth-rails_csrf_protection"
gem "pg", "~> 1.5"
gem "pg_search"
gem "puma", ">= 5.0"
gem "pundit"
gem "rails", "~> 7.1.3"
gem "requestjs-rails"
gem "retriable", "~> 3.1"
gem "sitemap_generator"
gem "sprockets-rails"
gem "stimulus-rails"
gem "stripe-rails"
gem "tailwindcss-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ] # Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "view_component"
gem 'faraday-retry'
gem 'sendgrid-actionmailer'
gem 'sendgrid-ruby'
gem 'aws-sdk-s3', require: false
gem 'rubyzip', '~> 2.3', '>= 2.3.0'
gem 'net-http'
gem 'rest-client'
gem "stripe", "~> 7.0"
gem 'activeadmin'
gem 'sass-rails'

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "rspec-rails", "~> 6.1"
  gem "letter_opener"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  gem "shoulda-matchers", "~> 6.2"
end
