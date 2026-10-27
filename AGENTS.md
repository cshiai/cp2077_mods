# AGENTS.md — active Cyberpunk 2077 mod source tree

This repository is the source-of-truth for the user's self-tuned Cyberpunk 2077 mods. These rules are durable session memory for every agent working in this repository. **Git is the only history, rollback, and change-audit mechanism.** The user keeps prior source and download history in the cloud; do not recreate that bookkeeping locally.

## 1. Permanent workflow policy (do not regress this)

The old archive/catalog/checksum workflow is retired. Agents must **not**:

- run `sha256sum`, `md5sum`, or any checksum comparison;
- create, update, or consult `SHA256SUMS`, `*.sha256`, hash manifests, file inventories, install manifests, archive catalogs, or similar integrity ledgers;
- make timestamped copies, quarantine trees, freeze directories, vanilla backups, diagnostic backups, or other duplicate source trees before editing;
- add a “safety backup” step to scripts or instructions, or ask the user to provide one for ordinary code work;
- retain, index, hard-link, or track downloaded mod ZIP/7z/RAR files or installer archives;
- spend effort proving that a copied file is byte-identical when `git diff`, `git status`, and the compiler are sufficient.

For rollback or comparison use `git status`, `git diff`, `git log`, branches/worktrees, `git show`, and `git restore`/`git revert`. Do not copy the working tree to simulate a branch. If a package is needed again, use the user's download history, extract it to a temporary location, copy only the required source/runtime payload into this repository, then delete the downloaded archive and temporary extraction directory. Do not confuse a shipped game asset (`.archive`, `.xl`, or a required DLL) with the downloaded archive that delivered it: keep only assets required by the current source tree.

Do not add new manifest/catalog/diagnostic files to “document” this policy. Existing historical reports may mention the retired workflow; they are background notes, not procedures. This file supersedes them.

## 2. What belongs in this repository

Track source and intentionally shipped runtime payloads only:

- `r6/scripts/` — 125 REDscript sources grouped by mod;
- `r6/tweaks/` — the 52 active TweakXL YAML/YML inputs;
- `r6/storages/` — intentionally shipped documentation/config payloads when a current mod requires them;
- `red4ext/plugins/` — bundled framework/plugin runtime files and their REDscript APIs;
- `native_plugins/UniversalAimFlashlight/` — C++ source, build script, and the built plugin used by this profile;
- `archive/pc/mod/` — intentionally selected game assets (`.archive`/`.xl`), not download archives;
- `r6/scripts/SimpleDroneCompanion/` and `r6/tweaks/SimpleDroneCompanion.yaml` — the selected four-session-bound-drone companion profile (two Minotaurs plus two Octants); no CET/Lua/Mod Settings/localization/economy layer;
- `sync_and_compile.sh`, `README.md`, and design notes.
- `launch-cyberpunk2077-proton-experimental.sh` — guarded Proton runtime entry; it must refuse unvalidated Steam builds.

Do not commit game-generated caches, logs, Proton prefixes, save data, or compiler output unless a source change explicitly requires a reproducible fixture. Keep user saves untouched.

## 3. Current runtime/dependency policy

The profile targets Cyberpunk 2077 2.5 on Steam/Proton and is source-first. The active framework chain is **redscript → RED4ext → (as used) ArchiveXL, TweakXL, and Codeware**. Exact versions and upstream links are maintained in `README.md`; update that table when a dependency changes.

