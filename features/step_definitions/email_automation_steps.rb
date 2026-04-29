Given("I clear all sent emails") do
  ActionMailer::Base.deliveries.clear
end

Then("an email should be sent to {string}") do |to_email|
  Timeout.timeout(5) do
    sleep 0.1 until ActionMailer::Base.deliveries.any? { |m| 
      Array(m.to).map(&:downcase).include?(to_email.downcase) 
    }
  end
  recipients = ActionMailer::Base.deliveries.map(&:to).flatten.compact.map(&:downcase)
  assert recipients.include?(to_email.downcase)
rescue Timeout::Error
    assert false, "No email was sent to #{to_email} within 5 seconds"
end

Then("no email should be sent") do
  assert_equal 0, ActionMailer::Base.deliveries.length
end
