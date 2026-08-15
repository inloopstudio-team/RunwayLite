class ToolCall < ApplicationRecord


  belongs_to :message

  def thought_signature
    replay_payload&.dig("thought_signature")
  end

end
