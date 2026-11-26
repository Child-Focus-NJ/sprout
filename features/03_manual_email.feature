@email_send
Feature: Manual email and application delivery
  As a staff member
  I want to send emails and application links through Sprout
  So that volunteer communication is recorded accurately

  Background:
    Given I am a signed-in system administrator
    And I am on the volunteer "Jane Doe" profile page

  Scenario: Staff sends an email from the volunteer profile
    When I click "Send Email"
    And I compose an email with subject "Session details" and message "See you tomorrow"
    And I press "Send"
    Then the email history should show "Session details" and "See you tomorrow"
    And I should see "Email sent to Mailchimp"

  Scenario: Staff starts an email from a template and edits it before sending
    Given an active email template named "Session follow-up" with subject "See you soon, {{first_name}}" and body "Hi {{first_name}}, thanks for coming."
    When I click "Send Email"
    And I choose the email template "Session follow-up"
    Then the email draft should retain "See you soon, Jane" and "Hi Jane, thanks for coming."
    When I compose an email with subject "See you soon, Jane" and message "Hi Jane, thanks for coming on Thursday!"
    And I press "Send"
    Then the email history should show "See you soon, Jane" and "Hi Jane, thanks for coming on Thursday!"
    And the saved email should use the template "Session follow-up"

  Scenario: Staff emails a volunteer from the list and comes back to the list
    Given I am on the volunteers list page
    When I click "Send Email" for "Jane Doe" on the list
    And I compose an email with subject "Session details" and message "See you tomorrow"
    And I press "Send"
    Then I should be on the volunteers list page
    And I should see "Email sent to Mailchimp"

  Scenario: An admin updates the application link through Sprout
    When I open application email settings from Admin
    And I save the application link "https://example.org/new-application"
    And I view the volunteer "Jane Doe" profile
    And I press "Send Application"
    Then the application email should contain "https://example.org/new-application"
    And the volunteer's application sent date should be set

  Scenario: An application cannot be sent before its link is configured
    Given the application link has not been configured
    When I press "Send Application"
    Then I should see "Set the application link in Admin settings"
    And no application email should be recorded

  Scenario: Staff can edit a draft after a rejection
    Given Mailchimp rejects the email
    When I click "Send Email"
    And I compose an email with subject "Session details" and message "See you tomorrow"
    And I press "Send"
    Then the email draft should retain "Session details" and "See you tomorrow"
    And I should see "Mailchimp rejected the email"
