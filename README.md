# pierce-dx

Pierce's dev experience — shell, scripts, terminal, editors, keyboard, AI tooling — as one private repo, checked out at `~/pierce-dx` on every machine. `setup.sh` applies it, `diff.sh` shows drift, and any agent can keep it current (see `AGENTS.md`).

```
├── AGENTS.md               # how agents operate this repo (four workflows)
├── CLAUDE.md               # → @AGENTS.md
├── SPEC.md                 # the spec this was built from
├── setup.sh                # apply everything to this machine (sole flag: --yes)
├── diff.sh                 # read-only drift report, home/ vs $HOME
├── cursor-extensions.txt   # Cursor extension ids, one per line
├── monitorcontrol.plist    # MonitorControl prefs (imported by setup.sh)
├── rectangle-pro-shortcuts.conf
│                           # readable Rectangle Pro action → shortcut mappings
├── scripts/
│   └── apply-rectangle-pro-shortcuts.sh
│                           # applies Rectangle Pro shortcuts without full setup
├── skills/dx/              # global agent skill routing "sync my dx" here
└── home/                   # mirrors $HOME path-for-path — the tree IS the mapping
```

First-party config lives as complete readable files under `home/`. Third-party tools are never vendored — `setup.sh` installs the latest of each, so a new machine may legitimately be ahead of the old one.

## Bootstrap (fresh machine)

1. Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. `brew install gh && gh auth login`
3. `gh repo clone pkelaita/pierce-dx ~/pierce-dx` (HTTPS — works before SSH is set up)
4. `cd ~/pierce-dx && ./setup.sh`

`setup.sh` prompts before overwriting any existing file that differs, and every overwrite is first backed up to `~/Desktop/pierce-dx-backup-<timestamp>/`. Identical files are skipped; re-running is idempotent. `--yes` answers every prompt (backups still happen).

## SSH key

`setup.sh` checks for a usable key and points here if missing. Keys are per-machine — generate, never copy:

```sh
ssh-keygen -t ed25519 -C "pierce@kelaita.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname) signing" --type signing
```

One key does both auth and commit signing. The applied `~/.ssh/config` routes github.com through ssh.github.com:443, and `setup.sh` regenerates `~/.config/git/allowed_signers` from whatever pubkey the machine has.

## Manual installs (GUI apps)

`setup.sh` installs no GUI apps (MonitorControl excepted). Install these yourself:

- **cmux** — prefer `brew install --cask cmux` so daily-up's `brew upgrade cmux` works (any install method is fine; that update entry then fails harmlessly); keyboard shortcuts are applied via `home/.config/cmux/cmux.json`
- **T3 Code** — install the stable or nightly DMG; daily-up updates whichever channel is installed, and keybindings are applied from `home/.t3/userdata/keybindings.json`
- **Ghostty**, **Cursor**, **Sublime Text** — configs for all three are applied by setup
- **Karabiner-Elements** — required for the applied `karabiner.json` remaps
- **Rectangle Pro** — shortcuts live in `rectangle-pro-shortcuts.conf`; run `./scripts/apply-rectangle-pro-shortcuts.sh` after editing (it restarts Rectangle Pro if needed)
- **Zen**, **1Password**, **CodexBar**, **supacode**
- **Raycast** — settings don't sync (encrypted); export/import manually
- **Maccy** — configure in-app

Sign-ins, all manual: `gh auth login` (done at bootstrap), `claude`, `codex`, cursor-agent (`agent`), `aws sso login`, 1Password.

## Sync usage

Tell any agent (the global `dx` skill routes these here):

- **capture** — "capture my dx drift": machine-side edits flow back into the repo
- **apply** — "apply my dx": repo-side changes flow onto the machine
- **extend** — "add X to my dx": a new alias/config/tool gets wired in
- **discover** — "check this machine for new dx": audits and proposes candidates y/n

Or run `./setup.sh` / `./diff.sh` yourself.

---

This repo supersedes `github.com/pkelaita/configs` (archive it manually if desired).
