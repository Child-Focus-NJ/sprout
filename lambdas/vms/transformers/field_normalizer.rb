# frozen_string_literal: true

module Vms
  module Transformers
    # Converts between Sprout's snake_case and VMS's PascalCase.
    # Parses ASP.NET date format (/Date(ms)/) into ISO 8601.
    # Handles known VMS quirks (e.g., EncyptedPartyID typo).
    module FieldNormalizer
      # ASP.NET JSON date pattern: /Date(1771495200000)/
      DATE_PATTERN = %r{/Date\((\d+)\)/}

      # Map of VMS PascalCase field names to Sprout snake_case.
      # Only includes fields that need special handling beyond simple conversion.
      FIELD_ALIASES = {
        "EncyptedPartyID" => "encrypted_party_id",  # VMS typo — missing 'r'
        "EncryptedID" => "encrypted_id",
        "InquiryID" => "inquiry_id",
        "PartyID" => "party_id",
        "ProgramID" => "program_id",
        "CountyID" => "county_id"
      }.freeze

      module_function

      # Convert a VMS record hash from PascalCase to snake_case.
      # Also parses ASP.NET date values.
      def normalize_record(record)
        result = {}
        record.each do |key, value|
          snake_key = FIELD_ALIASES[key] || pascal_to_snake(key)
          result[snake_key] = normalize_value(value)
        end
        result
      end

      # Convert a batch of records.
      def normalize_records(records)
        records.map { |r| normalize_record(r) }
      end

      # Convert PascalCase or camelCase to snake_case.
      def pascal_to_snake(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
      end

      # Convert snake_case to PascalCase (for sending data to VMS).
      def snake_to_pascal(str)
        str.split("_").map(&:capitalize).join
      end

      # Normalize a single value — parse ASP.NET dates, pass through everything else.
      def normalize_value(value)
        return value unless value.is_a?(String)

        match = value.match(DATE_PATTERN)
        return value unless match

        # Convert milliseconds since epoch to ISO 8601 date
        timestamp_ms = match[1].to_i
        Time.at(timestamp_ms / 1000).utc.strftime("%Y-%m-%d")
      end

    end
  end
end
