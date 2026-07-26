FactoryBot.define do
  factory :nj_county do
    sequence(:name) { |n| "County #{n}" }
  end
end
