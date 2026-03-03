Feature: Email Automation
  As a system administrator
  I want emails to be sent automatically based on triggers
  So that staff does not need to send them manually

  Scenario: New inquiry triggers an email
    Given I clear all sent emails
    When I submit a valid inquiry for "jane@example.com"
    Then an email should be sent to "jane@example.com"

  Scenario: Invalid inquiry does not send an email
    Given I clear all sent emails
    When I submit an inquiry missing an email
    Then no email should be sent
