#!/usr/bin/env bash
set -euo pipefail

# Guarded runtime entry point for the source-first profile.  It deliberately
# refuses an unknown Steam build rather than bypassing compatibility checks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
PREFIX="${STEAM_COMPAT_DATA_PATH:-$STEAM_ROOT/steamapps/compatdata/1091500}"
MANIFEST="$STEAM_ROOT/steamapps/appmanifest_1091500.acf"
EXPECTED_BUILD="26161058"

if [[ -x "${PROTON:-}" ]]; then
  :
elif [[ -x "/usr/share/steam/compatibilitytools.d/proton-cachyos-slr/proton" ]]; then
  PROTON="/usr/share/steam/compatibilitytools.d/proton-cachyos-slr/proton"
else
  PROTON="$STEAM_ROOT/steamapps/common/Proton - Experimental/proton"
fi

read_build_id() {
  if [[ ! -f "$MANIFEST" ]]; then
    printf '%s\n' "unknown"
    return
  fi
  awk '$1 ~ /buildid/ { gsub(/"/, "", $2); print $2; exit }' "$MANIFEST"
}

current_build="$(read_build_id)"

print_status() {
  printf 'game=%s\n' "$GAME"
  printf 'proton=%s\n' "$PROTON"
  printf 'prefix=%s\n' "$PREFIX"
  printf 'installed_build=%s\n' "$current_build"
  printf 'expected_build=%s\n' "$EXPECTED_BUILD"
  printf 'build_guard=%s\n' "$([[ "$current_build" == "$EXPECTED_BUILD" ]] && echo pass || echo refuse)"
  printf 'redscript_sources=%s\n' "$(find "$SCRIPT_DIR/r6/scripts" -type f -name '*.reds' | wc -l)"
  printf 'tweak_inputs=%s\n' "$(find "$SCRIPT_DIR/r6/tweaks" -type f -name '*.yaml' | wc -l)"
}

guard_build() {
  if [[ "$current_build" != "$EXPECTED_BUILD" ]]; then
    printf 'Refusing launch: Steam build %s is not the validated baseline %s.\n' "$current_build" "$EXPECTED_BUILD" >&2
    printf 'Reassess compatibility before changing this guard.\n' >&2
    exit 2
  fi
  if [[ ! -x "$PROTON" ]]; then
    printf 'Refusing launch: Proton executable not found: %s\n' "$PROTON" >&2
    exit 2
  fi
  if [[ ! -f "$GAME/bin/x64/Cyberpunk2077.exe" ]]; then
    printf 'Refusing launch: game executable not found.\n' >&2
    exit 2
  fi
}

case "${1:-status}" in
  status)
    print_status
    ;;
  dry-run)
    guard_build
    print_status
    printf 'command=%q runinprefix %q\n' "$PROTON" "$GAME/bin/x64/Cyberpunk2077.exe"
    ;;
  launch)
    guard_build
    export STEAM_COMPAT_DATA_PATH="$PREFIX"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$STEAM_ROOT}"
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
    export DXVK_FILTER_DEVICE_NAME='NVIDIA GeForce RTX 5060 Laptop GPU'
    export VKD3D_FILTER_DEVICE_NAME='NVIDIA GeForce RTX 5060 Laptop GPU'
    exec "$PROTON" runinprefix "$GAME/bin/x64/Cyberpunk2077.exe"
    ;;
  *)
    printf 'usage: %s {status|dry-run|launch}\n' "$0" >&2
    exit 64
    ;;
esac
