Feature: User Login
    As a volunteer or administrator
    I want to sign in using my Gmail account
    So that I can access the system without managing a separate password

    Background:
        Given I am on the login page

    Scenario: Successful Login
        When I complete the Google OAuth flow as a Child Focus user
        Then I am redirected to the volunteer home page

    Scenario: Unsuccessful Login
        Given I do not have a Child Focus NJ email domain
        When I attempt Google OAuth with a non-allowed email
        Then I should see a rejected Google OAuth outcome
        And I will be on the login page
