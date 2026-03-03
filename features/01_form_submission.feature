Feature: Form Submission
  As a potential volunteer
  I want to submit an inquiry form
  So that I can sign up for an information session

  Scenario: Successful submission creates a new inquiry and shows confirmation
    Given I am on the inquiry form page
    When I submit a valid inquiry for "jane@example.com"
    Then I should see a submission confirmation
    And an inquiry should exist for "jane@example.com"

  Scenario: Missing required fields shows validation errors
    Given I am on the inquiry form page
    When I submit an inquiry missing an email
    Then I should see an email required error
    And no inquiry should exist for "jane@example.com"
