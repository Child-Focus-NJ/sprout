Feature: Dashboard
  As a staff member
  I want the dashboard to show headline numbers and charts
  So that I can see where the volunteer pipeline stands when I log in

  Background:
    Given I am a signed-in system administrator
    And the dashboard has volunteers in these stages:
      | name        | status           |
      | Harry Kane  | inquiry          |
      | Hana Kimura | inquiry          |
      | Sofia Reyes | application_sent |

  Scenario: Headline numbers
    When I visit the dashboard
    Then the "Volunteers" tile should show 3
    And the "Awaiting submission" tile should show 1

  Scenario: Charts draw in the browser
    When I visit the dashboard
    Then the inquiries per month chart should be drawn
    And the volunteers by stage chart should be drawn

  Scenario: Conversion and info session attendance
    Given an info session last week had 3 registrants and 2 checked in
    When I visit the dashboard
    Then the conversion card should show "0% of inquiries applied"
    And the attendance card should show "67% of registrants attended"

  Scenario: Awaiting submission list opens from a dropdown
    When I visit the dashboard
    Then the awaiting submission list should be collapsed
    When I open the awaiting submission dropdown
    Then "Sofia Reyes" should be in the awaiting submission list
