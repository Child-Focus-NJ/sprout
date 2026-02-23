# used for cucumber testing involving volunteers in the system
FactoryBot.define do
    factory :volunteer do
        first_name { "Test" }
        last_name { "Volunteer" }
        email { "volunteer@example.com" }
    end
end