# frozen_string_literal: true

class REST::FollowRecommendationCategorySerializer < ActiveModel::Serializer
  include RoutingHelper
  include FormattingHelper

  attributes :name, :theme_color

  has_many :accounts, each_serializer: REST::FollowRecommendationAccountSerializer
end
