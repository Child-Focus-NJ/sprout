# Browser forms must be exercised with the same token checks as development and
# production. Request specs can still post directly unless they opt in separately.
Around("@csrf") do |_scenario, run|
  previous_protection = ActionController::Base.allow_forgery_protection
  previous_per_form = ActionController::Base.per_form_csrf_tokens
  ActionController::Base.allow_forgery_protection = true
  ActionController::Base.per_form_csrf_tokens = true
  run.call
ensure
  ActionController::Base.allow_forgery_protection = previous_protection
  ActionController::Base.per_form_csrf_tokens = previous_per_form
end
