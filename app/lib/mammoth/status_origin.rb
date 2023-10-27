# frozen_string_literal: true
# rubocop:disable all
require 'singleton'

module Mammoth

    class StatusOrigin
        include Singleton
        include Redisable
    class NotFound < StandardError; end

    # Add Trending Follows and Reason
    def add_trending_follows(status, user)
        list_key = key(user[:acct], status[:id])
        reason = trending_follow_reason(status)

        add_reason(list_key, reason)
    end 

    # Add FOF and Reason to list
    def add_friends_of_friends(status, user)
        list_key = key(user[:acct], status[:id])
        reason = trending_fof_reason(status)

        add_reason(list_key, reason)
    end

    # Add Status and Reason to list
    def add_channel(status, channel)
        list_key = key(status[:id])
        reason = channel_reason(status, channel)
        
        add_reason(list_key, reason)
    end

    # Add MammothPick and Reason to list
    def add_mammoth_pick(status)
        list_key = key(status[:id])
        reason = mammoth_pick_reason(status)

        add_reason(list_key, reason)
    end 

    # Add reason by key id
    # Expire Reason in 7 days
    def add_reason(key, reason)
        redis.sadd(key, reason)
        redis.expire(key, 7.day.seconds) 
    end 

    def find(status_id, acct = nil)
        Rails.logger.debug "STATUS_ID & ACCT:  #{status_id}  #{acct}"
        public_list_key = key(status_id)
        personal_list_key = key(acct, status_id)
        Rails.logger.debug "PUBLIC KEY #{public_list_key}"
        Rails.logger.debug "PERSONAL KEY #{personal_list_key}"
        results = redis.smembers(public_list_key).map { |o| 
            payload = Oj.load(o, symbol_keys: true)

            originating_account = Account.find(payload[:originating_account_id])
            # StatusOrigin Active Model for serialization
            ::StatusOrigin.new(source: payload[:source], channel_id: payload[:channel_id], title: payload[:title], originating_account:originating_account )
        }

        Rails.logger.debug "MEMBER RESULTS:: #{results}"
        # Throw Error if array find is empty
        raise NotFound, 'status not found' unless results.length > 0 
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
        Oj.dump({source: "SmartList", channel_id: channel[:id], title: channel[:title], originating_account_id: status.account[:id]})
    end

    def mammoth_pick_reason(status)
        Oj.dump({source: "MammothPick", originating_account_id: status.account[:id] })
    end

    def trending_follow_reason(status)
        Oj.dump({source: "TrendingFollows", originating_account_id: status.account[:id] })
    end

    def trending_fof_reason(status)
        Oj.dump({source: "FriendsOfFriends", originating_account_id: status.account[:id] })
    end
  end
end
