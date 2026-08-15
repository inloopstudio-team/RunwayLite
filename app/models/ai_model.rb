class AiModel < ApplicationRecord

  serialize :modalities, coder: JSON
  serialize :capabilities, coder: JSON
  serialize :pricing, coder: JSON
  serialize :metadata, coder: JSON

  has_many :chats

end
