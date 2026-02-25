Feature: SMS Integration
  As a system administrator
  I want to send SMS reminders to volunteers
  So that I can reach them through multiple channels

  # Integrates with MailChimp SMS functionality

  Background:
    Given I am a signed-in system administrator

  Scenario: Manual SMS can be sent from volunteer profile
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has a phone number
    When I click "Send SMS"
    And I enter the message "Reminder: Info session tomorrow at 6pm"
    And I press "Send"
    Then the SMS should be sent to the volunteer's phone
    And I should see a confirmation message

  Scenario: SMS content can be customized
    Given I am on the volunteer "Jane Doe" profile page
    When I click "Send SMS"
    Then I should see a message composition field
    And I should see a character count
    And I should be able to type custom message content

  Scenario: SMS history visible in volunteer profile
    Given the volunteer "Jane Doe" has received 2 SMS messages
    When I view the volunteer "Jane Doe" profile
    Then I should see the SMS communication history
    And each entry should show the date and time sent
    And each entry should show the message content or preview

  Scenario: SMS delivery status is tracked
    Given an SMS was sent to the volunteer "Jane Doe"
    When I view the communication history for "Jane Doe"
    Then I should see the SMS delivery status
    And the status should be one of "queued", "sent", "delivered", or "failed"

  Scenario: System detects and flags bad phone numbers
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has an invalid or unreachable phone number
    When I view the volunteer profile
    Then the system should flag the phone number as bad
    And I should see an indication that the phone number may be invalid