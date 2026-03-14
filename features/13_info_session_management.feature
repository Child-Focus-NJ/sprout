Feature: Manage Information Sessions
    As a system administrator  
    I want to create, edit, and cancel information sessions
    So that I can maintain organized session offerings

    Background:
        Given the following information sessions exist:
            | capacity | location             | name                          | scheduled_at        | 
            | 10       | 415 Hamburg Turnpike | Tuesday Evening Info Session  | 2027-03-06 18:00:00 | 
            | 10       | Zoom                 | Thursday Evening Info Session | 2027-04-16 18:00:00 |
            | 10       | 415 Hamburg Turnpike | Monday Morning Info Session   | 2025-12-08 10:00:00 |

        Given the following volunteers exist:
            | email              | first_name | last_name | 
            | johndoe3@childfocusnj.org | John       | Doe       | 
            | janedoe2@childfocusnj.org | Jane       | Doe       | 
        And I am a signed-in system administrator
        And I am on the information session management page

        Scenario: Creating an information session successfully
            Given I click the "Create New" navigation button
            Then I should be on the create new information session page
            And I have selected "415 Hamburg Turnpike" from "Location"
            And I have filled out the "Name" field with "Monday Morning Info Session"
            And I have filled out the "Date & Time" field with "2027-03-16T10:00"
            And I have clicked the "Create Event" button
            Then I am on the information session management page
            And an information session with date Mar 16, 2027 and time 10:00 AM should be on the list of information sessions
            And an information session with date Mar 16, 2027 and time 10:00 AM should be on the inquiry form

        Scenario: Creating a Zoom information session
            Given I click the "Create New" navigation button
            Then I should be on the create new information session page
            And I have selected "Zoom" from "Location"
            And I have filled out the "Name" field with "Monday Morning Info Session"
            And I have filled out the "Date & Time" field with "2027-04-06T10:00"
            And I have clicked the "Create Event" button
            Then I am on the information session management page
            And an information session with date Mar 16, 2027 and time 10:00 AM should be on the list of information sessions
            And an information session with date Mar 16, 2027 and time 10:00 AM should be on the inquiry form
            And the information session with date Mar 16, 2027 and time 10:00 AM should have a Zoom link for the meeting
        
        Scenario: Creating an information session with missing fields
            Given I click the "Create New" navigation button
            Then I should be on the create new information session page
            And I have selected "415 Hamburg Turnpike" from "Location"
            And I have filled out the "Name" field with "Monday Morning Info Session"
            And I have left the "Date & Time" field blank
            And I have clicked the "Create Event" button
            Then a message that says "Must include date." will appear
            And an information session with a blank date should not be on the list of information sessions
            And an information session with a blank date should not be on the inquiry form

        Scenario: Creating an information session in the past
            Given I click the "Create New" navigation button
            Then I should be on the create new information session page
            And I have selected "415 Hamburg Turnpike" from "Location"
            And I have filled out the "Name" field with "Monday Morning Info Session"
            And I have filled out the "Date & Time" field with "2024-03-27T10:00"
            And I have clicked the "Create Event" button
            Then a message that says "Information session must be in the future" will appear
            And an information session with date Mar 27, 2027 and time 10:00 AM should not be on the list of information sessions
            And an information session with date Mar 27, 2027 and time 10:00 AM should not be on the inquiry form

        Scenario: Editing an information session time
            Given I am on the edit page for information session with date Mar 06, 2027 and time 06:00 PM
            And I edit the "Time" field to be "7:00 PM"
            And I click the "Save Changes" button
            And I click the "Back" button
            Then I am on the information session management page 
            And an information session with date Mar 06, 2027 and time 07:00 PM should be on the list of information sessions
            And an information session with date Mar 06, 2027 and time 07:00 PM should be on the inquiry form
            And an information session with date Mar 06, 2027 and time 06:00 PM should not be on the list of information sessions
            And an information session with date Mar 06, 2027 and time 06:00 PM should not be on the inquiry form
            And all attendees should receive a notification email that the time for the event they are signed up for has changed to 07:00 PM

        Scenario: Removing an attendee from an information session 
            Given I am on the edit page for information session with date Mar 06, 2027 and time 06:00 PM
            And I click the "Remove" button for attendee with name "John Doe"
            And I click the "Yes" button on the confirmation pop-up modal
            Then "John Doe" should not appear on the list of attendees for information session with date Mar 06, 2027 and time 06:00 PM
            And the status for "John Doe" should change from "Registered for information session" to "Inquiry Submitted"

        Scenario: An attendee cancels their sign up for an information session 
            Given John Smith cancels their sign up for information session with date Mar 06, 2027 and time 07:00 PM
            Then "John Doe" should not appear on the list of attendees for information session with date Mar 06, 2027 and time 06:00 PM
            And the status for "John Doe" should change from "Registered for information session" to "Inquiry Submitted"

        Scenario: Deleting an information session with confirmation
            Given I am on the information session management page
            And I click the "Delete" button for information session with date Mar 06, 2027 and time 06:00 PM
            And I click the "Yes" button on the confirmation pop-up modal
            Then an information session with date Mar 06, 2027 and time 06:00 PM should not be on the list of information sessions
            And every attendee should receive an email notification that the event was cancelled and be prompted to sign up for a new information session
            And every attendees status should change from "Registered for information session" to "Inquiry Submitted"

        Scenario: Deleting an information session without confirmation
            Given I am on the information session management page
            And I click the "Delete" button for information session with date Mar 06, 2027 and time 06:00 PM
            And I click the "No" button on the confirmation pop-up modal
            Then an information session with date Mar 06, 2027 and time 06:00 PM should be on the list of information sessions

        Scenario: Viewing all upcoming information sessions 
            Given I am on the information session management page
            Then an information session with date Mar 06, 2027 and time 06:00 PM should be on the list of information sessions
            And an information session with date Apr 16, 2027 and time 06:00 PM should be on the list of information sessions

        
        Scenario: Filtering information sessions by date
            Given I am on the information session management page
            And I have filled out the "Start Date" field with "03/01/27"
            And I have filled out the "End Date" field with "03/31/27"
            And I have clicked the "Filter" button
            Then an information session with date Mar 06, 2027 and time 06:00 PM should be on the list of information sessions
            And an information session with date Apr 16, 2027 and time 06:00 PM should not be on the list of information sessions

        Scenario: Filtering information sessions by Upcoming/Past
            Given I am on the information session management page
            And I have changed the "Upcoming" dropdown to "Past" 
            And I have clicked the "Filter" button
            Then an information session with date Mar 06, 2027 and time 06:00 PM should not be on the list of information sessions
            And an information session with date Apr 16, 2027 and time 06:00 PM should not be on the list of information sessions
            And an information session with date Dec 08, 2025 and time 10:00 AM should be on the list of information sessions

        Scenario: Sending a reminder email the day before an information session
            Given "John Doe" has signed up for an information session with date Mar 06, 2027 and time 07:00 PM
            And "Jane Doe" has signed up for an information session with date Mar 06, 2027 and time 07:00 PM
            When the reminder job runs
            Then "John Doe" should receive a reminder email about the session
            And "Jane Doe" should receive a reminder email about the session
            