# frozen_string_literal: true

require "json"
require_relative "../transformers/field_normalizer"
require_relative "../transformers/kendo_response"
require_relative "../../shared/logger"

module Vms
  module Resources
    # Shared CRUD patterns for VMS resources.
    #
    # List pages use Kendo UI grids via AJAX POST to /{Controller}/_Index
    # (or _GridIndex for volunteers). Create/Edit/Delete follow the ASP.NET
    # MVC pattern: POST form data → 302 on success.
    class BaseResource
      def initialize(http_client)
        @http = http_client
      end

      protected

      # List records via Kendo grid AJAX endpoint.
      # endpoint_suffix: "_Index" or "_GridIndex" depending on controller
      # url_params: query string params appended to the URL (e.g., active=yes)
      # Returns normalized { data: [...], total: N, page: N, page_size: N }
      def kendo_list(controller_path, params = {}, endpoint_suffix: "_Index", url_params: {})
        page = params.fetch(:page, 1).to_i
        page_size = params.fetch(:page_size, 50).to_i
        order_by = params[:order_by]

        kendo_params = {
          "page" => page,
          "size" => page_size
        }
        kendo_params["orderBy"] = order_by if order_by

        # Build the endpoint path with optional URL query params
        endpoint = "#{controller_path}/#{endpoint_suffix}"
        unless url_params.empty?
          query_string = url_params.map { |k, v| "#{k}=#{v}" }.join("&")
          endpoint = "#{endpoint}?#{query_string}"
        end

        response = @http.post_json(endpoint, kendo_params)
        parsed = Transformers::KendoResponse.parse(response.body)
        records = Transformers::FieldNormalizer.normalize_records(parsed["data"])

        {
          "data" => records,
          "total" => parsed["total"],
          "page" => page,
          "page_size" => page_size
        }
      end

      # Submit a create form (POST form data → 302 on success).
      def form_create(controller_path, form_data)
        response = @http.submit_form(
          "#{controller_path}/Create",
          "#{controller_path}/Create",
          form_data
        )

        # 302 redirect indicates success in ASP.NET MVC
        if response.is_a?(Net::HTTPRedirection)
          { "success" => true }
        else
          { "success" => false, "error" => "Unexpected response: #{response.code}", "body" => response.body }
        end
      end

      # Submit an edit form.
      def form_edit(controller_path, encrypted_id, form_data)
        response = @http.submit_form(
          "#{controller_path}/Edit/#{encrypted_id}",
          "#{controller_path}/Edit/#{encrypted_id}",
          form_data
        )

        if response.is_a?(Net::HTTPRedirection)
          { "success" => true }
        else
          { "success" => false, "error" => "Unexpected response: #{response.code}", "body" => response.body }
        end
      end

      # Delete via confirmation page (GET → extract hidden fields → POST).
      def form_delete(controller_path, encrypted_id)
        # Step 1: GET the delete confirmation page
        get_response = @http.get("#{controller_path}/Delete/#{encrypted_id}")
        hidden_fields = @http.extract_hidden_fields(get_response.body)

        # CSRF token is optional — include if present
        csrf_token = @http.extract_csrf_token(get_response.body)
        hidden_fields["__RequestVerificationToken"] = csrf_token if csrf_token

        # Step 2: POST to confirm deletion
        response = @http.post_form(
          "#{controller_path}/Delete/#{encrypted_id}",
          hidden_fields
        )

        if response.is_a?(Net::HTTPRedirection)
          { "success" => true }
        else
          { "success" => false, "error" => "Unexpected response: #{response.code}", "body" => response.body }
        end
      end

      # Build an API response hash for API Gateway proxy integration.
      def api_response(status, body)
        {
          statusCode: status,
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate(body)
        }
      end
    end
  end
end
