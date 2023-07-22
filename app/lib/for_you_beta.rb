# frozen_string_literal: true

class ForYouBeta
  include Redisable

  def add_to_enrollment(handle)
    key = key()
    redis.sadd(key, handle)
  end

  def enrollment_list
    key = key()
    redis.smembers(key)
  end

  private

  def key
    'beta_enrollment:v1:accounts'
  end
end
