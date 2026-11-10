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

echo "== [1/15] preflight"
xcode-select -p >/dev/null 2>&1 || { echo "Xcode Command Line Tools missing — run: xcode-select --install" >&2; exit 1; }
command -v brew >/dev/null 2>&1 || { echo "Homebrew missing — see README.md (Bootstrap)" >&2; exit 1; }
if [ ! -f "$HOME/.ssh/id_ed25519" ] || \
   ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    SSH_OK=0
    echo "No working GitHub SSH key — see README.md (SSH key setup). Continuing; git clones may fail."
fi

echo "== [2/15] brew formulae"
brew install bash fd gh git-lfs go-task pnpm uv awscli ripgrep htop tree docker || note_fail "brew formulae"

echo "== [3/15] login shell (latest bash, not the system 3.2)"
BREW_BASH="$(brew --prefix)/bin/bash"
if [ -x "$BREW_BASH" ]; then
    grep -qxF "$BREW_BASH" /etc/shells || echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null || note_fail "/etc/shells: $BREW_BASH"
    if [ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" != "$BREW_BASH" ]; then
        chsh -s "$BREW_BASH" || note_fail "chsh to $BREW_BASH"
    fi
else
    note_fail "homebrew bash missing at $BREW_BASH"
fi

echo "== [4/15] brew casks (CLI tools + MonitorControl + Macterm)"
brew install --cask claude-code@latest codex 1password-cli || note_fail "brew casks"
# Gatekeeper can't verify codex's notarization and offers to trash it on every run
xattr -dr com.apple.quarantine "$(brew --prefix)/Caskroom/codex" 2>/dev/null
brew install --cask --adopt monitorcontrol || note_fail "monitorcontrol cask"
brew install --cask --adopt thdxg/tap/macterm || note_fail "macterm cask"

echo "== [5/15] runtimes"
curl -fsSL https://viteplus.dev/install.sh | sh || note_fail "vite-plus"
curl -fsSL https://bun.sh/install | bash || note_fail "bun"
curl -fsSL https://cursor.com/install | bash || note_fail "cursor-agent"

echo "== [6/15] globals + cursor extensions"
# matches .bash_profile, which isn't applied until step 8
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
pnpm add -g sst tsx typescript || note_fail "pnpm globals"
uv tool install tox || note_fail "uv: tox"
# Cursor's python.defaultInterpreterPath points at ~/.local/bin/python3.14
uv python install 3.14 --default || note_fail "uv: python 3.14"
gh extension list 2>/dev/null | grep -q "github/gh-stack" || gh extension install github/gh-stack || note_fail "gh-stack extension"
if command -v cursor >/dev/null 2>&1; then
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        cursor --install-extension "$ext" < /dev/null || true
    done < "$REPO_DIR/cursor-extensions.txt"
else
    note_fail "cursor CLI not found — install extensions from cursor-extensions.txt manually"
fi

echo "== [7/15] agent skills"
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
# repo-owned skills: symlink into the global skills dir + each agent's dir
mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills"
for skill_dir in "$REPO_DIR"/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    ln -sfn "$skill_dir" "$HOME/.agents/skills/$skill_name"
    ln -sfn "$HOME/.agents/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
    ln -sfn "$HOME/.agents/skills/$skill_name" "$HOME/.codex/skills/$skill_name"
    ln -sfn "$HOME/.agents/skills/$skill_name" "$HOME/.cursor/skills/$skill_name"
done

echo "== [8/15] config files (home/ → \$HOME)"
# plist/json readers don't expand $HOME, so those files get the placeholder
# rendered to this machine's home path; shell files keep it literal
RENDER_DIR=$(mktemp -d)
while IFS= read -r -d '' src; do
    rel="${src#"$REPO_DIR"/home/}"
    dest="$HOME/$rel"
    case "$rel" in
        *.plist|*.json)
            if grep -qF '$HOME' "$src"; then
                rendered="$RENDER_DIR/$rel"
                mkdir -p "$(dirname "$rendered")"
                perl -pe 's/\$HOME/$ENV{HOME}/g' "$src" > "$rendered"
                touch -r "$src" "$rendered"
                src="$rendered"
            fi ;;
    esac
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
rm -rf "$RENDER_DIR"

echo "== [9/15] script clones (~/scripts)"
clone_or_pull() {
    local url=$1 dest=$2
    if [ -d "$dest/.git" ]; then
        git -C "$dest" pull --ff-only || note_fail "pull: $dest"
    else
        git clone "$url" "$dest" || note_fail "clone: $url"
    fi
}
mkdir -p "$HOME/scripts"
# the applied ~/.ssh/config routes github.com via ssh.github.com:443, whose host
# key preflight (run before configs were applied) never recorded
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com >/dev/null 2>&1
clone_or_pull git@github.com:pkelaita/awsp.git "$HOME/scripts/awsp"
clone_or_pull git@github.com:pkelaita/fav.git "$HOME/scripts/fav"
clone_or_pull git@github.com:ming86/cc-account-switcher.git "$HOME/scripts/cc-account-switcher"

echo "== [10/15] git allowed_signers"
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    mkdir -p "$HOME/.config/git"
    printf 'pierce@kelaita.com %s\n' "$(cat "$HOME/.ssh/id_ed25519.pub")" > "$HOME/.config/git/allowed_signers"
else
    echo "no ~/.ssh/id_ed25519.pub — skipping allowed_signers (see README.md, SSH key setup)"
fi

echo "== [11/15] MonitorControl preferences"
defaults import app.monitorcontrol.MonitorControl "$REPO_DIR/monitorcontrol.plist" || note_fail "MonitorControl prefs"

echo "== [12/15] Rectangle Pro shortcuts"
"$REPO_DIR/scripts/apply-rectangle-pro-shortcuts.sh" || note_fail "Rectangle Pro shortcuts"

echo "== [13/15] Macterm preferences"
# hotkeys only: the rest of the domain is machine state (window frames, recents)
while read -r action chord; do
    defaults write com.thdxg.macterm "macterm.hotkey.$action" "$chord" || note_fail "Macterm hotkey: $action"
done <<'EOF'
toggle_quick_terminal disabled
next_project cmd+down
previous_project cmd+up
next_global_tab cmd+opt+down
previous_global_tab cmd+opt+up
rename_project cmd+shift+r
EOF

echo "== [14/15] daily-up LaunchAgent"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kelaita.daily-up.plist" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.kelaita.daily-up.plist" || note_fail "daily-up LaunchAgent"

echo "== [15/15] summary"
echo "config files identical (untouched): $IDENTICAL"
[ -n "$INSTALLED" ] && echo "installed:$INSTALLED"
[ -n "$OVERWRITTEN" ] && echo "overwritten (backups in $BACKUP_DIR):$OVERWRITTEN"
[ -n "$DECLINED" ] && echo "declined (left as-is):$DECLINED"
[ -n "$FAILURES" ] && echo "FAILED:$FAILURES"
[ "$SSH_OK" -eq 0 ] && echo "reminder: set up your GitHub SSH key — README.md (SSH key setup)"
echo "manual steps (GUI apps, sign-ins): README.md (Manual installs)"
exit 0
