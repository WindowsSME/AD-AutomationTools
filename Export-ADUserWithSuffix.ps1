function Export-ADUserWithSuffix {
<#
.SYNOPSIS
  Export AD users with sAMAccountName in the form <prefix>.<suffix>,
  into separate CSVs for active and inactive accounts.

.DESCRIPTION
  Filters AD accounts where the part before the dot matches a regex (default: two letters + seven digits).
  Optionally restricts suffixes (e.g., .admin, .user). 
  Outputs two CSVs: one for enabled users, one for disabled users.

.PARAMETER OutputFolder
  Folder where CSVs will be written. Defaults to current directory.

.PARAMETER SearchBase
  LDAP distinguishedName to limit the search scope.

.PARAMETER Suffix
  Specific suffixes to match (e.g., -Suffix admin,user). 
  If omitted, any suffix is matched.

.PARAMETER PreDotRegex
  Regex pattern that the part before the dot must match. 
  Default is ^[A-Za-z]{2}\d{7}$ (two letters + seven digits).

.EXAMPLE
  Export-ADUserWithSuffix

.EXAMPLE
  Export-ADUserWithSuffix -Suffix admin,user

.EXAMPLE
  Export-ADUserWithSuffix -SearchBase "OU=Users,DC=contoso,DC=com"

.NOTES
  Author : James Romeo Gaspar
  Date : September 26, 2025

#>

    [CmdletBinding()]
    param(
        [Parameter()][string]$OutputFolder = (Get-Location).Path,
        [Parameter()][string]$SearchBase,
        [Parameter()][string[]]$Suffix,
        [Parameter()][string]$PreDotRegex = '^[A-Za-z]{2}\d{7}$'
    )

    function Ensure-ActiveDirectoryModule {
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            throw "The ActiveDirectory module is not available. Install RSAT (Active Directory module) and try again."
        }
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    try {
        Ensure-ActiveDirectoryModule

        if ($Suffix -and $Suffix.Count -gt 0) {
            $suffixes = $Suffix | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $orParts  = $suffixes | ForEach-Object { "sAMAccountName -like '*.$($_)'" }
            $filter   = '(' + ($orParts -join ' -or ') + ')'
        } else {
            $filter = "sAMAccountName -like '*.*'"
        }

        $props = @(
            'sAMAccountName','givenName','sn','displayName','department','title',
            'mail','enabled','whenCreated','whenChanged','manager'
        )


        $commonParams = @{
            Filter        = $filter
            Properties    = $props
            ResultSetSize = $null
            ErrorAction   = 'Stop'
        }
        if ($SearchBase) { $commonParams['SearchBase'] = $SearchBase }

        $candidates = Get-ADUser @commonParams

        $regex = '^(?<core>[^\.]+)\.(?<suffix>[^\.]+)$'
        $users =
            $candidates |
            Where-Object {
                if ($_.sAMAccountName -match $regex) {
                    $core   = $Matches['core']
                    $suffix = $Matches['suffix']
                    if ($core -match $PreDotRegex) {
                        if ($Suffix -and $Suffix.Count -gt 0) {
                            $Suffix -contains $suffix
                        } else { $true }
                    } else { $false }
                } else { $false }
            }

        $projection = {
            $preDot = ($_.sAMAccountName -split '\.')[0]
            $eid    = ($preDot -replace '[^\d]', '')
            $managerName = $null
            if ($_.manager) {
                try {
                    $mgr = Get-ADUser -Identity $_.manager -Properties displayName -ErrorAction Stop
                    $managerName = $mgr.displayName
                } catch {
                    $managerName = $_.manager
                }
            }

            [PSCustomObject]@{
                SamAccountName = $_.sAMAccountName
                EID            = $eid
                'First Name'   = $_.givenName
                'Last Name'    = $_.sn
                'Display Name' = $_.displayName
                Department     = $_.department
                'Job Title'    = $_.title
                'Email Address'= $_.mail
                Manager        = $managerName
                Enabled        = [bool]$_.enabled
                'Creation Date'= $_.whenCreated
                'Modified Date'= $_.whenChanged
            }
        }




        $shaped   = $users | ForEach-Object $projection
        $active   = $shaped | Where-Object { $_.Enabled -eq $true }
        $inactive = $shaped | Where-Object { $_.Enabled -eq $false }

        if (-not (Test-Path -LiteralPath $OutputFolder)) {
            New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        }

        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $activePath   = Join-Path $OutputFolder "AD_Users_WithSuffix_ACTIVE_$ts.csv"
        $inactivePath = Join-Path $OutputFolder "AD_Users_WithSuffix_INACTIVE_$ts.csv"

        $active   | Export-Csv -Path $activePath   -NoTypeInformation -Encoding UTF8
        $inactive | Export-Csv -Path $inactivePath -NoTypeInformation -Encoding UTF8

        Write-Host "Export complete."
        Write-Host "Active users:   $activePath"
        Write-Host "Inactive users: $inactivePath"
    }
    catch {
        Write-Error $_
        exit 1
    }
}

Export-ADUserWithSuffix -OutputFolder "C:\Temp" 
