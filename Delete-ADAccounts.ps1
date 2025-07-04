<#
.SYNOPSIS
    Deletes service accounts listed in a CSV file.

.DESCRIPTION
    The Remove-SVCAccounts function reads a CSV containing samAccountNames,
    then either deletes each account (or simulates deletion if -Simulation is used),
    logging successes, failures, and skips to a CSV.

.PARAMETER CsvPath
    Path to the input CSV file (default: C:\Temp\decomsvclist.csv).

.PARAMETER LogCsvPath
    Path to the output log CSV file (default: C:\Temp\DeletedSVCLog.csv).

.PARAMETER Simulation
    Switch. If set, performs a dry‐run only (no actual deletes).

.NOTES
    Author: James Romeo Gaspar
    Date: July 4, 2025
#>

function Remove-SVCAccounts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$CsvPath    = "C:\Temp\decomsvclist.csv",

        [Parameter(Mandatory = $false)]
        [string]$LogCsvPath = "C:\Temp\DeletedSVCLog.csv",

        [Parameter(Mandatory = $false)]
        [switch]$Simulation
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

    $results      = @()
    $successCount = 0
    $failCount    = 0
    $skipCount    = 0

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
            if ($Simulation) {
                Write-Host "SIMULATION: Would delete '$samAccountName'" -ForegroundColor Cyan
                $status = "Simulation - Deleted"
            } else {
                Remove-ADUser -Identity $samAccountName -Confirm:$false -ErrorAction Stop
                Write-Host "SUCCESS: Deleted '$samAccountName'" -ForegroundColor Green
                $status = "Deleted"
            }
            $successCount++
        } catch {
            Write-Host "ERROR: Failed to delete '$samAccountName' - $_" -ForegroundColor Red
            $status = "Failed - $_"
            $failCount++
        }

        $results += [PSCustomObject]@{
            samAccountName = $samAccountName
            Status         = $status
        }
    }

    $results | Export-Csv -Path $LogCsvPath -NoTypeInformation

    $totalCount = $users.Count

    if ($Simulation) {
        Write-Host "`nSimulation complete. No accounts were actually deleted.`n"
    } else {
        Write-Host "`nProcessing complete. Full log written to $LogCsvPath`n"
    }

    Write-Host "Summary:"
    Write-Host "-------------------------"
    Write-Host "Total accounts processed : $totalCount"
    Write-Host "Successfully deleted     : $successCount"
    Write-Host "Failed to delete         : $failCount"
    Write-Host "Skipped (blank entries)  : $skipCount"
}


# Simulation: Default Setting
Remove-SVCAccounts -Simulation

# Actual Deletion 
# Remove-SVCAccounts
