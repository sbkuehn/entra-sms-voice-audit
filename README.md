# Entra SMS/Voice Audit Toolkit

**Author:** Shannon Eldridge-Kuehn
**Blog:** [Cloudy Musings](https://www.shankuehn.io/)
**GitHub:** [@sbkuehn](https://github.com/sbkuehn)
**License:** MIT

A PowerShell audit toolkit for identifying Microsoft Entra ID users who are
still relying on SMS or voice authentication ahead of Microsoft's retirement
of Microsoft-provided SMS and voice delivery on **February 1, 2027**.

> [Written up in full on Cloudy Musings: *Passkeys by Default: Entra Retires
> SMS and Voice MFA*](https://www.shankuehn.io/post/passkeys-by-default-entra-retires-sms-and-voice-mfa)

## Why this exists

Microsoft published the retirement timeline for SMS and voice authentication
on August 10, 2026. Starting September 1, 2026, tenants with users enabled
for SMS or voice get auto-enrolled into Microsoft-managed passkey nudges.
By February 1, 2027, users whose *only* MFA method is SMS or voice will hit
a **blocking** passkey registration prompt at sign-in, with no opt-out.

Before you can plan a remediation or comms rollout, you need to know who is
actually affected. This toolkit answers that question.

Official Microsoft reference: [Passkeys by default and retirement of
Microsoft-provided SMS and voice authentication](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-sms-voice-retirement)

## What's in this repo

```
entra-sms-voice-audit/
├── README.md                          <- you are here
├── LICENSE                            <- MIT license
├── docs/
│   ├── HOWTO.md                       <- step-by-step usage guide
│   └── DOCUMENTATION.md               <- technical reference and design notes
└── scripts/
    └── Get-EntraSmsVoiceAudit.ps1     <- the audit script
```

## Quick start

```powershell
# Install required modules if you don't already have them
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users -Scope CurrentUser

# Run the audit
.\scripts\Get-EntraSmsVoiceAudit.ps1
```

The script connects to Microsoft Graph, walks every enabled user in the
tenant, and produces a CSV report of everyone still using SMS or voice
authentication, with a specific flag for users who have **no
phishing-resistant fallback** (the ones who will be blocked on February 1,
2027).

For full setup instructions, required permissions, and parameter details,
see [docs/HOWTO.md](docs/HOWTO.md).

For a deeper technical breakdown of what the script does, how it scales, and
how to extend it, see [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md).

## Requirements

| Requirement | Details |
|---|---|
| PowerShell | 7.x recommended (5.1 supported) |
| Modules | `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users` |
| Graph scopes | `UserAuthenticationMethod.Read.All`, `User.Read.All` |
| Permissions | An account or app registration with read access to authentication methods tenant-wide |

## Output

The script produces a timestamped CSV (`entra-sms-voice-audit-yyyyMMdd.csv`)
with one row per user still enabled for SMS or voice, including:

- Display name and UPN
- Total registered authentication methods
- Whether a phishing-resistant method (FIDO2, Windows Hello for Business,
  passkey) is also registered
- Whether SMS/voice is their **only** method (`OnlySmsOrVoice`), the
  priority column for remediation

## License

MIT. See [LICENSE](LICENSE).

## Attribution

This toolkit, all documentation, and the accompanying scripts in this
repository were written by **Shannon Eldridge-Kuehn**. If you fork or reuse
this work, a credit back to [Cloudy Musings](https://shankuehn.io) is
appreciated but not required under the MIT license.
