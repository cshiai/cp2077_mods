# Living Night City: post-cleanup gang activity and encounter system

**Status:** design/decision document only; no new mod has been installed and the game has not been launched.
**Date:** 2026-10-26
**Target:** Cyberpunk 2077 2.5 / Steam-Proton build `26161058` in this repository.

This document records the source review of the newly downloaded **Night City Traffic Overhaul 2.50**, **NIGHT CITY ALIVE High Density 2.3**, **Factions Evolved (No Customizable) 2.50**, and **Spawned NPC Post Combat Fix 1.2** packages, then turns the useful parts into a choice-driven plan for one fixed, source-controlled encounter profile.

The intended result is a busier, more dangerous, more replayable Night City after the normal gigs and side jobs have been cleared: more gang traffic, visible gang-versus-gang incidents, occasional law-enforcement intervention, and bounded random encounters. The profile must remain compatible with this repository's rules:

- **No CET, Lua, Mod Settings, Native Settings, RedFunctions, localization, or runtime config files.**
- **No new diagnostics or unbounded logging.** Constants live in Git-controlled REDscript/TweakXL source.
- **No replacement of the existing Cazanu, MuchBetterAI, EnemyMultiplier, health, movement, Black Chrome, or other unrelated behavior unless a selected integration explicitly requires it.**
- Codeware DynamicEntitySystem is the only proposed native spawn API; its use must remain lifecycle-safe and share the existing 24-clone budget.
- Build and static validation come before any runtime launch. A gameplay smoke test is deferred until explicitly authorized.

> **How to use this file:** edit the checkboxes in place. For a **single-choice** group, mark exactly one option. For a **multi-choice** group, mark every option wanted. “Recommended” is a recommendation, not a preselected answer.

> **Implementation gate:** no encounter source should be imported or written until the core choices in sections **1.1–1.8** are marked. If a later choice is left blank, implementation must stop at that subsystem rather than silently inventing a runtime setting or default.

---

## 1. Decisions to return

These are the minimum choices needed before implementation can begin. The detailed rationale and secondary parameters are below.

### 1.1 Overall scope — single choice

- [ ] **A — Passive traffic only:** fixed NCTO traffic/faction vehicles; no new dynamic spawns or new reaction rules.
- [ ] **B — Traffic + reaction bridge:** NCTO plus a carefully ported subset of NCA's faction/stim behavior; no new dynamic spawns.
- [x] **C — Bounded living city (recommended):** fixed traffic, safe NCA reaction subset, PCF cleanup, and a shared-budget dynamic encounter allocator.
- [ ] **D — Vanilla activity orchestration:** use Codeware `OpenWorldSystem`/existing activities where discoverable; no custom encounter spawner unless activity discovery proves insufficient.

### 1.2 NCTO base — single choice

- [x] **A — Fork the downloaded NCTO 2.50 source (recommended):** correct for 2.5, remove all Mod Settings/listeners, and freeze the chosen values in source.
- [ ] **B — Port only NCTO's TweakXL data:** do not ship its REDscript traffic registry hook; use a smaller fixed traffic patch.
- [ ] **C — Port current NCTO 3.01:** only after removing its mandatory RCF/RedFunctions/config path; higher migration and compatibility risk.
- [ ] **D — Do not use NCTO:** build the encounter system around vanilla traffic and our own TweakXL records.

### 1.3 Factions Evolved — multi-choice

- [ ] **A — Do not import its vehicle roster.** Keep vanilla/NCTO vehicles only.
- [ ] **B — Import an installed-only curated roster (recommended):** retain only records whose base vehicle is deliberately present in the current profile.
- [x] **C — Import the complete 2.50 no-customizable roster:** 13 district lists and hundreds of modded vehicle IDs; requires a full external-vehicle audit.
- [ ] **D — Import only NCPD/utility YAMLs:** improve emergency response flavor without adding every civilian/gang car.
- [x] **E — Add the optional Reinforcements vehicle overlay:** only if a later source audit confirms it does not reintroduce Mod Settings/RedFunctions/CET.

### 1.4 NCA behavior — multi-choice

- [ ] **A — Do not port NCA reactions or stims.** Lowest risk and lowest spontaneous-fight frequency.
- [x] **B — Port the narrow reaction bridge (recommended):** hostile vehicle-hit/hijack stimuli, safe-area/navmesh guards, and bounded crowd aggression.
- [ ] **C — Port the full high-density stim preset:** more fights, but substantially more CPU/AI load and more mission interference.
- [ ] **D — Port only faction attitudes:** preserve vanilla stimulus handling and let existing AI decide when combat starts.

### 1.5 Post-combat cleanup — single choice

- [ ] **A — Omit PCF.** Spawned bodies/vehicles use vanilla cleanup.
- [ ] **B — Include PCF unchanged with explicit spawn tags.** Minimal source change, but only tagged/opt-in actors retreat.
- [x] **C — Include a refactored PCF (recommended):** preserve its mount/drive-off logic, remove optional logger plumbing, and gate retreat to encounter-owned gang actors.

### 1.6 Encounter source — multi-choice

- [x] **A — Traffic passengers:** use NCTO/Factions traffic pools to make gang presence visible without creating new entities.
- [x] **B — Gang-versus-gang seeds (recommended):** trigger only when two eligible hostile groups already coexist in an open-world area.
- [ ] **C — Dynamic reinforcement waves:** spawn explicit faction records through Codeware DynamicEntitySystem.
- [x] **D — Shared EMRS duplication:** reuse/refactor the existing EnemyMultiplier queue, navmesh placement, 24-clone cap, and deletion policy.
- [ ] **E — Codeware OpenWorld activities:** discover and start only safe, incomplete/repeatable activity kinds; no hardcoded activity name is accepted without evidence.

### 1.7 Encounter pacing — single choice

