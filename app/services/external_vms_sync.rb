# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "uri"

class ExternalVmsSync
  BASE_URL_ENV_KEY = "EXTERNAL_VMS_URL"
  USERNAME_ENV_KEY = "EXTERNAL_VMS_USERNAME"
  PASSWORD_ENV_KEY = "EXTERNAL_VMS_PASSWORD"
  DEFAULT_BASE_URL = "https://nj-passaic.evintotraining.com"
  DEFAULT_PAGE_SIZE = 50
  DEFAULT_ORDER_BY = "Inquired-desc"
  ACTIVE_STATUS = "active"
  SOURCE_NAME = "external_vms"
  DATE_FORMAT = "%m/%d/%Y"
  ASP_NET_DATE_PATTERN = %r{/Date\((\d+)\)/}
  CSRF_PATTERN = /name="__RequestVerificationToken"[^>]*value="([^"]+)"/
  FIELD_ALIASES = {
    "EncyptedPartyID" => "encrypted_party_id",
    "EncryptedID" => "encrypted_id",
    "InquiryID" => "inquiry_id",
    "PartyID" => "party_id",
    "ProgramID" => "program_id",
    "CountyID" => "county_id"
  }.freeze

  attr_reader :synced_volunteers

  def initialize(page_size: DEFAULT_PAGE_SIZE)
    @page_size = page_size
    @cookies = {}
    @synced_volunteers = []
  end

  def sync!
    login!
    records = list_active_inquiries

    ActiveRecord::Base.transaction do
      records.each do |record|
        volunteer = upsert_volunteer!(record)
        upsert_inquiry_submission!(volunteer, record)
        record_successful_sync!(volunteer, record)
        @synced_volunteers << volunteer
      end
    end

    @synced_volunteers
  rescue StandardError => e
    ExternalSyncLog.create!(
      sync_type: :pull,
      sync_direction: :inbound,
      status: :failed,
      started_at: Time.current,
      completed_at: Time.current,
      records_processed: @synced_volunteers.size,
      error_message: e.message
    )
    raise
  end

  private

  def login!
    response = get("/Account/LogOn")
    token = response.body.to_s.match(CSRF_PATTERN)&.[](1)

    form_data = {
      "UserName" => username,
      "Password" => password
    }
    form_data["__RequestVerificationToken"] = token if token.present?

    post_form("/Account/LogOn", form_data)
    raise "External VMS login failed" unless @cookies[".ASPXAUTH"].present?
  end

  def list_active_inquiries
    response = post_json("/Inquiry/_Index?active=#{ACTIVE_STATUS}", {
      "page" => 1,
      "size" => @page_size,
      "orderBy" => DEFAULT_ORDER_BY
    })

    parsed = JSON.parse(response.body)
    records = parsed["Data"] || parsed["data"] || []
    records.map { |record| normalize_record(record) }
  end

  def upsert_volunteer!(record)
    email = normalized_email(record)
    raise "External VMS record missing email" if email.blank?

    volunteer = find_existing_volunteer(record, email) || Volunteer.new(email: email)
    attributes = {
      first_name: required_record_value(record, "first_name"),
      last_name: required_record_value(record, "last_name"),
      phone: normalized_phone(record),
      inquiry_date: parsed_inquiry_date(record),
      external_synced_at: Time.current
    }
    attributes[:current_funnel_stage] = :inquiry if volunteer.new_record?
    external_id = record["encrypted_id"].presence || record["inquiry_id"].presence
    attributes[:external_id] = external_id if external_id.present?
    volunteer.assign_attributes(attributes)
    volunteer.save!
    volunteer
  end

  def upsert_inquiry_submission!(volunteer, record)
    submission = InquiryFormSubmission.find_or_initialize_by(
      source: SOURCE_NAME,
      email: volunteer.email
    )
    submission.assign_attributes(
      volunteer: volunteer,
      first_name: volunteer.first_name,
      last_name: volunteer.last_name,
      phone: volunteer.phone,
      processed: true,
      processed_at: Time.current,
      raw_data: record
    )
    submission.save!
  end

  def record_successful_sync!(volunteer, record)
    ExternalSyncLog.create!(
      volunteer: volunteer,
      sync_type: :pull,
      sync_direction: :inbound,
      status: :completed,
      started_at: Time.current,
      completed_at: Time.current,
      records_processed: 1,
      payload_snapshot: record
    )
  end

  def find_existing_volunteer(record, email)
    external_id = record["encrypted_id"].presence || record["inquiry_id"].presence
    Volunteer.find_by(external_id: external_id) || Volunteer.find_by(email: email)
  end

  def required_record_value(record, key)
    value = record[key].to_s.strip
    raise "External VMS record missing #{key}" if value.blank?

    value
  end

  def normalized_email(record)
    record["email"].to_s.strip.downcase
  end

  def normalized_phone(record)
    digits = record["phone"].to_s.gsub(/\D/, "")
    digits.presence || record["phone"].to_s.strip.presence
  end

  def parsed_inquiry_date(record)
    value = record["inquired"].presence || record["inquiry_date"].presence
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    Date.strptime(value.to_s, DATE_FORMAT)
  rescue Date::Error
    nil
  end

  def normalize_record(record)
    record.each_with_object({}) do |(key, value), result|
      normalized_key = FIELD_ALIASES[key] || key.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                             .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                                             .downcase
      result[normalized_key] = normalize_value(value)
    end
  end

  def normalize_value(value)
    return value unless value.is_a?(String)

    match = value.match(ASP_NET_DATE_PATTERN)
    return value unless match

    Time.at(match[1].to_i / 1000).utc.to_date.iso8601
  end

  def get(path)
    uri = uri_for(path)
    perform_request(Net::HTTP::Get.new(uri), uri)
  end

  def post_form(path, form_data)
    uri = uri_for(path)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(form_data)
    perform_request(request, uri)
  end

  def post_json(path, payload)
    uri = uri_for(path)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Requested-With"] = "XMLHttpRequest"
    request.body = payload.to_json
    perform_request(request, uri)
  end

  def perform_request(request, uri)
    request["Cookie"] = formatted_cookies if @cookies.any?
    response = http_for(uri).request(request)
    store_cookies(response)
    response
  end

  def http_for(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 30
    http
  end

  def uri_for(path)
    URI("#{base_url}#{path}")
  end

  def store_cookies(response)
    Array(response.get_fields("set-cookie")).each do |cookie|
      key, value = cookie.split(";", 2).first.split("=", 2)
      @cookies[key] = value if key.present?
    end
  end

  def formatted_cookies
    @cookies.map { |key, value| "#{key}=#{value}" }.join("; ")
  end

  def base_url
    ENV.fetch(BASE_URL_ENV_KEY, DEFAULT_BASE_URL).delete_suffix("/")
  end

  def username
    ENV.fetch(USERNAME_ENV_KEY)
  end

  def password
    ENV.fetch(PASSWORD_ENV_KEY)
  end
end
