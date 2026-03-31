# frozen_string_literal: true

require "json"

module Vms
  module Transformers
    # Parses Kendo UI grid JSON responses from VMS AJAX endpoints.
    #
    # VMS Kendo grids lazy-load data via AJAX POST to /{Controller}/_Index.
    # Response format: {"data": [...records...], "total": N}
    module KendoResponse
      module_function

      # Parse a Kendo grid AJAX response.
      # Returns { data: [...], total: N }
      def parse(response_body)
        parsed = JSON.parse(response_body)

        # Kendo responses have "Data" (PascalCase) and "Total"
        data = parsed["Data"] || parsed["data"] || []
        total = parsed["Total"] || parsed["total"] || data.length

        { "data" => data, "total" => total }
      end
    end
  end
end