- [x] **A — Quiet:** one seed every 8–12 minutes, at most one active encounter.
- [ ] **B — Balanced (recommended):** one eligible seed every 4–8 minutes, at most two active encounters.
- [ ] **C — High:** one eligible seed every 2–4 minutes, at most three active encounters.
- [ ] **D — Riot/chaos:** intentionally unbounded or near-continuous combat. **Not recommended** for stability or immersion.

### 1.8 Combat composition — multi-choice

- [ ] **A — Existing actors only:** never create an actor solely to start a fight.
- [x] **B — Small gang squads:** 2–4 members per side; no bosses/MaxTac/officers.
- [x] **C — Vehicle arrival:** one vehicle with 1–3 eligible occupants; the vehicle leaves via PCF.
- [x] **D — Escalation wave:** a second wave only after a cooldown and only if the first wave remains active.
- [x] **E — Authority intervention:** rare NCPD/Militech/Barghest/Arasaka/Kang Tao response, district-gated.

---

## 1.9 Current selected architecture (provisional)

The currently marked choices now describe this architecture:

- **NCTO 2.50 is the traffic foundation**, converted to fixed source constants with all Mod Settings/listener/config paths removed.
- **The complete Factions Evolved 2.50 roster is requested**, so implementation requires a record-by-record TweakXL/base-vehicle audit. Current runtime evidence found 413 missing vehicle bases; those records are now pruned from the active payload rather than emitting errors, while source lists remain the Git expansion point when the corresponding vehicle mods are installed.
- **The optional Reinforcements vehicle overlay is conditional**, not active. Its audit found 149 vehicle records, 375 dynamic squad/bike records, and two duplicate Tyger keys; current runtime evidence still showed 503 missing vehicle/character references, so the overlay is quarantined and the fixed StreetActivity path supplies the no-settings behavior.
- **NCA contributes only its narrow reaction bridge**, not the broad high-density stimulus preset or old traffic hook.
- **PCF is refactored** for encounter ownership, tag-based retreat, and no RedLogger/diagnostic dependency.
- **Traffic passengers plus gang-versus-gang seeds** are the encounter sources. Existing open-world actors are the seed; EMRS remains the shared cloning/placement/cleanup owner. Explicit standalone DES reinforcement waves and unverified OpenWorld activity names are currently excluded.
- **Quiet pacing is selected:** one seed opportunity every 8–12 minutes and at most one active encounter. The complete vehicle roster therefore increases visual variety, not encounter frequency; it must not be used as a reason to raise the combat scheduler rate.
- **Combat composition is selected:** small 2–4-member gang squads, vehicle arrival when an assigned/traffic vehicle is available, one cooldown-gated escalation wave, and rare district-gated authority intervention. Bosses, MaxTac, officers, civilians, and unbounded waves remain excluded.

The core choice gate is now satisfied. Implementation uses only the exact source packages that were re-downloaded and audited in the temporary extraction; no gameplay source is reconstructed from memory or partial snippets.

### 1.10 Implementation status

The exact four source packages have now been re-downloaded, extracted temporarily, copied into the source tree, and the downloaded archives/temp extraction were removed again. The current source includes:

- Fixed NCTO 2.50 scripts, archive, and traffic TweakXL inputs.
- Factions Evolved 2.50 database overlays plus its active NCPD/utility/vehicle YAML payload; 413 records whose bases were absent from the current installation were pruned after TweakXL runtime evidence.
- A no-settings `StreetActivity.ReactionBridge` based only on the narrow NCA reaction logic.
- A refactored `PostCombatFix` that recognizes EMRS/dynamic encounter tags without RedLogger diagnostics.
- A `StreetActivity.GangSeeds` scheduler using quiet pacing, existing open-world gangers, direct melee stimuli, and the EMRS shared clone path.
- A public EMRS encounter-clone seam that preserves the existing DynamicEntitySystem ownership, navmesh placement, cleanup, and hard 24-clone cap.
- The re-downloaded Factions Evolved Reinforcements overlay was audited as 16 TweakXL YAML files only, with no CET/Lua/Mod Settings/RedFunctions/native code. It defines 149 tagged faction vehicle records and 375 `DynamicSpawnSystem` squad/bike records, but current TweakXL evidence reported 503 missing references; it is therefore quarantined from the active payload. Two duplicate Tyger record keys were repaired in the audited source: the second `GRTygerNormalBike2` became `GRTygerNormalBike5`, and the second `GRTygerNormalSquad5` became `GRTygerNormalSquad6`.

`sync_and_compile.sh` completed successfully at **2026-10-26 14:42:25 EDT**, producing `final.redscripts.modded`; the game was not launched by this work session. A custom-tag YAML parser accepted all 51 active YAML/YML files. A later current TweakXL log provided runtime evidence of 413 missing vehicle bases and 503 inactive Reinforcements references; those records are now pruned/quarantined from the active payload. The seed scheduler also gates interiors, safe areas, `NoCombat`, authority actors, one delayed escalation wave, and PCF ownership cleanup.

---

## 2. Research findings

### 2.1 Package inventory and upstream status

