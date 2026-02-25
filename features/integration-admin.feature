Feature: Integration & Administration
    As a system administrator  
    I want to integrate with external systems and manage settings  
    So that data stays synchronized and the system is configurable
    
    Background:
    Given a volunteer profile exists in the system
    Given an administrator is logged in


        Scenario : Notify when volunteer data is transferred
            Given a volunteer profile has been transferred to the external system
            Then the system should notify the administrator that the transfer was successful
        
        Scenario : Show transfer status in volunteer profile
            Given a volunteer profile has been transferred to the external system
            When an administrator views the volunteer profile
            Then the transfer status and date/time of the transfer should be visible

        Scenario: Send data on application submission
            Given a volunteer submits an application
            Then the system should send the volunteer data to the external system

        Scenario: Keep volunteers in the system for future communications
            Given a volunteer submits an application
            Then the volunteer should remain in the system for future email communications

        Scenario: Role-based access control for administrators
            Given multiple user accounts exist
            When a user with administrator privileges logs in
            Then they should be able to access integration and settings management features
            And a user without administrator privileges should not see these options

        Scenario: Change reminder frequencies
            When they update the reminder frequency settings
            Then the new reminder frequency should be applied to all applicable notifications

        Scenario: Import historical data with duplicate detection
            Given a CSV/Excel/JSON file containing historical volunteer data is imported
            Then the system should detect duplicate records
            And import unique volunteer data
            And provide a summary of imported and skipped records

            
