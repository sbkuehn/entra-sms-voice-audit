# Technical Documentation: Entra SMS/Voice Audit Toolkit

**Author:** Shannon Eldridge-Kuehn · [Cloudy Musings](https://shankuehn.io) · [@sbkuehn](https://github.com/sbkuehn)

This document covers what the script does under the hood, the design
decisions behind it, and how to extend or scale it.

## Background

Microsoft's retirement of Microsoft-provided SMS and voice authentication
in Entra ID follows this timeline:

| Date | Event |
|---|---|
| September 1, 2026 | Tenants with SMS/voice-enabled users are auto-enrolled into a Microsoft-managed passkey Registration Campaign |
| September 18, 2026 | Microsoft publishes customer-managed telecom provider details via the Security Store |
| October 30, 2026 | Tenants may configure a customer-managed telecom provider if they have a genuine ongoing need for SMS/voice |
| February 1, 2027 | Microsoft-provided SMS/voice delivery is fully retired; users with SMS/voice as their only method hit a blocking passkey registration prompt |

Full source: [Passkeys by default and retirement of Microsoft-provided SMS
and voice authentication](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement)

## What the script does

`Get-EntraSmsVoiceAudit.ps1` performs the following steps:

1. **Connects to Microsoft Graph** using delegated auth with the scopes
   `UserAuthenticationMethod.Read.All` and `User.Read.All`.
2. **Retrieves all enabled users** in the tenant via `Get-MgUser -All`,
   filtered to `AccountEnabled -eq $true`.
3. **Iterates each user** and calls
   `Get-MgUserAuthenticationMethod -UserId <id>` to pull their registered
   authentication methods.
4. **Classifies each method** by its `@odata.type`, stripping the
   `#microsoft.graph.` prefix Graph returns (e.g.
   `#microsoft.graph.phoneAuthenticationMethod` becomes
   `phoneAuthenticationMethod`).
5. **Flags SMS/voice users**: any user with a `phoneAuthenticationMethod`
   entry.
6. **Flags at-risk users**: among SMS/voice users, those with *no*
   phishing-resistant method also registered (`fido2AuthenticationMethod`,
   `windowsHelloForBusinessAuthenticationMethod`, or
   `passkeyAuthenticationMethod`). These are the accounts that will hit a
   blocking prompt after February 1, 2027.
7. **Exports results** to a timestamped CSV and prints a console summary.

## Why per-user Graph calls

`Get-MgUserAuthenticationMethod` is a per-object endpoint; there is currently
no tenant-wide "list all authentication methods for all users" call in the
stable Graph API. That means this script's runtime scales linearly with
tenant size, roughly one Graph call per user, plus one for the initial user
list pull.

For a few hundred to a couple thousand users this is a fine, boring script
you can run interactively. For larger tenants, see the scaling notes below.

## Scaling to larger tenants

If you're running this against tens of thousands of users, consider:

- **Graph `$batch` requests.** Bundle up to 20 requests per HTTP call to
  `https://graph.microsoft.com/v1.0/$batch`, which cuts round-trip overhead
  significantly compared to one HTTP call per user.
- **Throttling handling.** Wrap the per-user call in retry logic that
  respects `Retry-After` headers on `429` responses rather than a bare
  `try/catch`.
- **Parallelization.** PowerShell 7's `ForEach-Object -Parallel` can process
  multiple users concurrently, but be mindful of Graph throttling limits when
  increasing concurrency.
- **Scoped runs.** Rather than sweeping the entire tenant every time, scope
  `Get-MgUser` to a specific group or OU-equivalent (e.g., a dynamic group
  of users still enabled for SMS/voice) once you've established a baseline.

None of these are implemented in the current script, intentionally, so it
stays simple and auditable for smaller runs. They're listed here as the
natural next steps for anyone adapting this for a large enterprise tenant.

## Data classification reference

| `@odata.type` (after prefix strip) | Meaning |
|---|---|
| `phoneAuthenticationMethod` | SMS or voice call authentication |
| `fido2AuthenticationMethod` | FIDO2 security key |
| `windowsHelloForBusinessAuthenticationMethod` | Windows Hello for Business |
| `passkeyAuthenticationMethod` | Platform or roaming passkey |
| `microsoftAuthenticatorAuthenticationMethod` | Microsoft Authenticator app (push or OTP) |
| `passwordAuthenticationMethod` | Password (not MFA on its own) |

The script currently only checks for the phishing-resistant set listed
above (`fido2`, `windowsHelloForBusiness`, `passkey`). Microsoft
Authenticator push/OTP is not phishing-resistant in the same sense, so a
user with only SMS and Authenticator push would still show as
`OnlySmsOrVoice = True` in terms of phishing-resistant coverage, even though
they technically have a second, non-SMS method. Adjust the
`$hasPhishingResistant` filter if you want to treat Authenticator push
differently for your reporting purposes.

## Extending the script

Common extension points:

- **Group-based comms list**: pipe `$atRisk` into `New-MgGroup` /
  `New-MgGroupMember` to build a targeted Entra security group directly from
  the audit results.
- **HTML report**: swap or supplement the CSV export with
  `ConvertTo-Html` for a shareable summary.
- **Scheduled runs**: wrap the script for execution via Azure Automation or
  a scheduled task using a certificate-based app registration instead of
  interactive delegated auth, so it can run unattended.
- **Sign-in correlation**: cross-reference results against the
  Authentication Methods Activity Report to distinguish *registered* SMS/
  voice methods from *actively used* ones.

## Related reading

- [Passkeys by default and retirement of Microsoft-provided SMS and voice authentication](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement)
- [Plan a passkey deployment in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication)
- [Microsoft Graph authenticationMethod resource type](https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethod)
- [Microsoft Graph throttling guidance](https://learn.microsoft.com/en-us/graph/throttling)
