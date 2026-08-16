class ToolCall < ApplicationRecord

  json_serialize :arguments
  json_serialize :metadata
  json_serialize :replay_payload


  belongs_to :message

  def thought_signature
    replay_payload&.dig("thought_signature")
  end

end
