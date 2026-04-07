FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@childfocusnj.org" }
    first_name { "Admin" }
    last_name  { "User" }
    role       { :admin }

    trait :staff do
      role { :staff }
    end

    trait :viewer do
      role { :viewer }
    end
  end
end
