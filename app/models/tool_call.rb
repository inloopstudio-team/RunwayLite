class ToolCall < ApplicationRecord
  if defined?(ActiveRecord::ConnectionAdapters::LibsqlAdapter)
  serialize :arguments, coder: JSON
  serialize :metadata, coder: JSON
  serialize :replay_payload, coder: JSON
  end


  belongs_to :message

  def thought_signature
    replay_payload&.dig("thought_signature")
  end

end
