# Security policy

PaperMode intercepts keyboard and pointer input using macOS Accessibility access. Problems involving permission boundaries, unintended input capture, unsafe helper communication or failure to release input may have security implications.

## Report privately

Use [GitHub private vulnerability reporting](https://github.com/prajwalbhatia/paperMode/security/advisories/new). This sends the report to repository maintainers without creating a public issue. Sign in to GitHub and select **Report a vulnerability** under **Security → Advisories** if the direct form is unavailable.

Include the affected version or commit, macOS and chip, reproduction steps, expected/actual behavior, potential impact, and a minimal proof of concept if safe. Redact passwords, tokens, private lesson URLs and unrelated personal data. Describe permission state without sharing credentials.

Do not publish exploit details in an issue, discussion or PR before coordinated disclosure. If the private form is unavailable, open a minimal issue asking for the private reporting channel to be restored, without vulnerability details. Ordinary bugs and feature requests belong in the public issue forms.

## Versions and response

The project is in preview; there is no stable release or long-term support branch yet. Fixes target current main and the latest preview. Please report older-version issues too, noting whether they also affect current code when you can safely check.

Maintainers will review reports as availability permits, discuss reproduction and a fix privately, and coordinate disclosure and credit with the reporter. No response-time or bounty commitment is offered.

Preview downloads are ad-hoc signed and not notarized by Apple. Checksums identify the published bytes; they do not provide independent publisher verification. See [installation guidance](docs/INSTALL.md) for the per-app approval flow.
