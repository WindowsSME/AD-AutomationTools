<# 
.SYNOPSIS
  Add AD users (by sAMAccountName) to security groups from a CSV.

.DESCRIPTION
  CSV columns:
    - privileged_user : sAMAccountName of the user
    - role            : Security Groups

.USAGE
  .\Add-UserToSG.ps1 -CsvPath .\privileged_users.csv -Verbose
  .\Add-UserToSG.ps1 -CsvPath .\privileged_users.csv -ReportPath .\AddUsersToSG_results.csv -UserSam jg3098662.admin -WhatIf


.AUTHOR
  Jame Romeo Gaspar
  September 12, 2025
  Revision 3.0

#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory=$true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CsvPath,

  [Parameter()] [char]$Delimiter = ',',
  [Parameter()] [string]$ReportPath,

  [Parameter()] [string]$UserSam,

  [Parameter()]
  [string]$RejectCommentsValue = 'Access revoked by default due to no action taken'
)

function Initialize-ADEnvironment {
  if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    throw "The ActiveDirectory module is not installed on this machine."
  }
  Import-Module ActiveDirectory -ErrorAction Stop
}

function Resolve-ADUser {
  param([string]$Sam)
  try {
    $u = Get-ADUser -Identity $Sam -Properties MemberOf
    if (-not $u) { throw }
    return $u
  } catch {
    throw "User with sAMAccountName '$Sam' was not found."
  }
}

function Resolve-ADGroup {
  param([string]$Id)
  try {
    $g = Get-ADGroup -Identity $Id -Properties GroupCategory
    if ($g) { return $g }
  } catch { }
  $g2 = Get-ADGroup -Filter "Name -eq '$Id'" -Properties GroupCategory
  if ($g2) { return $g2 }
  throw "Group '$Id' was not found."
}

function Test-GroupDirectMembership {
  param(
    [Microsoft.ActiveDirectory.Management.ADGroup]$Group,
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )
  try {
    $members = Get-ADGroupMember -Identity $Group.DistinguishedName -Recursive:$false -ErrorAction Stop
    return $members.DistinguishedName -contains $User.DistinguishedName
  } catch {
    return $false
  }
}

function ConvertTo-GroupList {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
  $raw = $Text -split '[;,|]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  return $raw | Select-Object -Unique
}

try {
  Initialize-ADEnvironment

  if (-not $UserSam) {
    $UserSam = Read-Host -Prompt 'Enter sAMAccountName to process'
  }
  $UserSam = $UserSam.Trim()
  if ([string]::IsNullOrWhiteSpace($UserSam)) { throw 'No sAMAccountName provided.' }

  Write-Verbose "Loading CSV from '$CsvPath'..."
  $rows = Import-Csv -Path $CsvPath -Delimiter $Delimiter -ErrorAction Stop
  if (-not $rows) { throw "CSV '$CsvPath' has no rows." }

  $cols = $rows[0].PSObject.Properties.Name
  foreach ($required in 'privileged_user','role','reject_comments') {
    if ($cols -notcontains $required) {
      throw "CSV missing required column '$required'. Present columns: $([string]::Join(',', $cols))"
    }
  }

  $targetReject = $RejectCommentsValue.Trim()
  $matchedRows = $rows | Where-Object {
    $_.privileged_user -and ($_.privileged_user.Trim()) -ieq $UserSam -and
    $_.reject_comments -and ($_.reject_comments.Trim()) -eq $targetReject
  }

  if (-not $matchedRows) {
    throw "No rows for user '$UserSam' with reject_comments '$targetReject' found in CSV."
  }

  Write-Verbose ("Matched {0} row(s) for user '{1}' with reject_comments '{2}'." -f ($matchedRows.Count), $UserSam, $targetReject)

  $allGroupNames = @()
  foreach ($r in $matchedRows) {
    $allGroupNames += ConvertTo-GroupList -Text ([string]$r.role)
  }
  $allGroupNames = $allGroupNames | Where-Object { $_ } | Select-Object -Unique

  if ($allGroupNames.Count -eq 0) {
    throw "User '$UserSam' has no groups listed in matching CSV rows."
  }

  $user = Resolve-ADUser -Sam $UserSam

  $groupCache = @{}
  $results = New-Object System.Collections.Generic.List[object]

  foreach ($gName in $allGroupNames) {

    if (-not $groupCache.ContainsKey($gName)) {
      try {
        $groupCache[$gName] = Resolve-ADGroup -Id $gName
      } catch {
        $results.Add([pscustomobject]@{ UserSam=$UserSam; Group=$gName; Status='GroupNotFound'; Message=$_.Exception.Message })
        continue
      }
    }
    $group = $groupCache[$gName]

    if ($group.GroupCategory -ne 'Security') {
      $results.Add([pscustomobject]@{ UserSam=$UserSam; Group=$group.Name; Status='Skipped'; Message='Not a security group' })
      continue
    }

    if (Test-GroupDirectMembership -Group $group -User $user) {
      $results.Add([pscustomobject]@{ UserSam=$UserSam; Group=$group.SamAccountName; Status='AlreadyMember'; Message='No action' })
      continue
    }

    if ($PSCmdlet.ShouldProcess("Group '$($group.SamAccountName)'", "Add member '$($user.SamAccountName)'")) {
      try {
        Add-ADGroupMember -Identity $group.DistinguishedName -Members $user.DistinguishedName -ErrorAction Stop
        $results.Add([pscustomobject]@{ UserSam=$UserSam; Group=$group.SamAccountName; Status='Added'; Message='Success' })
      } catch {
        $results.Add([pscustomobject]@{ UserSam=$UserSam; Group=$group.SamAccountName; Status='Error'; Message=$_.Exception.Message })
      }
    }
  }

  $results | Sort-Object Group | Format-Table -AutoSize

  if ($ReportPath) {
    $results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8 -Append
    Write-Host "Report written to $ReportPath"
  }

  Write-Verbose "Done."
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
