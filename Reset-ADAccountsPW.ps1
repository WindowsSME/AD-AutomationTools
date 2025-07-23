function Test-PasswordComplexity {
    param (
        [string]$PlainTextPassword
    )

    $lengthOK = $PlainTextPassword.Length -ge 30
    $uppercaseCount = ([regex]::Matches($PlainTextPassword, '[A-Z]')).Count
    $hasUpper = $uppercaseCount -ge 2
    $hasDigit = $PlainTextPassword -match '\d'
    $hasSpecial = $PlainTextPassword -match '[^a-zA-Z\d]'

    return $lengthOK -and $hasUpper -and $hasDigit -and $hasSpecial
}

function Reset-Passwords {
    param (
        [string]$CSVFilePath,
        [string]$LogFileDirectory = "C:\Temp",
        [switch]$WhatIf
    )

$maxAttempts = 1
$attemptCount = 0
$valid = $false
$logFile = "C:\Temp\PasswordPromptFailures.log"

function Generate-CompliantPassword {
    # Define NOT-allowed special characters
    $notAllowedSpecials = @('$', '"', "'", '`', '\', '/', '&', '%', '^', ':', ';', '.', ',') 

    # Create a list of all printable special characters (ASCII 33–47, 58–64, 91–96, 123–126)
    $allSpecials = @()
    $ranges = @(33..47 + 58..64 + 91..96 + 123..126)
    foreach ($code in $ranges) {
        $char = [char]$code
        if ($char -notin $notAllowedSpecials) {
            $allSpecials += $char
        }
    }

    # Build required components
    $uppercase = -join ((65..90) | Get-Random -Count 2 | ForEach-Object {[char]$_})
    $lowercase = -join ((97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_})
    $digits    = -join ((48..57) | Get-Random -Count 4 | ForEach-Object {[char]$_})
    $specials  = -join ($allSpecials | Get-Random -Count 3)
    $randomFiller = -join ((33..126) | Get-Random -Count 1 | ForEach-Object {[char]$_})

    # Combine and shuffle
    $passwordArray = ($uppercase + $lowercase + $digits + $specials + $randomFiller).ToCharArray()
    $shuffled = $passwordArray | Sort-Object {Get-Random}
    
    return -join $shuffled
}

    do {
        $attemptCount++

        $rawInput = Read-Host "Enter the new password to set for all users (or type 'cancel' to exit)"
    
        if ($rawInput -eq "cancel") {
            Write-Host "`n Cancel requested. Exiting..." -ForegroundColor Magenta
            exit
        }

        $plainTextPassword = $rawInput
        $securePassword = ConvertTo-SecureString $plainTextPassword -AsPlainText -Force

        if (Test-PasswordComplexity -PlainTextPassword $plainTextPassword) {
            $valid = $true
        } else {
            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Attempt ${attemptCount}: Password did not meet complexity."
            Add-Content -Path $logFile -Value $logEntry

            if ($attemptCount -ge $maxAttempts) {
                Write-Host "`n Maximum attempts reached. A compliant password will be auto-generated." -ForegroundColor Red
                $generatedPassword = Generate-CompliantPassword
                Write-Host "`n Generated Password: $generatedPassword" -ForegroundColor Green
                $generatedPassword | Set-Clipboard
                Read-Host "`n Password copied to clipboard. Press [Enter] after you've pasted it..."
                Set-Clipboard -Value ' '
                Write-Host " Clipboard cleared." -ForegroundColor DarkGray

                $securePassword = ConvertTo-SecureString $generatedPassword -AsPlainText -Force
                $valid = $true
            } else {
                Write-Host "`nPassword did not meet requirements. Please try again." -ForegroundColor Yellow
            }
        }

    } until ($valid)


    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath "PasswordResetLog_$timestamp.csv"
    $accounts = Import-Csv -Path $CSVFilePath
    $logData = @()

    Write-Host "`n Processing accounts from CSV..." -ForegroundColor Cyan

    foreach ($account in $accounts) {
        $samAccountName = $account.samAccountName
        $passwordResetStatus = "Failed"

        Write-Host "`n Processing account: $samAccountName" -ForegroundColor Yellow

        try {
            $user = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -Properties whenCreated, whenChanged, LockedOut
            if ($user) {
                Write-Host "Found account: $samAccountName" -ForegroundColor Green

                $createdDate = $user.whenCreated
                $originalLastModifiedDate = $user.whenChanged
                $needToUnlock = $user.LockedOut -eq $true

                if ($needToUnlock) {
                    Write-Host "Account is locked. Will unlock." -ForegroundColor Red
                }

                if (-not $WhatIf) {
                    if ($needToUnlock) {
                        Unlock-ADAccount -Identity $samAccountName
                        Write-Host "Account unlocked." -ForegroundColor Green
                    }

                    Write-Host "Resetting password..." -ForegroundColor Cyan
                    Set-ADAccountPassword -Identity $samAccountName -Reset -NewPassword $securePassword
                    Set-ADUser -Identity $samAccountName -ChangePasswordAtLogon $true
                    $passwordResetStatus = "Success"
                } else {
                    Write-Host "[WhatIf] Would unlock and reset password for: $samAccountName" -ForegroundColor DarkCyan
                    $passwordResetStatus = "Simulated (WhatIf)"
                }

                $currentLastModifiedDate = (Get-ADUser -Identity $samAccountName -Properties whenChanged).whenChanged

                $logData += [pscustomobject]@{
                    SamAccountName           = $samAccountName
                    CreatedDate              = $createdDate
                    OriginalLastModifiedDate = $originalLastModifiedDate
                    CurrentLastModifiedDate  = $currentLastModifiedDate
                    NeedToUnlock             = if ($needToUnlock) { "Yes" } else { "No" }
                    PasswordResetStatus      = $passwordResetStatus
                }
            } else {
                Write-Warning "Account $samAccountName does not exist."
                $logData += [pscustomobject]@{
                    SamAccountName           = $samAccountName
                    CreatedDate              = "N/A"
                    OriginalLastModifiedDate = "N/A"
                    CurrentLastModifiedDate  = "N/A"
                    NeedToUnlock             = "No"
                    PasswordResetStatus      = "Account does not exist"
                }
            }
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Error "Error processing account ${samAccountName}: $errorMessage"
            $logData += [pscustomobject]@{
                SamAccountName           = $samAccountName
                CreatedDate              = "N/A"
                OriginalLastModifiedDate = "N/A"
                CurrentLastModifiedDate  = "N/A"
                NeedToUnlock             = "No"
                PasswordResetStatus      = $errorMessage
            }
        }
    }

    Write-Host "`nExporting log to $LogFilePath..." -ForegroundColor Cyan
    $logData | Export-Csv -Path $LogFilePath -NoTypeInformation -Force

    Write-Host "`n Password reset completed. Log saved to:`n$LogFilePath" -ForegroundColor Green
}

# Example usage:
Reset-Passwords -CSVFilePath "C:\Temp\AccountsToReset.csv" -WhatIf
# Reset-Passwords -CSVFilePath "C:\Temp\AccountsToReset.csv"
