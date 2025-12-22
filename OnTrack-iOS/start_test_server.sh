#!/bin/bash

# Compatibility wrapper for legacy usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/test_server.sh" start "$@"
