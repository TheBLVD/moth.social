# frozen_string_literal: true

class REST::FollowRecommendationAccountSerializer < ActiveModel::Serializer
  include RoutingHelper
  include FormattingHelper

  attributes :summary
  has_one :account, serializer: REST::AccountSerializer
end
