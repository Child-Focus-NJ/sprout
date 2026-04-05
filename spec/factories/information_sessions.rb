# factory used for cucumber testing when an information session is needed in the system
FactoryBot.define do
  factory :information_session do
    capacity { 10 }
    scheduled_at { 1.day.from_now }
    sequence(:name) { |n| "Info session #{n}" }
    location { "415 Hamburg Turnpike" }
  end
end
