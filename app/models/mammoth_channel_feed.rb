# frozen_string_literal: true

class MammothChannelFeed < Feed
  def initialize(channel)
    super(:channel, channel[:id])
  end
end
