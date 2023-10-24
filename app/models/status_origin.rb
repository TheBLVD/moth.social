class StatusOrigin
  include ActiveModel::Model
  include ActiveModel::Serialization

  attr_accessor :source, :channel_id, :title, :originating_account

  def initialize(attributes = {})
    super
  end
  # belongs_to :originating_account, class_name: 'Account'
end
