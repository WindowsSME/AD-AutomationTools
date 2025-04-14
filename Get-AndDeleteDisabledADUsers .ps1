function Get-AndDeleteDisabledADUsers {

    # =============================================================  
    # Script: Automated Deletion of Disabled AD Accounts  
    # Author: James Romeo Gaspar  
    # Date: 14 February 2025  
    # Version: 1.1 (Updated: 18 February 2025)  
    # - Added comments to explain various sections and actions.  
    # - Included a detailed comment section outlining purpose, tasks, features, and benefits.  
    # =============================================================  
    # Description:  
    # - Identifies disabled AD accounts that have been inactive for more than 90 days.  
    # - Supports a "Simulation Mode" to log actions without actual deletions.  
    # - Deletes selected disabled accounts when in "Real Mode" and logs results.  
    # =============================================================  

    <#  
    Purpose:  
    - Automates the identification and management of disabled Active Directory (AD) user accounts that have been inactive for more than 90 days.  

    =============================================  
    Main Tasks:  
    1. **AD User Data Extraction:**  
       - Queries Active Directory for disabled user accounts.  
       - Filters users based on their last modified date (older than 90 days).  
       - Retrieves specific user properties (e.g., email, department, title).  
       - Exports user details to a CSV file for review.  

    2. **Simulated or Actual Deletion:**  
       - "Simulation" mode: Logs intended deletions without making changes.  
       - "Real" mode: Deletes selected disabled users from AD.  
       - Logs all actions (successes and failures) for auditing.  

    =============================================  
    Key Features:  
    - **Customizable User Properties:** Define additional user attributes to retrieve.  
    - **Simulation Mode:** Test the script safely before executing real deletions.  
    - **Logging:** Ensures transparency by recording all actions.  

    =============================================  
    Benefits:  
    - Cost-effective way to clean up old, disabled user accounts.  
    - Provides an opportunity to review accounts before permanent deletion.  
    - Enhances efficiency and control over AD user cleanup, reducing manual effort.  
    #>  


    # Define function parameters with default values
    [CmdletBinding()]
    param (

        # Output directory for CSV files and logs
        [string]$OutputDir = "C:\Temp\ADDisabledDelete",

        # Additional properties to retrieve for each user
        [string[]]$AdditionalProperties = @("EmailAddress", "Department", "Title"),

        # Simulation mode switch to avoid accidental deletion
        [switch]$Simulate
    )

    # Check if output directory exists; if not, attempt to create it
    if (-not (Test-Path -Path $OutputDir)) {
        try {
            New-Item -Path $OutputDir -ItemType Directory -Force
        } catch {
            Write-Error "Failed to create output directory: $_"
            return
        }
    }

    # Display message on console to indicate the beginning of the user extraction process
    Write-Host ""
    Write-Host "Extracting AD accounts that have been disabled for more than 90 days. Please wait..." -ForegroundColor Yellow

    # Define the threshold date (Set to 90 days ago by default)
    $thresholdDate = (Get-Date).AddDays(-90)
    
    # Include additional properties to be retrieved from AD
    $allProperties = @("Modified", "Enabled") + $AdditionalProperties

    try {

        # Query Active Directory for disabled users whose last modified date is older than 90 days
        $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties $allProperties |
            Where-Object { $_.Modified -lt $thresholdDate }
    } catch {
        Write-Error "Error querying Active Directory: $_"
        return
    }

    # If no disabled users found, display message and exit
    if ($disabledUsers.Count -eq 0) {
        Write-Host "No disabled users found with a Modified date before $thresholdDate." -ForegroundColor Yellow
        return
    }

    # Generate timestamp for file names to ensure uniqueness
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

    # Define file paths for exporting results and logs
    $OutputPath = Join-Path -Path $OutputDir -ChildPath "DisabledADUsers_$timestamp.csv"
    $LogPath = Join-Path -Path $OutputDir -ChildPath "Logs_$timestamp.csv"
    
    # Initialize empty arrays to store user data and log entries
    $results = @()
    $log = @()

    
    # Display message indicating data extraction
    Write-Host "Showing extraction results..." -ForegroundColor Cyan

    # Loop through each disabled user to build the result data
    foreach ($user in $disabledUsers) {
        # Create custom object with all necessary properties dynamically
        $result = [PSCustomObject]@{
            SamAccountName = $user.SamAccountName
            Name           = $user.Name
            Enabled        = $user.Enabled
            whenChanged    = $user.whenChanged
        } 

        # Add additional properties dynamically
        $AdditionalProperties | ForEach-Object { $result | Add-Member -MemberType NoteProperty -Name $_ -Value ($user.$_ -as [string] -replace "\r|\n", " ") }

        # Add the result to the array
        $results += $result

    }

    # Display extracted results in a table format
    $results | Format-Table -AutoSize

    try {

        # Export the results to a CSV file
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "Results exported to $OutputPath" -ForegroundColor Cyan
        Write-Host ""
    } catch {
        # Handle any errors encountered while exporting results
        Write-Error "Error exporting results to CSV: $_"
        Write-Host ""
        return
    }

    # Print message indicating deletion process will begin
    Write-Host ""
    Write-Host "Deleting extracted disabled AD Accounts..." -ForegroundColor Cyan

    # Loop through each disabled user for deletion or simulation
    foreach ($user in $disabledUsers) {
        if ($Simulate) {

            # In simulation mode, log the deletion action without actually performing it
            $log += [PSCustomObject]@{
                Action          = "[SIMULATION] User '$($user.SamAccountName)' would be deleted."
                Timestamp       = Get-Date
            }
            Write-Host ""
            Write-Host "[SIMULATION] User '$($user.SamAccountName)' would be deleted." -ForegroundColor Yellow
        } else {
            try {

                # Perform the actual deletion of the user from AD
                Remove-ADUser -Identity $user.SamAccountName -Confirm:$false
                $log += [PSCustomObject]@{
                    Action    = "User '$($user.SamAccountName)' deleted."
                    Timestamp = Get-Date
                }
                Write-Host ""
                Write-Host "User '$($user.SamAccountName)' deleted." -ForegroundColor Green
            } catch {

                # If an error occurs during deletion, log the failure
                $log += [PSCustomObject]@{
                    Action    = "Failed to delete user '$($user.SamAccountName)': $_"
                    Timestamp = Get-Date
                }
                Write-Host ""
                Write-Error "Failed to delete user '$($user.SamAccountName)': $_"
            }
        }
    }

    try {

        # Export the log data to a CSV file
        $log | Export-Csv -Path $LogPath -NoTypeInformation
        Write-Host ""
        Write-Host "Logs exported to $LogPath" -ForegroundColor Cyan
    } catch {

        # Handle errors when exporting the log file
        Write-Host ""
        Write-Error "Error exporting logs to CSV: $_"
    }
}


# Call the function with simulation mode enabled. Simulation switch on by default.
Get-AndDeleteDisabledADUsers -Simulate

# Call the function without simulation to perform actual deletion
# Get-AndDeleteDisabledADUsers
