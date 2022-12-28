require 'ddtrace'

if Rails.env.production?
  Datadog.configure do |c|
    c.env = 'production'
    c.service = 'moth.social'
    c.tracing.instrument :rails, **options
  end
end
