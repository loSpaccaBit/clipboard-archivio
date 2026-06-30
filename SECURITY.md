# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.5.x   | ✅        |
| < 1.5   | ❌        |

## Reporting a vulnerability

**Please do not open public issues for security vulnerabilities.**

Email or contact the maintainer via GitHub:

- **Francesco Pio Nocerino** — [@lospaccabit](https://github.com/lospaccabit)

Include:

- Description of the issue and impact
- Steps to reproduce
- macOS and app version
- Any proof-of-concept if available

You should receive a response within **7 days**. If the report is accepted, we will coordinate a fix and disclosure timeline.

## Security model

- Clipboard data is stored locally in `~/Library/Application Support/ClipboardArchivio/`
- Vault items use **AES-GCM** with keys in the system Keychain
- Sensitive-data detection runs **entirely on-device** (no network calls)
- Sandbox is disabled (`app-sandbox: false`) to access arbitrary file paths from the Finder; only reference paths are stored for normal file clips

## Best practices for users

- Enable vault auto-protect for passwords and tokens
- Use full-archive encryption on shared Macs
- Clear history when handing off the machine