RED="\\[\\033[31m\\]"
GREEN="\\[\\033[32m\\]"
YELLOW="\\[\\033[33m\\]"
BLUE="\\[\\033[1;34m\\]"
CYAN="\\[\\033[1;36m\\]"
MAGENTA="\\[\\033[35m\\]"
WHITE="\\[\\033[0m\\]"


# preserves true alphanumeric sorthing (for Linux, anyway)
# export LC_COLLATE=C
# export PS1="$CYAN\h:$YELLOW\$(parse_git_branch) $MAGENTA\w $RED\!$ $WHITE"
# export PS1="$CYAN\h:$MAGENTA\w $RED\!$ $WHITE"


export PS1="\[$CYAN\]\$(scutil --get ComputerName 2>/dev/null):$MAGENTA\w $RED\!$ $WHITE"
if [ `whoami` == "root" ]; then
	export PS1='ROOT \[\033[07;00;36m\]\H\[\033[m\]:\[\033[00;35m\]\w\[\033[m\] ROOT \!$ '
fi


# Configs
alias arc="vim ~/.aws/config"
alias vrc="vim ~/.vim_runtime/my_configs.vim"
alias grc="vim ~/.gitconfig"
alias ggrc="vim ~/.config/ghostty/config"
alias brc="vim ~/.bashrc"
alias brcc="source ~/.bashrc"


# Run daily updates (reads from ~/.daily-up/updates.conf)
while IFS=$'\t' read -r _name _cmd; do
  [[ -z "$_name" || "$_name" == \#* ]] && continue
  alias "$_name=$_cmd"
done < ~/.daily-up/updates.conf
unset _name _cmd
alias up="~/.daily-up/daily-up.sh"


# Git
alias gits="grep -iE \
    \"^alias g[^=]*=['\\\"']?(git|gh)([[:space:]]|$)\" \
    ~/.bashrc \
    | sed 's/^alias //' \
    | awk '{ if (length(\$0) > 90) print substr(\$0, 1, 87) \"...\"; else print }'"
alias gl="git log --oneline -n 25"
alias gs="git status"
alias gd="git diff"
alias ga="git add ."
alias gm="git commit -m "
alias gp="git push"
alias gb="git branch"
alias gc="git checkout"
alias gr="git restore --staged"
alias gi='f() { git rebase -i HEAD~$1; unset -f f; }; f' # interactive rebase (gi 3 → git rebase -i HEAD~3, etc.)
alias gbb='git checkout -b'
alias gre="git rebase"
alias gam="git commit --amend"
alias gbc="git fetch --prune && git branch -vv | awk '\$1 != \"*\" && /: gone]/ {print \$1}' | xargs -r -n 1 git branch -D" # branch cleanup
alias gpu="git pull"
alias gpf="git push --force-with-lease"
alias gfa="git fetch --all"
alias gst="git stash"
alias gsl="git stash list"
alias gsp="git stash pop"
alias gsa="git stash apply"
alias gsd="git stash drop"
alias grm="git fetch origin && git rebase origin/main"
alias gpr='gh pr list --state open --json number,title,url,isDraft,author | jq -r ".[] | \"\(.number): \(.title)\(if .isDraft then \" [DRAFT]\" else \"\" end) — @\(.author.login) — \(.url)\""'
# push current branch, open a PR (default title, empty body), squash-merge it, delete the branch, then prune (gp/ppr)
alias gpp='f() {
  local main cur base title;
  main=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@");
  [ -z "$main" ] && main=main;
  cur=$(git symbolic-ref --short HEAD 2>/dev/null);
  if [ -z "$cur" ]; then echo "gpp: detached HEAD, not on a branch"; unset -f f; return 1; fi;
  if [ "$cur" = "$main" ]; then echo "gpp: refusing to run on $main"; unset -f f; return 1; fi;
  if git rev-parse --verify --quiet "origin/$main" >/dev/null; then base="origin/$main"; else base="$main"; fi;
  if [ "$(git rev-list --count "$base..HEAD")" -eq 0 ]; then echo "gpp: $cur has no commits ahead of $main"; unset -f f; return 1; fi;
  title=$(git log --reverse --format=%s "$base..HEAD" | head -1);
  gp && gh pr create --title "$title" --body "" && gh pr merge --squash --delete-branch && ppr;
  unset -f f;
}; f'


# Cmux
alias cn='cmux new-workspace --cwd "$(pwdd)"'
alias cnn="cmux new-workspace --cwd"

# Python
alias ve="source .venv/bin/activate"
alias vv="uv venv"
alias ur="uv run"
alias python="python3"
alias pclear="pip freeze | xargs pip uninstall -y"


# Docker
alias ds="open -a Docker --background"
alias dsp="docker system prune -a"


# Web Dev
alias shad="pnpm dlx shadcn@latest"
alias sinit="pnpm dlx shadcn@latest init --src-dir"
alias mf="make fix"


# Applications
alias code='open -b com.microsoft.VSCode "$@"' # https://github.com/microsoft/vscode/issues/60579
alias mc="open -a MonitorControl"
alias c="cursor ."
alias 1p="op" # 1Password
alias caik="pnpm dlx caik-cli"
alias a='agent'
alias cc='claude --dangerously-skip-permissions'
alias ccc='claude'
alias co='codex --dangerously-bypass-approvals-and-sandbox'
alias cco='codex'

# Scripts
alias awsp='. ~/scripts/awsp/awsp.sh'
alias fav='. ~/scripts/fav/fav.sh'
alias ccp='bash ~/scripts/cc-account-switcher/ccswitch.sh'
alias ccl="ccp --list"
alias ccs="ccp --switch-to"
alias mclear='bash ~/scripts/mclear/mclear.sh' # close idle macterm tabs

# Misc
alias path="sed 's/:/\n/g' <<< \"$PATH\""
alias rm='rm -i' # protect from accidental deletion
alias clearcache='read -p "Confirm (y/n): " confirm && [ "$confirm" = "y" ] && sudo rm -rf ~/Library/Caches/* /Library/Caches/*'
alias ttr="tput rmam" # disable auto-margins
alias tts="tput smam" # re-enable auto-margins 
alias make='make -j $(sysctl -n hw.logicalcpu)' # Parallelize make
alias mmake="/usr/bin/make" # Standard make (for when I need it to be sequential)
alias lc="fd --type f -i \
  -E '*.json' -E '*.ico' -E '*.png' -E '*.yaml' -E '*.svg' -E '*.md' \
  -E 'README' -E 'LICENSE' \
  -E '**/db/migrations/**' \
  . | xargs wc -l"
alias ppr="gc main && gpu && gbc"
alias t="task"

# Copies the output of $0, or of the previous command if not given
yank() {
    if [ $# -eq 0 ]; then
        fc -ln -1 | bash | awk '{printf "%s", $0}' | pbcopy
    else
        "$@" | awk '{printf "%s", $0}' | pbcopy
    fi
}

# Prints the cwd with the proper ~ placement
pwdd() {
  case "$PWD" in
    "$HOME") printf '~\n' ;;
    "$HOME"/*) printf '~/%s\n' "${PWD#"$HOME"/}" ;;
    *) printf '%s\n' "$PWD" ;;
  esac
}




# uv
export PATH="/Users/kelaita/.local/bin:$PATH"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
