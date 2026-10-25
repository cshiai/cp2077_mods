# Active Redscript Mods (`active_redscript_mods/`)

This directory is the canonical source tree for the active **22-file Redscript mod suite + 1 custom RED4ext v1.31.0 native plugin (`UniversalAimFlashlight.dll`)** for Cyberpunk 2077 v2.5.

## Design Policy
- **Redscript (`0.5.32`) + RED4ext (`1.31.0`) only**: Zero external third-party TweakXL, ArchiveXL, Codeware, Mod Settings, or CET dependencies.
- **Single flat namespace directory**: All 22 `.reds` files reside in `r6/scripts/CustomRedscriptSuite/` and sync directly into `$GAME/r6/scripts/CustomRedscriptSuite/`.
- **Custom Patch 2.50 Native Plugin**: `native_plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll` is built from `Main.cpp` against the Patch 2.50 `RED4ext.SDK` (`RED4EXT_V1_RUNTIME_VERSION_2_50`) and syncs into `$GAME/red4ext/plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll`.

## Active Modules (22 `.reds` files + 1 `.dll` plugin)

1. **`Over 9000 - No Attribute Restriction.reds`** — Skill checks always require `0` attributes (`Device.GetSkillCheckContainer`, `SkillCheckBase.Evaluate`, `DialogueChoiceHubPrereq.IsFulfilled`).
2. **`ThreeModProfile.reds`** — Infinite carry capacity (`CarryCapacity = 999999.0` on player attach/detach).
3. **`PassiveHealthRegen25.reds`** — 2.5% Max HP/s passive health regeneration in and out of combat (`StatPoolType.Health` custom regen rate).
4. **`MaxHealthStamina100.reds`** — +100% Max Health (`2.0x`) and +100% Max Stamina (`2.0x`) via `ConstantStatModifier` (`Multiplier`).
5. **`FastWalkNoRestrictions150.reds`** — +150% player movement speed (`2.5x` `MaxSpeed`) and removes safe-zone / scene / workspot / call speed restrictions.
6. **`BypassEquipmentAttachmentRestrictions.reds`** — Removes quest/equip locks and cyberware slot restrictions.
7. **`UniversalSlotsAndAttachments.reds`** — Grants all ranged weapons Scope + Muzzle slots and maxes mod slots (`WeaponMod1..4`, `GenericMod1..5` on clothing) via a non-destructive TweakDB flat-buffer clone injector (`CopyU32At` + `SetRecordID`), unlocks in-combat weapon/attachment swapping, makes weapon mods removable, and forces silencers/scopes to fit any ranged weapon with `0%` damage penalty.
8. **`UniversalIconicWeapons.reds`** — Infuses every player-equipped weapon with Iconic rarity (`IsItemIconic` = `true`), `+35%` base damage, `+25%` crit chance, `+50%` crit damage, `+25%` armor penetration, `+20%` fire rate/reload/handling, and archetype-specific elemental & ballistic perks (Ricochet + Shock on Power, instant-charge + 100% wall-pen + EMP on Tech, instant lock + 2x projectile velocity + Chemical on Smart, +40% attack speed + Bleed/Burn + 5% heal-on-hit on Melee/Thrown).
9. **`LevelCap150XP150.reds`** — Uncaps Player Level, Street Cred, and 5 Skill Proficiencies to `150` (`GetProficiencyMaxLevel`), grants `+150%` XP gain (`2.5x`), and awards Attribute + Perk points through level 150.
10. **`ZeroCostCraftingUpgrade.reds`** — Crafting and upgrading cost `0` components (`GetRecipeIngredients` / `GetItemFinalUpgradeCost` cleared), allows infinite item upgrades, and unlocks all recipe quality tiers (`Common` through `Legendary++`).
11. **`InstantUpgradeNoConfirm.reds`** — Removes the hold-to-upgrade delay (`InstantUpgradeNoConfirm.reds`) and auto-confirms upgrade/crafting popups.
12. **`EnemyHealthScalingByLevel.reds`** — Scales all non-friendly NPC Max Health dynamically with player level (`+100%` at L1-20, `+200%` at L21-35, `+300%` at L36-50, `+400%` at L51-80, `+500%` at L81+) and scales enemy armor (`+50%` to `+150%`).
13. **`EnemyMultiplierRedscript.reds`** — Pure-Redscript replication of `EnemyMultiplierRS 1.2.6` (Nexus #35088). Clones eligible hostile NPCs (`multiplier = 2`, `maxClones = 48`, `cloneRange = 60m`, `cloneSpacing = 1.5m` snapped to human navmesh via `NavigationSystem.FindPointInSphereOnlyHumanNavmesh`) using vanilla `PreventionSpawnSystem.RequestUnitSpawn` + `SpawnRequestFinished` callback interception and `EntityGameInterface.Destroy` / `RequestDespawn` without Codeware or ModSettings.
14. **`ApexEnemiesCombatOverhaul.reds`** — Grants enemies `+35%` movement speed, `+25%` fire rate, `+40%` reload speed, `-50%` accuracy scatter, `+100%` dodge/dash reactivity, `2.5x` visual detection speed, and forces immediate full-squad combat alert.
15. **`LethalEnemyNetrunners.reds`** — Pure-Redscript port of Challenging Enemy Netrunners + Enemy Quickhack Fixes: unlocks tiered enemy netrunner quickhacks (Overheat, Short Circuit, Reboot Optics, Cyberware Malfunction, Weapon Glitch, Cripple Movement, Contagion, Synapse Burnout, System Collapse) and fixes vanilla netrunner AI bugs.
16. **`CyberNinjaParkour.reds`** — Unlocks Quadruple Jump (`4` air jumps), `2.2x` Air Dash / Dodge thrust, `35.0 m/s` slide boost, zero fall damage (`HasFallDamage = false`), and mid-air/sprint shooting & reloading.
17. **`InstantBreachAutoSolver.reds`** — Auto-solves Breach Protocol minigames the instant they open, unlocking all Daemons (`MinigameAction.NetworkDataMineLootAllMaster`, etc.) at `100%` completion.
18. **`InstantUISuite.reds`** — Instant 1-ms scanning (`ScannerTime = 0.01`), instant disassembly/drop/vendor transfers, and zero-cooldown vehicle summoning.
19. **`WeaponMagazineAndAmmo5X.reds`** — Multiplies ranged weapon `MagazineCapacity` by `5.0x`, grants `5x` player ammo capacity (`9999` per ammo type), and auto-refills magazine and reserve ammo on equip.
20. **`Nexus34645_Startup.reds`** — Pure-Redscript port of Fast Launch (Skip Intro Videos) (`Nexus #34645`): skips startup logo, breaching, and attract-loop videos directly to the main menu.
21. **`Nexus34645_AutoContinue.reds`** — Pure-Redscript port of Fast Launch (Auto Load Last Save) (`Nexus #34645`): automatically triggers `Continue` once on initial startup into the most recent save.
22. **`UniversalAimFlashlight.reds` + `native_plugins/UniversalAimFlashlight/UniversalAimFlashlight.dll`** — Custom Patch 2.50 `RED4ext v1.31.0` C++ native plugin + Redscript controller. Attaches two camera-parented `gameLightComponent` spotlights (`n"Flashlight"` and `n"FlashlightFill"`) to `PlayerPuppet` during `OnRequestComponents`, automatically activates the flashlight when aiming with any weapon (`AimingStateEvents.OnEnter` / `OnExit` / `OnUpperBodyStateChange`) with weapon-class adaptive beam profiles (75m precision spotter for Sniper/Precision rifles, 48m tactical beam for standard firearms, 38m wide flood for Shotguns/LMGs/Melee), and unlocks double-tap Scanner Hold (`Tab` / `LB`) for manual persistent flashlight toggle.

## Sync & Compile

Run:

```bash
./active_redscript_mods/sync_and_compile.sh
```
