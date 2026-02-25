# frozen_string_literal: true

module VolunteerHelpers
  def find_or_create_volunteer_by_name(name)
    parts = name.split(" ", 2)
    first_name = parts[0] || "Unknown"
    last_name = parts[1] || ""

    Volunteer.find_or_create_by!(email: "#{name.parameterize}@example.com") do |v|
      v.first_name = first_name
      v.last_name = last_name
    end
  end
end

World(VolunteerHelpers)
