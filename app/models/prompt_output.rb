class PromptOutput < ApplicationRecord
  json_serialize :output_json


  belongs_to :account, optional: true

end
