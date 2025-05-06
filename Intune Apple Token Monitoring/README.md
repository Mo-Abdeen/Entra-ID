# Intune Apple Token Monitoring Script

Dieses PowerShell-Script überwacht automatisch die Apple-Token in Microsoft Intune und sendet eine E-Mail-Benachrichtigung, wenn ein Token in weniger als einer definierten Anzahl von Tagen abläuft.

---

## 📌 Zweck

Das Script prüft regelmäßig den Ablauf folgender Apple-Token in Intune:
- Apple VPP Tokens
- Apple DEP Tokens
- Apple MDM Push Certificate

Es erstellt einen übersichtlichen HTML-Report mit den wichtigsten Informationen und verschickt diesen per E-Mail, wenn mindestens ein Token unter den konfigurierten Schwellwert fällt.

---

## ⚙️ Hauptfunktionen

- Abfrage der Token über die Microsoft Graph API (Beta)
- Berechnung der verbleibenden Tage (`DaysLeft`) bis zum Ablauf
- Erstellung eines HTML-Reports mit:
  - Typ, Name, Apple ID, Ablaufdatum, Resttage, Status
  - Status-Visualisierung: ✅ OK oder ❌ Critical
- Automatischer E-Mail-Versand mit dem Report:
  - Nur wenn mindestens ein Token unter dem Schwellwert liegt
  - Report im Body und als Anhang

---

## 🛠 Voraussetzungen

- Azure Automation Runbook oder lokale PowerShell-Umgebung
- App-Registrierungen in Azure AD (Entra ID) in jedem überwachten Tenant:
  - Intune App mit Berechtigungen:
    - `DeviceManagementServiceConfig.Read.All`
    - `DeviceManagementApps.Read.All`
    - `Directory.Read.All`
  - Mail-App mit Berechtigung:
    - `Mail.Send`
- Zertifikat-Assets in Azure Automation:
  - `CERT_NAME_INTUNE`
  - `CERT_NAME_MAIL`

- Installierte PowerShell-Module:
  - `MSAL.PS`

---

## 🔑 Konfigurierbare Parameter

| Parameter             | Beschreibung                                          |
|-----------------------|-------------------------------------------------------|
| `$tenantIdIntune`    | Tenant ID der Intune-App                              |
| `$clientIdIntune`    | Client ID der Intune-App                              |
| `$certAssetIntune`   | Zertifikat-Asset-Name der Intune-App in Azure Automation |
| `$tenantIdMail`      | Tenant ID der Mail-App                                |
| `$clientIdMail`      | Client ID der Mail-App                                |
| `$certAssetMail`     | Zertifikat-Asset-Name der Mail-App in Azure Automation |
| `$Sender`            | Absender-E-Mail-Adresse                               |
| `$Recipient`         | Empfänger-E-Mail-Adresse                              |
| `$Organization`      | Organisationsname (wird im Report angezeigt)          |
| `$sendMailThreshold` | Schwellwert in Tagen (z. B. 30), unter dem eine E-Mail ausgelöst wird |

---

## 📤 E-Mail-Ausgabe

- **Betreff:**  
  `<Organization> | Intune Token Report - YYYY-MM-DD`

- **Body:**  
  HTML-Tabelle mit allen Token-Informationen.

- **Anhang:**  
  HTML-Report-Datei (`IntuneTokenReport.html`).

---

## 🛡 Statusdefinition im Report

| Status       | Bedingung                 |
|--------------|---------------------------|
| ✅ OK       | DaysLeft ≥ 30             |
| ❌ Critical | DaysLeft < 30             |

---

## 🚀 Ablauf

1. Script läuft (z. B. täglich per Azure Automation).
2. Holt Token-Informationen über Graph API.
3. Berechnet Resttage bis Ablauf.
4. Wenn mindestens 1 Token unter `$sendMailThreshold`:
   - E-Mail mit Report wird verschickt.
5. Wenn keine Token unter Schwellwert:
   - Script beendet sich ohne E-Mail (es wird nur ein Logeintrag geschrieben).


