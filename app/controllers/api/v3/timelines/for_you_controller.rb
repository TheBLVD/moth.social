# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  DEFAULT_STATUSES_LIST_LIMIT = 40
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  before_action :set_list

  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = set_for_you_feed
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  private

  def set_list
    @owner_account = set_owner
    @list = List.where(account: @owner_account, title: LIST_TITLE).first!
  end

  def set_owner
    if params['acct']
      @username, @domain = params['acct'].strip.gsub(/\A@/, '').split('@')
      account = Account.where(username: @username, domain: @domain).first!
      return account unless account.nil?
    else
      Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    end
  end

  def set_for_you_feed
    if @owner_account.username == FOR_YOU_OWNER_ACCOUNT
      cached_list_statuses
    else
      build_for_you_feed
    end
  end

  def build_for_you_feed; end

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

  def list_feed
    ListFeed.new(@list)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def next_path
    api_v2_timelines_for_you_url pagination_params(max_id: pagination_max_id)
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
