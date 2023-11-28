# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  # TODO: Re-enable with fix
  # before_action :require_mammoth!
  before_action :set_for_you_default, only: [:show]
  after_action :insert_pagination_headers, only: [:show], unless: -> { @statuses.empty? }

  def show
    @statuses = list_statuses
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  private

  def set_for_you_default
    @default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    @account = account_from_acct
  end

  def list_statuses
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

  # Mammoth Picks list
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
