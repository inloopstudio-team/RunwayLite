class PromptOutput < ApplicationRecord

  serialize :output_json, coder: JSON

  belongs_to :account, optional: true

end
