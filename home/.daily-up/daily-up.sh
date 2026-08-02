#!/usr/bin/env bash
# Daily update script — reads updates from updates.conf and runs them in parallel.
# Designed to be triggered by a macOS Launch Agent or manually via the bashrc "up" alias.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$SCRIPT_DIR/updates.conf"
LOGFILE="$SCRIPT_DIR/daily-up.log"

log() {
  echo "$*" | tee -a "$LOGFILE"
}

export PATH="/opt/homebrew/bin:/Users/kelaita/Library/pnpm:$PATH"

log "Starting daily update"

pids=()
names=()
tmpdir=$(mktemp -d)

while IFS=$'\t' read -r name cmd; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  eval "$cmd" > "$tmpdir/$name.out" 2>&1 &
  pids+=($!)
  names+=("$name")
done < "$CONF"

failures=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    log "FAILED: ${names[$i]}"
    ((failures++))
  else
    log "OK: ${names[$i]}"
  fi
  tee -a "$LOGFILE" < "$tmpdir/${names[$i]}.out"
done

rm -rf "$tmpdir"

if [ "$failures" -gt 0 ]; then
  log "Daily update finished with $failures failure(s)"
else
  log "Daily update complete"
fi
