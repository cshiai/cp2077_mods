# Adversarial review — 26 October 2026

## Scope

Reviewed all 115 active REDscript sources, 27 TweakXL inputs, ArchiveXL
extensions, the guarded Proton launcher, sync/compile path, and current
RED4ext/TweakXL/ArchiveXL logs. The review targeted null dereferences, stale
entity references, invalid array indices, delayed-callback lifecycle,
duplicated stat modifiers, TweakXL inheritance errors, and current-build load
failures.

## Fixes applied

### Framework and integration

* Removed the two ambiguous `MovementActions.MeleeRingSelector.actions` and
  `DefaultRingSelector.actions` edits. Parent selector edits remain, so the
  intended action reachability is preserved without the TweakXL type-inference
  error.
* Removed The Nullifier's stale 2.5 node-1250 proxy-mesh deletion. The current
  sector reports that node as `worldCookedCollisionNode`; omitting that stale
  entry lets the remaining ArchiveXL patches apply instead of rejecting the
  whole sector.
* Added defensive callback/resource/map guards to The Nullifier and fixed its
  dormant photo-mode path to test the cast restriction object rather than the
  loop variable.

### Cyberware and equipment

* Added `CyberwareFlavorDescriptions.reds`, a CET-free replacement of the
  post-2.0 cyberware description hide predicate. Only the explicit cyberware
  exclusion is removed; crafting, upgrade, grenade, consumable, material, and
  skillbook rules remain vanilla.
* Guarded Cyberware-EX equipment data, transaction systems, player/UI objects,
  missing equipment areas, empty inventory records, opposite-slot indices, and
  quickhack HUD/player references.
* Hardened Universal Slots against missing choosers, transaction/scriptable
  systems, empty UI slot widgets, and invalid installation state.

### Combat, Cazanu, and health

* Cazanu limb, crawl-blood, seated-combat, and arm-cleanup paths now fail
  closed when time/stat-pool/transaction/delay/workspot/resource/static-entity
  systems are unavailable; event and hit-shape inputs are validated before
  use.
* Enemy health scaling now guards the player system, compensates player damage
  for every scaled NPC including Boss/MaxTac, and retains the requested
  smoother 2.5×→6× curve with 0.3% max-health/sec enemy regeneration.
* Apex incoming damage, player max-health/stamina, and passive regeneration
  hooks now check required stat systems before adding modifiers.
* Lethal Enemy Netrunners now guard AI components, quickhack records, sensor
  events, and stats; reveal cleanup uses the proxy's own entity ID.
* Black Chrome has bounded 64-stack application loops, valid-game fallbacks,
  nonnegative resource deltas, and null-safe aux-deck action enumeration.

### Much Better AI

* Cadence validates weapon records/evolution/blackboards before access.
* Actor eligibility and punish-window callbacks guard absent workspot, scene,
  targeting, and system interfaces.
* Stealth, fireteam, snapshot, capability, acoustic, and punish-window systems
  now fail closed when delay, targeting, blackboard, stat-pool, or gameplay
  package services disappear during teardown or load transitions.

### Second compile-only hardening pass

* Added a shared Cazanu workspot-ownership guard and applied it to crawl,
  seated, grounded-death, final-blood, and diagnostic paths; missing workspot
  services no longer become null dereferences or accidental pose steals.
* Added guarded time, delay, transaction, and stat-pool access to Cazanu's
  follow-up diagnostics and blood/death controllers.
* Added a shared Much Better AI delay-cancellation guard and null-safe periodic
  scheduler setup across search, cover, fireteam, nerve, reposition,
  temperament, and watchdog systems.

### Third compile-only hardening pass

* Guarded Blur Begone notifications, EnemyMultiplier scheduling, cyberware UI
  events, QuestGuide popup/rebuild events, and Instant Breach blackboard access.
* Added null-safe difficulty lookup for lethal netrunner hacks and guarded the
  remaining Cazanu static-entity/status-effect paths.
* Added fail-closed guards to remaining Much Better AI capability, snapshot,
  fireteam, and punish-window service lookups.
* Completed a final static-chain sweep across the active tree: remaining
  Cazanu, QuestGuide, CyberwareEx, Blur Begone, and health-scaling service
  accesses now guard teardown-time nulls or stale lifecycle flags.

### Diagnostics and movement follow-up

* Confirmed Cazanu diagnostics are hard-disabled, the Much Better AI logger is
  error-only, the acoustic trace probe is a literal `false`, and clone
  telemetry is permanently silenced (the EnemyMultiplier log helper is now a
  no-op while gameplay settings remain fixed).
* Audited all active `MaxSpeed` references. `FastWalkNoRestrictions150` is the
  only player-wide 2.5x modifier; Black Chrome speed records are scoped to
  equipped cyberware. Hardened the fast-walk modifier for missing stat systems
  and invalid IDs, made reapplication remove-first/idempotent, and added one
  delayed post-attach/re-surrect reapply to survive save-load and equipment
  stat-container rebuilds without a per-frame timer.

### Historical crash artifacts

* Inspected the Proton-prefix REDEngine queue: 15 directories dated 23–25
  October contain two 120-second watchdog asserts and several symbol-less
  access violations. The earliest watchdog reports still load CET; a subset of
  later reports load the older UniversalAimFlashlight binary. These artifacts
  predate the current 26-October source/DLL and contain no usable stack symbols,
  so they are not evidence of a current mod regression. No post-hardening game
  launch or crash report exists; the reports were left untouched.

## Validation evidence

* `./sync_and_compile.sh`: PASS at 13:16:19 EDT; `Compilation complete` and
  `final.redscripts.modded` written.
* `git diff --check`: PASS.
* `bash -n sync_and_compile.sh native_plugins/UniversalAimFlashlight/build.sh
  launch-cyberpunk2077-proton-experimental.sh`: PASS.
* Guarded helper status/dry-run: Steam build `26161058`, `build_guard=pass`,
  115 scripts and 27 tweak inputs; no game process was started.
* Existing runtime evidence (from the earlier approved smoke run) shows
  RED4ext 1.31.0 initialized, all seven expected plugins loaded,
  `scc invoked successfully`, TweakXL import/execution completed, and
  ArchiveXL loaded both extensions and merged Black Chrome translations.
  No new game launch was performed for this pass, per the user's
  compilation-first instruction.

## Remaining uncertainty

The prior logs prove current-build startup, script compilation, TweakXL import,
and ArchiveXL patch/localization loading. The latest pass proves compilation
and static integration only; it intentionally does not claim a post-edit
runtime launch. No available log contains player velocity or combat telemetry,
so source review cannot empirically prove the movement multiplier in a live
encounter. A later approved gameplay matrix should hover a vanilla and Black
Chrome cyberware item, measure walk/sprint distance, trigger a Cazanu limb loss
and natural DOT kill, exercise a Boss/MaxTac damage case, create/dismiss a clone
wave, and test seated combat/quickhack reveal. Diagnostics and clone verbose
logging remain disabled, so those behavioral traces are intentionally absent
from normal logs.
