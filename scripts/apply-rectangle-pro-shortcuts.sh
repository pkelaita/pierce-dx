#!/bin/bash
set -u

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIG_FILE="$REPO_DIR/rectangle-pro-shortcuts.conf"

key_code() {
    case "$1" in
        a) echo 0 ;; s) echo 1 ;; d) echo 2 ;; f) echo 3 ;; h) echo 4 ;; g) echo 5 ;;
        z) echo 6 ;; x) echo 7 ;; c) echo 8 ;; v) echo 9 ;; b) echo 11 ;; q) echo 12 ;;
        w) echo 13 ;; e) echo 14 ;; r) echo 15 ;; y) echo 16 ;; t) echo 17 ;; 1) echo 18 ;;
        2) echo 19 ;; 3) echo 20 ;; 4) echo 21 ;; 6) echo 22 ;; 5) echo 23 ;; =) echo 24 ;;
        9) echo 25 ;; 7) echo 26 ;; -) echo 27 ;; 8) echo 28 ;; 0) echo 29 ;; ]) echo 30 ;;
        o) echo 31 ;; u) echo 32 ;; \[) echo 33 ;; i) echo 34 ;; p) echo 35 ;; return|enter) echo 36 ;;
        l) echo 37 ;; j) echo 38 ;; \') echo 39 ;; k) echo 40 ;; \;) echo 41 ;; \\) echo 42 ;;
        ,) echo 43 ;; /) echo 44 ;; n) echo 45 ;; m) echo 46 ;; .) echo 47 ;; tab) echo 48 ;;
        space) echo 49 ;; \`) echo 50 ;; delete|backspace) echo 51 ;; escape|esc) echo 53 ;;
        keypad-enter) echo 76 ;; home) echo 115 ;; end) echo 119 ;; page-up) echo 116 ;;
        page-down) echo 121 ;; left) echo 123 ;; right) echo 124 ;; down) echo 125 ;; up) echo 126 ;;
        f1) echo 122 ;; f2) echo 120 ;; f3) echo 99 ;; f4) echo 118 ;; f5) echo 96 ;; f6) echo 97 ;;
        f7) echo 98 ;; f8) echo 100 ;; f9) echo 101 ;; f10) echo 109 ;; f11) echo 103 ;; f12) echo 111 ;;
        *) return 1 ;;
    esac
}

process_shortcuts() {
    local apply=$1

    while read -r action shortcut extra; do
        case "$action" in
            ''|'#'*) continue ;;
        esac

        if [ -n "${extra:-}" ]; then
            echo "invalid Rectangle Pro shortcut line: $action $shortcut $extra" >&2
            return 1
        fi

        IFS=+ read -r -a parts <<< "$shortcut"
        part_count=${#parts[@]}
        key=${parts[$((part_count - 1))]}
        code=$(key_code "$key") || {
            echo "unknown Rectangle Pro shortcut key: $key" >&2
            return 1
        }

        flags=0
        index=0
        while [ "$index" -lt $((part_count - 1)) ]; do
            case "${parts[$index]}" in
                command|cmd) flags=$((flags + 1048576)) ;;
                option|opt|alt) flags=$((flags + 524288)) ;;
                control|ctrl) flags=$((flags + 262144)) ;;
                shift) flags=$((flags + 131072)) ;;
                fn) flags=$((flags + 8388608)) ;;
                *)
                    echo "unknown Rectangle Pro shortcut modifier: ${parts[$index]}" >&2
                    return 1
                    ;;
            esac
            index=$((index + 1))
        done

        if [ "$apply" -eq 1 ]; then
            defaults write com.knollsoft.Hookshot "$action" -dict keyCode -int "$code" modifierFlags -int "$flags" || return 1
        fi
    done < "$CONFIG_FILE"
}

process_shortcuts 0 || exit 1

rectangle_was_running=0
if pgrep -x 'Rectangle Pro' >/dev/null; then
    rectangle_was_running=1
    osascript -e 'tell application "Rectangle Pro" to quit'
    for _ in 1 2 3 4 5; do
        pgrep -x 'Rectangle Pro' >/dev/null || break
        sleep 1
    done
    if pgrep -x 'Rectangle Pro' >/dev/null; then
        echo "Rectangle Pro did not quit; shortcuts were not changed" >&2
        exit 1
    fi
fi

apply_status=0
process_shortcuts 1 || apply_status=$?

if [ "$rectangle_was_running" -eq 1 ]; then
    open -gja 'Rectangle Pro'
fi

exit "$apply_status"
