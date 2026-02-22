Feature: Status Management
  As a system administrator
  I want to track and update volunteer status
  So that I know where each volunteer is in the process

  Background:
    Given I am a signed-in system administrator

  Scenario: Manual status change updates volunteer and creates audit log
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "inquiry"
    When I change the status to "attended session"
    And I press "Update Status"
    Then the volunteer should have status "attended session"
    And I should see a status change entry for "inquiry" to "attended session"
    And the status change should include a timestamp

  Scenario: Status updates automatically when volunteer attends session
    Given I am on the sign-in page for session "March 2025 Info Session"
    And the volunteer "Jane Doe" is registered for this session
    When I check in the volunteer "Jane Doe"
    Then the volunteer should have status "attended session"
    And I should see a status change entry for "inquiry" to "attended session"
    And the volunteer's first session attended date should be set

  Scenario: Status updates automatically when application is submitted
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "application_sent"
    When I mark the application as submitted
    Then the volunteer should have status "application submitted"
    And I should see a status change entry for "application_sent" to "application submitted"
    And the volunteer's application submitted date should be set

  Scenario: Status options include required funnel stages
    Given I am on the volunteer "Jane Doe" profile page
    When I open the status change dropdown
    Then I should see status option "inquiry"
    And I should see status option "attended session"
    And I should see status option "application sent"
    And I should see status option "application submitted"
    And I should see status option "inactive"

  Scenario: Inactive volunteer retains application sent date
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "application_sent"
    And the volunteer was sent an application on "2025-02-15"
    When I change the status to "inactive"
    And I press "Update Status"
    Then the volunteer should have status "inactive"
    And I should still see application sent date "2025-02-15"

  Scenario: System prevents duplicate application sends
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "application_sent"
    And the volunteer has already received the application email
    When I attempt to send the application email again
    Then the application email should not be sent
    And I should see a message that the application was already sent
