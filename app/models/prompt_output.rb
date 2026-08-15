class PromptOutput < ApplicationRecord
  if defined?(ActiveRecord::ConnectionAdapters::LibsqlAdapter)
  serialize :output_json, coder: JSON
  end


  belongs_to :account, optional: true

end
