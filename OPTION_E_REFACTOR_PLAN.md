# Option E — full-refactoring plan

This is the implementation plan for the current Git worktree.  It is a source
plan, not an installation manifest: Git history is the only rollback mechanism
and no downloaded archive, checksum ledger, or backup tree is part of the
work.

## Non-negotiable behavior and scope

The refactor is ordered so that correctness and hook safety come before tuning.
The existing CET prohibition, optional (not installed) Mod Settings behavior,
Proton/NVIDIA launch policy, save-data policy, and build guard remain in force.
The following items are deliberately **not** behavior targets and must remain
unchanged: COM-04; PR-05; PR-06; PR-09; PR-10; UX-03; and UX-07.  PR-02 may be
split into smaller implementation units, but its current player-visible
behavior and numbers must be preserved.  PR-07 continues to provide the
currently working ammo-capacity x10 effect.

Unless a later test demonstrates a reason to choose 3%, Cazanu uses a single
documented **5% of maximum health** floor.  The value is centralized so it can
be changed to any value in the requested 3–5% range without another logic
rewrite.  The clone limit remains exactly 24.

## Ordered workstreams

### 0. Baseline and contracts

1. Record the current source/compile state with Git status and a clean diff
   check; do not create filesystem copies.
2. Build a small behavior matrix for every changed hook: vanilla call order,
   return-value contract, optional dependency, ownership of mutable state, and
   cleanup path.
3. Keep each change localized to its owning module.  Shared helpers are added
   only when they remove a demonstrated duplicate or hook collision.

### 1. C0–C6 critical correctness pass (highest priority)

* **C0/C-01 — vanilla-call preservation:** repair wrappers such as
  `PlayerDevelopmentData.HandleAddingPerkLevel` so the wrapped method is
  called exactly once before/after the custom delta as intended.
* **C0/C-02 — return contracts:** audit every `Bool` replacement/wrapper and
  return the vanilla result when a wrapper has one; replacements return an
  explicit success/failure value.  No implicit default returns remain.
* **C0/C-03 — hook ownership/order:** identify colliding wrappers and give
  each high-risk method one coordinator/owner.  Preserve both features by
  calling narrowly scoped helpers from that owner; remove early returns that
  bypass another feature.  Priority collisions are DoubleJump decisions,
  iconic-tier/ammo hooks, slot tables/UI, Cazanu wound processing, and player
  attach/death hooks.
* **C0/C-04 — optional data safety:** guard every optional `GameObject`/record,
  equipment index, static-data tag lookup, UI widget, and array access before
  dereference.  Rebuild attachment/mod collections idempotently instead of
  retaining stale entries between refreshes.
* **C0/C-05 — state and transaction safety:** make TweakDB/stat writes and
  equipment mutations one-time or explicitly reversible; never clear a
  collection owned by another mod.  Preserve vanilla/quest restrictions when
  broadening convenience checks.
* **C0/C-06 — lifecycle/performance:** pair every listener, timer, entity, and
  modifier registration with cleanup; make repeated attach/load/unload safe;
  bound scans, raycasts, UI rebuilds, and log volume.  Add focused comments for
  any engine API whose lifetime is not obvious.

Validation gate: redscript compiles with no errors, and a static audit finds no
unowned high-risk wrapper or implicit Bool return in the touched modules.

### 2. Cazanu and combat (COM-03)

1. Centralize the 5% health-floor constant and apply it only to tracked
   Elite/Rare/Boss/MaxTac enemies.  Mechanical, civilian, crowd, companion,
   player, unknown-rarity, and ordinary human NPCs are ineligible.
2. Remove every Cazanu path that zeros damage or clears bleeding, burning,
   poison, or electrocution from a survivor.  Natural DOTs remain available;
   limb protection is the only protection supplied by this system.
3. Keep wound/crawl timing semantics unless a correctness test requires a
   change.  Make tracking, dismemberment, and forced-death cleanup idempotent.
4. Implement COM-03's recommended bounded work: throttle blood/obstacle probes,
   cache stable probes for a short interval, avoid repeated workspot searches,
   cap per-tick work by distance/active survivor count, and reduce redundant
   marks/raycast groups without changing combat outcomes.

