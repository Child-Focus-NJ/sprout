FactoryBot.define do
  factory :user do
    first_name { "Admin" }
    last_name  { "User" }
    email      { "admin@childfocusnj.org" }
    role       { :admin }
  end
end
