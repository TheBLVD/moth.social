class StatusOriginSerializer < ActiveModel::Serializer
  attributes :source, :title, :channel_id

  belongs_to :originating_account, serializer: REST::AccountSerializer
end
