require "warden"

Rails.application.config.middleware.use Warden::Manager do |manager|
  manager.failure_app = ->(_env) { [ 302, { "Location" => "/login" }, [] ] }
end

Warden::Manager.serialize_into_session(:user) { |user| user.id }
Warden::Manager.serialize_from_session(:user) { |id| User.find_by(id: id) }
