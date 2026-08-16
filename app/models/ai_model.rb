class AiModel < ApplicationRecord
  json_serialize :modalities
  json_serialize :capabilities
  json_serialize :pricing
  json_serialize :metadata


  has_many :chats

end
