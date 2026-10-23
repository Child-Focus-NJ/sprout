Feature: Search the volunteers list and filter it by status
  As a staff member
  I want to search volunteers by name and switch between status tabs
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
