# OU Checker
# Author: James Romeo Gaspar
# 1 April 2024

$computersFilePath = "C:\Temp\ADComputers.txt"

if (Test-Path $computersFilePath) {
    $fileContent = Get-Content $computersFilePath
    if ($fileContent -and ($fileContent | Where-Object { $_.Trim() -ne "" })) {
        $computers = $fileContent
        $totalComputers = $computers.Count
        $processedComputers = 0

        $results = foreach ($computer in $computers) {
            try {
                $adcomputer = Get-ADComputer -Identity $computer -Properties Created, Modified, LastLogonDate -ErrorAction Stop
                $distinguishedName = $adcomputer.DistinguishedName
                [PSCustomObject]@{
                    'Computer Name' = $computer
                    'Creation Date' = $adcomputer.Created
                    'Last Logon Date'     = $adcomputer.LastLogonDate
                    'Last Modified Date' = $adcomputer.Modified
                    'Enabled' = $adcomputer.Enabled
                    'Organizational Unit' = ($distinguishedName -split ",", 2)[1]
                }
                $processedComputers++
            } catch {
                [PSCustomObject]@{
                    'Computer Name' = $computer
                    'Creation Date' = "N/A"
                    'Last Logon Date'     =  "N/A"  # Corrected property name
                    'Last Modified Date' = "N/A"
                    'Enabled' = "N/A"
                    'Organizational Unit' = "Computer Object does not exist in AD"
                }
            }
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "ouChecker_$timestamp.csv"
        $results | Export-Csv -Path "C:\Temp\$filename" -NoTypeInformation
        Write-Host "Total computers in the list: $totalComputers | Computers processed: $processedComputers" -ForegroundColor Green
        Write-Host "Exported results to C:\Temp\$filename" -ForegroundColor Cyan
    } else {
        Write-Host "The file 'ADComputers.txt' is empty." -ForegroundColor Red
    }
} else {
    Write-Host "The file 'ADComputers.txt' is missing in the directory C:\Temp. Please create file then try again." -ForegroundColor Red
}
