# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  before_action :set_for_you_default

  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = set_for_you_feed
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  private

  def set_for_you_default
    @default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    @beta_for_you_list = List.where(account: @default_owner_account, title: BETA_FOR_YOU_LIST).first!
  end

  def set_for_you_feed
    should_personalize = validate_owner_account
    if should_personalize
      for_you_feed
    else
      cached_list_statuses
    end
  end

  # Check the For You Beta Personal List
  # @return [Boolean]
  def validate_owner_account
    # TODO: Verify Local DOMAIN
    @username, @domain = params['acct'].strip.gsub(/\A@/, '').split('@')

    @owner_account = @beta_for_you_list.accounts.without_suspended.includes(:account_stat).where(username: @username,
                                                                                                 domain: @domain).first
    !@owner_account.nil?
  end

  def for_you_feed
    # Get Fedi Accounts
    Rails.logger.debug { "#{@username}@#{@domain}" }
    fedi_account_handles = FollowRecommendationsService.new.call(handle: "#{@username}@#{@domain}")
    # Get Account id's for all of them
    username_query = Array.[]
    domain_query = Array.[]
    fedi_account_handles.each do |handle|
      h = handle.split('@')
      username_query.push(h[0])
      domain_query.push(h[1])
    end
    # Array of account id's
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    Rails.logger.info { "ACCOUNT_IDS>>>>>> #{account_ids.inspect}" }
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 24.hours.ago..Time.now).limit(40)
  end

  def cached_list_statuses
    cache_collection general_for_you_list_statuses, Status
  end

  def general_for_you_list_statuses
    list_feed.get(
      limit_param(DEFAULT_STATUSES_LIST_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def default_list
    List.where(account: @default_owner_account, title: LIST_TITLE).first!
  end

  def list_feed
    ForYouFeed.new('foryou', default_list.id)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def next_path
    api_v3_timelines_for_you_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v3_timelines_for_you_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
