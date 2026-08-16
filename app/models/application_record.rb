class ApplicationRecord < ActiveRecord::Base

  include ObfuscatesId

  primary_abstract_class

  # Use instead of `serialize :col, coder: JSON` — skips on libSQL where json
  # columns auto-deserialize natively and serialize raises ColumnNotSerializableError.
  def self.json_serialize(*attrs)
    return if ActiveRecord::Base.configurations.find_db_config(Rails.env)&.adapter&.include?("libsql")
    attrs.each { |attr| serialize attr, coder: JSON }
  end

  def as_json(options = {})
    hash = super(options)
    hash["id"] = to_param
    hash
  end

end
