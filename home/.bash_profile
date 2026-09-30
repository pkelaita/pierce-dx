#=== start of automatically maintained lines (do not delete)===
# .bashrc, sourced by interactive non-login shells (also called by .bash_profile)
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi
# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"
# PNPM
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# UV globals
export PATH="$HOME/.local/bin:$PATH"


export EDITOR='vim'



# Vite+ bin (https://viteplus.dev)
. "$HOME/.config/vite-plus/env"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
