# frozen_string_literal: true

class ForYouFeed < Feed
  def initialize(type = 'personal', id)
    @type = type.to_sym
    @id = id

    case @type
    when :personal
      super(:personal, id)
    when :foryou
      super(:foryou, id)
    end
  end

  # If there is an foryou feed
  # redis returns 1 for true, 0 for false
  def exists?
    redis.exists(key) == 1
  end

  def key
    FeedManager.instance.key(@type, @id)
  end
end
