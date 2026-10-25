FactoryBot.define do
  factory :note_category do
    sequence(:name) { |n| "Note Category #{n}" }
  end
end
