# frozen_string_literal: true

class MammothChannelFeed < Feed
  def initialize(type, id)
    @type = type.to_sym
    super(@type, id)
  end
end
