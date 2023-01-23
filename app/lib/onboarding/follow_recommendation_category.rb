# frozen_string_literal: true

# Represents a grouping of suggested accounts that can be followed by new users on moth.social.
# Categories are grouped by theme, eg.: tech, news, art, etc.
module Onboarding
  class FollowRecommendationCategory
    # category name
    attr_reader :name
    # rgba hex string
    attr_reader :theme_color
    # Recommended user accounts for this category
    attr_reader :accounts

    def initialize(name:, theme_color:, accounts:)
      @name = name
      @theme_color = theme_color
      @accounts = accounts
    end

    def self.model_name
      self.class.name
    end

    def read_attribute_for_serialization(key)
      send(key) if respond_to?(key)
    end
  end
end
