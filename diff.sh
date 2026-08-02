#!/bin/bash
# pierce-dx diff — read-only drift report: home/ vs $HOME. No flags, always exits 0.
set -u

REPO_DIR=$(cd "$(dirname "$0")" && pwd)

IDENTICAL=0
while IFS= read -r -d '' src; do
    rel="${src#"$REPO_DIR"/home/}"
    case "$rel" in
        .aws/config|.codex/config.toml)
            echo "ignored (machine-local): $rel"
            continue ;;
    esac
    dest="$HOME/$rel"
    if [ ! -f "$dest" ]; then
        echo "missing: $rel"
    elif cmp -s "$src" "$dest"; then
        IDENTICAL=$((IDENTICAL + 1))
    else
        echo "modified: $rel"
    fi
done < <(find "$REPO_DIR/home" -type f ! -name '.DS_Store' -print0 | sort -z)

echo "identical: $IDENTICAL"
exit 0
