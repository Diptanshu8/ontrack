#!/bin/bash

# Deprecated wrapper retained for backwards compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "⚠️  'run_tests_isolated.sh' is deprecated. Forwarding to 'test.sh --suite --isolated'..." >&2
exec "$SCRIPT_DIR/test.sh" --suite --isolated "$@"








