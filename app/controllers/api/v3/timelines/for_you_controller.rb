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
    @account = account_from_acct
  end

  def set_for_you_feed
    should_personalize = validate_owner_account
    if should_personalize
      cached_personalized_statuses
    else
      cached_list_statuses
    end
  end

  # Check account_from_acct finds an account
  # Check the For You Beta Personal List
  # @return [Boolean]
  def validate_owner_account
    if @account.nil?
      return false
    end
    @owner_account = @beta_for_you_list.accounts.without_suspended.includes(:account_stat).where(id: @account.id).first
    !@owner_account.nil?
  end

  # Will not return an empty list
  # If no statuses are found for the user,
  # but they are on the beta list then we return the default Public Feed
  def cached_personalized_statuses
    statuses = cache_collection personalized_for_you_list_statuses, Status
    if statuses.empty?
      cached_list_statuses
    else
      statuses
    end
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

  def personalized_for_you_list_statuses
    personalzied_feed.get(
      limit_param(DEFAULT_STATUSES_LIST_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def personalzied_feed
    ForYouFeed.new('personal', @account.id)
  end

  def default_list
    List.where(account: @default_owner_account, title: LIST_TITLE).first!
  end

  def list_feed
    ForYouFeed.new('foryou', default_list.id)
  end

  def account_from_acct
    resource_user    = acct_param
    username, domain = resource_user.split('@')

    if domain == Rails.configuration.x.local_domain
      domain = nil
    end

    Account.where(username: username, domain: domain).first
  end

  def acct_param
    params.require(:acct)
  end

  # Pagination
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
