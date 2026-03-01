Feature: Account Management
  As a system administrator
  I want to prevent duplicate volunteer accounts
  So that I can track the volunteer journey accurately

  Scenario: Duplicate email does not create a second volunteer
    Given a volunteer exists with email "dup@example.com"
    When I submit a valid inquiry for "dup@example.com"
    Then there should still be only 1 volunteer with email "dup@example.com"
    And I should see a duplicate email message

  Scenario: Normalized email matches an existing volunteer
    Given a volunteer exists with email "casey@example.com"
    When I submit a valid inquiry for "  CASEY@EXAMPLE.COM "
    Then there should still be only 1 volunteer with email "casey@example.com"
    And I should see a duplicate email message