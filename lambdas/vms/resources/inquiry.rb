# frozen_string_literal: true

require_relative "base_resource"

module Vms
  module Resources
    class Inquiry < BaseResource
      CONTROLLER = "/Inquiry"
      DEFAULT_COUNTY_ID = 22967  # Passaic County

      # GET /vms/inquiries
      # Query params: status (active/inactive), page, page_size, order_by
      def list(params)
        status = params.fetch("status", "active")
        query_params = {
          page: params.fetch("page", 1),
          page_size: params.fetch("page_size", 50),
          order_by: params.fetch("order_by", "Inquired-desc")
        }

        # VMS filters by active/inactive via URL query parameter
        result = kendo_list(CONTROLLER, query_params, url_params: { "active" => status })
        api_response(200, result)
      end

      # POST /vms/inquiries
      def create(body)
        form_data = build_create_form(body)
        result = form_create(CONTROLLER, form_data)

        unless result["success"]
          return api_response(422, result)
        end

        # After successful creation, list inquiries to find the new record
        # and return its EncryptedID
        list_result = kendo_list(CONTROLLER, { page: 1, page_size: 10, order_by: "Inquired-desc" },
                                 url_params: { "active" => "active" })
        new_record = find_created_record(list_result["data"], body)

        if new_record
          api_response(201, {
            "success" => true,
            "encrypted_id" => new_record["encrypted_id"]
          })
        else
          api_response(201, { "success" => true, "encrypted_id" => nil })
        end
      end

      # PUT /vms/inquiries/{id}
      # Only supports: active (boolean), party_id (integer)
      def edit(encrypted_id, body)
        # GET the edit page first to read current form values and hidden fields
        get_response = @http.get("#{CONTROLLER}/Edit/#{encrypted_id}")
        hidden_fields = @http.extract_hidden_fields(get_response.body)

        # Include optional CSRF token if present
        csrf_token = @http.extract_csrf_token(get_response.body)
        hidden_fields["__RequestVerificationToken"] = csrf_token if csrf_token

        form_data = hidden_fields.merge(
          "Active" => body.fetch("active", true).to_s
        )
        form_data["PartyID"] = body["party_id"].to_s if body["party_id"]

        response = @http.post_form(
          "#{CONTROLLER}/Edit/#{encrypted_id}",
          form_data
        )

        if response.is_a?(Net::HTTPRedirection)
          api_response(200, { "success" => true })
        else
          api_response(422, { "success" => false, "error" => "Edit failed: #{response.code}" })
        end
      end

      # DELETE /vms/inquiries/{id}
      def delete(encrypted_id)
        result = form_delete(CONTROLLER, encrypted_id)
        status = result["success"] ? 200 : 422
        api_response(status, result)
      end

      private

      def build_create_form(body)
        {
          "FirstName" => body["first_name"],
          "LastName" => body["last_name"],
          "Phone" => body["phone"],
          "Email" => body["email"],
          "Gender" => body.fetch("gender", 0).to_s,
          "Inquired" => body["inquired"],
          "Address" => body.fetch("address", ""),
          "Address2" => body.fetch("address2", ""),
          "City" => body.fetch("city", ""),
          "State" => body.fetch("state", ""),
          "Zip" => body.fetch("zip", ""),
          "CountyID" => body.fetch("county_id", DEFAULT_COUNTY_ID).to_s
        }
      end

      def find_created_record(records, body)
        # Match by name and email since those are guaranteed unique per creation
        records.find do |r|
          r["first_name"]&.downcase == body["first_name"]&.downcase &&
            r["last_name"]&.downcase == body["last_name"]&.downcase &&
            r["email"]&.downcase == body["email"]&.downcase
        end
      end
    end
  end
end
