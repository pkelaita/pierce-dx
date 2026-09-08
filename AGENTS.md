# pierce-dx

Single source of truth for Pierce's dev experience, checked out at `~/pierce-dx` on every machine. Machines stay in sync by applying the repo onto them and capturing drift back into it.

**Convention:** `home/` mirrors `$HOME` path-for-path — the tree IS the mapping. No manifest. To sync a file, drop it in `home/` at its real relative path.

**Scripts:**
- `./setup.sh [--yes]` — applies everything: third-party tools installed at latest, `home/` copied into `$HOME` (prompts per differing file; `--yes` skips prompts; every overwrite is backed up to `~/Desktop/pierce-dx-backup-<ts>/`).
- `./diff.sh` — read-only drift report: `modified` / `missing` / identical count / ignored.

## Workflows

**capture** — `./diff.sh`; copy each drifted live file into `home/`, then replace machine-specific home paths with literal `$HOME`; review `git diff`; commit + push.

**apply** — `git pull && ./setup.sh --yes`.

**extend** — new config file → drop into `home/` at its real relative path. New tool → add its install-latest command to the matching `setup.sh` section (third-party is never vendored). Then apply, verify with `./diff.sh`, commit + push.

**discover** — audit for unsynced DX: `brew leaves` vs setup.sh's formula list; `pnpm ls -g`; `uv tool list`; `gh extension list`; installed skills vs setup.sh; `~/scripts/` contents; new aliases/exports in live `~/.bashrc`/`~/.bash_profile` vs vendored copies; config files in known dot-locations not yet in `home/`. Propose candidates ONE BY ONE for y/n; wire accepted ones via extend. Never re-propose anything on the rejected list.

## Hard rules

- Two-tier model: first-party files are vendored in `home/`; third-party tools are installed-latest-by-command, never vendored (pkelaita's own GitHub repos count as third-party).
- Keep home paths portable in the repo using literal `$HOME`. Live configs may require the expanded absolute home path; preserve that form where the application does not expand `$HOME`, and expand repo placeholders when applying those configs. This representation difference is expected, not drift. Normalize home paths before comparing or reporting drift; never capture an expanded machine path over a repo placeholder.
- Track and sync T3 Code's `.t3/userdata/{client-settings,desktop-settings,settings,keybindings}.json` through `home/`. Check these files during capture, apply, and drift review. Keep credentials, tokens, secrets, databases, sessions, logs, attachments, caches, and runtime metadata machine-local; inspect settings for credentials and machine paths before capture.
- `~/.aws/config` is machine-local and never vendored — the repo contains no AWS config. Never capture `.codex/config.toml` into the repo — machine-local; `diff.sh` ignores it.
- Nothing from `~/projects` or work artifacts. Zero openlattice traces.
- No GUI app installs except MonitorControl.
- Rejected — do not re-propose: gcloud, postgres, worktrunk, zed, Maccy/Raycast settings, general macOS defaults, GUI casks.
