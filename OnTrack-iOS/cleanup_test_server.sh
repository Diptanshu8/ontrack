#!/bin/bash

# Compatibility wrapper for legacy usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LEGACY_ARGS=("$@")
FORWARDED_ARGS=()

for arg in "${LEGACY_ARGS[@]}"; do
    if [ "$arg" = "--clean-logs" ]; then
        # Cleaning logs is now the default behaviour, so ignore silently
        continue
    fi
    FORWARDED_ARGS+=("$arg")
done

"$SCRIPT_DIR/test_server.sh" stop "${FORWARDED_ARGS[@]}"
