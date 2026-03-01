FactoryBot.define do
  factory :user do
    first_name { "Admin" }
    last_name  { "User" }
    email      { "admin@example.com" }
    password   { "password123" }
    role       { :admin }
  end
end
