#!/bin/bash
# Antigravity Optimizer - Skill Router (Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUTER_PATH="$SCRIPT_DIR/tools/skill_router.py"

# Check for arguments
if [ -z "$1" ]; then
    echo "Usage: activate-skills <task text>" >&2
    echo "       activate-skills --verify" >&2
    exit 1
fi

# Check if router exists
if [ ! -f "$ROUTER_PATH" ]; then
    echo "Error: Router not found at $ROUTER_PATH" >&2
    exit 1
fi

# Check for Python availability (try python3 first, then python)
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "Error: Python is required but not found in PATH." >&2
    echo "Please install Python 3.6+ from https://python.org" >&2
    exit 1
fi

# Run the router
exec "$PYTHON_CMD" "$ROUTER_PATH" "$@"
