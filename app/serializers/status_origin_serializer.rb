class StatusOriginSerializer < ActiveModel::Serializer
  attributes :source, :title

  belongs_to :originating_account, serializer: REST::AccountSerializer
end
