FactoryBot.define do
  factory :session_registration do
    association :volunteer
    association :information_session
    status { :registered }
  end
end