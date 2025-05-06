# ========================
# Konfiguration
# ========================
$tenantIdIntune  = ""  #Tenant ID der Intune-App
$clientIdIntune  = ""  #Client ID der Intune-App
$certAssetIntune = ""  #Zertifikat-Asset-Name der Intune-App in Azure Automation


$tenantIdMail    = ""  #Tenant ID der Mail-App 
$clientIdMail    = ""  #Client ID der Mail-App 
$certAssetMail   = ""  #Zertifikat-Asset-Name der Mail-App in Azure Automation

$Sender          = ""  #Absender-E-Mail-Adresse
$Recipient       = ""  #Empfänger-E-Mail-Adresse 
$Organization    = ""  #Organisationsname (wird im Report angezeigt)

$sendMailThreshold   = "30"  # Nur senden, wenn DaysLeft < 30   #Schwellwert in Tagen (z. B. 30), unter dem eine E-Mail ausgelöst wird

Import-Module MSAL.PS -Force

# ========================
# 1️⃣ Access Token Intune App
# ========================
$certIntune = Get-AutomationCertificate -Name $certAssetIntune
$tokenIntune = Get-MsalToken -ClientId $clientIdIntune -TenantId $tenantIdIntune -ClientCertificate $certIntune -Scopes "https://graph.microsoft.com/.default"
$accessTokenIntune = $tokenIntune.AccessToken
$headersIntune = @{ Authorization = "Bearer $accessTokenIntune"; "Content-Type" = "application/json" }

# ========================
# Graph-Abfragen Intune
# ========================
$endpoints = @{
    VPP = "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens"
    DEP = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings"
    MDM = "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate"
}

$results = @()
foreach ($type in $endpoints.Keys) {
    try {
        $response = Invoke-RestMethod -Uri $endpoints[$type] -Headers $headersIntune -Method GET
    } catch {
        Write-Warning "❌ Fehler bei ${type}: $_"
        continue
    }

    $items = if ($type -eq 'MDM') {
        @($response)
    } elseif ($response.value) {
        $response.value
    } else {
        @()
    }

    foreach ($item in $items) {
        if ($type -eq 'DEP') {
            $expirationRaw = $item.tokenExpirationDateTime
            $name = $item.tokenName
            $appleId = $item.appleIdentifier
        } else {
            $expirationRaw = $item.expirationDateTime
            $name = if ($item.displayName) { $item.displayName }
                    elseif ($item.tokenName) { $item.tokenName }
                    elseif ($item.organizationName) { $item.organizationName }
                    else { 'MDM Push Certificate' }
            $appleId = if ($item.appleId) { $item.appleId }
                       elseif ($item.appleIdentifier) { $item.appleIdentifier }
                       else { '' }
        }

        if (-not $expirationRaw) { continue }

        $expiration = Get-Date $expirationRaw
        $daysLeft = ($expiration - (Get-Date)).Days

        $results += [PSCustomObject]@{
            Type       = $type
            Name       = $name
            AppleId    = $appleId
            Expiration = $expiration.ToString("yyyy-MM-dd")
            DaysLeft   = $daysLeft
        }
    }
}

$belowThreshold = $results | Where-Object { $_.DaysLeft -lt $sendMailThreshold }

if ($belowThreshold.Count -gt 0) {
    $tableRows = ""
    if ($results.Count -eq 0) {
        $tableRows = "<tr><td colspan='6'>No tokens found.</td></tr>"
    } else {
        foreach ($r in $results | Sort-Object Type, Name) {
            $statusBadge = if ($r.DaysLeft -lt 30) {
                "<span class='badge bg-danger'>Critical ❌</span>"
            } else {
                "<span class='badge bg-success'>OK</span>"
            }
            $tableRows += "<tr><td>$($r.Type)</td><td>$($r.Name)</td><td>$($r.AppleId)</td><td>$($r.Expiration)</td><td>$($r.DaysLeft)</td><td>$statusBadge</td></tr>`n"
        }
    }

    $reportDate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $htmlBody = @"
<h2>$Organization Intune Token Report</h2>
<table border='1' cellpadding='5' cellspacing='0' style='border-collapse: collapse; width: 100%; font-family: Arial; font-size: 12px;'>
<tr style='background-color: #f2f2f2;'>
<th>Type</th>
<th>Name</th>
<th>Apple ID</th>
<th>Expiration</th>
<th>Days Left</th>
<th>Status</th>
</tr>
$tableRows
</table>
<p>Generated on $reportDate</p>
"@

    $reportPath = Join-Path $env:TEMP "IntuneTokenReport.html"
    $htmlBody | Out-File -FilePath $reportPath -Encoding UTF8

    # ========================
    # 2️⃣ Access Token Mail App
    # ========================
    $certMail = Get-AutomationCertificate -Name $certAssetMail
    $tokenMail = Get-MsalToken -ClientId $clientIdMail -TenantId $tenantIdMail -ClientCertificate $certMail -Scopes "https://graph.microsoft.com/.default"
    $accessTokenMail = $tokenMail.AccessToken
    $headersMail = @{ Authorization = "Bearer $accessTokenMail"; "Content-Type" = "application/json" }

    # ========================
    # E-Mail senden
    # ========================
    $fileBytes = [System.IO.File]::ReadAllBytes($reportPath)
    $base64File = [Convert]::ToBase64String($fileBytes)

    $attachment = @{
        "@odata.type" = "#microsoft.graph.fileAttachment"
        Name          = "IntuneTokenReport.html"
        ContentType   = "text/html"
        ContentBytes  = $base64File
        IsInline      = $false
    }

    $mailMessage = @{
        Message = @{
            Subject = "$Organization | Intune Token Report - $(Get-Date -Format 'yyyy-MM-dd')"
            Body    = @{
                ContentType = "HTML"
                Content     = $htmlBody
            }
            ToRecipients = @(@{ EmailAddress = @{ Address = $Recipient } })
            Attachments  = @($attachment)
        }
        SaveToSentItems = $false
    }

    $jsonBody = $mailMessage | ConvertTo-Json -Depth 10 -Compress
    $sendMailUrl = "https://graph.microsoft.com/v1.0/users/$Sender/sendMail"

    try {
        Invoke-RestMethod -Uri $sendMailUrl -Headers $headersMail -Method POST -Body $jsonBody -ErrorAction Stop
        Write-Host "✅ E-Mail erfolgreich gesendet." -ForegroundColor Green
    } catch {
        Write-Error "❌ Fehler beim Senden der E-Mail: $($_.Exception.Message)"
    }
}
else {
    Write-Host "ℹ️ Keine Tokens unter $sendMailThreshold Tage – keine E-Mail gesendet."
}