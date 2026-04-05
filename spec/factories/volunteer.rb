# used for cucumber testing involving volunteers in the system
FactoryBot.define do
  factory :volunteer do
    sequence(:email) { |n| "volunteer#{n}@childfocusnj.org" }
    first_name { "Test" }
    last_name { "Volunteer" }
  end
end
