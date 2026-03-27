Feature: Email Automation
  As a system administrator
  I want emails to be sent automatically based on triggers
  So that staff does not need to send them manually

  Background:
    Given I am a signed-in system administrator

  Scenario: New inquiry triggers an email
    Given I clear all sent emails
    And I am on the inquiry form page
    When I submit a valid inquiry for "jane@childfocusnj.org"
    Then an email should be sent to "jane@childfocusnj.org"

  Scenario: Invalid inquiry does not send an email
    Given I clear all sent emails
    And I am on the inquiry form page
    When I submit an inquiry missing an email
    Then no email should be sent
