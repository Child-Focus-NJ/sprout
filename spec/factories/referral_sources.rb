FactoryBot.define do
  factory :referral_source do
    sequence(:name) { |n| "Referral Source #{n}" }
    active { true }

    trait :inactive do
      active { false }
    end
  end
end

