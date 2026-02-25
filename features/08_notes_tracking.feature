Feature: Notes and Communication Tracking
  As a system administrator
  I want to track all communications with notes
  So that communication history is always up-to-date

  Background:
    Given I am a signed-in system administrator

  Scenario: Add note to volunteer profile with timestamp and creator
    Given I am on the volunteer "William P" profile page
    When I click "Add Note"
    And I enter "Called to confirm session attendance"
    And I press "Save Note"
    Then I should see the note "Called to confirm session attendance"
    And the note should display a timestamp
    And the note should display who created it

  Scenario: All communications consolidated into single chronological timeline
    Given the volunteer "William P" has notes, reminders, and info session entries
    When I view the volunteer "William P" profile
    Then I should see a single consolidated timeline
    And the timeline should include reminders, info sessions, and manual notes
    And entries should be in chronological order

  Scenario: Automatic note created when reminder email or SMS is sent
    Given I am on the volunteer "William P" profile page
    When a reminder email or SMS is sent to the volunteer
    Then a note should be automatically created
    And the note should indicate the type of communication sent
    And the note should include the date and time

  Scenario: Timeline can be filtered by activity type
    Given the volunteer "William P" has notes, emails, and SMS in the timeline
    When I view the volunteer "William P" profile
    Then I should see a filter by type option
    When I filter the timeline to show only notes
    Then I should see only manual notes
    And I should not see email or SMS entries in the filtered view

  Scenario: Note button clearly separated from delete button
    Given I am on the volunteer "William P" profile page
    When I view the action buttons
    Then I should see an "Add Note" button
    And I should see a "Delete" button for the volunteer
    And the Note button should be visually distinct from the Delete button
    And the Delete button should require confirmation

  Scenario: Add note to multiple volunteers from list view
    Given I am on the volunteers list page
    When I select the volunteers "William P" and "Harry Johnson"
    And I click "Add Note to Selected"
    And I enter "Send 4 week follow-up email"
    And I press "Apply"
    Then the note should be added to both volunteers
    And I should see a confirmation message