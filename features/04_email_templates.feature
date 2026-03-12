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
