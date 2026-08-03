# pierce-dx

Single source of truth for Pierce's dev experience, checked out at `~/pierce-dx` on every machine. Machines stay in sync by applying the repo onto them and capturing drift back into it.

**Convention:** `home/` mirrors `$HOME` path-for-path — the tree IS the mapping. No manifest. To sync a file, drop it in `home/` at its real relative path.

**Scripts:**
- `./setup.sh [--yes]` — applies everything: third-party tools installed at latest, `home/` copied into `$HOME` (prompts per differing file; `--yes` skips prompts; every overwrite is backed up to `~/Desktop/pierce-dx-backup-<ts>/`).
- `./diff.sh` — read-only drift report: `modified` / `missing` / identical count / ignored.

## Workflows

**capture** — `./diff.sh`; for each drifted file `cp "$HOME/<path>" home/<path>`; review `git diff`; commit + push.

**apply** — `git pull && ./setup.sh --yes`.

**extend** — new config file → drop into `home/` at its real relative path. New tool → add its install-latest command to the matching `setup.sh` section (third-party is never vendored). Then apply, verify with `./diff.sh`, commit + push.

**discover** — audit for unsynced DX: `brew leaves` vs setup.sh's formula list; `pnpm ls -g`; `uv tool list`; `gh extension list`; installed skills vs setup.sh; `~/scripts/` contents; new aliases/exports in live `~/.bashrc`/`~/.bash_profile` vs vendored copies; config files in known dot-locations not yet in `home/`. Propose candidates ONE BY ONE for y/n; wire accepted ones via extend. Never re-propose anything on the rejected list.

## Hard rules

- Two-tier model: first-party files are vendored in `home/`; third-party tools are installed-latest-by-command, never vendored (pkelaita's own GitHub repos count as third-party).
- `~/.aws/config` is machine-local and never vendored — the repo contains no AWS config. Never capture `.codex/config.toml` into the repo — machine-local; `diff.sh` ignores it.
- Nothing from `~/projects` or work artifacts. Zero openlattice traces.
- No GUI apps except MonitorControl.
- Rejected — do not re-propose: gcloud, postgres, worktrunk, zed, Maccy/Raycast settings, macOS defaults, GUI casks.
