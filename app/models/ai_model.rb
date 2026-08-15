class AiModel < ApplicationRecord
  if defined?(ActiveRecord::ConnectionAdapters::LibsqlAdapter)
  serialize :modalities, coder: JSON
  serialize :capabilities, coder: JSON
  serialize :pricing, coder: JSON
  serialize :metadata, coder: JSON
  end


  has_many :chats

end
