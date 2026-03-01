Feature: Integration & Administration
    As a system administrator  
    I want to integrate with external systems and manage settings  
    So that data stays synchronized and the system is configurable

    Background:
        Given I am on the system management page
        And the following users exist:
            | email              | first_name | last_name | role     |
            | joel777@gmail.com  | Joel       | Savitz    | employee |
            | robh89@gmail.com   | Robert     | Hernandez | employee |
        
        And the following volunteers exist:
            | email              | first_name | last_name | 
            | katej@gmail.com    | Katie      | Jones     | 
            | eddyh@gmail.com    | Edward     | Henning   |
        
        
        Scenario: Volunteer data transferred to external system successfully
            Given I am a signed-in system administrator
            And "Katie Jones" submits an application
            Then I should receive a notification that "Katie Jones" data was transferred to the external system
            And the status for "Katie Jones" should be "Applied"
            And the profile for "Katie Jones" should include a note that says "Data transferred to external system" with the time and date that it occurred

        Scenario: Changing reminder frequencies 
            Given I am a signed-in system administrator
            And I click "Remove" for "Six Months"
            And I have clicked the "Add Frequency" button
            And I enter "Three Months" in the "title" field
            Then I should see "Three Months" on the frequency list
            And I should not see "Six Months" on the frequency list

        Scenario: Changing volunteer tags 
            Given I am a signed-in system administrator
            And I click "Remove" for "VIP"
            And I have clicked the "Add Tag" button
            And I enter "Temporarily Inactive" in the "title" field
            Then I should see "Temporarily Inactive" on the frequency list
            And I should not see "VIP" on the frequency list

        Scenario: Importing historical data
            Given I am a signed-in system administrator
            And I have clicked the "Import Data" button
            And I upload an Excel sheet containing "Colin Smith"
            Then "Colin Smith" should appear on the volunteers page

        Scenario: Removing an Employee
            Given I am a signed-in system administrator
            And I have clicked the "Remove" button for "Joel Savitz"
            Then I should get a confirmation box that says "Are you sure you want to remove this user?"
            And I click "Yes"
            Then I should not see "Joel Savitz" on the page

        Scenario: Adding an Employee
            Given I am a signed-in system administrator
            And I have clicked "Add Employee"
            And I enter "Kevra" in the "First Name" field
            And I enter "Scholl" in the "Last Name" field
            And I enter "kevra23@gmail.com" in the "Email" field
            And I select "Employee" in the "Role" dropdown field
            And I have clicked the "Add Employee" button
            And I have clicked the "Confirm" on the confirmation modal
            Then "Kevra Scholl" should appear on the page
