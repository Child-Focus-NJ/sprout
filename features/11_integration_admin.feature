Feature: Integration & Administration
    As a system administrator  
    I want to integrate with external systems and manage settings  
    So that data stays synchronized and the system is configurable

    Background:
        Given I am a signed-in system administrator
        And I am on the system management page
        And the following users exist:
            | email                     | first_name | last_name | role     |
            | joel777@childfocusnj.org  | Joel       | Savitz    | staff    |
            | robh89@childfocusnj.org   | Robert     | Hernandez | staff    |
        
        And the following volunteers exist:
            | email                     | first_name | last_name | 
            | katej@childfocusnj.org    | Katie      | Jones     | 
            | eddyh@childfocusnj.org    | Edward     | Henning   |

        And the following reminder frequencies exist:
            | title      |
            | Six Months |

        And the following volunteer tags exist:
            | title |
            | VIP   |
        
        
        Scenario: Volunteer data transferred to external system successfully
            Given "Katie Jones" submits an application
            Then I should receive a notification that "Katie Jones" data was transferred to the external system
            And the status for "Katie Jones" should be "Applied"
            And the profile for "Katie Jones" should include a note that says "Data transferred to external system" with the time and date that it occurred

        Scenario: Changing reminder frequencies
            Given I click "Remove" for "Six Months"
            And I have clicked the "Add Frequency" button
            And I enter "Three Months" in the "frequency_title" field
            And I have clicked the "Save Frequency" button
            Then I should see "Three Months" on the frequency list
            And I should not see "Six Months" on the frequency list

        Scenario: Changing volunteer tags
            Given I click "Remove" for "VIP"
            And I have clicked the "Add Tag" button
            And I enter "Temporarily Inactive" in the "tag_title" field
            And I have clicked the "Save Tag" button
            Then I should see "Temporarily Inactive" on the frequency list
            And I should not see "VIP" on the frequency list

        Scenario: Importing historical data
            And I upload an Excel sheet containing "Colin Smith"
            Then "Colin Smith" should appear on the volunteers page

        Scenario: Removing an Employee
            Given I have clicked the "Remove" button for "Joel Savitz"
            Then I should get a confirmation box that says "Are you sure you want to remove this user?"
            And I click "Yes"
            Then I should not see "Joel Savitz" on the page

        Scenario: Adding an Employee
            And I have clicked the "Add Employee" button
            And I enter "Kevra" in the "First Name" field
            And I enter "Scholl" in the "Last Name" field
            And I enter "kevra23@childfocusnj.org" in the "Email" field
            And I select "Staff" in the "Role" dropdown field
            And I have clicked the "Save Employee" button
            Then "Kevra Scholl" should appear on the page
