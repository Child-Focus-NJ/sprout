Given("I clear all sent emails") do
  ActionMailer::Base.deliveries.clear
end

Then("an email should be sent to {string}") do |to_email|
  recipients = ActionMailer::Base.deliveries.map(&:to).flatten.compact.map(&:downcase)
  assert recipients.include?(to_email.downcase)
end

Then("no email should be sent") do
  assert_equal 0, ActionMailer::Base.deliveries.length
end