### 3. Enemy systems (COM-04–COM-07)

* **COM-04:** no source edit; retain the current smootherstep health curve and
  regeneration behavior exactly.
* **COM-05:** correct only the post-hit health scaling correction so it cannot
  multiply unrelated attack components or undo vanilla damage.  Keep the
  current curve and difficulty values unchanged.
* **COM-06:** retain `maxClones = 24`; require a hostile combat enemy (not a
  generic NPC, civilian, neutral ganger, crowd, or companion), explicitly allow
  Elite (and the existing Rare policy), and make clone creation/deletion and
  tracking cleanup exception-safe and idempotent.
* **COM-07:** preserve lethal-netrunner intent while fixing event return values,
  duplicate status/modifier registration, and removal of reveal/proxy effects
  on hack completion, puppet death, unload, and failed target resolution.

### 4. Player/gear systems (PR-01–PR-10)

* **PR-01:** narrow attachment/prerequisite bypasses to valid player-owned
  equipment and intended item categories; preserve broken, quest, and invalid
  slot protections.
* **PR-02:** if useful, split iconic conversion, saved-stat packages, and
  disassembly policy into helpers/modules, but preserve all current eligibility,
  stat values, and player-visible behavior.
* **PR-03:** make universal slot/attachment replacement null-safe, idempotent,
  and transactionally rebuilt; do not leave stale mods or duplicate slots.
* **PR-04:** harden CyberwareEx indices, optional records, perk callbacks,
  listener cleanup, and slot creation while preserving its intended features.
* **PR-05/PR-06:** no behavior or tuning changes; only compile-fix a shared
  contract if a C0 fix proves it is required.
* **PR-07:** keep ammo capacity x10 as the sole active effect.  Replace broad
  “remove all saved modifiers” operations with ownership-aware removal (a
  marker/registry for only this mod's modifiers), including reload and
  uninstall paths.
* **PR-08:** harden attachment crafting recursion, null handling, and
  transaction cleanup without changing recipes or costs.
* **PR-09/PR-10:** leave level-cap and parkour/fast-walk behavior untouched.

### 5. UX systems

* **UX-01:** retain instant scanner behavior while avoiding per-frame/per-NPC
  queue churn; apply duration changes once at scan start and restore state on
  completion/cancel.
* **UX-02:** retain instant-upgrade behavior with a transaction/debounce guard
  so one input cannot spend resources or fire callbacks twice.
* **UX-03:** no source or behavior change.
* **UX-04:** remove `Nexus34645_AutoContinue` source and stale game-side script;
  keep unrelated Nexus startup code only if it has an independent purpose.
* **UX-05:** make QuestGuide indexing/counting bounds-safe and incremental;
  debounce refreshes and keep localization/settings optional.
* **UX-06:** use a balanced flashlight profile (moderate range/intensity and
  one shadowed main light) with ray-tracing contribution explicitly disabled;
  rebuild the native plugin and keep its REDscript companion in sync.
* **UX-07:** no behavior/default change to The Nullifier.

### 6. Build, documentation, and verification

1. Update `README.md` source map/dependency notes for removed AutoContinue,
   new ownership/configuration points, and the balanced flashlight profile.
2. Run `git diff --check` and shell syntax checks after each workstream.
3. Run the native build when C++ changes, then `sync_and_compile.sh`; inspect
   the current `redscript_rCURRENT.log` and current RED4ext log.
4. Exercise focused smoke tests: load/save, elite Cazanu DOT and dismemberment,
   hostile/elite clone cap, netrunner hack cleanup, gear modifier preservation,
   QuestGuide refresh, instant UI paths, and flashlight startup.
5. Keep diagnostics enabled during the first combat verification, then disable
   them once evidence is collected.  Do not claim full current-build runtime
   success when the launcher build guard or missing upstream compatibility
   prevents that test.

## Completion criteria

The goal is complete only when every requested workstream is either implemented
and compiled/tested or has a clearly documented, reproducible external blocker;
the untouched-item matrix is verified; no unrelated rule (especially the CET
ban) changed; and the final report lists exact files changed, tests run, current
runtime evidence, and remaining uncertainty.
