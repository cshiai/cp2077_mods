# Active Redscript Mods

Personal, source-first Cyberpunk 2077 mod collection. The repository is intentionally maintained as ordinary Git-managed code: edit, compile, play-test, and commit. Git history and the user's cloud download history are the rollback paths; downloaded installer archives, checksum ledgers, manifests, and duplicate backup trees are not part of this project.

## Current profile

- **Game target:** Cyberpunk 2077 2.5 on Steam/Proton (validate against the installed build before enabling a new native plugin).
- **Source:** 150 `r6/scripts` `.reds` files plus bundled plugin-script APIs, 53 active TweakXL YAML/YML inputs, selected ArchiveXL resources, and the custom/third-party RED4ext plugins. RedFunctions is retired and removed.
- **Enemy-health tuning:** `EnemyHealthScalingByLevel` uses a quintic smootherstep from 2.5× at level 10 to a hard 6× cap at level 60+, with 0.1% max-health regeneration per second for eligible non-Johnny enemies.
- **Cazanu combat scope:** living limb survival is one fit for all non-mechanical human enemies, from Trash/Weak/Normal through Officer, Rare, Elite, Boss, and MaxTac; it uses a centralized 5% maximum-health floor and never suppresses natural DOTs. Blood/obstacle sampling is bounded for lower event and raycast cost.
- **Enemy duplication:** hostile combat enemies only, with Elite/Rare included and a hard 24-clone cap; neutral NPCs are never cloned. Dead/defeated/unconscious clones are rejected and removed on the bounded sweep so corpse markers and duplicate clone loot cannot persist.
- **Diagnostics:** Gameplay diagnostics/telemetry are disabled: Cazanu snapshots and writes are hard-off, EnemyMultiplier logging is a no-op, the Much Better AI logger is error-only, and acoustic tracing is false. Re-enable only through a focused, approved source edit.
- **Movement:** `FastWalkNoRestrictions150` now applies an idempotent 2.5× player `MaxSpeed` modifier, bringing sprint toward the engine's ~15 m/s on-foot ceiling (vehicle-like travel), and performs one delayed post-attach reapply to survive save-load/equipment stat refreshes; it does not poll every frame.
- **Runtime layout:** copy this tree into the game root with `sync_and_compile.sh`; the script then invokes the game's `scc.exe` and prints the current redscript log.
- **Guarded runtime entry:** `./launch-cyberpunk2077-proton-experimental.sh status|dry-run|launch` uses Proton `runinprefix`, preserves the NVIDIA environment, and refuses Steam builds other than the current validated baseline `26161058`.
- **CET policy:** Cyber Engine Tweaks is deliberately **not installed or supported**. No CET Lua, ASI, console, or CET-required mod may be added.
- **Much Better AI profile:** the imported 2.3 enemy-AI source is now a fixed REDscript/TweakXL profile. Its CET Lua bootstrap, Native Settings UI, JSON settings store, localization packages, runtime config class, and user-facing tuning parameters are intentionally absent. Gameplay constants are reviewed source values; change them in Git rather than through a runtime menu.
- **Weather profile:** `archive/pc/mod/weather_probability_rebalance.archive` is an archive-only weather-probability resource. It has no scripts, settings, CET, or native plugin and is loaded through the ordinary mod archive path.
- **FX/Load profiles:** FX Begone 2.2.1 and the currently installed Load Begone 3.1.1 plugin are installed as fixed profiles. Their Mod Settings annotations/listeners and any CET dependency were removed; native RED4ext plugins and REDscript companions remain together. Load Begone adds recap-screen/voice-language callbacks, start-screen busy detection, recap replay support, and blackout overlays while retaining the source-controlled defaults.
- **Blur/ReFRACT profiles:** Blur Begone 2.6.0 remains active as a fixed source profile. ReFRACT 1.5.0 is retained but REDscript-gated off on the current Proton/MSVCP runtime after two native D3D12 `_Mtx_lock` access violations; its native DLL is not hand-edited and can be re-enabled only with a rebuilt/validated companion.
- **Black Chrome profile:** Black Chrome 1.1.5 is installed as a fixed ArchiveXL/TweakXL + pure REDscript profile. Its CET reward bootstrap and optional Alternative Berserk bridge were removed; defensive null/lifecycle guards were added to the effectors and cyberdeck/PoolSystem hooks. The 19-vendor payload uses explicit `VendorItem` entries so the 627 cyberware additions survive current TweakXL parsing and vendor stock generation.
- **Cyberware descriptions:** `CustomRedscriptSuite/CyberwareFlavorDescriptions.reds` restores the post-2.0 cyberware flavour-text panel by removing only the vanilla cyberware hide predicate. `CyberwareEx` repairs persistent ripperdoc stock/materialized inventory during vendor preparation and after each purchase, so deterministic cyberware can be bought and equipped repeatedly in one visit; its slot-index and GLP paths preserve duplicate copies instead of evicting the matching `cyberwareType`, and it keeps an equipped cyberdeck in the three-slot cyberware strip. `UniversalSlotsAndAttachments` now preserves the vanilla `OnEquip`/`OnAttach` gameplay-package entries that supply function text; crafting/upgrade/consumable/material hide rules remain intact. Its former duplicate-quickhack/extra-cyberdeck-slot feature was removed; deck program installation and duplicate filtering now use vanilla paths.
- **Living Night City encounter profile:** `NightCityTrafficOverhaul` is a fixed, source-controlled fork of NCTO 2.50 with Mod Settings/listeners removed; Factions Evolved 2.50 data is layered through TweakXL. Runtime TweakXL evidence showed 413 vehicle bases absent from the current installation and 503 inactive Reinforcements references, so those optional records were pruned from the active profile rather than left as errors. `StreetActivity` adds a narrow NCA reaction bridge, quiet gang-versus-gang seeds, EMRS-shared encounter cloning, and refactored PCF retreat/cleanup. It has no CET/Lua/Mod Settings/RedFunctions dependency.
- **SimpleDroneCompanion:** the fixed profile now summons six session-bound Militech combat drones (two Minotaurs, two Octants, and two Phantom Liberty Cerberus units) owned by Codeware's `DynamicEntitySystem`. Fixed F9 or `Left Shoulder + X` input toggles all six; marker-gated combat hooks preserve vanilla damage/health, block drone-to-V/drone-to-drone damage, route drone kills to V, and inject bounded follower threats. Companion detections are fed directly into the target tracker so quest-oriented Cerberus reaction presets cannot remain passive after spawn. TweakXL supplies static Minotaur/Octant/Cerberus subcharacter fallbacks and private Minotaur weapon records with `+0.40 TriggerDismembermentChance`, `+1.50 HitDismembermentFactor`, and `+1.50 HitWoundsFactor`; Cerberus inherits the `Immortal` mechanical safety tag and its base weapon. Enemy-health scaling, EMRS cloning, Cazanu limb survival, Apex damage/poise, and Much Better AI eligibility all explicitly exclude the companion marker. A persistent HUD panel renders six live health bars with HP percentages; no CET, Lua, Mod Settings, localization, persistence, item, or vendor layer is installed.
  The public `SDC_TryCustomFollowFallback()` seam is deliberately tiny and only runs when a vanilla follow command is rejected outside combat; it is the future extension point for a reviewed custom AI action without adding a settings surface.
