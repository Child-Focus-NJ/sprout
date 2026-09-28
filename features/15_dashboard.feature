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
