Rails.application.config.middleware.delete ActionDispatch::HostAuthorization if Rails.env.test?
