Feature: Application Process
  As a system administrator
  I want to automate the application process
  So that volunteers receive and submit applications efficiently

  Background:
    Given I am a signed-in system administrator

  Scenario: Application email sent after attendance is confirmed
    Given I am on the sign-in page for session "March 2025 Info Session"
    And the volunteer "Jane Doe" is registered for this session
    And the volunteer has status "inquiry"
    When I check in the volunteer "Jane Doe"
    Then the application email should be queued for the volunteer "Jane Doe"
    And the volunteer status should change to "application_sent"
    And the volunteer's application sent date should be set

  Scenario: Application submission is tracked and staff is notified
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "application_sent"
    When I mark the application as submitted
    Then the system should record when the application was submitted
    And the volunteer's application submitted date should be set
    And staff should be notified of the submission

  Scenario: Status changes from application sent to application submitted
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "application_sent"
    When I mark the application as submitted
    Then the volunteer should have status "application submitted"
    And the volunteer should appear in the applied section

  Scenario: Volunteers awaiting submission appear in dedicated view
    Given there are volunteers with status "application_sent"
    When I go to the application dashboard
    Then I should see an "Awaiting submission" section
    And I should see volunteers with application_sent status
    And the list should be sorted by days waiting

  Scenario: Reminder frequency is configurable
    Given I am on the admin settings page
    When I view application reminder settings
    Then I should see the reminder interval setting
    And I should be able to change the reminder frequency

  Scenario: Application submitted in External System stops reminder emails
    Given the volunteer "Jane Doe" has status "application_sent"
    And the volunteer has pending application reminder emails
    When the system detects that the application was submitted in the External System
    Then the volunteer status should change to "application submitted"
    And all pending application reminder emails should be stopped