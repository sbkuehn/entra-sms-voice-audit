# How-To: Running the Entra SMS/Voice Audit

**Author:** Shannon Eldridge-Kuehn · [Cloudy Musings](https://shankuehn.io) · [@sbkuehn](https://github.com/sbkuehn)

This guide walks through setup and execution of
`scripts/Get-EntraSmsVoiceAudit.ps1` from a clean machine to a finished
report.

## 1. Prerequisites

- PowerShell 7.x (recommended) or Windows PowerShell 5.1
- An account with **at minimum** the Graph delegated permission
  `UserAuthenticationMethod.Read.All` and `User.Read.All`, or a directory
  role that grants equivalent read access (e.g., Global Reader, Authentication
  Policy Administrator, or Privileged Authentication Administrator for full
  visibility into authentication methods)
- Network access to `graph.microsoft.com`

## 2. Install the required modules

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
```

If you already have the full `Microsoft.Graph` module installed, these are
included and you can skip this step.

## 3. Clone or download the repo

```powershell
git clone https://github.com/sbkuehn/entra-sms-voice-audit.git
cd entra-sms-voice-audit
```

## 4. Run the script

Basic run, current tenant, output to the current directory:

```powershell
.\scripts\Get-EntraSmsVoiceAudit.ps1
```

Specify a tenant and output directory:

```powershell
.\scripts\Get-EntraSmsVoiceAudit.ps1 -TenantId "contoso.onmicrosoft.com" -OutputPath "C:\Reports\Entra"
```

You'll be prompted to sign in interactively and consent to the requested
Graph scopes the first time you run it (unless already consented at the
tenant level).

## 5. Read the output

The script does three things:

1. Prints a progress bar while it works through the user list
2. Writes a summary to the console:
   - Total users still enabled for SMS or voice
   - Users with **no phishing-resistant fallback** (the ones at risk of the
     blocking prompt on February 1, 2027)
3. Exports a CSV named `entra-sms-voice-audit-yyyyMMdd.csv` to your chosen
   output path

Open the CSV and sort by the `OnlySmsOrVoice` column. `True` rows are your
priority list, these are the accounts that lose sign-in access without a
passkey (or other phishing-resistant method) registered before February 1,
2027.

## 6. Suggested next steps after running the audit

- Build a security group from the `OnlySmsOrVoice = True` list and target
  it with your own Registration Campaign before Microsoft auto-enrolls it
  for you on September 1, 2026
- Cross-reference against the Authentication Methods Activity Report in the
  Entra admin center to confirm active use, not just registration
- Re-run the audit periodically (monthly, or ahead of key dates in the
  retirement timeline) to track remediation progress over time

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Connect-MgGraph` fails with a consent error | Your account or tenant admin hasn't consented to the requested scopes; ask an admin to grant consent |
| Script runs but returns zero rows | Confirm the account you ran the script as actually has `UserAuthenticationMethod.Read.All` and that the tenant does have SMS/voice-enabled users |
| Script is very slow on a large tenant | Expected, this is a per-user Graph call; see `docs/DOCUMENTATION.md` for notes on scaling this to larger tenants |
| `Could not read methods for <user>` warnings | Usually a permissions or throttling issue on a specific object; safe to ignore isolated warnings, investigate if they're widespread |
