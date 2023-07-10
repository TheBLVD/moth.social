# frozen_string_literal: true

class ForYouFeed < Feed
  def initialize(type = 'personal', id)
    @type = type.to_sym
    case @type
    when :personal
      super(:personal, id)
    when :foryou
      super(:foryou, id)
    end
  end
end