- **Cyber Engine Tweaks (CET) remains prohibited.** Do not install it, add CET Lua/ASI hooks, invoke its console, or introduce a mod that requires CET. Existing `ModSettings` annotations are optional REDscript integration and are not permission to add CET.
- **Mod Settings is currently absent** from both this repository and the game installation. Treat all `ModSettings` annotations and guarded listeners as inactive unless the user explicitly installs and requests it; do not turn it into a hard dependency.
- Keep the custom `UniversalAimFlashlight` RED4ext plugin and its REDscript companion coherent. Rebuild the DLL when `Main.cpp` or SDK-facing types change; do not hand-edit a generated binary.
- RedFunctions is retired from this profile because its native plugin is incompatible with the current game build. Do not restore its DLL, name table, REDscript stubs, or configuration-framework documentation unless it receives a verified current-build release and an explicit reintroduction decision.
- The imported Much Better AI profile is deliberately fixed and source-controlled: do not restore its upstream CET Lua bootstrap, Native Settings UI, JSON settings store, localization packages, runtime config class, or runtime parameter overrides. Its gameplay records belong in `r6/tweaks/MuchBetterAI/` and its constants belong in the REDscript source; tune them through Git only.
- `SimpleDroneCompanion` is currently source/compile validated only. Do not launch the game or claim follower, combat, save/load, or performance success until the user explicitly requests its focused smoke test; keep its vanilla-record seam, fixed fallback interfaces, and four-slot lifecycle source-controlled.
- The former duplicate-quickhack/extra-cyberdeck-slot feature in `UniversalSlotsAndAttachments` and `SlotsSlotsSlots` is retired. Do not restore duplicate quickhack filters, cyberdeck program slots 9–16, or the monowire quickhack-slot bypass; vanilla quickhack inventory, deduplication, and installation paths are authoritative.
- The Weather Probability Rebalance payload is archive-only (`archive/pc/mod/weather_probability_rebalance.archive`). Do not invent a settings/CET layer for it.
- FX Begone and Load Begone are fixed source profiles: their upstream Mod Settings annotations/listeners were removed, no CET payload is installed, and their RED4ext native companions remain mandatory for the functionality they expose. Do not restore user.ini/Mod Settings overrides; change the fixed defaults in Git.
- Blur Begone 2.6.0 and ReFRACT 1.5.0 are fixed source profiles: their upstream Mod Settings menus, hotkeys, and runtime tuning wrappers were removed. Keep the paired native DLLs and REDscript APIs together, apply reviewed constants from source, and do not restore Mod Settings/CET configuration layers.
- Black Chrome is a fixed ArchiveXL/TweakXL profile: its CET reward bootstrap and optional Alternative Berserk bridge are retired, and its native/effector code must remain guarded and lifecycle-safe.
- Night City Traffic Overhaul is a fixed source-controlled 2.50 fork: Mod Settings/listeners and RedLogger diagnostics are removed. Factions Evolved's 2.50 traffic/faction data is source-controlled under `r6/tweaks/zz_FactionsEvolved/`, but records whose external vehicle bases are absent from the current installation must stay pruned from the active TweakXL payload. The audited Reinforcements overlay remains quarantined/inactive because its vehicle/character references produced current-build TweakXL warnings; do not restore it until its dependencies are installed and revalidated. `StreetActivity` owns the narrow reaction bridge, quiet gang-seed scheduler, EMRS-shared encounter cloning, and PCF retreat integration.
- `CyberwareEx`, `QuestGuide`, `EnemyMultiplierRedscript`, and `SimpleDroneCompanion` use Codeware APIs. `CyberwareEx` also checks TweakXL; `SimpleDroneCompanion` uses Codeware's DynamicEntitySystem and its static weapon/subcharacter records require TweakXL. Tweak YAMLs require TweakXL; ArchiveXL supplies the bundled `.xl` resources and Mod Settings integration where present.
- Do not silently replace a framework with a similarly named fork. Confirm API compatibility in source and compile output first.
- Steam may update normally. Keep the existing build guard and NVIDIA/Proton launch policy; never bypass a guard or claim runtime compatibility solely from a successful local edit. Build `26161058` is the current reassessed baseline: the latest runtime log shows seven plugins loaded, RED4ext started, and `scc` invoked successfully. A future changed build requires a focused compile and runtime smoke test before enabling more code.

The launch environment must continue selecting the RTX 5060 rather than the AMD iGPU:

```text
__NV_PRIME_RENDER_OFFLOAD=1
__VK_LAYER_NV_optimus=NVIDIA_only
__GLX_VENDOR_LIBRARY_NAME=nvidia
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
DXVK_FILTER_DEVICE_NAME=NVIDIA GeForce RTX 5060 Laptop GPU
VKD3D_FILTER_DEVICE_NAME=NVIDIA GeForce RTX 5060 Laptop GPU
```

Steam shader caching stays enabled. Do not casually delete engine, D3D11/D3D12, or VKD3D shader caches; judge stutter only after one normal run has reached the menu/scene and exited normally.

The game path and environment used by the sync script are:

```text
Game:     $HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077
Proton:   $HOME/.local/share/Steam/steamapps/common/Proton - Experimental
Prefix:   $HOME/.local/share/Steam/steamapps/compatdata/1091500
```

