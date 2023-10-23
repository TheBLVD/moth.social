# frozen_string_literal: true
# rubocop:disable all
require 'singleton'

module Mammoth

    class StatusOrigin
        include Singleton
        include Redisable
    class NotFound < StandardError; end

    
    # Add Status and Reason to list
    def add_channel(status, channel)
        list_key = key(status[:id])
        reason = channel_reason(status, channel)
        
        redis.sadd(list_key,reason)
        
        # Keep the list from growning infinitely
        # trim(timeline_key, account_id)
    end

    private 

    # Redis key of a status
    # @param [Integer] status id
    # @param [Symbol] subtype
    # @return [String]
    def key(id, subtype = nil)
    return "origin:for_you:#{id}" unless subtype

    "origin:for_you:#{id}:#{subtype}"
    end

    def channel_reason(status, channel)
        OJ.dump({source: "SmartList", title: channel[:title], originating_account: status[:account]})
    end
  end
end
