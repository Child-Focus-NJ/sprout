@sign_in_attendance
Feature: Sign-in & Attendance
  As a system administrator
  I want to use an electronic sign-in sheet for info sessions
  So that attendance is automatically tracked and triggers follow-up actions

  Background:
    Given I am a signed-in system administrator

  Scenario: Admin checks in a registered volunteer and attendance is recorded
    Given an information session exists named "March 2025 Info Session"
    And a volunteer exists with email "jane@childfocusnj.org"
    And the volunteer is registered for the session "March 2025 Info Session"
    When I go to the sign-in page for session "March 2025 Info Session"
    And I check in the volunteer "jane@childfocusnj.org"
    Then the volunteer should be marked as attended for "March 2025 Info Session"
    And the volunteer status should update to "attended session"
    And the attendance should record a date and time
    And an application email should be triggered for "jane@childfocusnj.org"

  Scenario: Volunteer arrives without signup and is redirected to add form
    Given an information session exists named "March 2025 Info Session"
    When I go to the sign-in page for session "March 2025 Info Session"
    And I attempt to check in an unregistered volunteer "walkin@childfocusnj.org"
    Then I should be redirected to the inquiry form
    And I should see a prompt to add them to the system

  Scenario: Walk-in completes inquiry at check-in and is marked inquired and attended
    Given an information session exists named "March 2025 Info Session"
    When I go to the sign-in page for session "March 2025 Info Session"
    And I attempt to check in an unregistered volunteer "walkin@childfocusnj.org"
    Then I should be redirected to the inquiry form
    When I complete the walk-in inquiry for "walkin@childfocusnj.org" with first name "Pat" and last name "Walker"
    Then a volunteer should exist for "walkin@childfocusnj.org"
    And they should be marked as attended for "March 2025 Info Session"
    And the walk-in volunteer status should reflect attended session
    And an application email should be triggered for "walkin@childfocusnj.org"
