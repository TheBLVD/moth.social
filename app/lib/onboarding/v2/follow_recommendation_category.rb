# frozen_string_literal: true

# Represents a grouping of suggested follows that can be followed by new users on moth.social.
# Categories are grouped by theme, eg.: tech, news, art, etc.
module Onboarding
  module V2
    class FollowRecommendationCategory
      # category name
      attr_reader :name
      # Recommended user accounts for this category
      attr_reader :items

      def initialize(name:, items:)
        @name = name
        @items = items
      end

      def self.model_name
        self.class.name
      end

      def read_attribute_for_serialization(key)
        send(key) if respond_to?(key)
      end
    end
  end
end
