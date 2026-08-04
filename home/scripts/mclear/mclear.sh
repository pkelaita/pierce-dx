#!/bin/bash

# Macterm cleanup: in every project, close idle tabs and keep a free tab up front.
# - A tab is busy if any pane runs a non-shell foreground process
# - The front-most idle tab is kept as the free tab (reusing beats creating:
#   macterm spawns CLI-created tabs lazily on first view, which can glitch)
# - A new tab is only created when a project has no idle tabs; macterm can't
#   insert tabs at the front, so it lands last and gets fronted once to spawn
# - The pane running mclear itself doesn't count as busy, but is never closed

set -u

close_all() {
  local projects current project pid failed=0
  local pids=()

  projects=$(macterm project list --json) || return 1
  current=$(macterm tab list --json | jq -r 'first(.tabs[] | select(.active).id) // empty') || return 1
  [[ -n $current ]] || { echo "mclear: no active tab" >&2; return 1; }

  close_project() {
    local project=$1 current=$2 tabs tab
    tabs=$(macterm tab list --project "$project" --json) || return 1
    while read -r tab; do
      [[ $tab == "$current" ]] && continue
      macterm tab close "$tab" --project "$project" --force --json > /dev/null || return 1
    done <<< "$(jq -r '.tabs[].id' <<< "$tabs")"
  }

  while read -r project; do
    close_project "$project" "$current" &
    pids+=("$!")
  done <<< "$(jq -r '.projects[] | select(.loaded).id' <<< "$projects")"

  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  return "$failed"
}

if [[ ${1:-} == "--all" || ${1:-} == "-a" ]]; then
  close_all
  exit
fi

projects=$(macterm project list --json) || exit 1
ACTIVE=$(jq -r 'first(.projects[] | select(.active).id) // empty' <<< "$projects")

# Reconcile one project. Prints "<proj>\t<tab-id>" if it had to create a tab.
reconcile() {
  local proj=$1 rows idx id busy self spawned
  rows=$(macterm pane list --project "$proj" --json | jq -r --arg self "${MACTERM_SESSION:-}" '
    .panes | group_by(.tabID)[]
    | [ .[0].tabIndex,
        .[0].tabID,
        (any(.[]; .process != null and
          (if .session == $self
           then (.process | test("^-?(bash|zsh|fish|dash|tcsh|sh|macterm|jq)$") | not)
           else (.process | test("^-?(bash|zsh|fish|dash|tcsh|sh)$") | not)
           end))),
        any(.[]; .session == $self),
        any(.[]; .process != null) ]
    | @tsv' | sort -n)

  # Pick the tab to keep free. The self tab can never be closed, so when it's
  # idle it MUST be the free tab or the project ends up with two empties.
  # Otherwise: tab 1 if idle, else the first idle tab with a live shell, else
  # the first idle tab.
  local keep="" fallback=""
  while IFS=$'\t' read -r idx id busy self spawned; do
    [[ $busy == false && $self == true ]] && { keep=$id; break; }
  done <<< "$rows"
  if [[ -z $keep ]]; then
    while IFS=$'\t' read -r idx id busy self spawned; do
      [[ -z $idx || $busy == true ]] && continue
      if (( idx == 1 )) || [[ $spawned == true ]]; then keep=$id; break; fi
      [[ -z $fallback ]] && fallback=$id
    done <<< "$rows"
    [[ -z $keep ]] && keep=$fallback
  fi

  local new_id=""
  if [[ -z $keep ]]; then
    new_id=$(macterm tab new --project "$proj" --json | jq -r '.tabs[0].id')
  fi

  while IFS=$'\t' read -r idx id busy self spawned; do
    [[ -z $idx || $busy == true || $self == true || $id == "$keep" ]] && continue
    macterm tab close "$id" --project "$proj" --json > /dev/null
  done <<< "$rows"

  # Greet with the free tab on the next visit (never yank the active project)
  if [[ -n $new_id ]]; then
    echo "$proj"$'\t'"$new_id"
  elif [[ -n $keep && $proj != "$ACTIVE" ]]; then
    macterm tab select "$keep" --project "$proj" --json > /dev/null
  fi
}

created=$(
  while read -r proj; do
    reconcile "$proj" &
  done <<< "$(jq -r '.projects[] | select(.loaded).id' <<< "$projects")"
  wait
)

# Created tabs spawn lazily and glitch on deferred first view; front each once
# (they're already their project's active tab) so the shell starts now.
if [[ -n $created ]]; then
  orig_tab=$(macterm tab list --json 2>/dev/null | jq -r 'first(.tabs[] | select(.active).id) // empty')
  while IFS=$'\t' read -r proj id; do
    [[ -z $proj ]] && continue
    macterm project select "$proj" --json > /dev/null
    sleep 0.2
  done <<< "$created"
  [[ -n $ACTIVE ]] && macterm project select "$ACTIVE" --json > /dev/null
  [[ -n $orig_tab ]] && macterm tab select "$orig_tab" --project "$ACTIVE" --json > /dev/null 2>&1
fi
exit 0
