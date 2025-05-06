# ============================================================================
# Microsoft Graph Application Registration Script
#
# This script automates the process of registering a new Azure AD Application,
# assigning Microsoft Graph API permissions (Application permissions),
# uploading a certificate or creating a client secret for authentication,
# updating RequiredResourceAccess,
# creating a Service Principal,
# and granting Admin Consent automatically.
#
# Prerequisites:
# - Microsoft.Graph PowerShell module installed
# - Permission to register applications and grant admin consent
#
# Author: Mohamad Abdeen
# Version: 1.0
# LICENSE: MIT
# ============================================================================



# Check and install Microsoft.Graph module if not present
$moduleName = "Microsoft.Graph.Applications"
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
}

# ------------------- Functions -------------------

# Connect to Microsoft Graph
function Connect-Graph {
    try {
        Get-MgOrganization -ErrorAction Stop | Out-Null
        
    }
    catch {
        
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All", "Directory.ReadWrite.All"
    }
}

# Interactive permission selection
function Get-GraphPermissionIdInteractive {
    param(
        [string]$resourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    )

    $graphSP = Get-MgServicePrincipal -Filter "AppId eq '$resourceAppId'"
    $allPermissions = $graphSP.AppRoles | Where-Object { $_.AllowedMemberTypes -contains "Application" }

    while ($true) {
        $permissionName = Read-Host " Enter the name of the required permission (e.g., 'SecurityIncident.Read.All')"

        # Exact match
        $match = $allPermissions | Where-Object { $_.Value -eq $permissionName }

        if ($match) {
            Write-Host " Found permission: $($match.Value)"
            return @{
                Id = $match.Id
                DisplayName = $match.Value
            }
        }
        else {
            Write-Warning " No exact match found. Searching for similar permissions..."

            $wildcardPattern = "*" + ($permissionName -replace '\.', '*') + "*"

            $suggestions = $allPermissions | Where-Object { $_.Value -like $wildcardPattern } | Select-Object Id, Value

            if ($suggestions.Count -gt 0) {
                Write-Host " Did you mean:"
                for ($i = 0; $i -lt $suggestions.Count; $i++) {
                    Write-Host "$($i + 1). $($suggestions[$i].Value)"
                }

                $choice = Read-Host " Select a number or press Enter to retype"
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    continue
                }
                elseif ($choice -match '^\d+$') {
                    $index = [int]$choice - 1
                    if ($index -ge 0 -and $index -lt $suggestions.Count) {
                        $selected = $suggestions[$index]
                        Write-Host " Selected: $($selected.Value)"
                        return @{
                            Id = $selected.Id
                            DisplayName = $selected.Value
                        }
                    }
                    else {
                        Write-Warning " Invalid number. Please try again."
                    }
                }
                else {
                    Write-Warning " Please enter a valid number."
                }
            }
            else {
                Write-Host " No similar permissions found."
            }
        }
    }
}

