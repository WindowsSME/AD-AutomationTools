#Author: James Romeo Gaspar
$LogPath = "C:\Scripts\Logs\DeleteCompObj\ComputerDeletionLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

$Log = @()

$DeletedCount = 0
$NotFoundCount = 0

Get-Content C:\Temp\ADComputers.txt | ForEach-Object {
    $computerName = $_

    $computer = Get-ADComputer -Filter { Name -eq $computerName } -Properties LastLogonTimestamp,Modified,Enabled,DistinguishedName -ErrorAction SilentlyContinue

    if ($computer) {
        $lastLogon = [DateTime]::FromFileTime($computer.LastLogonTimestamp).ToString("yyyy-MM-dd HH:mm:ss")
        $modified = $computer.Modified
        $enabled = $computer.Enabled
        $ou = $computer.DistinguishedName

        $computer | Remove-ADObject -Recursive -Confirm:$false -Verbose -WhatIf

        $LogEntry = [PSCustomObject]@{
            ComputerName = $computerName
            Deleted = "Yes"
            LastAccessedDate = $lastLogon
            LastModifiedDate = $modified
            Enabled = $enabled
            LastKnownOU = $ou
        }

        $DeletedCount++
    }
    else {

        $LogEntry = [PSCustomObject]@{
            ComputerName = $computerName
            Deleted = "No"
            LastAccessedDate = ""
            LastModifiedDate = ""
            Enabled = "Computer does not exist in Active Directory"
            LastKnownOU = ""
        }

        $NotFoundCount++
    }
    $Log += $LogEntry
}

$CountLogEntry = [PSCustomObject]@{
    ComputerName = "Total"
    Deleted = "Deleted $DeletedCount computers. Not found in AD: $NotFoundCount computers."
    LastAccessedDate = ""
    LastModifiedDate = ""
    Enabled = ""
    LastKnownOU = ""
}
$Log += $CountLogEntry

$Log | Export-Csv -Path $LogPath -NoTypeInformation

Write-Output "Deleted $DeletedCount computers. Not found in AD: $NotFoundCount computers."
