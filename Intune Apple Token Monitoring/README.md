# Intune Apple Token Monitoring Script

This PowerShell script automatically monitors Apple tokens in Microsoft Intune and sends an email notification when any token is approaching its expiration date, based on a configurable threshold.

---

## 📌 Purpose

This script regularly checks the expiration status of the following Apple tokens in Microsoft Intune:

- Apple VPP Tokens
- Apple DEP Tokens
- Apple MDM Push Certificate

It generates a clean HTML report summarizing the status and sends it via email if any token is nearing expiration.

---

## ⚙️ Key Features

- Queries tokens using the Microsoft Graph API (Beta)
- Calculates remaining days (`DaysLeft`) until expiration
- Generates an HTML report with:
  - Type, Name, Apple ID, Expiration Date, Days Left, Status
  - Visual status indicators: ✅ OK or ❌ Critical
- Automated email delivery:
  - Only if at least one token falls below the configured threshold
  - Report included in the email body and as an attachment

---

## 🛠 Prerequisites

- Azure Automation Runbook or local PowerShell environment
- Azure AD (Entra ID) App registrations in each monitored tenant:
  - **Intune App** with permissions:
    - `DeviceManagementServiceConfig.Read.All`
    - `DeviceManagementApps.Read.All`
    - `Directory.Read.All`
  - **Mail App** with permission:
    - `Mail.Send`
- Azure Automation certificate assets:
  - `CERT_NAME_INTUNE`
  - `CERT_NAME_MAIL`
- Installed PowerShell module:
  - `MSAL.PS`

---

## 🔑 Configurable Parameters

| Parameter             | Description                                               |
|-----------------------|-----------------------------------------------------------|
| `$tenantIdIntune`    | Tenant ID of the Intune app                               |
| `$clientIdIntune`    | Client ID of the Intune app                               |
| `$certAssetIntune`   | Certificate asset name for the Intune app in Azure Automation |
| `$tenantIdMail`      | Tenant ID of the mail app                                 |
| `$clientIdMail`      | Client ID of the mail app                                 |
| `$certAssetMail`     | Certificate asset name for the mail app in Azure Automation |
| `$Sender`            | Sender email address                                      |
| `$Recipient`         | Recipient email address                                   |
| `$Organization`      | Organization name (shown in the report)                   |
| `$sendMailThreshold` | Number of days left to trigger email notifications (e.g., 30) |

---

## 📤 Email Output

- **Subject:**  
  `<Organization> | Intune Token Report - YYYY-MM-DD`

- **Body:**  
  HTML table with all token details.

- **Attachment:**  
  HTML report file (`IntuneTokenReport.html`).

---

## 🛡 Status Indicators in Report

| Status       | Condition           |
|--------------|---------------------|
| ✅ OK       | DaysLeft ≥ 30       |
| ❌ Critical | DaysLeft < 30       |

---

## 🚀 Script Workflow

1. Script runs on a schedule (e.g., daily via Azure Automation).
2. Retrieves token information from the Microsoft Graph API.
3. Calculates days left until expiration.
4. If at least one token is below the `$sendMailThreshold`:
   - Sends an email with the report.
5. If no tokens are below threshold:
   - Exits quietly with a log entry (no email sent).

---
