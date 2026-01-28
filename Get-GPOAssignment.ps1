<#
.SYNOPSIS
    Scans all Group Policy Objects (GPOs) to find which ones have "GPO Apply" 
    permissions for a specific security group or a list of groups offers 
    a CSV export at the end of the scan.

.DESCRIPTION
    This script provides an interactive prompt to either check a single security group 
    manually or import a list of groups from a text file. It includes a progress bar 
    for visual feedback and outputs the final results to a searchable GridView.

.PARAMETER GroupName
    The name of the single security group to search for (used in Option 1).

.PARAMETER FilePath
    The path to the text file containing group names, one per line (used in Option 2).

.NOTES
    Author: James Romeo Gaspar
    Date: January 28, 2026
#>

Import-Module GroupPolicy

Write-Host "`n--- GPO Security Group Scanner ---" -ForegroundColor Cyan
Write-Host "1. Scan for a SINGLE group"
Write-Host "2. Scan using a TEXT FILE list"
$choice = Read-Host "Select an option (1 or 2)"

$TargetGroups = @()

if ($choice -eq "1") {
    $name = Read-Host "Enter the Security Group name"
    if ([string]::IsNullOrWhiteSpace($name)) { Write-Error "Name cannot be empty."; return }
    $TargetGroups = @($name)
} 
elseif ($choice -eq "2") {
    $path = Read-Host "Enter the file path (Default: C:\Temp\SecurityGroups.txt)"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = "C:\Temp\SecurityGroups.txt" }

    if (Test-Path $path) {
        $TargetGroups = Get-Content -Path $path
        Write-Host "Imported $($TargetGroups.Count) groups from file." -ForegroundColor Gray
    } else {
        Write-Error "File not found at $path"; return
    }
} 
else {
    Write-Error "Invalid selection."; return
}

$gpos = Get-GPO -All
$totalGpos = $gpos.Count
$currentIndex = 0
$result = @()

foreach ($gpo in $gpos) {
    $currentIndex++
    $percentComplete = ($currentIndex / $totalGpos) * 100
    Write-Progress -Activity "Checking GPO Permissions" `
                   -Status "Processing: $($gpo.DisplayName)" `
                   -PercentComplete $percentComplete

    try {
        $permissions = Get-GPPermission -Guid $gpo.Id -All
        foreach ($perm in $permissions) {
            if ($TargetGroups -contains $perm.Trustee.Name -and $perm.Permission -match "GpoApply") {
                $result += [PSCustomObject]@{
                    Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm"
                    GPOName    = $gpo.DisplayName
                    GroupName  = $perm.Trustee.Name
                    Permission = $perm.Permission
                    GPOID      = $gpo.Id
                }
            }
        }
    } catch {

    }
}

Write-Progress -Activity "Checking GPO Permissions" -Completed

if ($result.Count -eq 0) {
    Write-Host "`nNo matches found for the specified group(s)." -ForegroundColor Red
} else {
    Write-Host "`nScan complete! Found $($result.Count) assignments." -ForegroundColor Green

    $result | Out-GridView -Title "GPO Matches Found"

    $exportChoice = Read-Host "Would you like to export these results to CSV? (Y/N)"
    if ($exportChoice -eq "Y") {
        $exportPath = "C:\Temp\GPOScan_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

        if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory | Out-Null }
        
        $result | Export-Csv -Path $exportPath -NoTypeInformation
        Write-Host "Results saved to: $exportPath" -ForegroundColor Cyan
    }
}
