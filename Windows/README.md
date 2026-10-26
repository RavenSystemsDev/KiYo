# KiYo for Windows — 0.1.0-alpha.3

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
installation. It also opens its own isolated test editor, verifies that password, email
and read-only fields are rejected, and tests selected-text/tail replacement there.
Email/password labels are checked through UI Automation and focused-control MSAA
metadata, including controls whose native UIA provider omits their accessible name.
This requires an interactive Windows desktop; it never targets an existing user
document. GitHub Actions is configured to build both portable archives.
It does not publish them as a stable release automatically.

The archives include .NET and runtime license notices. Extract the full folder,
then run `KiYo.exe`. Do not move only the EXE away from the accompanying files.
Settings: `%LOCALAPPDATA%\RavenSystems\KiYo\settings.json`.

## Input behavior and acceptance checks

Real key events are always forwarded, never queued or swallowed. Completed words
remain pending when more characters arrive or the single background worker is
busy. After a short quiet interval (25 ms), KiYo checks the latest observed suffix
against the editable field. A stale read is retried with the newest suffix;
already-resolved word decisions are reused. The unfinished next word is replayed
unchanged, and a layout switch is deferred until a completed-word boundary.

The suffix is limited to 1024 characters, individual tokens to 64 characters.
A mouse action, navigation, Backspace, external layout/focus change, paste, pause
or setting change invalidates older candidates. UI Automation validates the field,
selection and exact tail text again before returning. A replacement requires a
whitespace boundary before the observed suffix, or a confirmed document start.
An incomplete word such as observed `usic` inside `music` is never replaced on its
own. A provider that omits the preceding boundary is rejected rather than assumed
to be at document start. Replacement is one SendInput
batch with a final input-revision and native-focus check. Read failures back off
and stop after five attempts for unchanged input; idle pending text expires after
two seconds. An unresponsive provider keeps at most one outstanding call; typing
continues. Words beyond the bounded suffix and unsupported fields can be skipped.

Windows UIPI can reject injection; KiYo pauses if a replacement cannot complete.
No focus is forcibly changed. Validation and replacement cannot be made an atomic
transaction with external editors, so real-editor acceptance remains required.
See Microsoft's [SendInput documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)
and [UI Automation threading guidance](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-threading).

Fast-input regression tests use a virtual editor/clock: 90 speed/delay combinations
and 1,000 jittered three-phrase sequences, plus partial words, delayed layout
acknowledgment, double spaces, exceptions, cancellation and bounded memory.
These tests do not replace physical Windows input testing. The native test harness
also covers full-burst/partial-tail replacement and changed-text/caret rejection
in its own isolated editor; it must be run on Windows.

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
