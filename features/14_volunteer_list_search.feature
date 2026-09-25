Feature: Search and filter the volunteers list
  As a staff member
  I want to search volunteers by name and filter them by status and county
  So that I can find one volunteer or a group without scrolling the whole list

  Background:
    Given I am a signed-in system administrator
    And the volunteers list contains:
      | name        | status               | county |
      | Harry Kane  | inquiry              | Bergen |
      | Hana Kimura | application_eligible | Bergen |
      | Sofia Reyes | inquiry              | Essex  |

  Scenario: Search volunteers by name
    Given I am on the volunteers list page
    When I search volunteers for "kane"
    Then I should see only these volunteers in the list: "Harry Kane"
    And I should see "Showing 1 of 3 volunteers"

  Scenario: Filter by status and county from the filter popup
    Given I am on the volunteers list page
    When I open the volunteer filters
    And I choose the status "Inquiry" and the county "Bergen"
    And I apply the volunteer filters
    Then I should see only these volunteers in the list: "Harry Kane"
    And the filter button should show 2 active filters
    And I should see "Status: Inquiry"
    And I should see "County: Bergen"

  Scenario: Clear all filters
    Given I am on the volunteers list page filtered to status "Inquiry"
    Then I should see only these volunteers in the list: "Harry Kane, Sofia Reyes"
    When I click "Clear all"
    Then I should see all 3 volunteers in the list

  Scenario: Filter popup closes when clicking away
    Given I am on the volunteers list page
    When I open the volunteer filters
    Then the volunteer filter popup should be open
    When I click outside the volunteer filter popup
    Then the volunteer filter popup should be closed
