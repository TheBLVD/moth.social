require 'ddtrace'

if Rails.env.production? || Rails.env.staging?
  Datadog.configure do |c|
    c.env = Rails.env
    c.service = 'moth.social'
    c.tracing.instrument :httprb, service_name: 'moth.social'
    c.tracing.instrument :faraday, service_name: 'moth.social'
    c.tracing.instrument :active_support, service_name: 'moth.social'
    c.tracing.instrument :http, service_name: 'moth.social'
  end
end
