require 'ddtrace'

if Rails.env.production? || Rails.env.staging?
  Datadog.configure do |c|
    c.env = Rails.env
    c.service = 'moth.social'
  end
end
