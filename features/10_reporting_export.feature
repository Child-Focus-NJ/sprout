Feature: Reporting & Exporting
    As a system administrator  
    I want to generate reports and export data  
    So that I can analyze trends and use data in other systems

    Background:
        Given I am a signed-in system administrator
        And I am on the reporting and exporting page
        And the following volunteers exist:
            | email              | first_name | last_name | 
            | sammy123@gmail.com | Samantha   | Ray       |
        
        And the following information sessions exist:
            | capacity | location             | name                          | scheduled_at        | 
            | 10       | 415 Hamburg Turnpike | Tuesday Evening Info Session  | 2026-03-06 18:00:00 | 
            | 10       | Zoom                 | Thursday Evening Info Session | 2025-04-16 18:00:00 |
            | 10       | 415 Hamburg Turnpike | Monday Morning Info Session   | 2024-12-08 10:00:00 |

        Scenario: Exporting PDF report comparing sign-ups by year
            Given 200 volunteers signed up for information sessions in 2026
            And 189 volunteers signed up for information sessions in 2025
            And 205 volunteers signed up for information sessions in 2024
            And I select "years" in the "x-axis" dropdown in the create a report section
            And I select "information session sign-ups" in the "y-axis" dropdown in the create a report section
            And I have filled out the "Start Date" field with "01/01/2024" in the create a report section
            And I have filled out the "End Date" field with "12/31/2026" in the create a report section
            And I enter "sign-ups24-26" as the title in the create a report section
            And I select "PDF" in the "report format" dropdown in the create a report section
            And I have clicked the "Export Report" button
            Then a PDF named "sign-ups24-26" should be in my downloads folder
            And the PDF should contain a bar chart with the years 2024, 2025, and 2026 on the x-axis

        Scenario: Printing PDF report comparing applications by year
            Given 33 volunteers signed up for information sessions in 2026
            And 20 volunteers signed up for information sessions in 2025
            And 15 volunteers signed up for information sessions in 2024
            And I select "years" in the "x-axis" dropdown in the create a report section
            And I select "applications" in the "y-axis" dropdown in the create a report section
            And I have filled out the "Start Date" field with "01/01/2024" in the create a report section
            And I have filled out the "End Date" field with "12/31/2026" in the create a report section
            And I select "PDF" in the "report format" dropdown in the create a report section
            And I enter "applications24-26" as the title in the create a report section
            And I have clicked the "Print" button
            Then a PDF report should be sent to the printer

        Scenario: Exporting data to CSV, Excel, and JSON
            Given I select "Excel" in the "export format" dropdown in the export data section
            And Samantha Ray attended an information session in 2024
            And Samantha Ray has status "Attended an Information Session"
            And I select "Attended an Information Session" in the "Status" dropdown in the export data section
            And I have filled out the "Start Date" field with "01/01/2024" in the export data section
            And I have filled out the "End Date" field with "12/31/2024" in the export data section
            And I enter "Attendees2024" as the title in the create a report section
            And I have clicked the "Export Data" button
            Then an excel file named "Attendees2024" should be in my downloads folder
            And the excel sheet should contain "Samantha Ray"
            And the excel sheet should contain "Attended an Information Session"
            And the excel sheet should contain "sammy123@gmail.com"
