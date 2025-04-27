# SmartGraphApp-Register.ps1

SmartGraphApp-Register.ps1 is an PowerShell script designed to automate the registration of applications in Entra ID using the Microsoft Graph API.

## Features
- Automated Entra ID App registration
- Interactive Microsoft Graph API permission selection with typo-tolerant matching
- Authentication support via client secret or certificate upload
- Automatic creation of a Service Principal
- Automatic Admin Consent granting
- Reliable Microsoft Graph connection validation
- Secret generation with a fixed lifetime (1 year)

## Prerequisites
- PowerShell 7.x or later recommended
- Microsoft.Graph PowerShell module installed
- Permission to register applications and grant Admin Consent
- Access to an Entra ID tenant

## Installation
1. Clone the repository or download the `SmartGraphApp-Register.ps1` file.
2. Install the Microsoft.Graph module if not already installed:
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser -Force
