# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.
begin
  require File.expand_path('config/environment', __dir__)
rescue Exception => e
  Appsignal.send_error(e)
  raise
end
run Rails.application
