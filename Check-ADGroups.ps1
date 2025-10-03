<#
--------------------------------------------------------------------------------------
Script:    Check-ADGroups.ps1
Author:    James Romeo Gaspar
Date:      October 3, 2025
Purpose:   Reads a list of security groups from a CSV file and generates a report
           showing if they have members, how many, and their creation/modified dates.

Instructions:

1. Prerequisites:
   - Run the script in a PowerShell session with appropriate AD permissions.

2. Input (Required):
   - Prepare a CSV file with a column header named "SG".
   - Each row under "SG" should contain the name of an AD security group.
   - Default Input CSV (C:\Temp\InputGroups.csv):


3. Output (Automatically Generated):
   - After running the script, a CSV file named "GroupResults.csv" will be created 
     in the same path defined in the script (default: C:\Temp\GroupResults.csv).
   - This output file will include the following columns:
        SG                  → Group name
        With Members        → "Yes" if members exist, "None" if empty, "N/A" if not found
        Number of Members   → Count of members (0 if empty)
        Created Date        → When the group was created
        Last Modified Date  → Last modification date of the group object

4. Usage:
   - Save this script as Check-ADGroups.ps1.
   - Update the `$groups` input path if your CSV is located elsewhere.
   - Run the script in PowerShell:
        .\Check-ADGroups.ps1

5. Additional Info:
   - A progress bar will display while groups are being processed.
   - Missing groups will still be included in the output with "N/A" values.
--------------------------------------------------------------------------------------
#>


# Import list of groups from CSV (must have column "SG")
$groups = Import-Csv -Path "C:\Temp\InputGroups.csv"

# Prepare output array
$output = @()
$total = $groups.Count
$counter = 0

foreach ($g in $groups) {
    $counter++

    # Show progress bar
    Write-Progress -Activity "Processing Groups" `
                   -Status "Checking $($g.SG) ($counter of $total)" `
                   -PercentComplete (($counter / $total) * 100)

    $groupName = $g.SG
    try {
        # Get group details
        $group = Get-ADGroup -Identity $groupName -Properties whenCreated, whenChanged
        
        # Get group members
        $members = Get-ADGroupMember -Identity $groupName -ErrorAction SilentlyContinue
        $memberCount = if ($members) { $members.Count } else { 0 }

        # Build output object
        $obj = [PSCustomObject]@{
            SG                  = $groupName
            "With Members"      = if ($memberCount -gt 0) { "Yes" } else { "None" }
            "Number of Members" = $memberCount
            "Created Date"      = $group.whenCreated
            "Last Modified Date"= $group.whenChanged
        }

        $output += $obj
    }
    catch {
        Write-Warning "Could not find group: $groupName"
        $obj = [PSCustomObject]@{
            SG                  = $groupName
            "With Members"      = "N/A"
            "Number of Members" = "N/A"
            "Created Date"      = "N/A"
            "Last Modified Date"= "N/A"
        }
        $output += $obj
    }
}

# Export results to CSV
$output | Export-Csv -Path "C:\Temp\GroupResults.csv" -NoTypeInformation -Encoding UTF8
