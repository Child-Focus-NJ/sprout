FactoryBot.define do
  factory :vicinage do
    sequence(:name) { |n| "Vicinage #{n}" }
  end
end
