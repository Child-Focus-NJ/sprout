class SystemSetting < ApplicationRecord
  enum :value_type, { string: 0, integer: 1, boolean: 2, json: 3 }

  belongs_to :updated_by_user, class_name: "User", optional: true

  validates :key, presence: true, uniqueness: true

  def parsed_value
    case value_type
    when "string"
      value
    when "integer"
      value.to_i
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(value)
    when "json"
      JSON.parse(value) rescue nil
    end
  end

  def self.get(key)
    find_by(key: key)&.parsed_value
  end

  def self.set(key, value, type: :string, description: nil, user: nil)
    setting = find_or_initialize_by(key: key)
    setting.value = type == :json ? value.to_json : value.to_s
    setting.value_type = type
    setting.description = description if description
    setting.updated_by_user = user if user
    setting.save!
    setting
  end
end