- **Immersive Night City Fixes:** the two 27–28 October 2026 packages are merged as one fixed 2.5 profile. `#INCF-CORE.archive` plus `INCF.archive`/`INCF.xl` provide the world and streaming-sector corrections; `r6/scripts/INCF-CORE/` supplies bounded resource/entity callbacks and the missing-core/welcome guard. The upstream Mod Settings particle toggle and dependency/localization popup were removed: magazine debris suppression is a reviewed source constant, callbacks are idempotent and detached on service teardown, and popup retries are generation-bound and capped. No CET/Lua, Native Settings, runtime JSON, TweakDB records, or native DLL is included.

## Frameworks and dependencies

Versions below describe the APIs currently present or required by this tree; they are not a downloaded-package inventory. Follow each upstream repository's release notes for game-build compatibility.

| Component | Role in this tree | Version/API note | Upstream |
|---|---|---|---|
| **redscript** | Compiles all `.reds` sources into `final.redscripts.modded`. | 0.5.32 target | [jac3km4/redscript](https://github.com/jac3km4/redscript) |
| **RED4ext** | Native loader and script-extension host. | 1.31.x target for the current 2.5 profile | [WopsS/RED4ext](https://github.com/WopsS/RED4ext) |
| **RED4ext.SDK** | Build-only C++ headers/types for `UniversalAimFlashlight`. | Match the RED4ext/game build; not a runtime plugin by itself | [WopsS/RED4ext.SDK](https://github.com/WopsS/RED4ext.SDK) |
| **ArchiveXL** | Loads the bundled `.archive`/`.xl` resources and exposes ArchiveXL REDscript APIs. | Bundled API headers identify 1.28.1 | [psiberx/cp2077-archive-xl](https://github.com/psiberx/cp2077-archive-xl) |
| **TweakXL** | Applies the 53 active `r6/tweaks/**/*.yaml`/`.yml` files and supplies TweakDB APIs. | `CyberwareEx` and `SimpleDroneCompanion` require 1.12.0 or newer | [psiberx/cp2077-tweak-xl](https://github.com/psiberx/cp2077-tweak-xl) |
| **Codeware** | Shared native/script library for UI, localization, dynamic entities, and CyberwareEx. | **1.21.1 current**; `CyberwareEx` and `EnemyMultiplierRedscript` require 1.21.0 or newer | [psiberx/cp2077-codeware](https://github.com/psiberx/cp2077-codeware) |
| **Audioware** | Native audio-event player used by the Darth Vader lightsaber profile. | **1.10.1**; required for the bundled SWBF2 event bank | [psiberx/cp2077-audioware](https://github.com/psiberx/cp2077-audioware) |
| **Mod Settings** *(optional, not installed)* | Would read the remaining `@runtimeProperty("ModSettings.*")` annotations in SlotsSlotsSlots, QuestGuide, and The Nullifier. The fixed Blur Begone/ReFRACT profiles no longer expose this surface. | Not present in this repository or current game installation; never treat it as a hard requirement | [Cyberpunk2077-Mods/ModSettings](https://github.com/Cyberpunk2077-Mods/ModSettings) |
| **Blur Begone** *(bundled visual plugin)* | Fixed visual/native component under `red4ext/plugins/BlurBegone`; its reviewed REDscript constants are applied without Mod Settings. | 2.6.0 package; upstream distribution is [Nexus Mods 8105](https://www.nexusmods.com/cyberpunk2077/mods/8105) | No maintained public GitHub source identified |
| **ReFRACT** *(bundled visual plugin)* | Fixed renderer/refraction companion under `red4ext/plugins/ReFRACT`; shares glass hooks with Blur Begone and tracks vehicle/reflection state without CET or runtime settings. | 1.5.0 package; upstream distribution is [Nexus Mods 34858](https://www.nexusmods.com/cyberpunk2077/mods/34858) | No maintained public GitHub source identified |

The custom plugin is built from `native_plugins/UniversalAimFlashlight/Main.cpp` and registers one RED4ext native function used by `r6/scripts/CustomRedscriptSuite/UniversalAimFlashlight.reds`. Its own plugin version is `1.2.0`: balanced range/intensity, one raster-shadowed main beam, and ray-tracing contribution disabled. Rebuild it whenever the C++ source or SDK-facing types change.

## Source map

### `r6/scripts/CustomRedscriptSuite/` (21 modules)

Gameplay tuning and pure-redscript features: no CET dependency.

- **Progression/player:** No Attribute Restriction, `ThreeModProfile` carry capacity, `PassiveHealthRegen25`, `MaxHealthStamina100`, `LevelCap300XP300` (level/Street Cred/attribute cap 300, with targeted level-gated loot/vendor/recipe prerequisites raised to 300), `FastWalkNoRestrictions150`, `CyberNinjaParkour`.
- **Equipment/crafting:** `BypassEquipmentAttachmentRestrictions`, `UniversalSlotsAndAttachments`, `UniversalIconicWeapons`, `ZeroCostCraftingUpgrade`, `InstantUpgradeNoConfirm`, `WeaponMagazineAndAmmo5X`. Iconic weapon sales are instant; one upgrade click uses one vanilla transaction plus an ownership-aware saved-stat delta to reach Tier 5++; V's crafted-weapon package (including deterministic dismemberment and full armor penetration) applies only to ranged weapons (guns), while crafted melee weapons remain free of that gun package. Darth Vader's saber is a true IconicItem with an exclusive 100% dismemberment/wound signature plus simultaneous Burn, Shock, and Bleed; a qualifying hit severs the exact struck limb in one hit only when its limb hit-place is struck (torso/head/already-missing-limb hits never auto-cycle to another limb), and repaired Iconic upgrade curves apply to existing saves. Weapon mods and scopes/muzzles are recovered from the full player-part inventory, cross-family placement remains universal, and duplicate stack IDs do not get hidden just because one copy is already equipped. Quickhack program parts bypass only the vanilla tier gate, install into vanilla cyberdeck slots 1–8, and retain vanilla `shardType`/`HasThisShardInstalled` deduplication. Slot-family predicates use zero-allocation switches, including optional SlotsSlotsSlots extension IDs, instead of rebuilding 42/15/5-element arrays on every placement query.
- **Combat/AI:** `EnemyHealthScalingByLevel`, `EnemyMultiplierRedscript` (Codeware dynamic entities), `ApexEnemiesCombatOverhaul`, `LethalEnemyNetrunners`.
- **UI/flow/utility:** `InstantBreachAutoSolver`, `InstantUISuite`, and `UniversalAimFlashlight` (the native-plugin companion). The Nexus AutoContinue package and obsolete startup-only helper were removed.
- **Cyberware UI:** `CyberwareFlavorDescriptions` restores descriptions hidden by the 2.0 tooltip rule without CET.

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
| `r6/scripts/NightCityTrafficOverhaul/` | Fixed NCTO 2.50 traffic registry, 2.5 district DB, faction fleets, passenger pools, and vehicle-light hooks | Pure REDscript; Mod Settings/listeners removed; TweakXL/ArchiveXL supply traffic records/resources |
| `r6/scripts/StreetActivity/` | Quiet gang-seed scheduler, safe NCA reaction bridge, EMRS encounter-clone seam, and refactored post-combat retreat | Codeware DynamicEntitySystem through EMRS; no CET, Lua, RedFunctions, runtime settings, or diagnostics |
| `r6/scripts/SimpleDroneCompanion/` | Six fixed companions (two Minotaurs, two Octants, two Cerberus), dynamic-entity ownership, follower role, event-driven threat handoff, friendly-fire guard, V kill credit, and a persistent live-health HUD | Codeware DynamicEntitySystem; TweakXL static records; no CET, Lua, settings, persistence, or localization |
| `r6/scripts/LoadBegone/` | Fixed launch/continue/load flow and Dogtown checkpoint profile (2 files) | Requires the bundled `red4ext/plugins/LoadBegone/LoadBegone.dll`; no CET or Mod Settings |
| `red4ext/plugins/FXBegone/` | Fixed all-effects profile and player VFX suppression companion | Requires `FXBegoneNative.dll`; defaults preserve the upstream all-enabled profile; no CET or Mod Settings |
| `r6/scripts/BlackChrome/` | Black Chrome cyberware effectors, reward multiplier, aux-cyberdeck support, and bounded resource pool maintenance (10 files) | ArchiveXL `.xl` + TweakXL records; no CET; optional external bridges removed |
| `r6/scripts/Saber_DarthVader/` | Darth Vader lightsaber weapon state, staged blade visuals, Audioware SWBF2 audio, bullet deflection, deterministic one-hit dismemberment of the exact limb hit-place struck (four distinct limb hits for all four limbs; torso/head/already-missing-limb hits do not auto-cycle) + Burn/Shock/Bleed signature, maximum practical attack speed, zero melee stamina cost, Iconic upgrade support, vendor/crafting recipe, and idempotent recipe unlock | TweakXL + ArchiveXL + Codeware localization + Audioware 1.10.1; no CET/Lua |
| `r6/scripts/ImmersiveFirstPerson/` | Pure-REDscript IFP 2.2.0 camera compositor, native camera curve, body correction, bounded FreeLook cone, cached eligibility blackboard, and TickOnEvent lifecycle | Vanilla REDscript camera/input APIs; no CET/Lua/native plugin |
| `r6/scripts/INCF-CORE/` | Immersive Night City Fixes core marker, fixed magazine-debris suppression, sector/resource corrections, entity seam repair, and capped missing-core/welcome popup | Codeware 1.21.1+ and ArchiveXL 1.28.1+; no CET/Lua/Mod Settings/native plugin |

## Tweak and asset inputs

- `r6/tweaks/Attachments Crafting System.yaml`
- `r6/tweaks/CustomRedscriptSuite/AmmoCapacity10X.yaml`
- `r6/tweaks/SlotsSlotsSlots/00_Core_Slots.yaml`
- `r6/tweaks/SlotsSlotsSlots/10_Weapons_Iconic_Blueprints.yaml`
- `r6/tweaks/NightCityTrafficOverhaul/` contains the fixed NCTO 2.50 faction, passenger, utility, and traffic records.
- `r6/tweaks/zz_FactionsEvolved/` contains the selected Factions Evolved 2.50 NCPD, utility, and modded-vehicle records after removing records whose external bases are absent from this installation. The source lists can be re-expanded through Git when the corresponding vehicle mods are installed.
- `r6/tweaks/SimpleDroneCompanion.yaml` contains six companion subcharacter records (Minotaur, Octant, and Cerberus pairs), one Minotaur NPC equipment group, and the mandatory fixed dismemberment weapon-stat package. It is not an item/economy or configuration file.
- `archive/pc/mod/#INCF-CORE.archive`, `archive/pc/mod/INCF.archive`, and `archive/pc/mod/INCF.xl` are the selected Immersive Night City Fixes 1.5/0.36 world corrections. `INCF.xl` contains 201 streaming blocks, 1,944 active sector patches, and one device-resource patch; all 4,976 active node edits were range-checked against their declared `expectedNodes` values. Four crate deletions duplicated by `TheNullifier-removals.xl` were intentionally pruned to avoid same-index ArchiveXL conflicts. It defines no TweakDB records, so the installed `tweakdb.bin` and `tweakdb_ep1.bin` have no INCF IDs to resolve.
- Its weapon package uses stable named Minotaur/Base-HMG records rather than generated `inlineN` TweakDB IDs, so a future patch cannot silently renumber the NPC RPG donor.
- The audited optional Reinforcements overlay was deliberately not left active: its runtime payload referenced missing vehicle/character records and produced 503 warnings. Its duplicate Tyger keys and dependency findings are documented in `LIVING_NIGHT_CITY_ENCOUNTER_PLAN.md`; `StreetActivity` supplies the fixed no-settings gang seed/escalation path.
- `archive/pc/mod/` contains only selected shipped assets such as Nova LUT, distant shadows, dismemberment, and The Nullifier resources.
- `red4ext/plugins/ArchiveXL/Bundle/` contains the ArchiveXL resource bundle used by this profile.
- `OPTION_E_REFACTOR_PLAN.md` is the tracked implementation/acceptance plan for the full refactor; it is not a package or install manifest.
- `MUCH_BETTER_AI_WEATHER_ADVERSARIAL_REVIEW.md` records the CET/settings removal, static TweakXL rewiring, weather-archive review, safety findings, and runtime validation gates for the two newly imported mods.
- `FX_LOAD_BEGONE_REVIEW.md` records the fixed-profile conversion and compile-path integration for the FX Begone and Load Begone imports.
- `BLACK_CHROME_REVIEW.md` records the CET removal, dependency trimming, effect-component safety fixes, and PoolSystem lifecycle/performance refactor for Black Chrome.
- `RUNTIME_MOD_LOG_REVIEW.md` records the newest RED4ext/redscript evidence, the stale RedFunctions failure, diagnostics state, and focused Cazanu/clone runtime gates.
- The current profile also removes two stale 2.5 integration failures: ambiguous melee-selector TweakXL edits and The Nullifier's obsolete proxy-mesh node deletion.
- RedFunctions was removed after its native plugin reported current-build incompatibility; no DLL, name table, REDscript stubs, storage card, or plugin directory remains.
- `r6/scripts/MuchBetterAI/` and `r6/tweaks/MuchBetterAI/` are the reviewed fixed profile. The `static-integration.yaml` file is the TweakXL replacement for the upstream CET onInit array/flat mutations; it is intentionally not a settings file.
- `archive/pc/mod/weather_probability_rebalance.archive` is the extracted Weather Probability Rebalance 2.10 payload. No downloaded archive is retained.
- `archive/pc/mod/LoadBegone.archive`, `red4ext/plugins/LoadBegone/`, and `red4ext/plugins/FXBegone/` are the extracted fixed profiles for the two 26 October 2026 imports. No downloaded archive is retained.
- `archive/pc/mod/BlackChrome.archive` and `.archive.xl`, `r6/scripts/BlackChrome/`, and `r6/tweaks/BlackChrome/` are the extracted Black Chrome 1.1.5 payload. The upstream CET Lua reward mutator is intentionally not installed.
- `archive/pc/mod/NightCityTrafficOverhaul.archive` is the selected NCTO 2.50 traffic resource. No downloaded archive is retained.
- `r6/scripts/INCF-CORE/` and `r6/config/redsUserHints/INCF.toml` are the reviewed source/compiler hints for Immersive Night City Fixes. The two downloaded installer ZIPs and `/tmp/incf_import_review` are deliberately removed after integration.
- `archive/pc/mod/Saber_DarthVader.archive` and `.archive.xl` provide the lightsaber mesh, hilt, textures, and ArchiveXL factory; `r6/tweaks/Saber_DarthVader/saber_darthvader.yaml` adds the Iconic weapon, Little China stock, and 10 Legendary + 10 Epic component recipe.
- `r6/audioware/Saber_DarthVader/` contains the Audioware event map and 46 SWBF2 `.wav` assets used by `Saber_DarthVader`; the vanilla katana bank is suppressed with `audioWeaponConfiguration: saber_silent`.
- The three newly audited companion reference archives remain outside this repository and uninstalled until the SimpleDroneCompanion plan is complete, per the current user instruction; they must never be copied into Git or the game tree. Once the plan is closed, delete those downloaded archives and temporary extraction data rather than tracking them.

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

The current build `26161058` has clean RED4ext startup, all nine expected
profile plugins, and successful `scc` invocation in the latest available startup log;
the helper still refuses any different build. The latest source-only pass was
compile-validated without launching the game.

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

For the later user-requested companion smoke test, press **F9** (or **Left
Shoulder + X** on a controller) once to summon the six session-bound combat
drones (two Minotaurs, two Octants, and two Cerberus units) and again to dismiss them. This source-only pass intentionally did not launch
the game; do not treat the clean compile as proof that AI navigation or weapon
behavior has been visually verified.
