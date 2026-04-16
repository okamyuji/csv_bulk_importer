source "https://rubygems.org"

ruby "3.4.8"

# --- Core ---
gem "rails", "~> 8.1.3"
gem "propshaft"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "rack-cors"

# --- DB-backed adapters (Rails 8 defaults) ---
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# --- Auth ---
gem "devise"
gem "devise-jwt"
gem "pundit"

# --- Serialization ---
gem "alba"

# --- AWS (ActiveStorage S3 + direct S3 for chunk splitter) ---
gem "aws-sdk-s3", require: false

# --- Type checking ---
gem "sorbet-runtime"

# --- CSV ---
gem "csv"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bullet"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "syntax_tree", require: false
  gem "erb_lint", require: false

  # Sorbet / Tapioca
  gem "sorbet", require: false
  gem "tapioca", require: false, platforms: %i[ruby]

  # RSpec
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
end

group :test do
  gem "webmock"
  gem "vcr"
  gem "simplecov", require: false
  gem "rails-controller-testing"
end

group :development do
  gem "web-console"
  gem "foreman", require: false
end

group :development, :test do
  gem "dotenv-rails"
end
