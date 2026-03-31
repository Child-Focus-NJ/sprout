# frozen_string_literal: true

require_relative "base_resource"

module Vms
  module Resources
    class Volunteer < BaseResource
      CONTROLLER = "/Volunteers"
      DEFAULT_COUNTY_ID = 22967  # Passaic County

      # GET /vms/volunteers
      # Query params: status (yes/no/all), page, page_size, order_by
      def list(params)
        status = params.fetch("status", "yes")
        query_params = {
          page: params.fetch("page", 1),
          page_size: params.fetch("page_size", 50),
          order_by: params.fetch("order_by", "LastName-asc")
        }

        # Volunteers use _GridIndex (not _Index) with status as URL param
        result = kendo_list(
          CONTROLLER, query_params,
          endpoint_suffix: "_GridIndex",
          url_params: { "active" => status }
        )
        api_response(200, result)
      end

      # POST /vms/volunteers
      def create(body)
        form_data = build_create_form(body)
        result = form_create(CONTROLLER, form_data)

        unless result["success"]
          return api_response(422, result)
        end

        api_response(201, { "success" => true })
      end

      private

      def build_create_form(body)
        form = {
          "FirstName" => body["first_name"],
          "LastName" => body["last_name"],
          "Gender" => body.fetch("gender", 0).to_s,
          "PermissionToCall" => body.fetch("permission_to_call", true).to_s,
          "ShareInfoPermission" => body.fetch("share_info_permission", true).to_s
        }

        # Optional fields
        optional_fields = {
          "middle_name" => "MiddleName",
          "aka_name" => "AKAName",
          "ssn" => "SSN",
          "address" => "Address",
          "city" => "City",
          "state" => "State",
          "zip" => "Zip",
          "county_id" => "CountyID",
          "hispanic" => "Hispanic",
          "ethnicity_id" => "EthnicityID",
          "marital_status_id" => "MaritalStatusID",
          "birthdate" => "Birthdate",
          "home_email" => "HomeEmail",
          "work_email" => "WorkEmail",
          "best_email" => "BestEmail",
          "home_phone" => "HomePhone",
          "cell_phone" => "CellPhone",
          "work_phone" => "WorkPhone",
          "best_phone" => "BestPhone"
        }

        optional_fields.each do |snake, pascal|
          form[pascal] = body[snake].to_s if body.key?(snake) && !body[snake].nil?
        end

        # Default county to Passaic if not specified
        form["CountyID"] ||= DEFAULT_COUNTY_ID.to_s

        form
      end
    end
  end
end
