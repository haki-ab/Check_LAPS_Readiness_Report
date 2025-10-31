# LAPS Readiness Check

Small PowerShell utility to check whether a Windows device is ready for Cloud LAPS (Microsoft Entra / Intune).

## Objective
Detect pre-policy readiness for Windows LAPS:
- Azure AD join status
- LAPS module/cmdlet presence
- presence of LAPS system files
- local Administrator account status

## Usage
1. Clone repo.
2. Run PowerShell as Administrator.
3. Execute:
```powershell
.\Check_LAPS_Readiness_Report.ps1
