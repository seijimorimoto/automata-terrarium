# bin/

Sync executables that install the contents of this repo into the user-level Claude Code config (`~\.claude\`).

Per-category scripts cover skills, hooks, and settings. The `seiji-claude-sync` wrapper runs them in the right order. `seiji-claude-install` is a one-time setup that puts `bin/` on your shell PATH.

## Available scripts

| Script | Purpose |
| --- | --- |
| `seiji-claude-install` (`.ps1`) | One-time PATH setup. Appends a keyed marker block to your shell profile pointing at this repo's `bin/`. Idempotent. |
| `seiji-claude-sync` (`.ps1`) | Wrapper. Runs every per-category sync in order. |
| `seiji-claude-sync-skills` (`.ps1`) | Copies each subfolder of `skills/` to `~\.claude\skills\<name>\`. |
| `seiji-claude-sync-agents` (`.ps1`) | Copies each `agents/<name>/` folder to `~\.claude\agents\<name>\` (whole tree). Also accepts flat `agents/<name>.md` for compatibility with externally-authored agents. Skips `agents/README.md`. |
| `seiji-claude-sync-hooks` (`.ps1`) | Copies each subfolder of `hooks/` to `~\.claude\hooks\<name>\`. Script-files only — does not register hooks in `settings.json`. |
| `seiji-claude-sync-settings` (`.ps1`) | Merges every `settings\*.json` into `~\.claude\settings.json` per the rules below. |

Both PowerShell (`.ps1`) and POSIX (no extension) variants are provided. Use whichever matches your shell.

## Prerequisites

- **PowerShell 7+** (`pwsh`) — primary on Windows.
- **bash** with `readlink -f` available — for the POSIX variants. Git Bash on Windows, plus any modern Linux/macOS, satisfy this.
- **`jq`** (>= 1.6) — required only by `seiji-claude-sync-settings` (POSIX). Install:
  ```powershell
  # Windows (PowerShell)
  winget install jqlang.jq
  ```
  ```sh
  # macOS / Linux
  brew install jq          # macOS
  sudo apt-get install jq  # Debian/Ubuntu
  ```
  PowerShell does not need `jq` — it uses native `ConvertFrom-Json` / `ConvertTo-Json`.

## Install

```powershell
# Windows (PowerShell) — from this repo's root
.\bin\seiji-claude-install.ps1
# Open a new PowerShell window (or:  . $PROFILE) so PATH refreshes
seiji-claude-sync
```

```sh
# Linux / macOS / Git Bash — from this repo's root
./bin/seiji-claude-install
# Open a new shell (or:  source ~/.bashrc) so PATH refreshes
seiji-claude-sync
```

The install scripts append a marker block to your shell profile:

- **PowerShell** — `$PROFILE` (e.g., `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
- **POSIX** — `~/.bashrc` and `~/.zshrc` (whichever exist; `~/.bashrc` is created if neither does)

Running the install script again is a no-op once the marker is present. Use `--uninstall` / `-Uninstall` to remove the block.

### Manual PATH fallback

If you prefer not to have a script edit your shell profile, run the installer with `--dry-run` (or `-DryRun`), copy the printed `export PATH=...` / `$env:PATH = ...` line, and put it wherever you usually configure PATH.

### Symlink alternative (instead of sync)

If you'd rather have your user-level config point at this checkout via symlinks (so edits in the repo are visible immediately), you can create symlinks manually:

```powershell
# Windows (PowerShell) — requires Developer Mode or admin
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills" -Target "<repo>\skills"
```

```sh
# Linux / macOS
ln -s "<repo>/skills" "$HOME/.claude/skills"
```

Caveat for Windows: symbolic links typically need either Developer Mode enabled or an elevated shell. The sync approach is simpler if you're not set up for symlinks.

## Usage

### Wrapper

```powershell
seiji-claude-sync.ps1               # run skills -> agents -> hooks -> settings
seiji-claude-sync.ps1 -DryRun       # preview every step without writing
seiji-claude-sync.ps1 -NoBackup     # skip the settings-file backup
```

```sh
seiji-claude-sync               # run skills -> agents -> hooks -> settings
seiji-claude-sync --dry-run     # preview every step without writing
seiji-claude-sync --no-backup   # skip the settings-file backup
```

`settings` runs last so any hook registrations land after their script files are in place. `--no-backup` / `-NoBackup` is forwarded only to `seiji-claude-sync-settings` — the other steps don't produce backups.

### Per-category

```powershell
seiji-claude-sync-skills.ps1
seiji-claude-sync-agents.ps1
seiji-claude-sync-hooks.ps1
seiji-claude-sync-settings.ps1 -DryRun
seiji-claude-sync-settings.ps1 -NoBackup   # write merged file but skip the backup
```

```sh
seiji-claude-sync-skills
seiji-claude-sync-agents
seiji-claude-sync-hooks
seiji-claude-sync-settings --dry-run
seiji-claude-sync-settings --no-backup     # write merged file but skip the backup
```

Every per-category script is independent — you can run just the one(s) you need.

## Settings merge rules

`seiji-claude-sync-settings` merges every `settings\*.json` preset into `~\.claude\settings.json`. Presets are processed alphabetically (deterministic order). For each key:

- **Arrays of strings** (e.g., `permissions.allow`, `permissions.deny`, `permissions.ask`) — union, dedupe, sort alphabetically.
- **Arrays of objects** (e.g., `hooks.PreToolUse[*]`) — union, dedupe by deep JSON equality, **preserve order** (don't sort).
- **Objects** — recursive merge.
- **Scalars** (strings, numbers, booleans) — **preserve the user's existing value if set**. The preset's value is only written when the key is missing in `~\.claude\settings.json`. A warning is printed naming the key, the preset, and the value that would have been set.

By default the script backs up the existing `~\.claude\settings.json` to `~\.claude\settings.backup-<ISO timestamp>.json` before writing — the `.json` extension is preserved at the end so editors recognize the file's type. The merged JSON is validated before being written; if anything fails parsing, the script aborts and the original file is left untouched.

`-NoBackup` / `--no-backup` skips the backup step but still writes the merged settings file. Use this when you've made other arrangements for backups (e.g., your shell profile is under version control, or you're running this in CI on disposable state) and don't want timestamped copies accumulating in `~\.claude\`.

`-DryRun` / `--dry-run` prints the merged result and any warnings without writing.

The script targets `~\.claude\settings.json` only — it never touches `settings.local.json` or any project-level settings file.

### Sort-order note

The PowerShell variant uses culture-aware case-insensitive sort. The POSIX/jq variant uses ASCII byte order. The merged content is semantically identical (same union, same dedupe), but the visible ordering of strings inside arrays may differ between the two. Pick one variant and stick with it if you want byte-identical output across runs.

### What sync-settings does NOT do

The script does a content merge only. It does **not** verify that hook scripts referenced in a preset's hook registrations physically exist at `~\.claude\hooks\` before activating them. If you add a settings preset that registers a new hook, run `seiji-claude-sync-hooks` first (or just use the `seiji-claude-sync` wrapper, which runs hooks before settings).
