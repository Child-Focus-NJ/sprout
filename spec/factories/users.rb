FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@passaiccountycasa.org" }
    sequence(:google_uid) { |n| "google-uid-#{n}" }
    first_name { "Admin" }
    last_name  { "User" }
    role       { :user }
  end
end
