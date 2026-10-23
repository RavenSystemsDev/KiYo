# Security policy

KiYo handles keyboard input and requires Accessibility permission. Please use synthetic test text when reporting problems.

For a vulnerability, use GitHub's **Report a vulnerability** option if the repository owner has enabled private vulnerability reporting. If it is unavailable, open an issue asking for a private reporting channel, without exploit details or sensitive data. No response-time commitment is claimed here.

Do not post typed private text, passwords, clipboard snapshots, signing certificates, keychains, account data or diagnostic files containing private additions in public issues.

## Data handling

Typed words are processed locally. App settings and explicit word exceptions persist. A limited spelling cache and the latest correction are held in memory. Optional sync writes settings and exceptions to a user-selected folder; anyone with access to that folder may inspect or modify them. There is no developer sync server or telemetry endpoint.

The app checks Secure Input and field metadata before correction. Some custom editors expose incomplete metadata, so password/email detection is not a universal guarantee. Copy fallback temporarily uses the clipboard and attempts to restore it; concurrent clipboard changes can affect that behavior.

Diagnostics are opt-in and contain counters rather than words. Signing credentials are excluded from this repository. Public releases should be Developer ID signed and notarized; ad-hoc builds are for development.

## Scope of review

Automated tests cover conversion, protected input, exceptions, shortcut handling, delimiter preservation, long tokens and isolated sync conflicts. They do not establish absence of vulnerabilities, confirm two-Mac delivery or replace testing each target editor.
