# frozen_string_literal: true
# rubocop:disable all
require 'singleton'

module Mammoth

    class StatusOrigin
        include Singleton
        include Redisable
    class NotFound < StandardError; end

    MAX_ITEMS = 1000

    # Add Trending Follows and Reason
    def add_trending_follows(status, user)
        list_key = key(user[:acct], status[:id])
        reason = trending_follow_reason(status)

        add_reason(list_key, status[:id], reason)
    end 

    # Add FOF and Reason to list
    def add_friends_of_friends(status, user)
        list_key = key(user[:acct], status[:id])
        reason = trending_fof_reason(status)

        add_reason(list_key, status[:id], reason)
    end

    # Add Status and Reason to list
    def add_channel(status, user, channel)
        list_key = key(user[:acct], status[:id])
        reason = channel_reason(status, channel)
        
        add_reason(list_key, status[:id], reason)
    end

    # Add MammothPick and Reason to list
    def add_mammoth_pick(status, user)
        list_key = key(user[:acct], status[:id])
        reason = mammoth_pick_reason(status)

        add_reason(list_key, status[:id], reason)
    end 

    # Array of statuses
    def bulk_add_mammoth_pick(statuses, user)
        reasons = statuses.map do |s| 
            list_key = key(user[:acct], s[:id])
            reason = mammoth_pick_reason(s)
            return {key: list_key, id: s[:id], reason: reason}
        end 
    end 

    def bulk_reasons(reasons)
        redis.pipeline do |p|
            reasons.each do |r|
                p.zadd(r[:key], r[:id], r[:reason])
                p.expire(r[:key], 1.day.seconds)
            end
        end 
    end 

    # Add reason by key id
    # Expire Reason in 2 days
    def add_reason(key, status_id, reason)
        redis.pipelined do |pipeline|
            pipeline.zadd(key, status_id, reason)
            pipeline.expire(r[:key], 1.day.seconds)
          end
    end 

    def find(status_id, acct = nil)
        personal_list_key = key(acct, status_id)
        results = redis.smembers(personal_list_key).map { |o| 
            payload = Oj.load(o, symbol_keys: true)

            originating_account = Account.find(payload[:originating_account_id])
            # StatusOrigin Active Model for serialization
            ::StatusOrigin.new(source: payload[:source], channel_id: payload[:channel_id], title: payload[:title], originating_account:originating_account )
        }

        # Throw Error if array find is empty
        raise NotFound, 'status not found' unless results.length > 0 
        return results
    end 

     # Trim a feed to maximum size by removing older items
  # @param [Integer] foryou_key
  # @return [void]
  def trim(key)
    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(key, 0, -(MAX_ITEMS + 1))
  end

    # Delete All Status Origins by username
    # ALERT: extra check to ensure a valid acct handle is passed.  
    def reset(acct)
        username, domain = acct.strip.gsub(/\A@/, '').split('@')
        return nil unless username && domain

        list_key = key("#{username}@#{domain}")
        redis.keys("#{list_key}*").each { |key| redis.del(key) }
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
        Oj.dump({source: "SmartList", channel_id: channel[:id], title: channel[:title], originating_account_id: status[:account_id]})
    end

    def mammoth_pick_reason(status)
        Oj.dump({source: "MammothPick", originating_account_id: status[:account_id] })
    end

    def trending_follow_reason(status)
        Oj.dump({source: "Follows", originating_account_id: status.account[:id] })
    end

    def trending_fof_reason(status)
        Oj.dump({source: "FriendsOfFriends", originating_account_id: status.account[:id] })
    end
  end
end
