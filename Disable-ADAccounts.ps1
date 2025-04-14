<#
.SYNOPSIS
    Disables list of SVC accounts in AD based on samAccountName from a CSV file.

.DESCRIPTION
    This script reads a list of SVC accounts from a CSV file, disables each account in Active Directory,
    and logs the results to a CSV file with status details for each account.
    It also displays progress and a summary to the console.

.PARAMETER CsvPath
    Full path to the input CSV file. The CSV must contain a header named 'samAccountName'.

.PARAMETER LogCsvPath
    Full path to the output CSV file where results will be logged.

.EXAMPLE
    Disable-SVCAccounts -CsvPath "C:\Temp\decomsvclist.csv" -LogCsvPath "C:\Temp\DisabledSVCLog.csv"

.NOTES
    Author: James Romeo Gaspar
    Created: April 10, 2025
#>

function Disable-SVCAccounts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CsvPath,

        [Parameter(Mandatory = $true)]
        [string]$LogCsvPath
    )

    if (-not (Test-Path $CsvPath)) {
        Write-Error "CSV file not found: $CsvPath"
        return
    }

    try {
        $users = Import-Csv -Path $CsvPath
    } catch {
        Write-Error "Failed to import CSV: $_"
        return
    }

    # Initialize counters and result list
    $results = @()
    $successCount = 0
    $failCount = 0
    $skipCount = 0

    foreach ($user in $users) {
        $samAccountName = $user.samAccountName

        if ([string]::IsNullOrWhiteSpace($samAccountName)) {
            $status = "Failed - Missing samAccountName"
            Write-Host "SKIPPED: $status" -ForegroundColor Yellow
            $skipCount++
            $results += [PSCustomObject]@{
                samAccountName = ""
                Status         = $status
            }
            continue
        }

        try {
            Disable-ADAccount -Identity $samAccountName -ErrorAction Stop
            $status = "Disabled"
            Write-Host "SUCCESS: Disabled '$samAccountName'" -ForegroundColor Green
            $successCount++
        } catch {
            $status = "Failed - $_"
            Write-Host "ERROR: Failed to disable '$samAccountName'" -ForegroundColor Red
            $failCount++
        }

        $results += [PSCustomObject]@{
            samAccountName = $samAccountName
            Status         = $status
        }
    }

    # Export results to CSV
    $results | Export-Csv -Path $LogCsvPath -NoTypeInformation

    $totalCount = $users.Count

    # Print summary
    Write-Host "`n Processing complete. Full log written to $LogCsvPath`n"
    Write-Host "Summary:"
    Write-Host "-------------------------"
    Write-Host "Total accounts processed : $totalCount"
    Write-Host "Successfully disabled    : $successCount"
    Write-Host "Failed to disable        : $failCount"
    Write-Host "Skipped (blank entries)  : $skipCount"
}

Disable-SVCAccounts -CsvPath "C:\Temp\decomsvclist.csv" -LogCsvPath "C:\Temp\DisabledSVCLog.csv"
