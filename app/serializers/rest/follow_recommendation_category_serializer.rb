# frozen_string_literal: true

class REST::FollowRecommendationCategorySerializer < ActiveModel::Serializer
  include RoutingHelper
  include FormattingHelper

  attributes :name, :theme_color

  has_many :accounts

  def accounts
    object.accounts.map do |a|
      {
        account: REST::AccountSerializer.new(a[:account]).as_json,
        summary: a[:summary],
      }
    end
  end
end
