#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

python_command=""
if [[ -n "${CONDA_PREFIX:-}" ]] && command -v python >/dev/null 2>&1 \
    && [[ "$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" == "3.13" ]]; then
    python_command="$(command -v python)"
elif command -v python3.13 >/dev/null 2>&1; then
    python_command="$(command -v python3.13)"
else
    echo "HaizFlow requires Python 3.13. Install python3.13 and python3.13-venv first." >&2
    exit 1
fi

for command in ffmpeg ffprobe; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing $command. Install FFmpeg first: sudo apt install ffmpeg" >&2
        exit 1
    fi
done

if ! command -v secret-tool >/dev/null 2>&1; then
    echo "Missing secret-tool. Install it first: sudo apt install libsecret-tools" >&2
    exit 1
fi

qt_xcb_cursor="/usr/lib/x86_64-linux-gnu/libxcb-cursor.so.0"
if [[ ! -e "$qt_xcb_cursor" ]]; then
    echo "Missing libxcb-cursor0, required by Qt on Ubuntu." >&2
    echo "Install it with: sudo apt install libxcb-cursor0" >&2
    exit 1
fi

if [[ -x .venv/bin/python ]] && ! .venv/bin/python -c 'import array, sys; assert sys.version_info[:2] == (3, 13)' >/dev/null 2>&1; then
    echo "Repairing an inconsistent .venv using $python_command"
    "$python_command" -m venv --clear --copies .venv
elif [[ ! -x .venv/bin/python ]]; then
    "$python_command" -m venv --copies .venv
fi
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -e .

# VieNeu's resource manifest also supports Windows, but its native phonemizer
# and filter-bank extensions must match the current operating system.
if [[ "$(uname -m)" == "x86_64" ]]; then
    mkdir -p runtime/models/vieneu/sdk
    .venv/bin/python -m pip download --only-binary=:all: --no-deps \
        --dest runtime/models/vieneu/sdk \
        sea-g2p==0.10.0 kaldi-native-fbank==1.22.3
fi

echo "Ubuntu environment is ready. Start HaizFlow with: ./scripts/run-desktop.sh"