| Package studied | Payload observed | What it actually does | Decision implication |
|---|---|---|---|
| **Night City Traffic Overhaul 2.50** (Nexus 25552) | `NCTO.reds`, district DB, traffic/faction lists, settings, vehicle-light logic, ~21 TweakXL files, and a traffic `.archive` | Rewrites the always-loaded community crowd registry on resource load. Adds gang, police, taxi, bus, utility, modded-vehicle, passenger, speed, security, and light behavior. | Useful foundation, but the downloaded source has a very large Mod Settings surface and must become a fixed profile. The upstream page says 2.50 was the last Mod Settings build for 2.31/2.5; current 3.01 moved to RCF. |
| **NIGHT CITY ALIVE High Density 2.3** (Nexus 10395) | `Reactions.reds`, `Traffic.reds`, a 2.31 district table, high-density passenger/stim/attitude YAML, and vehicle passenger patches | Broadens stimulus aggression, civilian bump/vehicle reactions, faction attitudes, and some vehicle/passenger traffic. Its traffic hook assumes a 2.31 registry node/index. | Do not install unchanged. Port only selected reaction/attitude ideas; discard its traffic hook and old district table for the 2.5 profile. |
| **Factions Evolved (No Customizable) 2.50** (Nexus 25873) | Replacement `NCTOvehicles.reds`/`NCTOmoddedVehicles.reds` plus NCPD, utility, and faction vehicle YAML | Expands NCTO's vehicle/faction pools. Function names intentionally match NCTO, so the files are an overlay/replacement, not an independent second traffic system. | Good data source, not a second module. Use a curated installed-only subset; wholesale YAML import references many optional vehicle mods. Current 3.01 upstream requires RCF, Codeware, and RedFunctions, which are not allowed here. |
| **Spawned NPC Post Combat Fix 1.2** (Nexus 32862) | One 30 KB REDscript file | Tracks a post-combat latch, sends eligible NPCs back to their assigned vehicle or 300 m away on foot, handles seat reservation, driver promotion, drive-off retries, and cleanup. | Useful lifecycle component. It is not an encounter spawner. Its default eligibility is tag/opt-in based, so imported actors need an explicit encounter tag or a safe refactor. |

