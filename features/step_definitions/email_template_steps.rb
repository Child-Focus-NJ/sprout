When('I create an email template named {string} with subject {string} and body {string}') do |name, subject, body|
  visit "/admin/communication_templates/new"

  fill_in "Name", with: name
  fill_in "Subject", with: subject
  fill_in "Body", with: body
  click_button "Create"
end

Then('I should see the template {string} in the templates list') do |name|
  visit "/admin/communication_templates"
  assert_text(name)
end

Given('an email template exists named {string} with subject {string} and body {string}') do |name, subject, body|
  CommunicationTemplate.find_or_create_by!(name: name) do |t|
    t.subject = subject
    t.body = body
    t.funnel_stage = :inquiry
    t.template_type = :email
    t.trigger_type = :manual
  end
end

When('I preview the template {string} using a sample volunteer named {string}') do |template_name, first_name|
  visit "/admin/communication_templates"
  first(".template-name-link", text: template_name).click
  click_link "Preview"

  fill_in "First name", with: first_name
  click_button "Preview"
end

Then('I should see {string}') do |text|
  assert_text(text)
end
