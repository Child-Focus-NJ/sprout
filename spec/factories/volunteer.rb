# used for cucumber testing involving volunteers in the system
FactoryBot.define do
  factory :volunteer do
    sequence(:email) { |n| "volunteer#{n}@childfocusnj.org" }
    first_name { "Test" }
    last_name { "Volunteer" }

    trait :with_vicinage do
      association :vicinage
    end

    trait :with_referral_source do
      association :referral_source
    end
  end
end
