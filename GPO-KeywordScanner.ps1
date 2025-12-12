# ==============================================================================
# GPO Keyword Scanner
# Purpose: Searches all GPOs for the string "DisabledHotKeys" inside the XML report.
# Output:  Exports GPO Name, Match Status, and Linked OU Path to CSV in C:\Temp.
# Author: James Romeo Gaspar
# Date: December 12, 2025
# ==============================================================================

$SearchTerm = "DisabledHotKeys"
$Timestamp  = Get-Date -Format "yyyy-MM-dd_HHmmss" 
$ExportPath = "C:\Temp\GPO_Scan_With_Path_$Timestamp.csv"

$GPOs = Get-GPO -All

$Results = @()
Write-Host "Scanning GPOs..." -ForegroundColor Cyan

foreach ($GPO in $GPOs) {

    $GPOReportString = Get-GPOReport -Guid $GPO.Id -ReportType Xml
    $MatchStatus = "No"
    $LinkedPath  = "-" 

    if ($GPOReportString -match $SearchTerm) {
        $MatchStatus = "Yes"
        [xml]$XmlData = $GPOReportString
        
        if ($XmlData.GPO.LinksTo) {
            $LinkedPath = ($XmlData.GPO.LinksTo.SOMPath) -join "; "
        } else {
            $LinkedPath = "Not Linked"
        }

        Write-Host "Match: $($GPO.DisplayName)" -ForegroundColor Green
    } else {
        Write-Host "No Match: $($GPO.DisplayName)" -ForegroundColor Gray
    }
    
    $CustomObject = [PSCustomObject]@{
        "GPO Name"    = $GPO.DisplayName
        "Match"       = $MatchStatus
        "Linked Path" = $LinkedPath
    }
    
    $Results += $CustomObject
}

$Results | Export-Csv -Path $ExportPath -NoTypeInformation

Write-Host "`n Scan Complete! Saved to: $ExportPath" -ForegroundColor Yellow
