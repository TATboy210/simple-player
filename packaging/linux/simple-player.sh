#!/bin/bash
# Simple Player — Linux launch script
# Sets up library path and launches the player.
# Usage: ./simple-player.sh [file]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"

# Forward all arguments (file paths from .desktop %U or CLI)
exec "$SCRIPT_DIR/simple_player_flutter" "$@"
