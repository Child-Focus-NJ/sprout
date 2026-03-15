Feature: Status Management
  As a system administrator
  I want to track and update volunteer status
  So that I know where each volunteer is in the process

  Background:
    Given I am a signed-in system administrator

  Scenario: Manual status change updates volunteer and creates audit log
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "Inquiry"
    When I change the status to "Application eligible"
    And I press "Update status"
    Then the volunteer should have status "Application eligible"
    And I should see a status change entry for "Inquiry" to "Application eligible"
    And the status change should include a timestamp

  Scenario: Status updates automatically when volunteer attends session
    Given I am on the sign-in page for session "March 2025 Info Session"
    And the volunteer "Jane Doe" is registered for this session
    When I check in the volunteer "Jane Doe"
    Then the volunteer should have status "Application eligible"
    And I should see a status change entry for "Inquiry" to "Application eligible"
    And the volunteer's first session attended date should be set

  Scenario: Status updates automatically when application is submitted
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "Application sent"
    When I mark the application as submitted
    Then the volunteer should have status "Applied"
    And I should see a status change entry for "Application sent" to "Applied"
    And the volunteer's application submitted date should be set

  Scenario: Status options include required funnel stages
    Given I am on the volunteer "Jane Doe" profile page
    When I open the status change dropdown
    Then I should see status option "Inquiry"
    And I should see status option "Application eligible"
    And I should see status option "Application sent"
    And I should see status option "Applied"
    And I should see status option "Inactive"

  Scenario: Inactive volunteer retains application sent date
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "Application sent"
    And the volunteer was sent an application on "2026-02-21"
    When I change the status to "Inactive"
    And I press "Update status"
    Then the volunteer should have status "Inactive"
    And I should still see application sent date "2026-02-21"

  Scenario: System prevents duplicate application sends
    Given I am on the volunteer "Jane Doe" profile page
    And the volunteer has status "Application sent"
    And the volunteer has already received the application email
    When I attempt to send the application email again
    Then the application email should not be sent
    And I should see a message that the application was already sent
