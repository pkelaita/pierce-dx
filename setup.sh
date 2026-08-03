#!/bin/bash
# pierce-dx setup — applies Pierce's DX to this machine.
# Idempotent: identical files are skipped, differing files prompt (--yes overwrites),
# every overwrite is backed up to ~/Desktop. Third-party tools install latest, no backups.
# Sole flag: --yes (non-interactive). Runs on stock macOS bash 3.2.
set -u

REPO_DIR=$(cd "$(dirname "$0")" && pwd)

YES=0
if [ $# -eq 1 ] && [ "$1" = "--yes" ]; then
    YES=1
elif [ $# -gt 0 ]; then
    echo "usage: ./setup.sh [--yes]" >&2
    exit 1
fi

BACKUP_DIR="$HOME/Desktop/pierce-dx-backup-$(date +%Y%m%d-%H%M%S)"
IDENTICAL=0
INSTALLED=""
OVERWRITTEN=""
DECLINED=""
FAILURES=""
SSH_OK=1

note_fail() {
    FAILURES="$FAILURES
  $1"
}

echo "== [1/13] preflight"
xcode-select -p >/dev/null 2>&1 || { echo "Xcode Command Line Tools missing — run: xcode-select --install" >&2; exit 1; }
command -v brew >/dev/null 2>&1 || { echo "Homebrew missing — see README.md (Bootstrap)" >&2; exit 1; }
if [ ! -f "$HOME/.ssh/id_ed25519" ] || \
   ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    SSH_OK=0
    echo "No working GitHub SSH key — see README.md (SSH key setup). Continuing; git clones may fail."
fi

echo "== [2/13] brew formulae"
brew install bash fd gh git-lfs go-task pnpm uv awscli ripgrep htop tree docker || note_fail "brew formulae"

echo "== [3/13] login shell (latest bash, not the system 3.2)"
BREW_BASH="$(brew --prefix)/bin/bash"
if [ -x "$BREW_BASH" ]; then
    grep -qxF "$BREW_BASH" /etc/shells || echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null || note_fail "/etc/shells: $BREW_BASH"
    if [ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" != "$BREW_BASH" ]; then
        chsh -s "$BREW_BASH" || note_fail "chsh to $BREW_BASH"
    fi
else
    note_fail "homebrew bash missing at $BREW_BASH"
fi

echo "== [4/13] brew casks (CLI tools + MonitorControl)"
brew install --cask claude-code@latest codex 1password-cli || note_fail "brew casks"
brew install --cask --adopt monitorcontrol || note_fail "monitorcontrol cask"

echo "== [5/13] runtimes"
curl -fsSL https://viteplus.dev/install.sh | sh || note_fail "vite-plus"
curl -fsSL https://bun.sh/install | bash || note_fail "bun"
curl -fsSL https://cursor.com/install | bash || note_fail "cursor-agent"

echo "== [6/13] globals + cursor extensions"
pnpm add -g sst tsx typescript || note_fail "pnpm globals"
uv tool install tox || note_fail "uv: tox"
gh extension list 2>/dev/null | grep -q "github/gh-stack" || gh extension install github/gh-stack || note_fail "gh-stack extension"
if command -v cursor >/dev/null 2>&1; then
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        cursor --install-extension "$ext" < /dev/null || true
    done < "$REPO_DIR/cursor-extensions.txt"
else
    note_fail "cursor CLI not found — install extensions from cursor-extensions.txt manually"
fi

echo "== [7/13] agent skills"
# repo → skill names, from this machine's ~/.agents/.skill-lock.json
# the skills CLI matches --skill values literally, so comma lists must be split
# into one --skill flag per name
while read -r repo names; do
    set --
    for name in ${names//,/ }; do
        set -- "$@" --skill "$name"
    done
    pnpm dlx skills add "$repo" -g -y -a '*' "$@" < /dev/null || note_fail "skills: $repo"
done <<'EOF'
astrolicious/agent-skills astro
get-convex/agent-skills convex-migrate
github/awesome-copilot create-agentsmd
mattpocock/skills domain-modeling,grill-with-docs,grilling,to-spec
vercel-labs/skills find-skills
anthropics/skills frontend-design
github/gh-stack gh-stack
pbakaus/impeccable impeccable
shadcn/ui shadcn
nomideusz/simple-web-design simple-web-design
hardikpandya/stop-slop stop-slop
vercel/turborepo turborepo
vercel-labs/agent-skills vercel-react-best-practices
EOF
# the repo's own dx skill: symlink into the global skills dir + each agent's dir
mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills"
ln -sfn "$REPO_DIR/skills/dx" "$HOME/.agents/skills/dx"
ln -sfn "$HOME/.agents/skills/dx" "$HOME/.claude/skills/dx"
ln -sfn "$HOME/.agents/skills/dx" "$HOME/.codex/skills/dx"
ln -sfn "$HOME/.agents/skills/dx" "$HOME/.cursor/skills/dx"

echo "== [8/13] config files (home/ → \$HOME)"
while IFS= read -r -d '' src; do
    rel="${src#"$REPO_DIR"/home/}"
    dest="$HOME/$rel"
    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        IDENTICAL=$((IDENTICAL + 1))
    elif [ ! -e "$dest" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -p "$src" "$dest"
        INSTALLED="$INSTALLED
  $rel"
    else
        if [ "$YES" -eq 1 ]; then
            ans=y
        else
            printf 'overwrite %s? [y/n] ' "$rel"
            IFS= read -r ans < /dev/tty || ans=n
        fi
        if [ "$ans" = "y" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -p "$dest" "$BACKUP_DIR/$rel"
            cp -p "$src" "$dest"
            OVERWRITTEN="$OVERWRITTEN
  $rel"
        else
            DECLINED="$DECLINED
  $rel"
        fi
    fi
done < <(find "$REPO_DIR/home" -type f ! -name '.DS_Store' -print0 | sort -z)

echo "== [9/13] script clones (~/scripts)"
clone_or_pull() {
    local url=$1 dest=$2
    if [ -d "$dest/.git" ]; then
        git -C "$dest" pull --ff-only || note_fail "pull: $dest"
    else
        git clone "$url" "$dest" || note_fail "clone: $url"
    fi
}
mkdir -p "$HOME/scripts"
clone_or_pull git@github.com:pkelaita/awsp.git "$HOME/scripts/awsp"
clone_or_pull git@github.com:pkelaita/fav.git "$HOME/scripts/fav"
clone_or_pull git@github.com:ming86/cc-account-switcher.git "$HOME/scripts/cc-account-switcher"
# clone only — the vendored karabiner.json is the applied artifact; never run its installer
clone_or_pull git@github.com:pkelaita/Zen-Reverse-Tab-Switch-With-Ctrl-Backtick.git "$HOME/scripts/zen-remap-ctrl-backtick"

echo "== [10/13] git allowed_signers"
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    mkdir -p "$HOME/.config/git"
    printf 'pierce@kelaita.com %s\n' "$(cat "$HOME/.ssh/id_ed25519.pub")" > "$HOME/.config/git/allowed_signers"
else
    echo "no ~/.ssh/id_ed25519.pub — skipping allowed_signers (see README.md, SSH key setup)"
fi

echo "== [11/13] MonitorControl preferences"
defaults import app.monitorcontrol.MonitorControl "$REPO_DIR/monitorcontrol.plist" || note_fail "MonitorControl prefs"

echo "== [12/13] daily-up LaunchAgent"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kelaita.daily-up.plist" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kelaita.daily-up.plist" || note_fail "daily-up LaunchAgent"

echo "== [13/13] summary"
echo "config files identical (untouched): $IDENTICAL"
[ -n "$INSTALLED" ] && echo "installed:$INSTALLED"
[ -n "$OVERWRITTEN" ] && echo "overwritten (backups in $BACKUP_DIR):$OVERWRITTEN"
[ -n "$DECLINED" ] && echo "declined (left as-is):$DECLINED"
[ -n "$FAILURES" ] && echo "FAILED:$FAILURES"
[ "$SSH_OK" -eq 0 ] && echo "reminder: set up your GitHub SSH key — README.md (SSH key setup)"
echo "manual steps (GUI apps, sign-ins): README.md (Manual installs)"
exit 0
