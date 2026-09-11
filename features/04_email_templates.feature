Feature: Email Templates
  As a system administrator
  I want to manage email templates
  So that I can send consistent communications

  Scenario: Admin creates an email template
    Given I am a signed-in system administrator
    When I create an email template named "Welcome" with subject "Welcome {{first_name}}" and body "Hi {{first_name}}!"
    Then I should see the template "Welcome" in the templates list

  Scenario: Admin previews a template with sample data
    Given I am a signed-in system administrator
    And an email template exists named "Welcome" with subject "Welcome {{first_name}}" and body "Hi {{first_name}}!"
    When I preview the template "Welcome" using a sample volunteer named "Jane"
    Then I should see "Welcome Jane"
    And I should see "Hi Jane!"

  Scenario: Admin edits an existing template
    Given I am a signed-in system administrator
    And an email template exists named "Welcome" with subject "Welcome {{first_name}}" and body "Hi {{first_name}}!"
    When I edit the template "Welcome" to have the subject "Welcome back {{first_name}}"
    Then the template "Welcome" should have subject "Welcome back {{first_name}}"

  Scenario: Admin deletes a template
    Given I am a signed-in system administrator
    And an email template exists named "Old Newsletter" with subject "Old" and body "Old body"
    When I delete the template "Old Newsletter"
    Then I should not see the template "Old Newsletter" in the templates list
