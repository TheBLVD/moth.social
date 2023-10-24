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
        
        # Expire Reason in 7 days
        redis.sadd(list_key, reason)
        redis.expire(list_key, 7.day.seconds) 
    end

    def find(status_id)
        list_key = key(status_id)
        results = redis.smembers(list_key).map { |o| 
            payload = Oj.load(o, symbol_keys: true)
            originating_account = Account.create(payload[:originating_account])
            origin = ::StatusOrigin.new(source: payload[:source], id: payload[:id], title: payload[:title], originating_account:originating_account )
            Rails.logger.debug "AR:: ACCOUNT  #{originating_account}"
            Rails.logger.debug "AR:: ORIGIN  #{origin}"
            origin
    }
        Rails.logger.debug "RESULT:: #{results}"

        return results
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
        Oj.dump({source: "SmartList", id: status[:id], title: channel[:title], originating_account: status.account})
    end
  end
end
