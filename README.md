# AD-AutomationTools

PowerShell scripts for managing and auditing Active Directory environments. These tools are useful for routine maintenance, compliance reporting, and organizational cleanup.

---

## Included Scripts

### [Delete-ADComputers.ps1](./Delete-ADComputers.ps1)
Identifies and removes inactive or stale computer objects from AD.

### [Move-ADComputers.ps1](./Move-ADComputers.ps1)
Automatically moves computers to target OUs based on name or criteria.

### [Get-AllADOUs.ps1](./Get-AllADOUs.ps1)
Exports a list of all Organizational Units (OUs) in the AD domain.

### [OUChecker.ps1](./OUChecker.ps1)
Validates the existence and structure of key OUs in the domain.

### [GPO-get-targeted-data.ps1](./GPO-get-targeted-data.ps1)
Pulls GPO-targeted settings or linked objects for analysis.

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
