#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python_path="$project_root/.venv/bin/python"

if [[ ! -x "$python_path" ]]; then
    echo "Virtual environment not found. Run ./scripts/install-ubuntu.sh first." >&2
    exit 1
fi

qt_platform_plugin="$project_root/.venv/lib/python3.13/site-packages/PySide6/Qt/plugins/platforms/libqxcb.so"
if [[ -f "$qt_platform_plugin" ]] && ldd "$qt_platform_plugin" 2>/dev/null | grep -q 'not found'; then
    echo "Qt cannot start because Ubuntu runtime libraries are missing:" >&2
    ldd "$qt_platform_plugin" 2>/dev/null | grep 'not found' >&2
    echo "Install the required Qt library with: sudo apt install libxcb-cursor0" >&2
    exit 1
fi

# NVIDIA wheels keep CUDA libraries in component-specific directories.
# Torch loads its own dependencies, but TorchCodec uses dlopen and needs those
# directories visible to the Linux dynamic loader from process startup.
shopt -s nullglob
nvidia_library_paths=("$project_root"/.venv/lib/python3.13/site-packages/nvidia/*/lib)
shopt -u nullglob
python_base_prefix="$($python_path -c 'import sys; print(sys.base_prefix)')"
runtime_library_paths=(
    "${nvidia_library_paths[@]}"
    "$project_root/.venv/lib/python3.13/site-packages/PySide6/Qt/lib"
    "$python_base_prefix/lib"
)
runtime_library_path="$(IFS=:; echo "${runtime_library_paths[*]}")"
export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$project_root"
exec "$python_path" "$project_root/haizflow_desktop.py" "$@"
