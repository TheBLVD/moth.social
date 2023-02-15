# frozen_string_literal: true

class REST::V2::FollowRecommendationCategorySerializer < ActiveModel::Serializer
  include RoutingHelper
  include FormattingHelper

  attributes :name

  has_many :items

  def items
    object.items.map do |a|
      if a[:type] == :account
        REST::AccountSerializer
          .new(a[:name])
          .as_json
          .merge(summary: a[:summary], type: :account)
      else
        a
      end
    end
  end
end
