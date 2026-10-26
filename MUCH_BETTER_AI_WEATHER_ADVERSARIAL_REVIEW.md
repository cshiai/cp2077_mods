# Weather Probability Rebalance + Much Better AI

## Review scope

This review covers the two newly downloaded packages received on 25 October
2026:

* **Weather Probability Rebalance 2.10** — one archive payload,
  `weather_probability_rebalance.archive`.
* **Much Better AI 2.3** — 80 REDscript files, six TweakXL YAML files, and
  five CET Lua files (`init.lua`, `settingsManager.lua`, `nativeSettingsUI.lua`,
  `localizer.lua`, and `logger.lua`).

The downloaded ZIP/RAR files were extracted to a temporary directory, reviewed,
copied selectively, and deleted. They are not part of the repository.

The supplied RAR listing did not include a README or explicit license file;
the package/version labels above are the local download labels. This tree is a
personal source integration, not a redistribution package.

## Findings and decisions

### Weather Probability Rebalance

The weather package is archive-only. It contains no REDscript, TweakXL,
Mod Settings, CET, RED4ext DLL, or configuration file. It is therefore safe to
ship as `archive/pc/mod/weather_probability_rebalance.archive`. It changes the
weather probability data only; it does not compete with the source hooks in
The Nullifier. Its interaction with the user's other visual archives is an
asset load-order question for runtime testing, not a script/API conflict.

### Much Better AI settings surface

The original package made every gameplay decision pass through a CET Lua
settings store and then used `Override()` to replace 100-plus REDscript
accessors. That design was unsuitable here:

* it required CET and its Lua lifecycle;
* it wrote a mutable JSON file outside Git;
* it added a large Native Settings UI and 18 localization packages for a menu
  that is intentionally unavailable in this profile;
* its `onInit` TweakDB edits were not reproducible from the source tree; and
* several switches could change hook ownership or enable expensive global
  scans while a save was running.

The integrated profile now has **no CET Lua, no settings JSON, no Native
Settings UI, no Mod Settings annotations, no localization package, and no
runtime config class**. The upstream settings values are fixed in the
reviewed REDscript logic. Changes must be made through Git and a compile, so
there is one deterministic gameplay profile rather than a hidden per-machine
override.

### Rewiring the former CET bootstrap

`r6/tweaks/MuchBetterAI/static-integration.yaml` is the deterministic TweakXL
replacement for the Lua `ApplyModuleTweaks()` routine. It uses `append-once`
for the action arrays and retains vanilla records rather than replacing whole
graphs. It carries over:

* punish-window actions and melee block/parry branches;
* weapon-ring discipline actions;
* threat-hop/strafe actions and the catch-up condition;
* field-medicine action reachability; and
* the fixed alert-memory, ticket-capacity, and strafe-cooldown values.

The REDscript side remains authoritative for hostility, rarity, visibility,
cooldowns, ownership leases, and fireteam/nerve arbitration. The YAML only
makes the reviewed actions reachable from vanilla graphs. No mutable setting or
file-backed parameter remains.

### Code trimming and safety fixes

The following dead or unsafe surfaces were removed:

* the entire upstream localization tree and settings/config source;
* the disabled combat-audit timer, which woke every few seconds only to return;
* the response-order persistence stubs and tagged dynamic-entity cleanup,
  which had no producer/consumer in the imported package and could delete
  unrelated entities carrying the same tag;
* additive game-side copies of those retired files are explicitly removed by
  `sync_and_compile.sh` so an old extraction cannot resurrect them.

The integrated code also adds or preserves:

* snapshot cache reuse until the player has moved three metres (the upstream
  `> 0.0` test defeated its own cache);
* null guards for missing scriptable systems, targeting players, actor movement
  components, puppet blackboards, TweakDB character/affiliation records,
  projectile events, and door/action events;
* bounded hostile-actor eligibility and the existing workspot, follower,
  civilian, paperdoll, and authored-control checks;
* collapsed fixed-profile branches in marksmanship, cadence, netrunner,
  grapple, sensor, acoustic, movement-policy, and counter-perch code so the
  removed settings switches do not leave dead runtime paths;
* wrapper chaining (`wrappedMethod`) for every remaining AI hook, including the
  overlapping `ShootEvents`, `StimBroadcasterComponent`, `DoubleJumpEvents`,
  `AICondition`, and `NPCPuppet.OnDeath` chains;
* soft `ModuleExists` compatibility only for optional Immersive Shooting AI and
  AI Trigger Overhaul integrations; neither is a hard dependency; and
* the existing Cazanu, enemy-health, clone, player, UX, and Codeware,
  and CET-ban policies unchanged.

## Compatibility matrix

| Surface | Result |
|---|---|
| CET / CET Lua / CET console | Removed; no package path is copied or invoked |
| Mod Settings | No Much Better AI usage; pre-existing optional Mod Settings annotations in unrelated modules remain guarded and are not made hard dependencies |
| redscript | All 106 repository `.reds` files compile in the current offline pass |
| TweakXL | 11 YAML inputs; Much Better AI static integration has unique top-level keys and uses additive `append-once` edits |
| Codeware | Still required by the existing CyberwareEx/QuestGuide framework; Much Better AI no longer imports Codeware localization |
| ArchiveXL | Weather payload is an ordinary archive asset; no new ArchiveXL API hook |
| Existing combat hooks | Chained wrappers call `wrappedMethod`; no new replacement hook was introduced |
| Saves | Not read, altered, migrated, or deleted |

## Validation and remaining uncertainty

Completed checks:

```text
./sync_and_compile.sh                         PASS (Compilation complete)
redscript output                               PASS (final.redscripts.modded)
Much Better AI CET/settings surface scan      PASS (no matches)
TweakXL top-level duplicate-key scan           PASS
game-side retired-source cleanup               PASS
compiled blob contains MuchBetterAI symbols    PASS
game-side weather/static-tweak payloads        PASS
guarded Proton helper refuses build 26161058   PASS
```

The last compile completed at 19:28:37 EDT on 25 October 2026. The sync script
also passed its fixed-profile CET/settings guard. The installed Steam manifest
is build `26161058`, which the repository policy still marks unvalidated, and
no approved launch helper is present in this checkout. This is compile
and static integration evidence, not proof that every TweakDB record exists on
the currently installed Steam build. The current RED4ext runtime log predates
this import, and the maintained launch helper/build guard is not available in
this checkout for an approved post-change game smoke test. Before calling the
AI/weather profile runtime-complete, launch through the approved Proton path,
confirm TweakXL applies `static-integration.yaml`, reach one ordinary combat
encounter and one stealth/door/vehicle case, then inspect the newest RED4ext
and redscript logs for hook initialization, missing-record warnings, crashes,
and frame-time regressions.

