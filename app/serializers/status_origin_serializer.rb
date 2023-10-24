class StatusOriginSerializer < ActiveModel::Serializer
  attributes :source, :title, :id

  belongs_to :originating_account, serializer: REST::AccountSerializer
end
