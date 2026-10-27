# Drone companion audit and implementation plan

**Status:** implementation in progress. The downloaded reference packages remain uninstalled and outside the repository. The selected vanilla-first two-drone design is being implemented and compile-checked before a later, user-requested in-game smoke test.

## 1. Scope and constraints

The target is a **small, reliable combat-drone companion** that fits this repository:

- pure REDscript gameplay logic;
- Codeware DynamicEntitySystem for lifecycle ownership;
- no Cyber Engine Tweaks (CET), Lua, overlay, console, Native Settings, Mod Settings, JSON settings, or runtime tuning;
- downloaded reference archives may remain temporarily outside the repository until the full plan is complete, but must never be copied into Git or installed into the game tree;
- fixed constants reviewed in Git;
- one dependable fighting drone rather than a fleet of variants;
- bounded work, explicit cleanup, and compatibility with the existing enemy, Cazanu, CyberwareEx, and UI hooks.

The upstream package is a reference implementation, not a drop-in dependency. Its Nexus page requires CET, RED4ext, redscript, Codeware, and TweakXL, and exposes a large in-game settings surface. Its listed modification and asset permissions require author permission, so this plan is a clean-room redesign rather than a source/assets fork. [Drone Companion requirements and permissions](https://www.nexusmods.com/cyberpunk2077/mods/32572)

## 2. Downloaded package inventory

The extracted package contains:

| Payload | Audit result | Keep for the redesign? |
|---|---|---|
| `bin/x64/plugins/cyber_engine_tweaks/mods/DroneCompanion/` | 41 Lua files, about 17.6k lines. CET bootstrap, JSON settings/presets, backup/restore, overlay menu, hotkeys, camera, vehicle chauffeur, hijack, loot, arena, persistence, and periodic schedulers. | **No.** CET/Lua and local settings are prohibited here. |
| `r6/scripts/DroneCompanion/` | 15 REDscript files, about 15k lines. Gameplay wrappers, two menu implementations, HUD, phone integration, inventory/crafting filters, and eight language packages. | **Study only.** Reimplement a narrow subset. |
| `r6/tweaks/DroneCompanion.yaml` | 1,133 lines. Nine chassis, faction variants, shards, firmware, vendor stock, crafting recipes, icons, and mappins. | **No** for the minimal design; retain only a tiny TweakXL file if the selected trigger/record option needs it. |
| `archive/pc/mod/DroneCompanion.archive` | About 13 MB of custom UI/icon/font/effect/template resources. | **No** for a vanilla-record Octant/Wyvern design. |

The archive has no embedded manifest or license file that independently identifies its exact package version; its filename is not treated as authoritative version evidence. The three reference archives are being retained outside this repository during the continuing audit, per the current user instruction; they remain uninstalled and untracked.

## 3. What the upstream code does

### 3.1 Bootstrap and state

`init.lua` constructs a global module graph, loads 20-plus Lua modules, installs CET callbacks, and runs several periodic loops (0.25 s, 0.5 s, 1 s, and 2 s) plus `onUpdate`/`onDraw`. It stores settings, presets, skins, key bindings, squad state, and language selection in JSON. It also writes `settings.backup.json`, `menu.backup.json`, `squad.backup.json`, session files, and `trail.log`. Those are precisely the local configuration/backup surfaces this profile bans.

### 3.2 Runtime record generation

`records.lua` clones vanilla character records at runtime with CET TweakDB calls, copies dozens of flats, creates subcharacter records, creates status effects and abilities, rewrites follower conditions, creates weapon/equipment groups, changes vendor stock, and optionally builds explosive weapons. This is flexible but load-order-sensitive and difficult to audit against the current TweakXL payload. It also makes the effective records depend on runtime settings.

### 3.3 Companion lifecycle

`companion.lua` keeps per-record tables for stance, target, mute state, damage, weapon loadout, wrecks, mappins, vehicle state, and delayed generation counters. It calls `CompanionSystem.SpawnSubcharacterOnPosition`, repeatedly verifies spawns, retries failed spawns beside the player, teleports/recalls drones, handles elevators/vehicles, and performs a large watchdog pass. The approach is feature-rich but has many delayed callbacks and state races.

### 3.4 Combat integration

`DroneCompanion.reds` wraps many global engine methods: quickhack lists, damage processing, kill credit, AI sensing/attitude, threat calculation, hit reactions, nameplates, damage digits, dismemberment, crafting, input, and more. The broad wrappers are what make the large feature set work, but they are also the highest conflict surface with the current Much Better AI, Cazanu, and UI modules.

### 3.5 UI and optional systems

The package contains two large menu paths (`DroneMenu.reds` and `DroneMenuInk.reds`), a squad HUD, phone contact, quickhack wheel extensions, perk-tree integration, first-person drone camera, arena duels, hijacking, vehicle chauffeur/passenger combat, loot collection, repair wrecks, skins, firmware/perks, auto-summon, and localization. None is required for “summon one reliable fighting drone.”

## 4. Adversarial findings

| Priority | Finding | Consequence | Redesign response |
|---|---|---|---|
| P0 | CET/Lua is the package's control plane. | Violates the repository's permanent CET ban and adds a second runtime scheduler. | Rebuild the control plane as one REDscript `ScriptableSystem`. |
| P0 | Runtime JSON settings and explicit backup/restore files. | Violates Git-only history and creates untracked mutable state. | Remove all JSON, settings, preset, session, and backup code. |
| P0 | Runtime `TweakDB` record cloning/mutation. | Results vary with load order and can collide with other TweakXL edits. | Prefer an existing vanilla character record; use declarative TweakXL only when unavoidable. |
| P1 | Two independent in-game menu implementations and many UI wrappers. | Large conflict and crash surface, especially with QuestGuide and existing character/perk UI. | No custom menu/HUD in the baseline. |
| P1 | Multiple periodic scans plus `onUpdate`/`onDraw`. | Avoidable CPU/UI work and possible stutter in large fights. | Event-driven threat handoff plus one bounded watchdog (about 1 s) only while active. |
| P1 | Delayed spawn/recall/retry/vehicle/elevator callbacks. | Stale callbacks can act on a replaced entity or save/load boundary. | Generation token per spawn; delete through DynamicEntitySystem; no vehicle/camera/arena path. |
| P1 | Three instances per model by default, tunable to ten, plus variants and hijacks. | Entity count and AI cost grow quickly; enemy multipliers already use a 24-clone ceiling. | Hard cap of two active Minotaurs in the selected S2 profile; no variants or fleet UI. |
| P1 | Broad `DamageSystem`, `AIActionTarget`, `SenseComponent`, and `HitReactionComponent` wrappers. | Potentially changes unrelated NPC combat. | Every wrapper must first prove the actor has the simple-drone marker; avoid threat-recalculation wrappers unless a focused test proves they are necessary. |
| P2 | Custom archive/UI assets for a feature that can use a vanilla mech record. | Adds ArchiveXL/resource compatibility and a 13 MB asset payload. | Use vanilla Minotaur visuals and no custom archive. |
| P2 | Eight language packs and custom menu strings. | More compile surface for no gameplay value in a no-menu design. | No custom localization in the baseline; use one vanilla notification path or fixed English source text. |

## 5. Follow-up audit of the newly downloaded references

### 5.1 Mechs of Night City 1.0.7

The package contains roughly 43.8k lines of REDscript across the `ControllableMechs` and `TerminalKit` modules, four large archives, an `MNCPhysics.dll` native plugin, Input Loader bindings, Audioware data, and TweakXL records. Its own README requires **RedFunctions** and Input Loader in addition to redscript, RED4ext, Codeware, TweakXL, and ArchiveXL. RedFunctions is retired and incompatible in this profile, so the package cannot be installed or compiled here.

Useful patterns:

- `CMFleet` is a stateful bay/repair/deploy manager with generation-guarded delayed callbacks.
- `CMDroneAutopilot` demonstrates bounded delayed steering and a separate autonomous flight mode.
- `CMUDrone` uses `DynamicEntitySpec` for physics proxies and explicit `DeleteEntity` cleanup.
- `CMCHits` and `CMCCalm` show why broad global `DamageSystem` and `TargetTrackingExtension` wrappers are risky: they rewrite instigators, damage multipliers, threat tracking, movement, and ragdoll behavior for many actors.

The package is primarily a **player-piloting/physics/fleet** system, not a lightweight NPC follower. Its drone projectiles frequently build custom `AttackData` and queue hit events directly, so a weapon-record dismemberment stat would not automatically reach the normal Cazanu limb pipeline. It is reference material only; the simple companion must not inherit its physics proxy, fleet, input, or native-plugin surface.

### 5.2 Night City Allies AIO 1.6.11

The AIO contains 152 REDscript files (about 30.4k lines), an archive, CET Lua bootstrap, InkGUI/Lua bridge, Mod Settings properties, persistence, phone, vehicle, interaction, animation, equipment, and large UI systems. Its included `LICENSE.md` grants MIT rights to study/reuse source portions for personal non-commercial work, while prohibiting redistribution of the complete mod.

The strongest reusable design ideas are narrow:

- `NpcHandle.SpawnAt()` creates a tagged `DynamicEntitySpec`, resolves the entity asynchronously, then applies attitude and behavior after resolution.
- `NCAFollowPlayerBehavior` assigns an `AIFollowerRole` and issues a bounded follow command only when needed.
- `CombatBehavior` switches to the vanilla follower target-tracking preset instead of writing a custom global target scanner.
- `NCABehavior` owns and cancels one AI command, preventing command accumulation.

The systems that must **not** enter the drone profile are NCA's persistence registry, Mod Settings, phone/UI stack, vehicle/animation systems, CET bridge, god-mode option, and 0.75-second tick over all squad members. We can implement the same lifecycle ideas in a small, independent module without importing NCA.

### 5.3 Drone Companion 6.10.0 reference refresh

The refreshed archive confirms the earlier findings: 41 CET Lua files, 15 REDscript files, a 1,133-line multi-chassis TweakXL payload, and a custom archive. Its canonical drone weapon path is runtime-generated in `records.lua` from vanilla weapon records; no fixed dismemberment stat is present. The final redesign therefore adds an explicit, source-controlled weapon-stat requirement below rather than relying on the upstream dynamic weapon builder.

## 6. Recommended architecture (baseline)

The selected implementation is **B3 / C1 + C2 / T1 / S2 / L1 / A1 + A2 / D1 / R1 / U1 / E1 / W1** below. The optional comparison-material group **P** is intentionally left unselected because the downloaded references have already been audited. Where multiple options are checked, the static record inherits the vanilla implementation and carries only the selected deterministic override; the direct vanilla record ID remains the source-level fallback seam for the post-smoke-test comparison. No runtime settings or UI are added.

1. `SimpleDroneCompanion.reds` defines one `SDC_System extends ScriptableSystem` and one marker tag/field; no status-effect or localization record is needed.
2. It obtains Codeware's `DynamicEntitySystem`, resolves each offset against the human navmesh when available, creates two `DynamicEntitySpec` instances from the selected static Minotaur records, and tags each entity. If TweakXL has not loaded the private records, the backend seam falls back to `Character.militech_base_minotaur`. Codeware documents `DynamicEntitySpec` as the record/template, position, appearance, persistence, spawn, and tag contract. [Codeware DynamicEntitySpec](https://github.com/psiberx/cp2077-codeware/blob/main/scripts/World/DynamicEntitySpec.reds)
3. `persistState = false` and `persistSpawn = false` in the baseline. The drone is session-bound and is explicitly deleted at player detach/load boundaries; the user summons it again after loading a save.
4. On the dynamic-entity created/spawned event, apply the marker field, `AIFollowerRole`, player attitude group, friendly attitude to V, and the fixed weapon record package. Never use god mode.
5. Combat target handoff is event-driven: when V is attacked, or the marked drone damages a hostile NPC, inject a threat into that one drone. Do not poll every NPC or run a global threat scan.
6. A narrow damage guard blocks drone-to-V and drone-to-drone damage but leaves enemy-to-drone and drone-to-enemy damage intact. Kill credit is transferred to V only when the marked drone is the instigator.
7. A one-second watchdog runs only while at least one drone is active: verify attachment/aliveness, clear stale IDs, reissue a follow command only when the vanilla command is absent, and retire dead dynamic entities. It does not teleport or scan unrelated actors.
8. Dismiss deletes the managed entity through `DynamicEntitySystem.DeleteEntity`; no teleport-to-“-300”, no vehicle/elevator special cases, and no delayed retry chain. The one-second watchdog is the bounded generation-guarded stale-spawn timeout.
9. Input is a fixed source-level binding or a single item action, not a runtime key/settings menu. The action toggles summon/dismiss and has no variant picker.
10. Static checks and `sync_and_compile.sh` are the first validation gate. Runtime testing is a later, explicit smoke test; a clean compile is not presented as gameplay proof. The current source-only gate is green with the existing Proton Experimental wineserver; no game launch was performed by this implementation pass.

TweakXL is only needed if the chosen option creates a static subcharacter/item/action record; its declarative YAML model is designed for this kind of narrow record change. [TweakXL README](https://github.com/psiberx/cp2077-tweak-xl)

## 7. Mandatory weapon package

The selected drone's weapon **must** carry the fixed 40% dismemberment modifier. This is not a user setting or an optional perk.

- `BaseStats.TriggerDismembermentChance`: additive `0.40` exactly.
- `BaseStats.HitDismembermentFactor`: additive `1.50` to give the Cazanu living-limb path enough dismemberment damage.
- `BaseStats.HitWoundsFactor`: additive `1.50` so the wound bridge and dismemberment threshold work together instead of producing a visible-but-ineffective stat.

The implementation uses a dedicated `SimpleDrone` weapon/attack record in TweakXL. Its NPC RPG data is rebuilt from stable named `Base_HMG_NPC_Data` and Minotaur HMG stat-group records; it deliberately avoids auto-generated `inlineN` records, which can be renumbered between game updates. It must not modify every NPC weapon or the player's inventory weapons. If a later smoke test proves the static clone changes vanilla behavior, the source-level C1 seam can switch to the untouched record without changing lifecycle code.

This package is intentionally separate from the existing `UniversalIconicWeapons` player-weapon migration. It is a fixed companion-weapon mechanic, not an Iconic conversion.

## 8. Decisions to mark

**Selections are locked for implementation. Multi-selected groups are represented by a primary fixed path plus a small fallback seam; no runtime setting is created.**

### B. Chassis / combat identity

- [ ] **B1 (Recommended): Militech Octant** — vanilla aerial gunship record, ranged combat, no faction/skin switch, no custom archive.
- [ ] **B2: Militech Wyvern** — smaller smart-weapon drone; use only if its vanilla smart-projectile behavior proves more reliable in the target build.
- [x] **B3: Militech Minotaur** — heavy ground mech; higher obstruction/pathing risk and more interaction with vehicles/doors.
- [ ] **B4: Android** — rejected for the baseline because weapon/equipment slots and humanoid locomotion add failure modes.

### C. Spawn record strategy

- [x] **C1 (Recommended): Spawn the vanilla `Character.militech_base_minotaur` directly** — zero custom archive and no runtime record cloning; smallest dependency surface for the selected B3 chassis.
- [x] **C2: Add one declarative TweakXL subcharacter record** — copies only the fields required for player attitude, equipment, health, and AI; more deterministic but requires a focused YAML audit.
- [ ] **C3: Reuse the downloaded custom template/archive** — not recommended; requires permission and adds ArchiveXL/resource risk.

### T. Summon trigger

- [x] **T1 (Recommended): One fixed keyboard/controller binding in REDscript** — F9 on keyboard or `Left Shoulder + X` on a controller toggles summon/dismiss; no CET/Input Loader/settings dependency and no QuestGuide key overlap.
- [ ] **T2: One inventory control item/action** — right-click/use a single control token; requires a tiny TweakXL item/action record but avoids a hard-coded key.
- [ ] **T3: Phone contact or custom menu** — rejected for the baseline because it recreates the package's UI/phone complexity.

### S. Squad size and limits

- [ ] **S1 (Recommended): Exactly one active drone** — hard cap, one marker, one target, one watchdog path.
- [x] **S2: Two active drones** — requires bounded multi-entity state and a documented CPU/performance test; no variants still allowed.
- [ ] **S3: Configurable/fleet size** — rejected; it is a runtime tuning surface and duplicates the package's scale problems.

### L. Save/load lifecycle

- [x] **L1 (Recommended): Session-bound** — no save persistence; delete on detach/load and summon again after a save is loaded.
- [ ] **L2: Persist one entity through saves** — use `persistState`/`persistSpawn` and explicit load reconciliation; higher stale-ID and save-compatibility risk.

### A. AI and follow behavior

- [x] **A1 (Recommended): Vanilla follower role + event-driven threat injection** — use `AIFollowerRole`, attitude group, and narrow damage/sense hooks.
- [x] **A2: Keep a fixed custom-follow fallback seam** — the vanilla follower command is primary; a single bounded `AIMoveToCommand` is attempted only when the engine rejects follow while the drone is not in combat. No custom action package, settings, or periodic target scan is enabled.
- [ ] **A3: Periodic target scan** — rejected; it costs more and can fight the current AI overhaul.

### D. Damage and kill credit

- [x] **D1 (Recommended): Friendly-fire guard and player kill credit** — drone can be hurt and killed; V receives XP/credit for drone kills; drone never damages V or itself.
- [ ] **D2: Vanilla damage rules** — smallest hook count, but the drone may damage V or other companions in explosions.
- [ ] **D3: Invulnerable drone** — rejected as unimmersive and incompatible with the requested “reliable,” not “unkillable,” behavior.

### R. Fixed combat tuning

- [x] **R1 (Recommended): Vanilla health/damage** — keep the chosen chassis' native balance; reliability comes from lifecycle/AI fixes, not multipliers.
- [ ] **R2: Fixed 1.50× health and 1.25× damage** — a modest source-level combat cushion, never exposed as a setting.
- [ ] **R3: Fixed 2.00× health and 1.50× damage** — powerful and likely to compete with the user's current 6× enemy scaling; not recommended without playtesting.

### U. UI and feedback

- [x] **U1 (Recommended): No custom UI** — the vanilla warning-message channel reports deploy, dismiss, or failure; no HUD, menu, perk button, phone thread, localization layer, or camera.
- [ ] **U2: Minimal status nameplate/toast** — add one bounded Codeware/vanilla UI hook showing “Drone active” and health; no settings.
- [ ] **U3: Full squad HUD/menu** — rejected for this project; it recreates the largest conflict/performance surface.

### E. Economy / acquisition (only relevant to T2 or C2)

- [x] **E1 (Recommended): No item/economy layer** — fixed binding summons the drone directly.
- [ ] **E2: One control token sold by existing weapon vendors** — one TweakXL item and one action; no shards, variants, firmware, or vendor rotation.
- [ ] **E3: One craft recipe** — adds a crafting record; use only if the user wants an explicit material cost.

### W. Companion weapon implementation (the 40% requirement is mandatory)

- [x] **W1 (Recommended): Static TweakXL weapon clone** — clone the selected vanilla `Items.Minotaur_HMG_Right`/`Items.Minotaur_HMG_Left` pair and their stable named NPC RPG data, append the three fixed stat modifiers above, and equip them through one static subcharacter record.
- [ ] **W2: Runtime saved-stat bridge** — resolve the equipped weapon after spawn and add the three saved modifiers idempotently; use only if a static clone changes the vanilla weapon's behavior.
- [ ] **W3: Custom direct-hit attack rewrite** — rejected for the baseline; it bypasses the normal weapon/Cazanu path and repeats the risk seen in Mechs of Night City's custom projectile code.

### P. Optional comparison material

- [ ] **P1 (Recommended): Do not import other companion code; use the clean-room baseline.**
- [ ] **P2: Download Night City Allies #27625 for a source audit** — its page states the source is MIT and its recent versions moved core functionality toward redscript, making it useful for follower lifecycle/persistence patterns. Do not install it alongside the prototype. [Night City Allies](https://www.nexusmods.com/cyberpunk2077/mods/27625)
- [ ] **P3: Download Mechs of Night City #34927 for behavioral comparison** — current 2.5 drone/mech control, but its page restricts modification; use only as a black-box/reference audit unless the author grants permission. [Mechs of Night City](https://www.nexusmods.com/cyberpunk2077/mods/34927)
- [ ] **P4: Download legacy Drone Companions #4520 for historical comparison** — useful for the older TechDeck/crafting approach, but it is a 2022 CET/Native Settings design and should not be installed or ported directly. [Drone Companions](https://www.nexusmods.com/cyberpunk2077/mods/4520)

## 9. Implementation sequence after selections

1. **Lock the design:** complete. B3/C1+C2/T1/S2/L1/A1+A2/D1/R1/U1/E1/W1 are selected; P is intentionally unselected after the reference audit. No upstream code or assets are copied.
2. **Create the smallest source module:** complete in `r6/scripts/SimpleDroneCompanion/`; it owns the system, marker, input, spawn, cleanup, follower role, event-driven threat handoff, damage guard, and kill-credit hook.
3. **Add records only if selected:** complete in `r6/tweaks/SimpleDroneCompanion.yaml`; it contains two static subcharacter records, one equipment group, and the fixed weapon package, with no vendor/item/settings layer.
4. **Add no archive by default:** use the vanilla drone record and icon. ArchiveXL remains available to the profile but is not made a new hard dependency for the minimal mod.
5. **Remove all upstream surfaces:** no CET folder, Lua, Mod Settings annotations, Native Settings, JSON, session files, backup files, trail log, custom menu/HUD, camera, chauffeur, arena, hijack, loot, skins, firmware, or variant data.
6. **Integrate compatibility guards:** complete for current source: marker checks precede every combat wrapper, session generation and watchdog-generation state invalidate stale work, `DynamicEntitySystem.IsManaged` precedes deletion, and no global AI changes are made for unmarked actors.
   `StreetActivity` explicitly excludes the companion marker from gang-seed candidates so the friendly Minotaurs cannot become encounter participants.
   The marker is cleared in `ScriptedPuppet.OnDetach` before streamed objects can be reused.
7. **Compile first:** `git diff --check`, shell syntax checks, and `sync_and_compile.sh` pass when invoked with the currently running Proton Experimental toolchain. The game was not launched by this pass; a fresh TweakXL runtime log remains a later smoke-test gate.
8. **Focused runtime smoke test later:** summon/dismiss, save/load behavior selected in L, one combat against ordinary enemies, one elite, one vehicle-area fight, one player death/reload, and one removal/cleanup test. Check that no stale entity remains and that existing Cazanu/EnemyMultiplier/Much Better AI behavior is unchanged.
9. **Performance gate:** compare idle, combat, and dismissal behavior with two drones. Reject any per-frame scan, repeated UI rebuild, unbounded callback queue, or clone/entity leak.
10. **Document the final fixed constants, including the mandatory 40% dismemberment weapon package, in `README.md`, then commit the focused source change.**

## 10. Definition of done for the drone module

- no CET/Lua/Mod Settings/JSON/settings/backup payload exists;
- no downloaded installer/archive is tracked or installed; temporary reference archives are deleted only after the full plan and implementation are complete;
- only selected source and intentionally shipped runtime payloads are present;
- two drones summon and dismiss together through the selected trigger;
- the entity is owned and cleaned up by Codeware DynamicEntitySystem;
- it follows and fights without a global polling loop;
- it cannot damage V or another companion, but can be killed by enemies;
- its equipped weapon has exactly the fixed `+0.40 TriggerDismembermentChance` package and the supporting Cazanu wound/dismemberment factors;
- kills are credited to V when selected;
- save/load and detach behavior matches L1 or L2 exactly;
- `git diff --check`, shell checks, and `sync_and_compile.sh` succeed;
- runtime claims are made only from a later focused smoke test, not from compilation alone.
