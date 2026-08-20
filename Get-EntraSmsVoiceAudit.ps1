<#
.SYNOPSIS
    Audits Microsoft Entra ID users for SMS and voice authentication method usage
    ahead of the Microsoft-provided SMS/voice retirement (February 1, 2027).

.DESCRIPTION
    Enumerates all enabled users in the tenant, reads their registered
    authentication methods via Microsoft Graph, and flags anyone still using
    SMS or voice authentication. Users with SMS/voice as their ONLY method
    are called out separately, since these are the accounts that will hit a
    blocking passkey registration prompt once Microsoft-provided SMS and
    voice delivery is retired.

    Reference: https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement

.PARAMETER OutputPath
    Directory to write the CSV report to. Defaults to the current directory.

.PARAMETER TenantId
    Optional tenant ID to connect to. If omitted, Connect-MgGraph will use
    the default tenant for the authenticated account.

.EXAMPLE
    .\Get-EntraSmsVoiceAudit.ps1

    Runs the audit against the default tenant and writes a timestamped CSV
    to the current directory.

.EXAMPLE
    .\Get-EntraSmsVoiceAudit.ps1 -OutputPath "C:\Reports" -TenantId "contoso.onmicrosoft.com"

    Runs the audit against a specific tenant and writes the CSV to C:\Reports.

.NOTES
    Author:   Shannon Eldridge-Kuehn
    Blog:     https://shankuehn.io
    GitHub:   https://github.com/sbkuehn
    Requires: Microsoft.Graph.Authentication, Microsoft.Graph.Users,
              Microsoft.Graph.Identity.SignIns
    Scopes:   UserAuthenticationMethod.Read.All, User.Read.All

    This script performs one Graph call per user to read authentication
    methods. For tenants in the tens of thousands of users, consider
    batching requests via the Graph $batch endpoint rather than running
    this loop as-is. See docs/DOCUMENTATION.md for notes on scaling this.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

#region Connect

$connectParams = @{
    Scopes = @("UserAuthenticationMethod.Read.All", "User.Read.All")
}
if ($TenantId) {
    $connectParams["TenantId"] = $TenantId
}

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph @connectParams | Out-Null

$context = Get-MgContext
Write-Host "Connected to tenant: $($context.TenantId)" -ForegroundColor Cyan

#endregion

#region Collect users

$results = [System.Collections.Generic.List[object]]::new()

Write-Host "Retrieving enabled users..." -ForegroundColor Cyan
$users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, AccountEnabled |
    Where-Object { $_.AccountEnabled }

$total = $users.Count
$counter = 0

if ($total -eq 0) {
    Write-Warning "No enabled users returned. Check permissions and try again."
    return
}

#endregion

#region Audit authentication methods

foreach ($user in $users) {
    $counter++
    Write-Progress -Activity "Auditing authentication methods" `
        -Status "$counter / $total : $($user.UserPrincipalName)" `
        -PercentComplete (($counter / $total) * 100)

    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $user.Id `
            -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not read methods for $($user.UserPrincipalName): $_"
        continue
    }

    $methodTypes = $methods | ForEach-Object {
        # The odata type tells us what kind of method this is
        $_.AdditionalProperties['@odata.type'] -replace '#microsoft.graph.', ''
    }

    $hasSmsOrVoice = $methodTypes | Where-Object {
        $_ -in @('phoneAuthenticationMethod')
    }

    $hasPhishingResistant = $methodTypes | Where-Object {
        $_ -in @('fido2AuthenticationMethod', `
                 'windowsHelloForBusinessAuthenticationMethod', `
                 'passkeyAuthenticationMethod')
    }

    if ($hasSmsOrVoice) {
        $results.Add([PSCustomObject]@{
            DisplayName          = $user.DisplayName
            UserPrincipalName    = $user.UserPrincipalName
            TotalMethods         = $methodTypes.Count
            HasPhishingResistant = [bool]$hasPhishingResistant
            OnlySmsOrVoice       = -not [bool]$hasPhishingResistant
            RegisteredMethods    = ($methodTypes -join ', ')
        })
    }
}

Write-Progress -Activity "Auditing authentication methods" -Completed

#endregion

#region Report

# Users who will hit a blocking prompt on Feb 1, 2027
$atRisk = $results | Where-Object { $_.OnlySmsOrVoice }

Write-Host "`nUsers still enabled for SMS or voice: $($results.Count)" `
    -ForegroundColor Yellow

Write-Host "Users with NO phishing-resistant fallback (blocked on Feb 1, 2027): $($atRisk.Count)" `
    -ForegroundColor Red

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$csvPath = Join-Path -Path $OutputPath -ChildPath "entra-sms-voice-audit-$(Get-Date -Format 'yyyyMMdd').csv"

$results | Sort-Object OnlySmsOrVoice -Descending | `
    Export-Csv -Path $csvPath `
        -NoTypeInformation

Write-Host "`nReport written to: $csvPath" -ForegroundColor Green

$results | Format-Table DisplayName, UserPrincipalName, OnlySmsOrVoice, RegisteredMethods `
    -AutoSize

#endregion
