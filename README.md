# Active Redscript Mods

Personal, source-first Cyberpunk 2077 mod collection. The repository is intentionally maintained as ordinary Git-managed code: edit, compile, play-test, and commit. Git history and the user's cloud download history are the rollback paths; downloaded installer archives, checksum ledgers, manifests, and duplicate backup trees are not part of this project.

## Current profile

- **Game target:** Cyberpunk 2077 2.5 on Steam/Proton (validate against the installed build before enabling a new native plugin).
- **Source:** 104 `r6/scripts` `.reds` files plus bundled plugin-script APIs, eleven TweakXL YAML inputs, selected ArchiveXL resources, and the custom/third-party RED4ext plugins. RedFunctions is retired and removed.
- **Enemy-health tuning:** `EnemyHealthScalingByLevel` uses a quintic smootherstep from 1.25× at level 10 to a hard 3× cap at level 60+.
- **Cazanu combat scope:** limb survival is limited to Elite/Rare/Boss/MaxTac human enemies, uses a centralized 5% maximum-health floor, and never suppresses natural DOTs. Blood/obstacle sampling is bounded for lower event and raycast cost.
- **Enemy duplication:** hostile combat enemies only, with Elite/Rare included and a hard 24-clone cap; neutral NPCs are never cloned.
- **Diagnostics:** Cazanu limb-survival diagnostics are temporarily enabled for the elite-enemy investigation; disable them after evidence is collected.
- **Runtime layout:** copy this tree into the game root with `sync_and_compile.sh`; the script then invokes the game's `scc.exe` and prints the current redscript log.
- **Guarded runtime entry:** `./launch-cyberpunk2077-proton-experimental.sh status|dry-run|launch` uses Proton `runinprefix`, preserves the NVIDIA environment, and refuses Steam builds other than the validated baseline `26133166`.
- **CET policy:** Cyber Engine Tweaks is deliberately **not installed or supported**. No CET Lua, ASI, console, or CET-required mod may be added.
- **Much Better AI profile:** the imported 2.3 enemy-AI source is now a fixed REDscript/TweakXL profile. Its CET Lua bootstrap, Native Settings UI, JSON settings store, localization packages, runtime config class, and user-facing tuning parameters are intentionally absent. Gameplay constants are reviewed source values; change them in Git rather than through a runtime menu.
- **Weather profile:** `archive/pc/mod/weather_probability_rebalance.archive` is an archive-only weather-probability resource. It has no scripts, settings, CET, or native plugin and is loaded through the ordinary mod archive path.
- **FX/Load profiles:** FX Begone 2.3.0 and Load Begone 3.0.0 are installed as fixed profiles. Their Mod Settings annotations/listeners and any CET dependency were removed; native RED4ext plugins and REDscript companions remain together.

## Frameworks and dependencies

Versions below describe the APIs currently present or required by this tree; they are not a downloaded-package inventory. Follow each upstream repository's release notes for game-build compatibility.

