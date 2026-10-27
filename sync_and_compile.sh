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
# Keep the imported Much Better AI profile deterministic.  This guard prevents
# a future additive extraction from silently reintroducing its retired CET,
# settings, or localization surface.
MBAI_SRC="$SCRIPT_DIR/r6/scripts/MuchBetterAI"
if [[ -d "$MBAI_SRC/Localization" ]]; then
  echo "ERROR: MuchBetterAI localization payload is prohibited in this profile" >&2
  exit 1
fi
if [[ -d "$MBAI_SRC" ]] && grep -R -n -E 'cyber_engine_tweaks|registerForEvent|settingsManager|nativeSettings|MuchBetterAISettings|MuchBetterAIConfig|ModSettings|@runtimeProperty|ModLocalization' "$MBAI_SRC" >/dev/null; then
  echo "ERROR: MuchBetterAI contains a retired CET/settings/localization surface" >&2
  exit 1
fi
# RED4ext's runtime SCC pass can rewrite @wrapMethod sources in the game-side
# tree into generated wrapper/proxy bodies.  Always copy the immutable source
# tree first so manual recompiles recover from the previous launch.
cp -a "$SCRIPT_DIR/r6/scripts/." "$GAME/r6/scripts/"
# UX-04 was intentionally removed.  `cp -a` is additive, so clean only this
# explicitly retired source file to prevent an old game-side copy returning.
rm -f "$GAME/r6/scripts/CustomRedscriptSuite/Nexus34645_AutoContinue.reds"
rm -f "$GAME/r6/scripts/CustomRedscriptSuite/Nexus34645_Startup.reds"
# The level-cap module was renamed when its cap moved from 150 to 300.  Since
# the source copy is additive, remove the retired game-side filename so both
# generations cannot compile together.
rm -f "$GAME/r6/scripts/CustomRedscriptSuite/LevelCap150XP150.reds"
# Much Better AI is now a fixed, CET-free profile.  Remove the upstream
# settings/localization sources if an earlier extraction left them in the
# additive game-side tree; neither is part of the repository anymore.
rm -f "$GAME/r6/scripts/MuchBetterAI/config.reds"
rm -rf "$GAME/r6/scripts/MuchBetterAI/Localization"
# These imported compatibility/audit stubs had no producers or consumers and
# only scheduled work (or destructive tagged-entity cleanup).  Keep an older
# additive extraction from reintroducing them into the game-side tree.
rm -f "$GAME/r6/scripts/MuchBetterAI/Audit/CombatAuditSystem.reds"
rm -f "$GAME/r6/scripts/MuchBetterAI/Compatibility/ResponseCleanup.reds"
rm -f "$GAME/r6/scripts/MuchBetterAI/Compatibility/ResponseCompatibility.reds"
# RedFunctions was retired after its native plugin failed the current game
# build.  `cp -a` is additive, so explicitly remove every old source/runtime
# payload and its Redscript Configuration Framework documentation.
rm -rf "$GAME/r6/scripts/RedFunctions" "$GAME/red4ext/plugins/RedFunctions"
rm -f "$GAME/r6/storages/RedscriptConfigFramework/RedFunctions.card.json" \
  "$GAME/r6/storages/RedscriptConfigFramework/RedFunctions.docs.txt"
rmdir "$GAME/r6/storages/RedscriptConfigFramework" 2>/dev/null || true

if [[ -d "$SCRIPT_DIR/r6/tweaks" ]]; then
  mkdir -p "$GAME/r6/tweaks"
  cp -a "$SCRIPT_DIR/r6/tweaks/." "$GAME/r6/tweaks/"
fi
# The optional Reinforcements Gang-vs-Gang overlay is intentionally not part
# of this profile: its vehicle/character records are unavailable here and
# produced hundreds of TweakXL reference warnings.  `cp -a` is additive, so
# remove an older game-side extraction instead of allowing it to return.
rm -f "$GAME/r6/tweaks/zz_FactionsEvolved/FactionsEvolved_Reinforcements.yaml"
rm -rf "$GAME/r6/tweaks/zz_FactionsEvolved/reinforcements"

if [[ -d "$SCRIPT_DIR/r6/storages" ]]; then
  mkdir -p "$GAME/r6/storages"
  cp -a "$SCRIPT_DIR/r6/storages/." "$GAME/r6/storages/"
fi

if [[ -d "$SCRIPT_DIR/r6/audioware" ]]; then
  mkdir -p "$GAME/r6/audioware"
  cp -a "$SCRIPT_DIR/r6/audioware/." "$GAME/r6/audioware/"
fi

if [[ -d "$SCRIPT_DIR/red4ext/plugins" ]]; then
  mkdir -p "$GAME/red4ext/plugins"
  cp -a "$SCRIPT_DIR/red4ext/plugins/." "$GAME/red4ext/plugins/"
fi
# Blur Begone/ReFRACT are fixed source profiles.  Remove the upstream
# Mod Settings menu wrappers from an older additive extraction so they cannot
# reintroduce a runtime configuration surface.
rm -f "$GAME/red4ext/plugins/BlurBegone/scripts/BlurBegoneMenu.reds" \
  "$GAME/red4ext/plugins/ReFRACT/scripts/ReFRACTMenu.reds"

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
  "$GAME/red4ext/plugins/BlurBegone/scripts" \
  "$GAME/red4ext/plugins/ReFRACT/scripts" \
  "$GAME/red4ext/plugins/FXBegone/scripts" \
  "$GAME/red4ext/plugins/LoadBegone/scripts"; do
  if [[ -d "$plugin_scripts" ]]; then
    printf '%s\n' "$plugin_scripts" >> "$PATHS_FILE"
  fi
done

"$PROTON" runinprefix "$GAME/engine/tools/scc.exe" -compile "$GAME/r6/scripts" -compilePathsFile "$PATHS_FILE" -outputCacheFile "$GAME/r6/cache/final.redscripts.modded"

cat "$GAME/r6/logs/redscript_rCURRENT.log"
