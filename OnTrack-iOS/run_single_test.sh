#!/bin/bash

# Deprecated wrapper retained for backwards compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
    echo "❌ A test identifier is required. For help run: $SCRIPT_DIR/test.sh --help" >&2
    exit 1
fi

echo "⚠️  'run_single_test.sh' is deprecated. Forwarding to 'test.sh'..." >&2
exec "$SCRIPT_DIR/test.sh" "$@"








