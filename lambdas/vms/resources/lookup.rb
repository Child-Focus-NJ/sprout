# frozen_string_literal: true

require "json"
require_relative "base_resource"

module Vms
  module Resources
    class Lookup < BaseResource
      # Valid lookup types and their VMS controller paths.
      # The Kendo grid endpoint is /{Controller}/_Index.
      TYPES = {
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

      # GET /vms/lookups/{type}
      def list(type)
        controller = TYPES[type]
        unless controller
          return api_response(404, {
            "error" => "Unknown lookup type: #{type}",
            "valid_types" => TYPES.keys
          })
        end

        # Fetch all records (use large page_size since lookups are small)
        result = kendo_list(controller, { page: 1, page_size: 9999 })

        # Normalize to consistent shape: { id, encrypted_id, name, active }
        normalized = result["data"].map do |record|
          normalize_lookup_record(record, type)
        end

        api_response(200, {
          "data" => normalized,
          "total" => normalized.length
        })
      end

      private

      def normalize_lookup_record(record, type)
        # Lookup tables use type-specific field names:
        # CountyID/CountyName, VolunteerStatusID/VolunteerStatusName, etc.
        # We normalize these into a consistent shape.
        type_base = type.gsub(/([a-z])([A-Z])/, '\1_\2')

        {
          "id" => record["#{Transformers::FieldNormalizer.pascal_to_snake(type)}_id"] ||
                   record["id"],
          "encrypted_id" => record["encrypted_id"] ||
                            record["encrypted_#{Transformers::FieldNormalizer.pascal_to_snake(type)}_id"],
          "name" => record["#{Transformers::FieldNormalizer.pascal_to_snake(type)}_name"] ||
                    record["name"],
          "active" => record.fetch("active", true)
        }
      end
    end
  end
end
