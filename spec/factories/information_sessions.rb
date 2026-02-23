# factory used for cucumber testing when an information session is needed in the system
FactoryBot.define do
    factory :information_session do
        capacity { 10 }
        scheduled_at { Date.today }
        name {'name'}
        location { '415 Hamburg Turnpike' }
    end
end