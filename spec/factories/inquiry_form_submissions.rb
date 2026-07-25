FactoryBot.define do
  factory :inquiry_form_submission do
    association :volunteer
    first_name { "Test" }
    last_name { "Volunteer" }
    sequence(:email) { |n| "inquiry#{n}@example.com" }
    source { "public_inquiry_form" }
    processed { false }

    trait :with_county do
      association :nj_county
    end

    trait :with_referral_source do
      association :referral_source
    end

    trait :for_session_check_in do
      association :preferred_session, factory: :information_session
      source { "walk_in_check_in" }
    end

    trait :processed do
      processed { true }
      processed_at { Time.current }
    end
  end
end