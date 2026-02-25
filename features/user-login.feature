Feature: User Login
    As a volunteer or administrator  
    I want to sign in using my Gmail account  
    So that I can access the system without managing a separate password

    Background:
        Given I am on the login page
        
        Scenario: Successful Login
            Given I have a CASA email domain
            And I click the "Sign In" button
            Then I am redirected to the volunteer home page

        Scenario: Unsuccessful Login
            Given I do not have a CASA email domain
            And I click the "Sign In" button
            Then I will receive the message "Must use a CASA associated email"
            And I will be on the login page

    