Use the real `Cyberpunk2077.exe` through Proton `runinprefix` for deterministic RED4ext loading. Do not switch to `proton run` or `REDprelauncher.exe`. Do not require Steam to be closed, disable auto-updates, or use an update lock unless the user explicitly asks. Preserve the established NVIDIA-only Vulkan variables and shader-cache policy.

## 4. Development loop (code first, small and reversible through Git)

1. Read this file and `README.md`; inspect `git status --short`, the relevant source, and recent `git log`.
2. State the behavior being changed and the smallest files that should change. Prefer one feature/fix per commit.
3. Edit `.reds`, `.yaml`, C++, or shell source directly. Keep namespaces, module guards, and dependency boundaries explicit. Avoid broad search/replace across unrelated mods.
4. Run static checks immediately:

   ```bash
   git diff --check
   bash -n sync_and_compile.sh native_plugins/UniversalAimFlashlight/build.sh
   ```

5. Compile the profile with:

   ```bash
   ./sync_and_compile.sh
   ```

   The script refreshes the game-side source tree, discovers installed framework script paths, and invokes the game's `scc.exe`. It prints `r6/logs/redscript_rCURRENT.log`; treat compiler errors as failures, not warnings. For native changes, set `RED4EXT_SDK_INCLUDE` if needed and run `native_plugins/UniversalAimFlashlight/build.sh` before syncing.

6. Inspect the focused diff and compiler log. If a runtime test is appropriate, launch through the approved Proton path, reach the menu/target scene, exit normally, and inspect the newest RED4ext log plus `redscript_rCURRENT.log`. Test one changed subsystem at a time.
7. Commit the source change with a concise message. Use Git branches/worktrees for experiments; do not create filesystem backups. Record unresolved behavior in the commit message or a short source comment, not a new inventory ledger.

## 5. Debugging and validation rules

Authoritative runtime indicators are current logs, not old reports:

```bash
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
find "$GAME/red4ext/logs" -type f -name 'red4ext-*.log' -size +0c -printf '%T@ %p\n' | sort -n | tail -1
cat "$GAME/r6/logs/redscript_rCURRENT.log"
grep -E 'plugin\(s\) loaded|RED4ext has been started|scc invoked successfully' "$GAME"/red4ext/logs/red4ext-*.log | tail
grep -E 'Compilation complete|Output successfully|REDScript compilation has failed' "$GAME/r6/logs/redscript_rCURRENT.log" | tail
```

Healthy evidence normally includes RED4ext initialization/startup, expected plugin count, successful `scc` invocation, `Compilation complete`, and an output path ending in `final.redscripts.modded`, with no compilation-failed line. A clean compile is not proof of gameplay correctness: test hooks, save/load, UI, and performance behavior relevant to the change.

Do not delete saves, perform a clean reinstall, run game-file verification, or remove generated caches without explicit user approval. First identify whether a warning is stale output, a missing dependency, a source error, or a real current runtime failure; use Git to isolate the code change. Never “fix” a warning by deleting an unrelated mod.

## 6. Mod-specific engineering guidance

- Prefer vanilla REDscript hooks and bounded work over per-frame global scans. Guard every optional framework call with `ModuleExists`/version checks where the source already supports optional operation.
- For TweakXL, keep YAML edits narrowly scoped and preserve record inheritance/append semantics. For ArchiveXL resources, keep paths and names stable; for Codeware UI/localization, follow its public APIs rather than raw offsets.
- For RED4ext C++, validate lifecycle ownership, RTTI registration, unload behavior, and game-build address compatibility. Keep logging useful but bounded.
- Keep gameplay tuning constants near the module that owns them and document the intended effect. Avoid hidden coupling between `CustomRedscriptSuite`, `CazanuLimbSurvival`, `SlotsSlotsSlots`, `CyberwareEx`, and `QuestGuide`.
- Do not add CET, Mod Settings hard requirements, or new native dependencies to a pure-redscript module without an explicit design decision and README update.

## 7. Definition of done

A change is ready when:

- the source diff is focused and `git diff --check` is clean;
- shell syntax checks pass;
- `sync_and_compile.sh` (and the native build when applicable) succeeds, or the remaining failure is explicitly explained;
- current logs support the claimed runtime status, without presenting historical or compile-only evidence as full success;
- `README.md` dependency/module notes are updated when behavior or requirements change;
- no downloaded archive, checksum ledger, backup tree, manifest, or similar bookkeeping was added.
