# frozen_string_literal: true

# Mammoth Generated JWT Token Decrypt
# If no MAMMOTH_SECRET_KEY is set, decode is bypassed entirely.
class JsonToken
  SECRET_KEY = ENV.fetch('MAMMOTH_SECRET_KEY', nil)

  def self.decode(token)
    return unless SECRET_KEY
    decoded = JWT.decode(token, SECRET_KEY)[0]
    ActiveSupport::HashWithIndifferentAccess.new decoded
  end
end
