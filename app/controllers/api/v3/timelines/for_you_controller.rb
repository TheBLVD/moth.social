# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  DEFAULT_STATUSES_LIST_LIMIT = 40
  before_action :set_owner

  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = set_for_you_feed
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  private

  def set_owner
    begin
      @username, @domain = params['acct'].strip.gsub(/\A@/, '').split('@')
      @owner_account = Account.where(username: @username, domain: @domain).first!
    rescue ActiveRecord::RecordNotFound
      @owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    end
  end

  def set_for_you_feed
    if @owner_account.username == FOR_YOU_OWNER_ACCOUNT
      cached_list_statuses
    else
      build_for_you_feed
    end
  end

  def build_for_you_feed
    # Get Fedi Accounts
    Rails.logger.info { "#{@username}@#{@domain}" }
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
    cache_collection list_statuses, Status
  end

  def list_statuses
    list_feed.get(
      limit_param(DEFAULT_STATUSES_LIST_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def default_list
    List.where(account: FOR_YOU_OWNER_ACCOUNT, title: LIST_TITLE).first!
  end

  def list_feed
    ListFeed.new(default_list)
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