| Component | Role in this tree | Version/API note | Upstream |
|---|---|---|---|
| **redscript** | Compiles all `.reds` sources into `final.redscripts.modded`. | 0.5.32 target | [jac3km4/redscript](https://github.com/jac3km4/redscript) |
| **RED4ext** | Native loader and script-extension host. | 1.31.x target for the current 2.5 profile | [WopsS/RED4ext](https://github.com/WopsS/RED4ext) |
| **RED4ext.SDK** | Build-only C++ headers/types for `UniversalAimFlashlight`. | Match the RED4ext/game build; not a runtime plugin by itself | [WopsS/RED4ext.SDK](https://github.com/WopsS/RED4ext.SDK) |
| **ArchiveXL** | Loads the bundled `.archive`/`.xl` resources and exposes ArchiveXL REDscript APIs. | Bundled API headers identify 1.28.0 | [psiberx/cp2077-archive-xl](https://github.com/psiberx/cp2077-archive-xl) |
| **TweakXL** | Applies the eleven `r6/tweaks/**/*.yaml` files and supplies TweakDB APIs. | `CyberwareEx` requires 1.12.0 or newer | [psiberx/cp2077-tweak-xl](https://github.com/psiberx/cp2077-tweak-xl) |
| **Codeware** | Shared native/script library for UI, localization, dynamic entities, and CyberwareEx. | **1.21.1 current**; `CyberwareEx` and `EnemyMultiplierRedscript` require 1.21.0 or newer | [psiberx/cp2077-codeware](https://github.com/psiberx/cp2077-codeware) |
| **Mod Settings** *(optional, not installed)* | Would read the `@runtimeProperty("ModSettings.*")` annotations in SlotsSlotsSlots, QuestGuide, The Nullifier, and Blur Begone. Sources guard registration with `ModuleExists`. | Not present in this repository or current game installation; never treat it as a hard requirement | [Cyberpunk2077-Mods/ModSettings](https://github.com/Cyberpunk2077-Mods/ModSettings) |
| **Blur Begone** *(bundled visual plugin)* | Optional visual/native component under `red4ext/plugins/BlurBegone`. | 2.5.0 package currently present; upstream distribution is [Nexus Mods 8105](https://www.nexusmods.com/cyberpunk2077/mods/8105) | No maintained public GitHub source identified |

The custom plugin is built from `native_plugins/UniversalAimFlashlight/Main.cpp` and registers one RED4ext native function used by `r6/scripts/CustomRedscriptSuite/UniversalAimFlashlight.reds`. Its own plugin version is `1.2.0`: balanced range/intensity, one raster-shadowed main beam, and ray-tracing contribution disabled. Rebuild it whenever the C++ source or SDK-facing types change.

## Source map

### `r6/scripts/CustomRedscriptSuite/` (22 modules)

Gameplay tuning and pure-redscript features: no CET dependency.

- **Progression/player:** No Attribute Restriction, `ThreeModProfile` carry capacity, `PassiveHealthRegen25`, `MaxHealthStamina100`, `LevelCap150XP150`, `FastWalkNoRestrictions150`, `CyberNinjaParkour`.
- **Equipment/crafting:** `BypassEquipmentAttachmentRestrictions`, `UniversalSlotsAndAttachments`, `UniversalIconicWeapons`, `ZeroCostCraftingUpgrade`, `InstantUpgradeNoConfirm`, `WeaponMagazineAndAmmo5X`.
- **Combat/AI:** `EnemyHealthScalingByLevel`, `EnemyMultiplierRedscript` (Codeware dynamic entities), `ApexEnemiesCombatOverhaul`, `LethalEnemyNetrunners`.
- **UI/flow/utility:** `InstantBreachAutoSolver`, `InstantUISuite`, `Nexus34645_Startup`, and `UniversalAimFlashlight` (the native-plugin companion). The Nexus AutoContinue mod was removed.

### Other source modules

| Directory | Contents | Dependency notes |
|---|---|---|
| `r6/scripts/CazanuLimbSurvival/` | 11 bounded limb-wound, crawl, seated-combat, and follow-up systems | Uses vanilla hooks plus the framework APIs called by its source; no CET |
| `r6/scripts/SlotsSlotsSlots/` | Core slot tables/UI and weapon slot behavior (5 files) | Optional Mod Settings UI; YAML records use TweakXL |
| `r6/scripts/CyberwareEx/` | Cyberware-EX core and globals (2 files) | Codeware 1.21.0+ and TweakXL 1.12.0+ |
| `r6/scripts/QuestGuide/` | Quest guide UI, localization, settings, and perk button (4 files) | Codeware UI/localization; optional Mod Settings |
| `r6/scripts/Attachments Crafting System/` | Attachment/crafting script | TweakXL YAML companion |
| `r6/scripts/TheNullifier/` | Lighting, fog, boundary, and kill-trigger toggles | Optional Mod Settings; no CET |
| `r6/scripts/MuchBetterAI/` | Fixed hostile-AI overhaul: marksmanship, footwork, fireteams, stealth, nerve, netrunner, and capability systems (57 files) | Pure REDscript; TweakXL supplies the action records; no CET, Mod Settings, localization, or config surface |
| `r6/scripts/LoadBegone/` | Fixed launch/continue/load flow and Dogtown checkpoint profile (2 files) | Requires the bundled `red4ext/plugins/LoadBegone/LoadBegone.dll`; no CET or Mod Settings |
| `red4ext/plugins/FXBegone/` | Fixed all-effects profile and player VFX suppression companion | Requires `FXBegoneNative.dll`; defaults preserve the upstream all-enabled profile; no CET or Mod Settings |

## Tweak and asset inputs

- `r6/tweaks/Attachments Crafting System.yaml`
- `r6/tweaks/CustomRedscriptSuite/AmmoCapacity10X.yaml`
- `r6/tweaks/SlotsSlotsSlots/00_Core_Slots.yaml`
- `r6/tweaks/SlotsSlotsSlots/10_Weapons_Iconic_Blueprints.yaml`
- `archive/pc/mod/` contains only selected shipped assets such as Nova LUT, distant shadows, dismemberment, and The Nullifier resources.
- `red4ext/plugins/ArchiveXL/Bundle/` contains the ArchiveXL resource bundle used by this profile.
- `OPTION_E_REFACTOR_PLAN.md` is the tracked implementation/acceptance plan for the full refactor; it is not a package or install manifest.
- `MUCH_BETTER_AI_WEATHER_ADVERSARIAL_REVIEW.md` records the CET/settings removal, static TweakXL rewiring, weather-archive review, safety findings, and runtime validation gates for the two newly imported mods.
- `FX_LOAD_BEGONE_REVIEW.md` records the fixed-profile conversion and compile-path integration for the FX Begone and Load Begone imports.
- RedFunctions was removed after its native plugin reported current-build incompatibility; no DLL, name table, REDscript stubs, storage card, or plugin directory remains.
- `r6/scripts/MuchBetterAI/` and `r6/tweaks/MuchBetterAI/` are the reviewed fixed profile. The `static-integration.yaml` file is the TweakXL replacement for the upstream CET onInit array/flat mutations; it is intentionally not a settings file.
- `archive/pc/mod/weather_probability_rebalance.archive` is the extracted Weather Probability Rebalance 2.10 payload. No downloaded archive is retained.
- `archive/pc/mod/LoadBegone.archive`, `red4ext/plugins/LoadBegone/`, and `red4ext/plugins/FXBegone/` are the extracted fixed profiles for the two 26 October 2026 imports. No downloaded archive is retained.

When importing a mod, download it, extract it to a temporary directory, inspect its source/license and dependency declarations, copy the needed source/runtime files into the appropriate directory, and delete the downloaded archive. Never vendor a ZIP/7z/RAR merely for provenance.

## Build and test

### Normal sync and compile

```bash
./sync_and_compile.sh
```

`sync_and_compile.sh` copies `r6/scripts`, `r6/tweaks`, `red4ext/plugins`, and selected `archive/pc/mod` content to the game, discovers framework script paths, and runs `engine/tools/scc.exe`. It prints `r6/logs/redscript_rCURRENT.log`; a successful run must contain `Compilation complete` and an output path ending in `final.redscripts.modded`.

### Guarded runtime smoke test

```bash
./launch-cyberpunk2077-proton-experimental.sh status
./launch-cyberpunk2077-proton-experimental.sh dry-run
./launch-cyberpunk2077-proton-experimental.sh launch
```

The helper intentionally refuses the currently installed unvalidated build;
do not bypass that guard.

### Native plugin build

```bash
RED4EXT_SDK_INCLUDE=/path/to/RED4ext.SDK/include \
  ./native_plugins/UniversalAimFlashlight/build.sh
./sync_and_compile.sh
```

The build script expects the local `xwin` CRT/SDK headers and `clang++`/`lld-link`. Do not replace a failed native build with a pre-existing binary without first fixing the source or toolchain error.

### Focused validation

```bash
git diff --check
bash -n sync_and_compile.sh native_plugins/UniversalAimFlashlight/build.sh
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
find "$GAME/red4ext/logs" -type f -name 'red4ext-*.log' -size +0c -printf '%T@ %p\n' | sort -n | tail -1
cat "$GAME/r6/logs/redscript_rCURRENT.log"
```

Use current RED4ext/redscript logs for runtime claims. A compile-only result is not a gameplay validation; test the changed hook, UI path, save/load behavior, and performance as appropriate. Keep changes small, use Git branches/worktrees for experiments, and commit focused fixes with clear messages.
