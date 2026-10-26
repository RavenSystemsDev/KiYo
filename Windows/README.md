# KiYo for Windows — 0.1.0-alpha.9

Development lives on the `windows` branch. macOS source and releases are on `main`.
This is an initial Windows implementation, not a stable Windows release.

Implemented: tray menu, Russian/English settings, optional per-user startup,
automatic RU/EN conversion after space, case preservation and KiYo spelling,
exceptions, configurable shortcuts for selected-text conversion and exclusions,
optional spelling correction using installed Windows dictionaries, single-instance startup,
and feedback by user-sent email. Processing is local; no clipboard fallback,
telemetry, text logs, administrator prompt or network-based language service.

The native window and input APIs are separate from the platform-independent
`KiYo.Core` library. Its initial word lists are ported from the macOS source.
No dictionary or font from an unrelated third party is included.

## Install

Download **KiYo-Setup.exe** from the `KiYo-Windows-Setup` artifact of a successful
[Windows alpha build](https://github.com/RavenSystemsDev/KiYo/actions/workflows/windows.yml?query=branch%3Awindows).
GitHub wraps artifacts in a ZIP: extract it, then open the single installer EXE.
The accompanying `.sha256` file is an optional integrity check, not an installer.
The same EXE supports Windows 11 on Intel/AMD x64 and ARM64 and chooses the native
app automatically. .NET is included; installation does not need internet or admin rights.

The installer offers Russian/English, a dark welcome/progress/completion flow,
optional installation folder and desktop shortcut, and optional launch at login.
By default the app is installed in `%LOCALAPPDATA%\Programs\Raven Systems\KiYo`.
Open KiYo from Start or beside the clock. Close KiYo before installing an update.
Uninstall from Windows Settings → Apps → Installed apps → KiYo.
Updates and uninstall preserve settings and exceptions; uninstall removes only
this installation's startup entry. Preferences remain in
`%LOCALAPPDATA%\RavenSystems\KiYo\settings.json`.

## Settings

Settings uses two compact tabs: **General** and **Shortcuts and exceptions**.
Dark controls and aligned switches stay consistent in either Windows color mode.
Add exceptions as individual words and remove them with the × button; changes
are applied only on Save. Only a long exceptions list scrolls, not the window.
**User guide** and **About KiYo** are separate buttons below either tab and are
also available from the tray menu. The guide shows the saved keyboard shortcuts;
About includes the version, Raven Systems, privacy and component/license notices.
The Save and feedback buttons remain visible at the bottom.

## Spelling correction

Enable **Spelling correction** in Settings and save. This setting is off by
default, including when loading older preferences. With Auto correction enabled,
completed words are checked after a space. Layout correction takes priority;
spelling uses the installed Windows en-US/ru-RU dictionaries independently of the
Layout dictionary switch. No dictionary download or online service is used.

Only a unique closest, dictionary-validated suggestion in the same alphabet is
accepted. Short/uppercase/mixed-case words, known technical terms, exclusions,
addresses and identifiers are left alone. Ambiguous suggestions, unavailable
language dictionaries, and protected or unsupported fields are skipped. This
corrects individual typos; it does not rewrite grammar or split joined words.
Backspace/retyping a rejected correction keeps the existing one-retry behavior.
Settings shows whether RU and EN dictionaries are installed.
If a language dictionary is missing, install that language's **Basic typing**
feature in Windows Settings → Time & language → Language & region.

## Build and test

Install the .NET 10 SDK, then run:

```powershell
dotnet run --project Windows/KiYo.Tests/KiYo.Tests.csproj -c Release
dotnet run --project Windows/KiYo.Windows.Smoke/KiYo.Windows.Smoke.csproj -c Release
# Install Inno Setup 6.7.3, then build the universal installer:
./Windows/build-installer.ps1
# Optional advanced portable distribution:
./Windows/package.ps1 -Runtime win-x64
```

Core tests also run on macOS/Linux. Cross-compilation on macOS verifies C# and
Windows reference assemblies, not real Windows behavior. The smoke project must
run on Windows and checks the native input ABI, OS dictionaries, layouts and hook
installation. It also opens its own isolated test editor, verifies that password, email
and read-only fields are rejected, and tests selected-text/tail replacement there.
Email/password labels are checked through UI Automation and focused-control MSAA
metadata, including controls whose native UIA provider omits their accessible name.
This requires an interactive Windows desktop; it never targets an existing user
document. GitHub Actions builds both native payloads into one EXE and tests its
Russian/English UI, launch, selected architecture, shortcuts, update protection,
settings retention and uninstall on a disposable Windows runner. UI screenshots
and logs are saved in a separate diagnostic artifact. The compiler download is
pinned to Inno Setup 6.7.3 and verified by SHA256 and publisher signature.
It does not publish a stable release automatically.

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
to be at document start. Standard Unicode Edit/RichEdit controls (including the RichEditD2D family used
by Windows Notepad) receive one `EM_REPLACESEL` operation for the validated
range, with undo support. KiYo no longer deletes their text using a stream of
Backspace events before injecting individual Unicode letters. Other supported
editors retain the keyboard-input fallback. Both paths recheck input revision
and focus and verify the resulting text through UI Automation. If an editor
does not confirm the replacement while input/focus remain unchanged, KiYo pauses
instead of repeating the destructive operation. Continued user input cancels
verification; it is never overwritten by a rollback. Read failures back off
and stop after five attempts for unchanged input; idle pending text expires after
two seconds. An unresponsive provider keeps at most one outstanding call; typing
continues. Words beyond the bounded suffix and unsupported fields can be skipped.

Windows UIPI can reject messages or injection; KiYo pauses if a replacement cannot be confirmed.
No focus is forcibly changed. Validation and replacement cannot be made an atomic
transaction with external editors, so real-editor acceptance remains required.
Regression coverage includes an isolated editor that accepts Backspace and spaces
but rejects letter messages: the old successful `SendInput` batch leaves a gap,
while whole-string replacement preserves the complete corrected word. This
compatibility fixture does not substitute for testing each Windows Notepad build.

See Microsoft's [EM_REPLACESEL documentation](https://learn.microsoft.com/en-us/windows/win32/controls/em-replacesel),
[SendInput documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)
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

No Authenticode signing, automatic updater or sync is included in this alpha. Standard US English and Russian layouts only; IMEs and
other layouts are skipped. Native compatibility requires actual Windows testing.

Raven Systems — https://ravensystems.io/
