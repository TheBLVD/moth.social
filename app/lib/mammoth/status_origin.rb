# frozen_string_literal: true
# rubocop:disable all
require 'singleton'

module Mammoth

    class StatusOrigin
        include Singleton
        include Redisable
    class NotFound < StandardError; end

    MAX_ITEMS = 5000

    # Add Trending Follows and Reason
    def bulk_add_trending_follows(statuses, user)
        reasons = statuses.map do |s| 
            list_key = key(user[:acct], s[:id])
            reason = trending_follow_reason(s)
             {key: list_key, id: s[:id], reason: reason}
        end 
        bulk_reasons(user, reasons)
    end 

    # Add FOF and Reason to list
    def bulk_add_friends_of_friends(statuses, user)
        reasons = statuses.map do |s| 
            list_key = key(user[:acct], s[:id])
            reason = trending_fof_reason(s)
             {key: list_key, id: s[:id], reason: reason}
        end 
        bulk_reasons(user, reasons)
    end

    def bulk_add_channel(statuses, user, channel)
        reasons = statuses.map do |s| 
            list_key = key(user[:acct], s[:id])
            reason = channel_reason(s, channel)
             {key: list_key, id: s[:id], reason: reason}
        end 
        bulk_reasons(user, reasons)
    end 
     
    # Array of statuses
    def bulk_add_mammoth_pick(statuses, user)
        reasons = statuses.map do |s| 
            list_key = key(user[:acct], s[:id])
            reason = mammoth_pick_reason(s)
             {key: list_key, id: s[:id], reason: reason}
        end 
        bulk_reasons(reasons)
    end 
    
    def bulk_reasons(user, reasons)
        user_list_key = key(user[:acct])
        Rails.logger.info "USER LIST KEY #{user_list_key}"
        redis.pipelined do |p|
            reasons.each do |r|
                p.zadd(user_list_key, 0, r[:key])
                p.zadd(r[:key], r[:id], r[:reason])
                p.expire(r[:key], 1.day.seconds)
            end
        end 

        # Regular Trimming of items keeps it from growing out of control
        trim(user)
    end 

    def find(status_id, acct = nil)
        personal_list_key = key(acct, status_id)
        results = redis.zrange(personal_list_key, 0, -1).map { |o| 
            payload = Oj.load(o, symbol_keys: true)

            originating_account = Account.find(payload[:originating_account_id])
            # StatusOrigin Active Model for serialization
            ::StatusOrigin.new(source: payload[:source], channel_id: payload[:channel_id], title: payload[:title], originating_account:originating_account )
        }

        # Throw Error if array find is empty
        raise NotFound, 'status not found' unless results.length > 0 
        return results
    end 


    # Delete All Status Origins by username
    # ALERT: extra check to ensure a valid acct handle is passed.  
    def reset(acct)
        username, domain = acct.strip.gsub(/\A@/, '').split('@')
        return nil unless username && domain

        user_list_key = key("#{username}@#{domain}")
        keys_to_purge = redis.zrange(user_list_key, 0, -1)
        redis.pipelined do |p|
            p.del(keys_to_purge)
            p.del(user_list_key)
        end 

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

    # Find items from 1000 - end of the  list
    # Then del them
    def trim(user)
        user_list_key = key(user[:acct])
        keys_to_purge = redis.zrange(user_list_key, MAX_ITEMS, -1)
        redis.pipelined do |p|
            p.del(keys_to_purge)
        end
    end 

    end

end
