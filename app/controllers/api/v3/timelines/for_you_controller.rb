# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  before_action :set_for_you_default, only: [:show]

  after_action :insert_pagination_headers, only: [:show], unless: -> { @statuses.empty? }

  def index
    result = PersonalForYou.new.user(acct_param)
    render json: result
  end

  def show
    @statuses = set_for_you_feed
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  # When Updating User with new settings
  # Update status to 'pending'
  # Also need to trigger a clear & rebuild of their personal for you feed
  def update
    payload = for_you_params
    payload[:status] = 'pending'
    result = PersonalForYou.new.update_user(acct_param, payload)

    UpdateForYouWorker.perform_async(acct_param, { rebuild: true })
    render json: result
  end

  private

  def set_for_you_default
    @default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    @beta_for_you_list = List.where(account: @default_owner_account, title: BETA_FOR_YOU_LIST).first!
    @account = account_from_acct
    @is_beta_program = beta_param
  end

  def set_for_you_feed
    should_personalize = validate_owner_account
    if should_personalize
      # Getting personalized
      fufill_personalized_statuses
    else
      # Getting the public feed
      enroll_beta
      cached_list_statuses
    end
  end

  # Check for account on the peronalized list
  # AND that account personalized feed is NOT empty.
  def for_you_feed_type
    if validate_owner_account && !cached_personalized_statuses.empty?
      'personal'
    else
      'public'
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

  # Only checking for beta parameter
  # After we've validated the acct is NOT on the beta list
  # So if you're already on the beta list we're not going add them
  def enroll_beta
    if @is_beta_program
      # Add to beta enrollment list
      for_you = ForYouBeta.new
      for_you.add_to_enrollment(acct_param)
    end
  end

  # Will not return an empty list
  # If no statuses are found for the user,
  # but they are on the beta list then we return the default Public Feed
  def fufill_personalized_statuses
    statuses = cached_personalized_statuses
    if statuses.empty?
      cached_list_statuses
    else
      statuses
    end
  end

  def cached_personalized_statuses
    cache_collection personalized_for_you_list_statuses, Status
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

  def for_you_params
    params.permit(
      :acct,
      :curated_by_mammoth,
      :friends_of_friends,
      :from_your_channels,
      :your_follows
    ).except('acct')
  end

  # Used to indicate beta group
  # for testflight
  def beta_param
    unless params[:beta].nil?
      params[:beta].casecmp('true').zero?
    end
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
