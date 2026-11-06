@csrf
Feature: Bulk actions on the volunteer list
  As a staff member
  I want to act on several volunteers at once
  So that I can handle a whole group without opening each profile

  Background:
    Given I am a signed-in system administrator
    And these volunteers are on the list:
      | name        | phone      | status  |
      | Harry Kane  | 5551112222 | inquiry |
      | Hana Kimura |            | inquiry |
      | Sofia Reyes | 5553334444 | applied |

  Scenario: Toolbar shows only while volunteers are selected
    When I visit the volunteers list
    Then the bulk toolbar should be hidden
    When I select "Harry Kane" on the list
    Then the bulk toolbar should show "1 selected"
    When I clear the selection
    Then the bulk toolbar should be hidden

  Scenario: Select all only picks the volunteers in the current filter
    Given I am on the volunteers list page filtered to status "Inquiry"
    When I select all volunteers
    Then the bulk toolbar should show "2 selected"

  Scenario: Toolbar stays on screen while scrolling a long list
    Given there are 40 more volunteers on the list
    When I visit the volunteers list
    And I select "Harry Kane" on the list
    Then the bulk toolbar should be on screen

  @sms_send
  Scenario: Create an SMS template when only email templates exist, then use it for a group
    Given an email template exists named "Email follow-up" with subject "Hello" and body "Hi {{first_name}}"
    When I visit the volunteers list
    And I select "Harry Kane" on the list
    And I select "Sofia Reyes" on the list
    And I click "Send SMS" in the bulk toolbar
    Then I should see "No active SMS templates yet."
    And the SMS template choices should be unavailable
    When I click "Create SMS template"
    Then the new template should default to active manual SMS
    When I save this SMS template named "Group follow-up" with body "Hi {{first_name}}, see you Friday!"
    And I visit the volunteers list
    And I select "Harry Kane" on the list
    And I select "Sofia Reyes" on the list
    And I click "Send SMS" in the bulk toolbar
    And I choose the SMS template "Group follow-up"
    Then the message draft should be "Hi {{first_name}}, see you Friday!"
    When I select the volunteer's one-time SMS consent
    And I press "Send"
    Then I should see "SMS sent to 2 volunteers."
    And the SMS for "Harry Kane" should say "Hi Harry, see you Friday!"
    And the SMS for "Sofia Reyes" should say "Hi Sofia, see you Friday!"

  @sms_send
  Scenario: A bulk SMS template is personalized for each selected volunteer
    Given an active SMS template named "Session reminder" says "Hi {{first_name}}, your session is tomorrow."
    When I visit the volunteers list
    And I select "Harry Kane" on the list
    And I select "Sofia Reyes" on the list
    And I click "Send SMS" in the bulk toolbar
    And I choose the SMS template "Session reminder"
    Then the message draft should be "Hi {{first_name}}, your session is tomorrow."
    When I enter the message "Hi {{first_name}}, see you Friday!"
    And I select the volunteer's one-time SMS consent
    And I press "Send"
    Then I should see "SMS sent to 2 volunteers."
    And the SMS for "Harry Kane" should say "Hi Harry, see you Friday!"
    And the SMS for "Sofia Reyes" should say "Hi Sofia, see you Friday!"

  @sms_send
  Scenario: Bulk SMS skips volunteers with no phone number
    When I visit the volunteers list
    And I select "Harry Kane" on the list
    And I select "Hana Kimura" on the list
    And I click "Send SMS" in the bulk toolbar
    Then the popup should say "1 of the 2 selected have no phone number and will be skipped for SMS: Hana Kimura."
    When I enter the message "Info session is Thursday at 6pm"
    And I select the volunteer's one-time SMS consent
    And I press "Send"
    Then I should see "SMS sent to 1 volunteer. Skipped 1 with no phone number: Hana Kimura."

  Scenario: Bulk SMS names the first few skipped volunteers and counts the rest
    Given there are 4 more volunteers on the list
    When I visit the volunteers list
    And I select all volunteers
    And I click "Send SMS" in the bulk toolbar
    Then the popup should say "5 of the 7 selected have no phone number and will be skipped for SMS: Extra Volunteer 0, Extra Volunteer 1, Extra Volunteer 2, and 2 more."

  Scenario: Send the application to the selected volunteers
    When I visit the volunteers list
    And I select all volunteers
    And I send the application to the selected volunteers
    Then I should see "Application sent to 2 volunteers. Skipped 1 who already had one, applied, or are inactive."
    And "Harry Kane" should be at status "application_sent"
