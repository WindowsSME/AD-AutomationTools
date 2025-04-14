# AD-AutomationTools

PowerShell scripts for managing and auditing Active Directory environments. These tools are useful for routine maintenance, compliance reporting, and organizational cleanup.

---

## Included Scripts

### User & Account Info

- [Get-LastLoggedUser.ps1](./Get-LastLoggedUser.ps1)  
  Returns the most recent interactive user login — useful for tracking device ownership or troubleshooting.

- [Get-LocalUsers.ps1](./Get-LocalUsers.ps1)  
  Lists all local user accounts on the system along with status indicators.

### Hardware & Device Info

- [Get-Monitor-Serial.ps1](./Get-Monitor-Serial.ps1)  
  Fetches serial numbers of connected monitors — helpful for physical asset management and inventory.

- [Get-WebcamInfo.ps1](./Get-WebcamInfo.ps1)  
  Detects available webcam devices, identifies if they are internal or external, and includes fallback detection via WMI.

- [Get-AppID.ps1](./Get-AppID.ps1)  
  Retrieves the AppID (Application User Model ID) for Windows apps — useful for notifications or taskbar tweaks.

### System Health & Logs

- [QAChecker.ps1](./QAChecker.ps1)  
  Performs a series of basic system checks (uptime, disk space, antivirus status, etc.) to verify that the system meets internal QA standards.

- [Get-LogZips.ps1](./Get-LogZips.ps1)  
  Collects logs from common system locations (Event Logs, WindowsUpdate, etc.), then compresses them for export or escalation.

### Storage Analysis

- [Profile-SpaceCheck.ps1](./Profile-SpaceCheck.ps1)  
  Scans all user profile folders and reports disk usage, helping identify storage bloat and cleanup candidates.

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
