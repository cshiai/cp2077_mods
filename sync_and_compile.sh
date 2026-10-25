#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/r6/scripts/CustomRedscriptSuite"
GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077}"
DEST_DIR="$GAME/r6/scripts/CustomRedscriptSuite"
if [[ -z "${PROTON:-}" ]]; then
  if [[ -x "/usr/share/steam/compatibilitytools.d/proton-cachyos-slr/proton" ]]; then
    PROTON="/usr/share/steam/compatibilitytools.d/proton-cachyos-slr/proton"
  else
    PROTON="$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton"
  fi
fi

export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/.local/share/Steam/steamapps/compatdata/1091500}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.local/share/Steam}"

mkdir -p "$DEST_DIR"
# RED4ext's runtime SCC pass can rewrite @wrapMethod sources in the game-side
# tree into generated wrapper/proxy bodies.  Always copy the immutable source
# tree first so manual recompiles recover from the previous launch.
cp -a "$SCRIPT_DIR/r6/scripts/." "$GAME/r6/scripts/"

if [[ -d "$SCRIPT_DIR/r6/tweaks" ]]; then
  mkdir -p "$GAME/r6/tweaks"
  cp -a "$SCRIPT_DIR/r6/tweaks/." "$GAME/r6/tweaks/"
fi

if [[ -d "$SCRIPT_DIR/red4ext/plugins" ]]; then
  mkdir -p "$GAME/red4ext/plugins"
  cp -a "$SCRIPT_DIR/red4ext/plugins/." "$GAME/red4ext/plugins/"
fi

if [[ -d "$SCRIPT_DIR/archive/pc/mod" ]]; then
  mkdir -p "$GAME/archive/pc/mod"
  cp -a "$SCRIPT_DIR/archive/pc/mod/." "$GAME/archive/pc/mod/"
fi

PLUGIN_DLL="$SCRIPT_DIR/native_plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll"
if [[ -f "$PLUGIN_DLL" ]]; then
  mkdir -p "$GAME/red4ext/plugins/UniversalAimFlashlight"
  cp -f "$PLUGIN_DLL" "$GAME/red4ext/plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll"
  mkdir -p "$SCRIPT_DIR/red4ext/plugins/UniversalAimFlashlight"
  cp -f "$PLUGIN_DLL" "$SCRIPT_DIR/red4ext/plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll"
fi

PATHS_FILE="$(mktemp)"
trap 'rm -f "$PATHS_FILE"' EXIT
for plugin_scripts in \
  "$GAME/red4ext/plugins/ArchiveXL/Scripts" \
  "$GAME/red4ext/plugins/Codeware/Scripts" \
  "$GAME/red4ext/plugins/TweakXL/Scripts" \
  "$GAME/red4ext/plugins/BlurBegone/scripts"; do
  if [[ -d "$plugin_scripts" ]]; then
    printf '%s\n' "$plugin_scripts" >> "$PATHS_FILE"
  fi
done

"$PROTON" runinprefix "$GAME/engine/tools/scc.exe" -compile "$GAME/r6/scripts" -compilePathsFile "$PATHS_FILE" -outputCacheFile "$GAME/r6/cache/final.redscripts.modded"

cat "$GAME/r6/logs/redscript_rCURRENT.log"
