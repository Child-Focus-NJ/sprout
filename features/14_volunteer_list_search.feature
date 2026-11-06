Feature: Search the volunteers list and filter it by status, vicinage, inquiry source and status date
  As a staff member
  I want to search volunteers by name, switch between status tabs and filter by vicinage, inquiry source or when they reached their status
  So that I can find one volunteer or a group without scrolling the whole list

  Background:
    Given I am a signed-in system administrator
    And the volunteers list contains:
      | name        | status               | vicinage | inquired   | source        |
      | Harry Kane  | inquiry              | Union    | 2026-09-01 | Tabling Event |
      | Hana Kimura | application_eligible | Union    | 2026-08-15 | Tabling Event |
      | Sofia Reyes | inquiry              | Passaic  | 2026-10-01 | Idealist      |

  Scenario: Search volunteers by name
    Given I am on the volunteers list page
    When I search volunteers for "kane"
    Then I should see only these volunteers in the list: "Harry Kane"

  Scenario: Pick a status tab
    Given I am on the volunteers list page
    Then the "All" status tab should be selected with 3 volunteers
    When I click the "Inquiry" status tab
    Then I should see only these volunteers in the list: "Harry Kane, Sofia Reyes"
    And the "Inquiry" status tab should be selected with 2 volunteers

  Scenario: Search stays on the current status tab
    Given I am on the volunteers list page
    When I click the "Inquiry" status tab
    And I search volunteers for "ha"
    Then I should see only these volunteers in the list: "Harry Kane"
    And the "Inquiry" status tab should be selected with 1 volunteers

  Scenario: Back to everyone from the All tab
    Given I am on the volunteers list page filtered to status "Inquiry"
    When I click the "All" status tab
    Then I should see all 3 volunteers in the list

  Scenario: Filter by vicinage inside a status tab
    Given I am on the volunteers list page
    When I click the "Inquiry" status tab
    And I open the volunteer filters
    And I choose the vicinage "Union"
    And I apply the volunteer filters
    Then I should see only these volunteers in the list: "Harry Kane"
    And the "Inquiry" status tab should be selected with 1 volunteers
    And the filter button should show 1 active filters
    And I should see "Vicinage: Union"
    When I click the "All" status tab
    Then I should see only these volunteers in the list: "Harry Kane, Hana Kimura"

  Scenario: Filter by inquiry source
    Given I am on the volunteers list page
    When I open the volunteer filters
    And I choose the inquiry source "Tabling Event"
    And I apply the volunteer filters
    Then I should see only these volunteers in the list: "Harry Kane, Hana Kimura"
    And the "All" status tab should be selected with 2 volunteers
    And the filter button should show 1 active filters
    And I should see "Inquiry source: Tabling Event"

  Scenario: Filter by when volunteers moved into their current status
    Given I am on the volunteers list page
    When I open the volunteer filters
    And I set the status date from "2026-08-01" to "2026-09-15"
    And I apply the volunteer filters
    Then I should see only these volunteers in the list: "Harry Kane"
    And the "All" status tab should be selected with 1 volunteers
    And the filter button should show 1 active filters
    And I should see "Status date: Aug 1, 2026 – Sep 15, 2026"

  Scenario: Back from a profile returns to the same tab, search and vicinage
    Given I am on the volunteers list page
    When I click the "Inquiry" status tab
    And I open the volunteer filters
    And I choose the vicinage "Union"
    And I apply the volunteer filters
    And I search volunteers for "ha"
    And I open the profile for "Harry Kane"
    And I click "Back to volunteers"
    Then I should see only these volunteers in the list: "Harry Kane"
    And the "Inquiry" status tab should be selected with 1 volunteers
    And I should see "Vicinage: Union"
    And the volunteer search should contain "ha"

  Scenario: The Inquiry tab lists the newest inquiries first with their dates
    Given I am on the volunteers list page
    When I click the "Inquiry" status tab
    Then I should see these volunteers in order: "Sofia Reyes, Harry Kane"
    And I should see "Inquired Oct 1, 2026"
    And I should see "Inquired Sep 1, 2026"

  Scenario: Filter popup closes when clicking away
    Given I am on the volunteers list page
    When I open the volunteer filters
    Then the volunteer filter popup should be open
    When I click outside the volunteer filter popup
    Then the volunteer filter popup should be closed
