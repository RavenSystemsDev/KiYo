# KiYo for Windows — 0.1.0-alpha.1

Development lives on the `windows` branch. macOS source and releases are on `main`.
This is an initial Windows implementation, not a stable Windows release.

Implemented: tray menu, Russian/English settings, optional per-user startup,
automatic RU/EN conversion after space, case preservation and KiYo spelling,
exceptions, configurable shortcuts for selected-text conversion and exclusions,
read-only use of installed Windows spelling dictionaries, single-instance startup,
and feedback by user-sent email. Processing is local; no clipboard fallback,
telemetry, text logs, administrator prompt or network-based language service.

The native window and input APIs are separate from the platform-independent
`KiYo.Core` library. Its initial word lists are ported from the macOS source.
No dictionary or font from an unrelated third party is included.

## Build and test

Install the .NET 10 SDK, then run:

```powershell
dotnet run --project Windows/KiYo.Tests/KiYo.Tests.csproj -c Release
dotnet run --project Windows/KiYo.Windows.Smoke/KiYo.Windows.Smoke.csproj -c Release
./Windows/package.ps1 -Runtime win-x64
# For ARM PCs:
./Windows/package.ps1 -Runtime win-arm64
```

Core tests also run on macOS/Linux. Cross-compilation on macOS verifies C# and
Windows reference assemblies, not real Windows behavior. The smoke project must
run on Windows and checks the native input ABI, OS dictionaries, layouts and hook
installation without injecting text. GitHub Actions builds both portable archives.
It does not publish them as a stable release automatically.

The archives include .NET and runtime license notices. Extract the full folder,
then run `KiYo.exe`. Do not move only the EXE away from the accompanying files.
Settings: `%LOCALAPPDATA%\RavenSystems\KiYo\settings.json`.

## Input behavior and acceptance checks

Real key events are always forwarded, never queued or swallowed. UI Automation
and spelling checks run off the hook thread with bounded acceptance deadlines.
Only the observed word immediately before the caret is checked. A new key, mouse
action, changed layout/focus or setting invalidates the pending replacement.
Replacement uses one `SendInput` batch, only if the original field still matches.
Windows UIPI can reject injection; KiYo pauses if a replacement cannot complete.
No focus is forcibly changed. A timing window between validation and injection
cannot be made an atomic transaction with external editors.

This intentionally skips correction when typing continues before validation; it
is not yet a promise of zero skipped words at every typing speed. A slow provider
can disable new requests until its one outstanding call returns; typing continues.

Before public release, test with a physical keyboard in Notepad, Word and at least
one Chromium/Electron editor:

- `ghbdtn hi rfr ltkf ` with alternating layouts, slowly and at speed.
- Capitalization, punctuation, Backspace/retry, exclusions and long tokens.
- Selected `ghbdtn, vbh!` and `руддщ 😀`, including multiline selections.
- Password, email, read-only and administrator windows: no automatic edits.
- Move caret/click/change app during validation: no stale replacement.
- Shortcut conflicts, first run in RU/EN, pause, duplicate launch, real logout/login.

No Authenticode signing, installer/updater, sync or spelling-error correction is
included in this alpha. Standard US English and Russian layouts only; IMEs and
other layouts are skipped. Native compatibility requires actual Windows testing.

Raven Systems — https://ravensystems.io/