Upstream references: [NCTO](https://www.nexusmods.com/cyberpunk2077/mods/25552), [NIGHT CITY ALIVE](https://www.nexusmods.com/cyberpunk2077/mods/10395), [Factions Evolved](https://www.nexusmods.com/cyberpunk2077/mods/25873), and [Spawned NPC Post Combat Fix](https://www.nexusmods.com/cyberpunk2077/mods/32862).

### 2.2 NCTO code review

**Strengths**

- Uses the game's community registry rather than a per-frame world scan; traffic changes are primarily applied at sector/resource load.
- Has separate district, faction, police, utility, taxi, bus, modded, and passenger pools.
- The 2.50 district resolver correctly distinguishes registry sizes 922 (2.31) and 924 (2.5); this is safer than NCA's fixed 2.31 table.
- Optional integrations are compile-guarded (`VehicleSelectorHelper`, Combat Cab Taxi, Taxi Work, RedLogger).

**Adversarial findings to fix in a fork**

1. `NCTOsettings.reds` contains approximately 982 `ModSettings` runtime annotations and the light system calls `ModSettings.RegisterListenerToClass`/`UnregisterListenerToClass`. Those paths must be removed, not merely left at default values.
2. `resetTrafficSecurity()` reads the *current* flat and writes it back; it does not restore the original value. A fixed profile should never expose a runtime disable/reset path, or it must snapshot known vanilla values in source.
3. Crowd-registry edits have no explicit idempotence marker. A repeated resource callback could append the same vehicle records more than once. Add a per-resource/per-system guard or rebuild from a captured baseline once.
4. `getAllVehicles()` assumes a particular vanilla-list marker exists and concatenates several lists without a general deduplication pass. Missing marker or repeated addon entries can inflate pools.
5. `vehicleCheck()` checks the string shape of a TweakDBID, not whether the record exists. TweakXL `$base` records can fail before this runtime filter ever runs. External vehicle records must be audited before YAML import.
6. The code assumes four time periods and non-empty arrays at several points. Add bounds checks for a 2.5 registry and return safely when a sector is incomplete.
7. `matchRandomPassengersSlots()` assumes the selected passenger template has enough slots. Clamp the copy count to both arrays.
8. Several local values (`sampleSize`, `timeOfDay`) are unused; remove them during the refactor.
9. Dynamic lights are logically separate from encounter behavior and should be optional source code, not a hidden dependency of the encounter system.
10. The large external vehicle roster is a performance/asset risk even when the REDscript compiles; each vehicle can increase streaming, AI, texture, and traffic memory pressure.

### 2.3 NCA code review

**Useful behavior**

- The reaction bridge makes vehicle hits/hijacks eligible for combat stimuli and adds explicit safe-area, `NoCombat`, player-zone, facing, range, and navmesh checks.
- Its high-density TweakXL raises selected stimulus aggression and removes tags that suppress crowd combat; this explains the intended “fight anywhere” feeling.
- Faction attitude YAML makes Wraiths, Scavs, Tyger Claws, Valentinos, 6th Street, and parts of NCPD hostile to each other, creating emergent street fights without a custom spawner.
- The passenger YAML supplies a large faction/rank/rarity pool, including rare and elite archetypes.

**Reasons not to install unchanged**

1. `Traffic.reds` directly reads node `3256` and uses a fixed 2.31 district array. The current NCTO 2.50 code already has a 924-entry 2.5 resolver and safer node probing.
2. `Traffic.reds` does not robustly guard a missing community registry before dereferencing it.
3. `Reactions.reds` wraps several private `ReactionManagerComponent` methods. This is high collision surface with other reaction/AI mods and must be merged into one intentional wrapper chain.
4. `OnVehicleHit()` returns `false` when the instigator is undefined instead of calling the wrapped method; that can suppress vanilla processing. The merged version must fail through to vanilla in that case.
5. Active-weapon access in the ranged/melee distance branch needs a null-safe fallback; an absent weapon must not become a native call on a null object.
6. The stim YAML is deliberately aggressive: many `NonAggressiveCrowd`/`NoAutoCombatStart` suppressors are removed, several aggression values become 20, and bump radius becomes 20 m. This can create cascading fights and AI load spikes in crowded areas.
7. The high-density passenger files add many rare/elite actors to civilian traffic. This is fun in moderation but interacts with our 6x health curve, limb system, lethal netrunners, and MuchBetterAI; elite probability must be bounded.
8. The archive includes transition files (`cdpr-to-low`, `low-to-std`, `std-to-high`). They are mutually contextual patches, not three profiles to stack blindly. Importing all of them would compound lists and probabilities.
9. Attitude changes can affect missions and scripted scenes. Encounter-only hostility should be preferred over globally changing every faction attitude.

### 2.4 Factions Evolved review

- The two REDscript files preserve the same public function names as NCTO and are intended to replace/extend its vehicle databases. They do not constitute an independent traffic engine.
- The downloaded 2.50 source contains roughly 540 modded vehicle IDs in district lists and roughly 1,256 vehicle IDs in its expanded faction/utility/police lists. The same vehicle may intentionally appear in several districts/fleets; duplicates *within one list* still need validation.
- The YAML creates many new vehicle records and passenger entries for NCPD, MaxTac, trauma, border, sheriff, utility, gang, and civilian fleets. A missing `$base` vehicle mod is a TweakXL load-time problem; NCTO's later `vehicleCheck()` cannot repair it.
- The current upstream page's 3.01 release advertises RCF/RedFunctions-powered customization and lists RedFunctions as mandatory. That is incompatible with this profile. The downloaded 2.50 “No Customizable” payload is the only viable starting point, and even it should be reduced to installed records.
- The author history itself notes that many entries have been removed or moved because of invisible, burned, texture, ArchiveXL-overload, or potential-crash behavior. This is evidence for an allowlist, not a whole-roster import.
- The upstream NCTO troubleshooting notes also call out engine-driven despawns, sunken vehicles, vehicle overlap, and area-specific crashes when unsupported traffic vehicles or high traffic density are used. Because the selected plan choice is the complete Factions roster, implementation must add a record-by-record load audit, a traffic-density ceiling, and a quarantine list for vehicle records that fail attachment/spawn validation; the roster cannot be treated as “compile = safe.” See the [NCTO troubleshooting discussion](https://www.nexusmods.com/cyberpunk2077/mods/25552?tab=posts).
- The selected optional Reinforcements overlay is not present in the studied Factions Evolved archive. The current Gang Vs Gang upstream package lists Mod Settings as a requirement and therefore cannot be copied unchanged; the overlay must be re-downloaded from the user's history, source-audited, and either ported to fixed constants or omitted. No implementation may silently install the upstream settings layer. See [Reinforcements — Gang Vs Gang](https://www.nexusmods.com/cyberpunk2077/mods/24243).

### 2.5 Post Combat Fix review

- The core state machine is thoughtful: combat latch → relaxed state → assigned vehicle lookup → seat reservation → mount → driver promotion → panic drive → delayed verification → foot fallback.
- It adds seven fields to `ScriptedPuppet` and five to `VehicleObject`, hooks `ScriptedPuppet.OnDetach`, `NPCPuppet.OnIncapacitated`, `ReactionManagerComponent.OnHighLevelStateDataEvent`, `VehicleComponent.OnVehicleFinishedMountingEvent`, and `EnterVehicle.Deactivate`.
- Defaults are conservative: 50 m maximum boarding walk, 300 m foot retreat, 2 m arrival tolerance, 2.5 s drive-off verification, and 0.50 m/s retry threshold.
- Eligibility is intentionally narrow (`m_pcfRetreatOptIn` or `pcf_GangerCanRetreat` record tag). NCTO/NCA traffic records in the downloaded packages do not automatically set that tag, so simply copying the file may appear to do nothing.
- The optional RedLogger branch is unnecessary here. Keep bounded logging disabled and use no runtime diagnostics.
- The merged version must prevent mission actors, companions, bosses, civilians, and actors in scenes/workspots from being marked as encounter-owned. It must also preserve the vehicle traffic system's own traffic-slot ownership.

### 2.6 Existing-profile integration review

- `EnemyMultiplierRedscript` already uses Codeware `DynamicEntitySystem`, a 24-clone hard cap, navmesh placement, delayed queue processing, owner tracking, and safe deletion. A second independent dynamic-spawn scanner would duplicate work and compete for entity lifetime.
- `MuchBetterAI` exposes reusable eligibility predicates (`MBAI_ActorEligible`, `MBAI_EnemyEligible`, movement/workspot/scene checks). Encounter actors should use the same exclusions rather than inventing a third definition of “active enemy.”
- Cazanu's limb/health behavior and the current 2.5x–6x enemy health curve must not be silently applied a second time to encounter actors. Spawned records should enter the normal stat pipeline once.
- The current repository compiles successfully at the baseline (`Compilation complete`, output `final.redscripts.modded`), and the current RED4ext baseline reports seven plugins and successful `scc` invocation. This plan changes no existing source yet.

### 2.7 Current wrapper collision surface

The current source tree already wraps the same engine classes that the downloaded packages target:

- `ReactionManagerComponent`: MuchBetterAI currently owns four wrappers (`CombatPropagation`, `AlertClock`, and two `CorpseDiscoveryLOS` paths). NCA adds several more private reaction wrappers. A blind merge would create a large order-dependent chain and could suppress a wrapped method if any branch returns early.
- `NPCPuppet`/`ScriptedPuppet`: Cazanu, EnemyHealthScaling, EnemyMultiplier, LethalEnemyNetrunners, MuchBetterAI, and several utility modules already wrap attach, damage, combat, or lifecycle methods. PCF adds more lifecycle wrappers. Encounter ownership should therefore use new helper methods/fields and avoid another broad replacement hook.
- `VehicleComponent`: PCF and NCTO light/traffic behavior both target vehicle lifecycle/mount events. Their handlers must be combined or made explicitly order-safe.
- `DynamicEntitySystem`: EnemyMultiplier is currently the only gameplay consumer. StreetActivity should call a shared allocator rather than create a second independent owner table and cleanup loop.

This collision evidence raises the priority of a single `StreetActivity.ReactionBridge` and a shared encounter allocator. It is not safe to treat the downloaded files as additive drop-ins even if each package compiles in isolation.

---

## 3. Proposed architecture

### 3.1 Recommended module boundary

Use a new source-owned module rather than dropping upstream files into unrelated namespaces:

```text
r6/scripts/StreetActivity/
  Config.reds                 # fixed constants; no annotations/settings
  Eligibility.reds            # safe-area, quest, scene, actor/faction gates
  Factions.reds               # static turf and encounter faction matrix
  Scheduler.reds              # one bounded tick and cooldown ledger
  EncounterAllocator.reds      # shared DES/EMRS spawn budget
  EncounterSeeds.reds          # traffic/contact/gang-v-gang seeds
  ReactionBridge.reds          # selected, corrected NCA behavior
  RetreatBridge.reds           # PCF lifecycle/ownership integration
  Cleanup.reds                 # despawn/retreat/owner cleanup

r6/tweaks/StreetActivity/
  fixed-traffic.yaml
  fixed-stimuli.yaml          # only if reaction choice is selected
  encounter-records.yaml      # only if explicit records are selected

archive/pc/mod/
  NightCityTrafficOverhaul.archive  # only if NCTO scope is selected
```

The existing `EnemyMultiplierRedscript` should expose a small, source-level allocator interface or be refactored into a shared service. It must remain the sole owner of the 24 dynamic clone cap and deletion bookkeeping. Do not have StreetActivity scan every `NPCPuppet` on its own every frame.

### 3.2 Event flow

1. **Player/streaming readiness:** register one guarded system callback after the player is attached and the dynamic entity system is ready.
2. **Candidate intake:** accept only events from NCTO traffic actors, an observed gang-versus-gang stimulus, or an explicitly selected vanilla activity. Never scan the whole world every frame.
3. **Eligibility:** reject safe areas, interiors, scenes, workspots, quests, companions, civilians, crowd-only actors, bosses, MaxTac, officers, named actors, existing combat groups that are already full, and actors outside the district/range gate.
4. **Seed ledger:** key by encounter location/faction pair; apply a monotonic cooldown so the same fight cannot create a storm of duplicate requests.
5. **Allocation:** reserve a small number of dynamic entities from the shared 24 cap; place on human navmesh; tag each entity with `StreetActivity.Encounter` and `pcf_GangerCanRetreat` (or the refactored equivalent).
6. **Attitude/squad:** initialize faction relation and join/attach to the originating encounter group before issuing combat stimuli. Do not globally change player or mission attitudes.
7. **AI hand-off:** allow MuchBetterAI to control only after the actor is attached, active, autonomous, and not in an authored scene.
8. **Resolution:** when a group is defeated, leaves combat, or becomes distant, PCF/cleanup sends winners away or deletes only encounter-owned dynamic entities according to the selected cleanup policy.
9. **Persistence:** encounter entities are nonpersistent and are removed on player detach/save transition; no save-file population is retained.

### 3.3 Why this is preferable to stacking all four mods

Stacking NCTO, NCA High Density, Factions Evolved, PCF, and a separate gang-reinforcement mod would create multiple wrappers around `ReactionManagerComponent`, multiple writers to the same crowd registry, overlapping faction attitudes, and competing dynamic spawn/cleanup loops. The proposed design selects data and algorithms, then gives each responsibility one owner.

---

## 4. Detailed design choices

### 4.1 Traffic density and faction weights — single choice

These are fixed source constants, not runtime sliders.

- [ ] **Low-risk:** keep NCTO defaults close to vanilla; gang/police traffic additions only.
- [ ] **Balanced (recommended):** preserve vanilla traffic, add moderate turf-gang fleets, one secondary gang pool in selected districts, and 5–10% outside-incursion weight.
- [ ] **High-density:** use NCA High-like gang traffic and frequent faction mixes, but cap passengers and active AI.
- [ ] **Custom per district:** choose district values in a source table (multi-choice below).

If custom per district is selected, mark each district profile:

| District | Quiet | Balanced | Hostile/active | Decision |
|---|---:|---:|---:|---|
| Badlands | [ ] | [ ] | [ ] |  |
| Dogtown | [ ] | [ ] | [ ] |  |
| City Center | [ ] | [ ] | [ ] |  |
| Heywood | [ ] | [ ] | [ ] |  |
| Japantown | [ ] | [ ] | [ ] |  |
| Kabuki/Little China | [ ] | [ ] | [ ] |  |
| Northside/North Oak | [ ] | [ ] | [ ] |  |
| Pacifica | [ ] | [ ] | [ ] |  |
| Santo Domingo | [ ] | [ ] | [ ] |  |
| Charter Hill | [ ] | [ ] | [ ] |  |

### 4.2 Passenger composition — multi-choice

- [ ] Mostly common/standard gangers; rare/elite actors remain uncommon.
- [ ] 10–15% rare/elite in gang cars (recommended ceiling for the current health/limb profile).
- [ ] Rare/elite police/trauma responders only, not civilian traffic.
- [ ] Include netrunners and specialists in small slots.
- [ ] Include cyberpsychosis/boss/MaxTac records. **Not recommended and normally prohibited.**
- [ ] Remove all optional passenger records whose character base is not verified in the current game build.

### 4.3 Encounter trigger — multi-choice

- [ ] **Gang vehicle contact:** two hostile gang vehicles within the same encounter radius.
- [ ] **Gunpoint/weapon display:** a gang traffic actor becomes hostile after a bounded player stimulus.
- [ ] **Crime witness:** civilian/NCPD reaction creates a gang-versus-law seed only outside safe/quest contexts.
- [ ] **Existing hostile proximity:** two non-crowd hostile factions are near each other while neither is in a mission scene.
- [ ] **Time/district roll:** one scheduler roll per cooldown window; no per-frame random roll.
- [ ] **Vanilla OpenWorld activity:** start only an activity returned by `GetActivities()` and passing repeatability/completion checks.

### 4.4 Encounter size — single choice

- [ ] **Small:** 2–3 actors total.
- [ ] **Balanced (recommended):** 3–5 actors total, normally 2+2 with at most one specialist.
- [ ] **Large:** 5–8 actors total, only as a rare escalation and never more than one active large fight.
- [ ] **Vehicle wave:** 1 vehicle plus 1–3 passengers; a second vehicle requires a separate cooldown.

### 4.5 Dynamic spawn strategy — single choice

- [ ] **No dynamic actors:** rely on traffic/passengers and existing open-world NPCs.
- [ ] **Explicit faction records:** Codeware DES creates known `Character.*` records with fixed tags (recommended for deterministic loadout/eligibility).
- [ ] **Clone observed actors:** reuse EMRS record/appearance logic and shared 24 cap; less data, more dependence on the original actor's state.
- [ ] **Vanilla activity first, DES fallback:** safest if activity discovery works, otherwise use explicit records.

### 4.6 Shared entity limits — single choice

- [ ] **Conservative (recommended):** StreetActivity may reserve at most 8 of EMRS's 24 clone slots; at most 2 new actors per scheduler tick.
- [ ] **Moderate:** reserve at most 12 of 24; at most 3 new actors per tick.
- [ ] **Aggressive:** reserve up to 16 of 24; at most 4 new actors per tick. **Requires runtime profiling.**

No option may increase the global hard cap beyond 24 without a separate stability review.

### 4.7 Pacing constants — mark one row per parameter

| Parameter | Conservative | Balanced (recommended) | High | Decision |
|---|---:|---:|---:|---|
| Global seed cooldown | 8–12 min | 4–8 min | 2–4 min |  |
| Same district cooldown | 12 min | 8 min | 5 min |  |
| Same faction-pair cooldown | 15 min | 10 min | 6 min |  |
| Minimum player-to-seed distance | 80 m | 60 m | 45 m |  |
| Maximum seed distance | 180 m | 140 m | 100 m |  |
| Active encounter count | 1 | 2 | 3 |  |
| Escalation delay | disabled | 45–90 s | 30–60 s |  |
| Maximum escalation waves | 0 | 1 | 2 |  |
| Encounter cleanup distance | 250 m | 220 m | 180 m |  |

### 4.8 Faction relationship model — single choice

- [ ] **Vanilla attitudes only:** fights occur only when the game's existing hostility says so.
- [ ] **Static lore matrix (recommended):** a small source table for known gang rivalries; no global civilian/player hostility changes.
- [ ] **NCA broad hostility:** import all selected NCA attitude overrides. More fights, higher mission-risk surface.
- [ ] **Dynamic encounter-only attitudes:** apply temporary relations only to the tagged encounter group, then restore/let the group expire.

If a static matrix is selected, choose rivalries (multi-choice):

- [ ] Maelstrom ↔ 6th Street
- [ ] Tyger Claws ↔ Valentinos
- [ ] Scavs ↔ most gangs
- [ ] Wraiths ↔ Aldecaldos/Militech/6th Street/Scavs
- [ ] Valentinos ↔ 6th Street/Maelstrom/Scavs
- [ ] NCPD/Militech ↔ selected criminal gangs
- [ ] Voodoo Boys ↔ selected gangs
- [ ] Arasaka/Kang Tao corporate conflict

### 4.9 Authority intervention — single choice

- [ ] Never; only gangs fight.
- [ ] Rare district-gated response (recommended): one authority wave at high encounter heat, with a long cooldown.
- [ ] Frequent authority response; can overproduce wanted-state/police AI and compete with NCPD mods.

If enabled, choose responders (multi-choice):

- [ ] NCPD
- [ ] Militech (Badlands/Santo Domingo)
- [ ] Barghest (Dogtown)
- [ ] Arasaka (City Center/Northside)
- [ ] Kang Tao (City Center)

### 4.10 AI hand-off — multi-choice

- [ ] Reuse `MBAI_ActorEligible`/`MBAI_EnemyEligible` gates.
- [ ] Permit MuchBetterAI fireteam coordination after a short attach delay.
- [ ] Permit cover/reposition/netrunner behaviors for encounter actors.
- [ ] Do not inject movement commands while the actor has an authored command, workspot, scene, grapple, or limb mobility failure.
- [ ] Do not change global AI cadence or marksmanship values for this feature.

### 4.11 PCF retreat behavior — single choice

- [ ] **Vehicle-first (recommended):** winners return to their assigned vehicle when within 50 m; otherwise run 300 m away.
- [ ] **Foot-first:** all winners leave on foot; lower vehicle-command risk but less immersive for traffic gangs.
- [ ] **Vehicle-only:** actors with no reachable vehicle remain; can leave statues behind.
- [ ] **No retreat:** rely on vanilla despawn.

For the refactor, choose eligibility:

- [ ] Only records/actors tagged `StreetActivity.Encounter`.
- [ ] Tagged encounter actors plus `m_pcfRetreatOptIn` callers.
- [ ] All autonomous hostile gangers outside scenes. **Higher risk; not recommended.**

### 4.12 Cleanup and persistence — multi-choice

- [ ] All new entities `persistState = false` and `persistSpawn = false`.
- [ ] Delete encounter-owned dead entities after they are distant from the player and no longer needed.
- [ ] Never delete an entity in active combat, a scene, a vehicle mount transition, or a quest-owned group.
- [ ] Remove all encounter-owned entities on player detach/save transition.
- [ ] Leave vanilla/NCTO traffic entities to their own population system.
- [ ] Do not alter save files, quest records, or vanilla world activity completion states.

### 4.13 Difficulty and rewards — single choice

- [ ] **Vanilla stats/rewards (recommended):** encounter actors use normal level/health/loot; existing health curve applies once.
- [ ] Spawned actor health multiplier 1.0–1.25 only; no extra damage multiplier.
- [ ] Spawned actor health multiplier 1.5+; **not recommended** with current 6x elite curve and limb survival.
- [ ] No special loot/XP; use normal game drops.
- [ ] Fixed small reward bonus. **Requires explicit design and economy review.**

### 4.14 Reaction/stim profile — single choice

- [ ] **Vanilla-compatible:** only add `VehicleHit`/`HijackVehicle` combat eligibility with safe guards.
- [ ] **Balanced (recommended):** add the above plus selected `CombatStimuli`/`BumpStimuli` changes, bounded by cooldown and range.
- [ ] **High-density:** remove most NCA crowd suppressors and use aggression 20. **Only after runtime profiling.**

### 4.15 Traffic light/speed extras — multi-choice

- [ ] Keep NCTO traffic lights fixed: dynamic headlights off in daytime, utility lights on.
- [ ] Keep NCTO traffic speed defaults.
- [ ] Apply a source-controlled speed increase to selected traffic classes.
- [ ] Omit vehicle light logic to reduce hook surface.
- [ ] Do not make vehicle lighting a prerequisite for encounter logic.

### 4.16 Logging and diagnostics — single choice

- [ ] **Diagnostics off (recommended):** no runtime logs; retain only compile evidence.
- [ ] Bounded error-only logging for native/API failures, automatically compiled out after validation.
- [ ] Temporary verbose encounter trace during runtime testing, then remove before final completion.

The repository's current policy favors the first option. No CET console or Mod Settings debug toggle is permitted.

### 4.17 External integrations — multi-choice

- [ ] Existing MuchBetterAI only.
- [ ] Existing EnemyMultiplier/Codeware DynamicEntitySystem only.
- [ ] Existing NCTO/PCF bridge only.
- [ ] Reinforcements System/Gang Vs Gang source-port later, after removing its Mod Settings dependency.
- [ ] NCPD Prevention/Law Enforcement Overhaul integration later, only through optional compile guards and verified records.
- [ ] No third-party optional integration; keep the core self-contained.

### 4.18 Vehicle roster policy — single choice

- [ ] Vanilla/NCTO vehicles only.
- [ ] Curated installed-only Factions Evolved list (recommended).
- [ ] All Factions Evolved 2.50 records after a TweakXL load audit.
- [ ] NCPD/utility subset only.

For every imported vehicle, the implementation must check its base record and remove the YAML/source entry if the asset is not intentionally installed. A runtime string check is not sufficient protection against a TweakXL load-time missing base.

### 4.19 Build organization — single choice

- [ ] Keep NCTO namespace and replace its source files in place; add a small `StreetActivity` bridge.
- [ ] **Hybrid (recommended):** fixed NCTO fork remains under `NightCityTrafficOverhaul`; new scheduler/spawner/eligibility/retreat code lives under `StreetActivity`.
- [ ] Rename all imported NCTO/NCA code to `StreetActivity`; cleanest long-term namespace, largest merge and compatibility effort.

### 4.20 Validation stage — single choice

- [ ] **Compile-only first (recommended/current user instruction):** static checks, `sync_and_compile.sh`, inspect compiler log, no game launch.
- [ ] Compile plus later manual menu smoke test after explicit approval.
- [ ] Full runtime encounter test matrix after explicit approval.

---

## 5. Recommended baseline if the choices are not yet marked

This is a proposal only; it is intentionally not written as a final implementation decision:

- Scope **C**; NCTO base **A**; Factions **B + D**; NCA **B + D**; PCF **C**.
- Traffic **Balanced**; one secondary gang pool per district; modest 5–10% incursion weight.
- Encounter seeds from existing gang proximity/traffic contact, with a small explicit DES wave only when a seed is observed.
- Balanced pacing, two active encounters maximum, 3–5 actors per encounter, one escalation wave at most.
- Shared EMRS budget: StreetActivity reserves at most 8 of the existing 24 slots; 2 dynamic actors per scheduler tick.
- Static lore relationship matrix, not global hostility; authority intervention rare and district-gated.
- Vanilla/normal stats and rewards; no additional health or damage multiplier.
- PCF vehicle-first retreat for tagged encounter actors; 300 m foot fallback.
- Nonpersistent entities, distance/death cleanup, no save modifications.
- Diagnostics off; compile-only validation first.

This produces more street life without turning every crowd bump into a city-wide battle or creating a second unbounded NPC-spawn system.

---

## 6. Implementation phases after decisions

### Phase 0 — Freeze the design

- Resolve every checkbox in this document.
- Record the chosen constants in one source table, not multiple files.
- Confirm no selected option requires CET, Lua, Mod Settings, RedFunctions, localization, or a new native plugin.

### Phase 1 — Import and normalize source

- Copy only selected source/runtime payloads from temporary extraction into Git-controlled paths; do not keep downloaded archives.
- Do not copy upstream `NCTOsettings.reds` annotations, NCA's old district/traffic hook, or optional config/localization files.
- Remove optional RedLogger/diagnostic branches from the fixed profile.
- Rename or isolate symbols where two upstream modules wrap the same private engine method.

### Phase 2 — Fixed NCTO traffic profile

- Port the 2.50 district DB and current 2.5 registry probing.
- Replace settings reads with immutable constants.
- Add idempotence/bounds/deduplication guards.
- Remove broken reset behavior and runtime enable/disable code.
- Import only selected TweakXL files and only verified vehicle records.
- Keep the NCTO `.archive` only if the selected traffic profile actually references it.

### Phase 3 — Reaction/attitude bridge

- Merge one intentional `ReactionManagerComponent` wrapper chain.
- Preserve vanilla fallback on null/unsupported events.
- Add safe weapon, safe-area, scene, navmesh, distance, and cooldown gates.
- Port only the selected stimulus/attitude subset.
- Verify that Cazanu, MuchBetterAI, and other existing wrappers still call their wrapped methods exactly once.

### Phase 4 — Shared encounter allocator

- Refactor EMRS's queue/cap/deletion bookkeeping into a callable allocator or add a narrow public request API.
- Enforce the selected reserved budget and 24 global hard cap.
- Spawn explicit records or approved clones through Codeware DES, delayed when invoked from a native event callback if required.
- Tag every entity for ownership, PCF retreat, and cleanup.
- Never persist new entities.

### Phase 5 — Encounter scheduler and AI hand-off

- Add one bounded scheduler tick, cooldown ledger, and per-district/faction pair keys.
- Use existing event candidates rather than a global actor scan.
- Apply MuchBetterAI eligibility and wait for entity attachment before AI commands.
- Start fights only in open-world, non-quest, non-safe, non-scene contexts.
- Keep group sizes and escalation within the selected budget.

### Phase 6 — Retreat/cleanup integration

- Port PCF's seat reservation, driver promotion, drive-off retry, and foot fallback logic.
- Make `StreetActivity.Encounter` ownership explicit.
- Remove encounter-owned dead/distant dynamic entities safely through DES.
- Ensure no vehicle traffic slot, quest actor, or vanilla population entity is deleted.

### Phase 7 — Compile-first validation

Run, in order:

```bash
git diff --check
bash -n sync_and_compile.sh native_plugins/UniversalAimFlashlight/build.sh launch-cyberpunk2077-proton-experimental.sh
./sync_and_compile.sh
```

Then inspect `r6/logs/redscript_rCURRENT.log` for `Compilation complete`, `Output successfully`, and no failure line. Inspect the source diff for accidental `CET`, `ModSettings`, `RedFunctions`, Lua, localization, archive-download, or diagnostic additions. Do **not** launch the game in this phase.

### Phase 8 — Runtime validation (only after explicit approval)

If and when approved, test one subsystem at a time: traffic registry, one gang seed, one dynamic actor, PCF retreat, authority intervention, save/load cleanup, and performance. Inspect current RED4ext/redscript logs and stop immediately on a crash, repeated spawn, stuck AI, missing vehicle record, or mission interference.

---

## 7. Acceptance criteria

### Source and dependency criteria

- No CET/Lua/Mod Settings/RedFunctions dependency or code path.
- No downloaded archive, checksum ledger, backup tree, manifest, or generated inventory added.
- No upstream NCA 2.31 traffic hook or old district table remains in the 2.5 profile.
- NCTO/Factions data is either intentionally selected or absent; no duplicate module definitions.
- Vehicle and character records are verified before TweakXL import.

### Logic and stability criteria

- One bounded scheduler; no per-frame global NPC scan.
- Shared DES/EMRS cap remains 24; all spawned entities are tagged, nonpersistent, and owner-tracked.
- Safe-area, quest, scene, workspot, companion, named/boss/MaxTac/officer/civilian/crowd gates work before spawning.
- Reaction wrappers call vanilla exactly once and fail closed on null/unsupported events.
- PCF retreat only touches encounter-owned/tagged actors and never deletes vanilla quest/population entities.
- Encounter stats/rewards are applied once through the existing pipeline.
- Repeated streaming callbacks do not duplicate traffic entries.

### Validation criteria

- `git diff --check` and shell syntax checks pass.
- `sync_and_compile.sh` succeeds and the current compiler log has no errors.
- Runtime tests, when approved, show no repeated spawns, stuck vehicles, post-combat statues, mission actor changes, or obvious frame-time spikes.
- README/design notes are updated only for actual selected dependencies and behavior.

---

## 8. Known non-goals

- This plan does not add a new UI, settings menu, localization, phone call, quest chain, or map marker.
- It does not turn the entire pedestrian crowd into hostile combatants.
- It does not make bosses/MaxTac/officers/civilians eligible for EMRS-style cloning.
- It does not alter the current Cazanu limb rules, the current enemy health curve, the 2.5x player speed modifier, or unrelated cyberware behavior.
- It does not promise literal vehicle physics for on-foot movement or unlimited city-wide combat.

---

## 9. Verified local integration evidence

This section records evidence from the current installed framework and source tree, not an assumption based on an upstream page:

- The newest local Codeware log reports **Codeware 1.21.1 initialized successfully** and loaded 127,623 predefined hashes.
- The installed Codeware API exposes `DynamicEntitySpec`, `DynamicEntitySystem.CreateEntity`, `DeleteEntity`, `RegisterListener`, and `OpenWorldSystem.StartActivity`/`StartActivities`.
- The current `EnemyMultiplierRedscript` already owns the dynamic-entity lifecycle, queueing, navmesh placement, owner tracking, cleanup, and the hard 24-clone ceiling. It exposes `Enqueue`, `CloneCount`, `PendingCount`, and `PoolCount`, but not yet a general encounter-spawn allocator; that is the main refactor seam if the shared-budget option is selected.
- Codeware's world documentation confirms that fully functional NPCs/vehicles should use a `recordID` pointing to a `SpawnableObject`; using only a template path may produce incomplete NPC/vehicle behavior. It also documents temporary IDs for nonpersistent entities, tag-based lifecycle callbacks, and `Entity/Attached`/`Entity/Detach` event handling. The allocator must therefore use verified `Character.*` records, `persistState = false`, `persistSpawn = false`, explicit ownership tags, and attach/detach callbacks rather than storing long-lived raw object references.
- The current redscript baseline remains compile-successful from the previous validation (`Compilation complete`, `final.redscripts.modded`). This planning turn did not launch the game and did not alter gameplay source.

These observations support the recommended architecture, but they do **not** prove that arbitrary activity names, vehicle records, or faction records are valid. Those must be discovered or validated during implementation.

## 10. Sources and technical references

- [Night City Traffic Overhaul — Nexus 25552](https://www.nexusmods.com/cyberpunk2077/mods/25552)
- [NIGHT CITY ALIVE — Nexus 10395](https://www.nexusmods.com/cyberpunk2077/mods/10395)
- [Factions Evolved — Nexus 25873](https://www.nexusmods.com/cyberpunk2077/mods/25873)
- [Spawned NPC Post Combat Fix — Nexus 32862](https://www.nexusmods.com/cyberpunk2077/mods/32862)
- [Reinforcements — Gang Vs Gang — Nexus 24243](https://www.nexusmods.com/cyberpunk2077/mods/24243) (studied as a possible future source-port, not a current dependency)
- [Codeware — GitHub](https://github.com/Cyberpunk2077-Mods/Codeware)
- [Codeware world/lifecycle documentation](https://github.com/psiberx/cp2077-codeware/wiki)
- [Codeware DynamicEntitySpec API](https://github.com/psiberx/cp2077-codeware/blob/main/scripts/World/DynamicEntitySpec.reds)

