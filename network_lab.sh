#!/usr/bin/env bash
# ==============================================================================
# IoT Internet Layer - Root Wrapper Script
# Forwards execution to scripts/network_lab.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/scripts/network_lab.sh" "$@"
