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
  # Passaic County default
  DEFAULT_COUNTY_ID = 22_967
  DEFAULT_GENDER = 2
  VOLUNTEER_OPTIONAL_FIELDS = {
    middle_name: "MiddleName",
    aka_name: "AKAName",
    ssn: "SSN",
    address: "Address",
    city: "City",
    state: "State",
    zip: "Zip",
    hispanic: "Hispanic",
    ethnicity_id: "EthnicityID",
    marital_status_id: "MaritalStatusID",
    birthdate: "Birthdate",
    home_email: "HomeEmail",
    work_email: "WorkEmail",
    best_email: "BestEmail",
    home_phone: "HomePhone",
    cell_phone: "CellPhone",
    work_phone: "WorkPhone",
    best_phone: "BestPhone"
  }.freeze
  LOOKUP_CONTROLLERS = {
    "County" => "/County",
    "VolunteerStatus" => "/VolunteerStatus",
    "VolunteerStatusReason" => "/VolunteerStatusReason",
    "VolunteerType" => "/VolunteerType",
    "VolunteerReferral" => "/VolunteerReferral",
    "InquiryEvent" => "/InquiryEvent",
    "VolunteerActivityType" => "/VolunteerActivityType",
    "VolunteerContactType" => "/VolunteerContactType",
    "EmploymentStatus" => "/EmploymentStatus",
    "Ethnicity" => "/Ethnicity",
    "LanguageType" => "/LanguageType",
    "Degree" => "/Degree",
    "EducationType" => "/EducationType"
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

  # Outbound (Sprout -> VMS) Creates an inquiry in the VMS
  def create_inquiry!(first_name:, last_name:, phone:, email:, inquired:, gender: DEFAULT_GENDER,
                       address: "", address2: "", city: "", state: "", zip: "", county_id: DEFAULT_COUNTY_ID)
    ensure_logged_in!

    form_data = {
      "FirstName" => first_name,
      "LastName" => last_name,
      "Phone" => phone,
      "Email" => email,
      "Gender" => gender.to_s,
      "Inquired" => inquired,
      "Address" => address,
      "Address2" => address2,
      "City" => city,
      "State" => state,
      "Zip" => zip,
      "CountyID" => county_id.to_s
    }

    raise "External VMS inquiry creation failed" unless form_post_succeeded?(post_form("/Inquiry/Create", form_data))

    encrypted_id = find_inquiry_encrypted_id(first_name: first_name, last_name: last_name, email: email)
    log_push!(records_processed: 1)
    encrypted_id
  rescue StandardError => e
    log_push!(status: :failed, error_message: e.message)
    raise
  end

  # The VMS Edit form only supports these two fields — personal info can't be
  # changed after creation.
  def edit_inquiry!(encrypted_id:, active: nil, party_id: nil)
    ensure_logged_in!

    form_data = hidden_fields_for("/Inquiry/Edit/#{encrypted_id}")
    form_data["Active"] = active.to_s unless active.nil?
    form_data["PartyID"] = party_id.to_s if party_id

    unless form_post_succeeded?(post_form("/Inquiry/Edit/#{encrypted_id}", form_data))
      raise "External VMS inquiry edit failed"
    end

    log_push!(records_processed: 1)
    true
  rescue StandardError => e
    log_push!(status: :failed, error_message: e.message)
    raise
  end

  def delete_inquiry!(encrypted_id:)
    ensure_logged_in!

    form_data = hidden_fields_for("/Inquiry/Delete/#{encrypted_id}")
    unless form_post_succeeded?(post_form("/Inquiry/Delete/#{encrypted_id}", form_data))
      raise "External VMS inquiry deletion failed"
    end

    log_push!(records_processed: 1)
    true
  rescue StandardError => e
    log_push!(status: :failed, error_message: e.message)
    raise
  end

  def create_volunteer!(first_name:, last_name:, gender: DEFAULT_GENDER, permission_to_call: true,
                         share_info_permission: true, county_id: DEFAULT_COUNTY_ID, **optional_fields)
    ensure_logged_in!

    form_data = {
      "FirstName" => first_name,
      "LastName" => last_name,
      "Gender" => gender.to_s,
      "PermissionToCall" => permission_to_call.to_s,
      "ShareInfoPermission" => share_info_permission.to_s,
      "CountyID" => county_id.to_s
    }
    optional_fields.each do |key, value|
      next if value.nil?

      field = VOLUNTEER_OPTIONAL_FIELDS.fetch(key) { raise ArgumentError, "Unknown volunteer field: #{key}" }
      form_data[field] = value.to_s
    end

    unless form_post_succeeded?(post_form("/Volunteers/Create", form_data))
      raise "External VMS volunteer creation failed"
    end

    log_push!(records_processed: 1)
    true
  rescue StandardError => e
    log_push!(status: :failed, error_message: e.message)
    raise
  end

  # ---- Inbound (pull) ----

  def list_volunteers(status: "yes", page: 1, page_size: DEFAULT_PAGE_SIZE, order_by: "LastName-asc")
    ensure_logged_in!
    kendo_list("/Volunteers/_GridIndex?active=#{status}", page: page, page_size: page_size, order_by: order_by)
  end

  # type is one of the keys in LOOKUP_CONTROLLERS, e.g. "County", "Ethnicity".
  def list_lookup(type)
    controller = LOOKUP_CONTROLLERS.fetch(type) { raise ArgumentError, "Unknown VMS lookup type: #{type}" }
    ensure_logged_in!
    kendo_list("#{controller}/_Index", page: 1, page_size: 9_999, order_by: nil)
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
    kendo_list("/Inquiry/_Index?active=#{ACTIVE_STATUS}", page: 1, page_size: @page_size, order_by: DEFAULT_ORDER_BY)
  end

  # Shared Kendo grid list pattern: list pages lazy-load data via AJAX POST,
  # returning {"Data" => [...], "Total" => N}. Used for inquiries, volunteers,
  # and lookups alike (endpoint already carries the ?active=... filter, if any).
  def kendo_list(endpoint, page:, page_size:, order_by: nil)
    body = { "page" => page, "size" => page_size }
    body["orderBy"] = order_by if order_by

    response = post_json(endpoint, body)
    parsed = JSON.parse(response.body)
    records = parsed["Data"] || parsed["data"] || []
    records.map { |record| normalize_record(record) }
  end

  def form_post_succeeded?(response)
    response.is_a?(Net::HTTPRedirection)
  end

  # GET a form page and collect its hidden <input> fields (plus the CSRF
  # token, if present), used by the Edit/Delete flows
  def hidden_fields_for(path)
    html = get(path).body.to_s
    fields = {}
    html.scan(/<input[^>]*type="hidden"[^>]*>/).each do |input|
      name = input[/name="([^"]+)"/, 1]
      value = input[/value="([^"]*)"/, 1]
      fields[name] = value if name
    end
    token = html.match(CSRF_PATTERN)&.[](1)
    fields["__RequestVerificationToken"] = token if token.present?
    fields
  end

  # The VMS's create response is a redirect with no body, so recover the new
  # record's encrypted_id by re-listing and matching on name + email
  def find_inquiry_encrypted_id(first_name:, last_name:, email:)
    records = kendo_list("/Inquiry/_Index?active=#{ACTIVE_STATUS}", page: 1, page_size: 10, order_by: DEFAULT_ORDER_BY)
    match = records.find do |record|
      record["first_name"]&.downcase == first_name.downcase &&
        record["last_name"]&.downcase == last_name.downcase &&
        record["email"]&.downcase == email.downcase
    end
    match && match["encrypted_id"]
  end

  def log_push!(status: :completed, records_processed: 0, error_message: nil, volunteer: nil)
    ExternalSyncLog.create!(
      volunteer: volunteer,
      sync_type: :push,
      sync_direction: :outbound,
      status: status,
      started_at: Time.current,
      completed_at: Time.current,
      records_processed: records_processed,
      error_message: error_message
    )
  end

  def ensure_logged_in!
    login! unless @cookies[".ASPXAUTH"].present?
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
