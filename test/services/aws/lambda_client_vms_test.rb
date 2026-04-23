# frozen_string_literal: true

require "minitest/autorun"
require "webmock/minitest"
require "json"
require "httparty"

# Load the service class directly (no Rails needed for this test)
require_relative "../../../app/services/aws/lambda_client"

class LambdaClientVmsTest < Minitest::Test
  def setup
    @base_url = "https://api.example.com/v1"
    ENV["API_GATEWAY_URL"] = @base_url
    @client = Aws::LambdaClient.new
  end

  def teardown
    ENV.delete("API_GATEWAY_URL")
    WebMock.reset!
  end

  # --- Inquiries ---

  def test_vms_list_inquiries_sends_get_with_query_params
    stub = stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: { "status" => "active", "page" => "1", "page_size" => "50" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_inquiries
    assert_requested(stub)
  end

  def test_vms_list_inquiries_passes_custom_params
    stub = stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: { "status" => "inactive", "page" => "2", "page_size" => "25" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_inquiries(status: "inactive", page: 2, page_size: 25)
    assert_requested(stub)
  end

  def test_vms_create_inquiry_sends_post_with_body
    stub = stub_request(:post, "#{@base_url}/vms/inquiries")
      .with(body: hash_including("first_name" => "Jane", "last_name" => "Smith"))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_create_inquiry(first_name: "Jane", last_name: "Smith", phone: "555", email: "j@e.com", gender: 2, inquired: "03/15/2026")
    assert_requested(stub)
  end

  def test_vms_edit_inquiry_sends_put_to_correct_path
    stub = stub_request(:put, "#{@base_url}/vms/inquiries/enc123==")
      .with(body: hash_including("active" => false))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_edit_inquiry(encrypted_id: "enc123==", active: false)
    assert_requested(stub)
  end

  def test_vms_delete_inquiry_sends_delete
    stub = stub_request(:delete, "#{@base_url}/vms/inquiries/enc123==")
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_delete_inquiry(encrypted_id: "enc123==")
    assert_requested(stub)
  end

  # --- Volunteers ---

  def test_vms_list_volunteers_sends_get_with_defaults
    stub = stub_request(:get, "#{@base_url}/vms/volunteers")
      .with(query: { "status" => "yes", "page" => "1", "page_size" => "50" })
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_volunteers
    assert_requested(stub)
  end

  def test_vms_create_volunteer_sends_post
    stub = stub_request(:post, "#{@base_url}/vms/volunteers")
      .with(body: hash_including("first_name" => "Jane"))
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_create_volunteer(first_name: "Jane", last_name: "Smith", gender: 2)
    assert_requested(stub)
  end

  # --- Lookups ---

  def test_vms_list_lookup_sends_get_with_type_in_path
    stub = stub_request(:get, "#{@base_url}/vms/lookups/County")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_list_lookup(type: "County")
    assert_requested(stub)
  end

  # --- Session ---

  def test_vms_refresh_session_sends_post
    stub = stub_request(:post, "#{@base_url}/vms/session/refresh")
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    @client.vms_refresh_session
    assert_requested(stub)
  end

  # --- Error handling ---

  def test_raises_lambda_error_on_non_2xx_response
    stub_request(:get, "#{@base_url}/vms/inquiries")
      .with(query: hash_including({}))
      .to_return(status: 500, body: { error: "boom" }.to_json, headers: { "Content-Type" => "application/json" })

    assert_raises(Aws::LambdaClient::LambdaError) do
      @client.vms_list_inquiries
    end
  end
end
