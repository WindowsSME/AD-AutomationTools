# Active Directory Automation Tools

PowerShell scripts for managing and auditing Active Directory environments. These tools are useful for routine maintenance, compliance reporting, and organizational cleanup.

---

## Included Scripts

### Cleanup & Housekeeping

- [Delete-ADAccounts.ps1](./Delete-ADAccounts.ps1)  
  Deletes specified user accounts from the domain based on input criteria.

- [Delete-ADComputers.ps1](./Delete-ADComputers.ps1)  
  Identifies and removes inactive or stale computer objects from Active Directory.

- [Disable-ADAccounts.ps1](./Disable-ADAccounts.ps1)  
  Disables AD user accounts based on last logon or custom criteria.

- [Get-AndDeleteDisabledADUsers.ps1](./Get-AndDeleteDisabledADUsers.ps1)  
  Finds and optionally deletes user accounts that are disabled or inactive.

### Reporting & Inventory

- [Get-ExactADLastLogon.ps1](./Get-ExactADLastLogon.ps1)  
  Queries all Domain Controllers to find the most accurate "Last Logon" timestamp for a user, bypassing replication delays.

- [Check-ADGroups.ps1](./Check-ADGroups.ps1)  
  Audits Active Directory groups to list memberships and identify empty or nested groups.

- [Export-ADUserWithSuffix.ps1](./Export-ADUserWithSuffix.ps1)  
  Exports user data specifically filtered by UPN suffix—useful for migrations or multi-domain reporting.

- [Get-ADUser-Suffix-and-SGs.ps1](./Get-ADUser-Suffix-and-SGs.ps1)  
  Extracts enabled AD accounts with suffixes and their associated security group memberships.

- [Get-AllADOUs.ps1](./Get-AllADOUs.ps1)  
  Retrieves a comprehensive list of all Organizational Units (OUs) within the domain.

- [OUChecker.ps1](./OUChecker.ps1)  
  Validates the Active Directory structure by checking for the presence of required OUs.

### Account Management

- [Add-UserToSG.ps1](./Add-UserToSG.ps1)  
  Bulk adds users to a specified Security Group via CSV or list input.

- [Reset-ADAccountsPW.ps1](./Reset-ADAccountsPW.ps1)  
  Resets passwords for multiple AD user accounts in bulk.

### GPO & Infrastructure Management

- [GPO-KeywordScanner.ps1](./GPO-KeywordScanner.ps1)  
  Scans Group Policy Objects for specific keywords—ideal for finding hardcoded IPs, sensitive strings, or deprecated settings.

- [Get-GPOAssignment.ps1](./Get-GPOAssignment.ps1)  
  Scans the domain to report exactly where specific GPOs are linked and their enforcement status.

- [GPO-get-targeted-data.ps1](./GPO-get-targeted-data.ps1)  
  Extracts GPO-linked object data to identify specifically targeted users, groups, or OUs.

- [DHCP-Enterprise-Auditor.ps1](./DHCP-Enterprise-Auditor.ps1)  
  Audits DHCP server configurations and scopes across the enterprise for consistency and compliance.

- [User-ID-Agent-Audit-Tool.ps1](./User-ID-Agent-Audit-Tool.ps1)  
  Audits Palo Alto User-ID agent mappings and logs to ensure accurate identity-to-IP correlation.

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
