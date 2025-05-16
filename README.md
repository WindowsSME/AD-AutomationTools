# Active Directory Automation Tools

PowerShell scripts for managing and auditing Active Directory environments. These tools are useful for routine maintenance, compliance reporting, and organizational cleanup.

---

## Included Scripts

### Cleanup & Housekeeping

- [Delete-AD-Computers.ps1](./Delete-AD-Computers.ps1)  
  Identifies and removes inactive or stale computer objects from Active Directory.

- [Delete-ADComputers.ps1](./Delete-ADComputers.ps1)  
  Alternative version for removing obsolete computer accounts.

- [Disable-ADAccounts.ps1](./Disable-ADAccounts.ps1)  
  Disables AD user accounts based on last logon or custom criteria.

- [Get-AndDeleteDisabledADUsers.ps1](./Get-AndDeleteDisabledADUsers.ps1)  
  Finds and optionally deletes user accounts that are disabled or inactive.

### Reporting & Inventory

- [Get-AllADOUs.ps1](./Get-AllADOUs.ps1)  
  Retrieves a list of all Organizational Units (OUs) in the domain.

- [OUChecker.ps1](./OUChecker.ps1)  
  Checks for the presence of expected OUs and validates basic AD structure.

- [GPO-get-targeted-data.ps1](./GPO-get-targeted-data.ps1)  
  Extracts GPO-linked object data to identify targeted users, groups, or OUs.

### Account Management

- [Reset-ADAccountsPW.ps1](./Reset-ADAccountsPW.ps1)  
  Resets passwords for multiple AD user accounts in bulk based on input.

---

## Usage

Run each script within a domain-joined PowerShell session with administrative privileges.

```powershell
.\ScriptName.ps1
```
Make sure the ActiveDirectory PowerShell module is installed.

---

## Notes
These scripts were tested in hybrid and on-prem AD environments.
Ensure you test in a lab before applying changes in production.

---

## Contributions
Have your own AD scripts? Feel free to fork, add, and open a pull request.

---

## License
MIT License
