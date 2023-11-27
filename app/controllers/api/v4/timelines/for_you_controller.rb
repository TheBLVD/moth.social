# frozen_string_literal: true

# Serving Mammoth 2.0
class Api::V4::Timelines::ForYouController < Api::BaseController
  # TODO: Re-enable with fix
  # before_action :require_mammoth!
  before_action :set_for_you_default, only: [:show]
  after_action :insert_pagination_headers, only: [:show], unless: -> { @statuses.empty? }

  rescue_from PersonalForYou::Error do |exception|
    render json: { error: exception }, status: 404
  end

  # Return Mammoth User Profile w/ foryou settings
  # api/v4/foryou/users/me/:acct
  def index
    result = PersonalForYou.new.mammoth_user_profile(acct_param)
    render json: result
  end

  # Return Mammoth User ForYou Feed
  # api/v4/foryou/users/:acct
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

    # Set Queue specificly for a rebuild
    UpdateForYouWorker.set(queue: 'mammoth_critial').perform_async({ acct: acct_param, rebuild: true })
    render json: result
  end

  private

  def set_for_you_default
    @default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    @account = account_from_acct
    @user = user_from_param
  end

  # Check user is personalzied
  # If they are get their foryou feed
  # Otherwise send them MammothPicks
  # TODO: overload foryou tasks, fallback to MammothPicks here.
  def set_for_you_feed
    if personalized_feed?
      # Getting personalized
      fufill_foryou_statuses
    else
      cached_list_statuses
    end
  end

  # Check account_from_acct finds an account
  # Check AccountRelay that they are a Mammoth 2.0 User
  # Check that there is personalized feed generated for them
  # @return [Boolean]
  def personalized_feed?
    return false if @account.nil? || !personalzied_feed.exists?

    PersonalForYou.new.mammoth_user?(acct_param)
  end

  # Determined to be a Mammoth 2.0 user
  # Return Personalized ForYou Feed
  def fufill_foryou_statuses
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
    ForYouFeed.new('personal', @user[:acct])
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

    domain = nil if domain == Rails.configuration.x.local_domain

    Account.where(username: username, domain: domain).first
  end

  def user_from_param
    PersonalForYou.new.user(acct_param)
  end

  def acct_param
    params.require(:acct)
  end

  def for_you_params
    params.permit(
      :acct,
      [enabled_channels: []],
      :curated_by_mammoth,
      :friends_of_friends,
      :from_your_channels,
      :your_follows
    ).except('acct')
  end

  # Pagination
  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def next_path
    api_v4_timelines_for_you_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v4_timelines_for_you_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
