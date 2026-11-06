class SystemSetting < ApplicationRecord
  enum :value_type, { string: 0, integer: 1, boolean: 2, json: 3 }

  belongs_to :updated_by_user, class_name: "User", optional: true

  validates :key, presence: true, uniqueness: true
  validate :application_url_format

  def self.valid_application_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    false
  end

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

  private

  def application_url_format
    return unless key == "application_url" && value.present?
    return if self.class.valid_application_url?(value)

    errors.add(:base, "Application link must be a complete http:// or https:// URL without login credentials.")
  end
end
