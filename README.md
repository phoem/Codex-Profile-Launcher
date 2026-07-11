# Isolated Codex profiles on Windows

`Codex-Profile.ps1` launches separate work and personal Codex desktop processes. Each profile gets two isolated stores:

- `CODEX_HOME` for Codex authentication, configuration, sessions, databases, skills, and plugins.
- Chromium `--user-data-dir` for cookies, local storage, cache, crash data, and desktop web state.

The launcher discovers the current Microsoft Store/MSIX install path each time, so an app update should not require editing the script.

## Quick start

Open PowerShell in the folder containing the script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Codex-Profile.ps1 Work
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Codex-Profile.ps1 Personal
```

The first launch of each profile should present a separate sign-in. Sign into the intended account and keep each account in its own named profile.

Profile data defaults to:

```text
%LOCALAPPDATA%\CodexProfiles\work\codex-home
%LOCALAPPDATA%\CodexProfiles\work\web-data
%LOCALAPPDATA%\CodexProfiles\personal\codex-home
%LOCALAPPDATA%\CodexProfiles\personal\web-data
```

## Create desktop shortcuts

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Codex-Profile.ps1 -InstallShortcuts
```

To choose different names or a different storage root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Codex-Profile.ps1 `
  -InstallShortcuts `
  -ShortcutProfiles Client,Personal `
  -ShortcutProfilesRoot D:\CodexProfiles
```

Do not move or rename the script after creating shortcuts; recreate the shortcuts if you do.

## Diagnostics

Show running Codex desktop processes that have an explicit isolated web-data path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Codex-Profile.ps1 -Status
```

You can also confirm isolation in Task Manager or PowerShell: each top-level `ChatGPT.exe` should have a different `--user-data-dir`, and each should spawn its own `codex.exe` backend.

## Important caveats

- This is verified with Windows package `OpenAI.Codex_26.707.3748.0_x64` (app version `26.707.3748.0`) but is not a documented, supported multi-profile feature. A future update could change the executable name, argument handling, environment handling, authentication flow, or storage layout.
- `CODEX_HOME` is a Codex configuration/state override; `--user-data-dir` is a Chromium runtime switch. Both were empirically required for complete separation in the tested build.
- Windows still sees both processes as the same installed package and the same package identity. Package-scoped Windows settings, notifications, protocol activation (`codex://`), shell integration, and OS credential storage may still be shared or may route to the wrong running profile.
- If browser sign-in returns to the wrong Codex window, close the other profile temporarily, finish sign-in, then reopen both. Do not copy `auth.json`, cookie databases, or other credentials between profile folders.
- Never launch the same profile concurrently from two different scripts or machines against a synchronized folder. Chromium and SQLite files expect single-profile ownership and can be corrupted by unsafe sharing.
- Keep profile roots on a local, access-controlled drive. They contain authentication material and conversation/project state. Do not put them in OneDrive, Dropbox, a Git repository, or a shared network location.
- The normal Start-menu Codex shortcut continues to use the default `%USERPROFILE%\.codex` and `%APPDATA%\Codex\web\Codex` stores. Use the named shortcuts consistently to avoid signing into the wrong account.

## Removing a profile

Sign out inside that profile, close its window, verify no process is using its `--user-data-dir`, and then delete only that profile's folder under `%LOCALAPPDATA%\CodexProfiles`. Deleting the folder permanently removes its local sessions, settings, and cached credentials.

## What was verified

On July 10, 2026, a probe launched the packaged `app\ChatGPT.exe` with both overrides while the default Codex app was already running. Windows created a second top-level desktop process. Its Chromium child processes all used the probe's explicit `--user-data-dir`, while its Codex backend independently initialized databases, config, plugins, and skills under the probe's `CODEX_HOME`. The original profile paths were not reused for those stores.

OpenAI's public documentation does not currently document `--user-data-dir` as a supported Codex desktop profile feature. Treat this launcher as an update-sensitive workaround, not an OpenAI-supported account switcher.