# Register a new application
function Register-App {
    param (
        [string]$appName,
        [array]$permissions,
        [string]$authType,
        [string]$certificatePath
    )

    Connect-Graph -NoWelcome

    $app = New-MgApplication -DisplayName $appName
    Write-Output " Application created: AppId = $($app.AppId)"

    $clientId = $app.AppId
    $appObjectId = $app.Id

    $authInfo = @{}

    if ($authType -eq "cert") {
        if (-not (Test-Path $certificatePath)) {
            throw " Certificate path '$certificatePath' does not exist or is incorrect!"
        }

        try {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
        }
        catch {
            throw " Failed to load the certificate. Ensure it is a valid .cer or .pem file. Error: $_"
        }


        $keyCredential = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphKeyCredential]::new()
        $keyCredential.Type = "AsymmetricX509Cert"
        $keyCredential.Usage = "Verify"
        $keyCredential.Key = $cert.RawData
        $keyCredential.DisplayName = "App Certificate"
        $keyCredential.StartDateTime = $cert.NotBefore
        $keyCredential.EndDateTime = $cert.NotAfter

        Update-MgApplication -ApplicationId $appObjectId -KeyCredentials @($keyCredential) | Out-Null

        $authInfo = @{
            Type = "Certificate"
            Thumbprint = $cert.Thumbprint
        }
    }
    elseif ($authType -eq "secret") {
        $now = (Get-Date).ToUniversalTime()
        $oneYearLater = $now.AddYears(1)

        $secret = Add-MgApplicationPassword -ApplicationId $appObjectId -PasswordCredential @{
         DisplayName   = "ClientSecret"
         StartDateTime = $now
         EndDateTime   = $oneYearLater
         }

        $authInfo = @{
            Type = "Secret"
            SecretValue = $secret.SecretText
            SecretExpires = $secret.EndDateTime
        }
    }
    else {
        throw " Invalid authentication method: $authType"
    }

    $resourceAccessList = foreach ($perm in $permissions) {
        $access = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess]::new()
        $access.Id = $perm.Id
        $access.Type = "Role"
        $access
    }

    $requiredAccess = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]::new()
    $requiredAccess.ResourceAppId = "00000003-0000-0000-c000-000000000000"
    $requiredAccess.ResourceAccess = $resourceAccessList

    Update-MgApplication -ApplicationId $appObjectId -RequiredResourceAccess @($requiredAccess) | Out-Null

    $sp = New-MgServicePrincipal -AppId $clientId
    Write-Output " Service Principal created: Id = $($sp.Id)"

    $graphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

    foreach ($perm in $permissions) {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id `
            -PrincipalId $sp.Id `
            -ResourceId $graphSP.Id `
            -AppRoleId $perm.Id | Out-Null
        Write-Output " Assigned permission: $($perm.DisplayName)"
    }

    $tenantId = (Get-MgOrganization).Id

    return @{
        ClientId = $clientId
        TenantId = $tenantId
        AuthInfo = $authInfo
    }
}

# ------------------- Script Start -------------------

Write-Output "`n Starting App Registration..."

# Collect user inputs
do {
    $appName = Read-Host " Please enter the App Name (only letters, numbers, hyphens allowed)"

    if ($appName -match '[^a-zA-Z0-9\-]') {
        Write-Warning " The App Name can only contain letters, numbers, and hyphens. No special characters or spaces."
        $appName = $null
    }
}
while (-not $appName)

do {
    $authType = Read-Host " Use Secret or Certificate? (secret/cert)"
    if ($authType -ne "secret" -and $authType -ne "cert") {
        Write-Warning " Invalid input! Please enter 'secret' or 'cert'."
    }
}
while ($authType -ne "secret" -and $authType -ne "cert")

$certificatePath = $null
if ($authType -eq "cert") {
    $certificatePath = Read-Host " Path to certificate (.cer, .crt, .pem)"
}

Connect-Graph -NoWelcome
$permissions = @()
do {
    $perm = Get-GraphPermissionIdInteractive
    if ($perm) {
        $permissions += $perm
    }
    $more = Read-Host " Add another permission? (y/n)"
}
while ($more -eq "y")

if ($permissions.Count -eq 0) {
    throw " No permissions selected. Script will exit."
}

$app = Register-App -appName $appName -permissions $permissions -authType $authType -certificatePath $certificatePath

if ($app) {
    Write-Output "`n Application successfully registered!"
    Write-Output "ClientId: $($app.ClientId)"
    Write-Output "TenantId: $($app.TenantId)"

    if ($app.AuthInfo.Type -eq "Certificate") {
        Write-Output "Certificate Thumbprint: $($app.AuthInfo.Thumbprint)"
    }
    elseif ($app.AuthInfo.Type -eq "Secret") {
        Write-Output " Client Secret:"
        Write-Output "Value: $($app.AuthInfo.SecretValue)"
        Write-Output "Expires on: $($app.AuthInfo.SecretExpires)"
    }
}

Disconnect-MgGraph

