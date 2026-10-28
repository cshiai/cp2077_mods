# Black Chrome 1.1.5 integration review

## Imported payload

The downloaded Black Chrome 1.1.5 ZIP was extracted to a temporary directory,
reviewed, copied into the source tree, and deleted. The installed payload is:

* `archive/pc/mod/BlackChrome.archive` and `BlackChrome.archive.xl`;
* 10 REDscript files under `r6/scripts/BlackChrome/`; and
* 16 TweakXL YAML inputs under `r6/tweaks/BlackChrome/`.

The upstream archive also contained a CET Lua bootstrap. It enumerated
currency reward records and appended `BlackChrome.RewardMultiplier`; it was not
installed. A pure REDscript `RPGManager.GiveReward` wrapper now applies the
player's `RewardBaseStatMultiplier` at the vanilla reward boundary, preserving
Sponsored Covering without a CET TweakDB scan.

## Dependency trimming

Black Chrome now uses only the existing ArchiveXL/TweakXL/redscript/RED4ext
chain. The optional `AlternativeBerserk` compatibility bridge was removed;
`ChipwareExpansion.ZetatechProcessor` remains a compile-time soft guard in the
CyberMonitor hooks and is not required. No CET Lua, Mod Settings, user.ini, or
new native dependency was added.

## Adversarial fixes

* Aegis validates hit data and clamps the configured deflection chance before
  mutating health damage or playing its sound.
* Berserk and Juice Tank validate hit targets, attack data, stat-pool systems,
  and nonzero max health; stack loops now terminate at one full stack instead
  of silently dropping exact-boundary damage.
* Smart Pump and Berserk activation validate equipment data, item IDs, action
  records, and created RPG actions before executing them.
* Cyberdeck helper functions handle missing owners/equipment data; quickhack
  list rebuilding handles missing player, aux-deck, and item records; tooltip
  hooks tolerate missing item data.
* CyberMonitor now returns the wrapped popup result and guards missing popup
  data instead of implicitly returning a default Boolean.
* Fortress Legs validates player/stats/hit data and clamps damage multipliers.
* The reward multiplier is applied once at `RPGManager.GiveReward`, keeping
  existing external money multipliers composable without mutating every reward
  record at runtime.
* PoolSystem now cancels delayed work on player detach, stores its delay ID,
  avoids stale player/stat handles, and uses a one-shot callback instead of a
  repeating callback that recursively scheduled another repeating callback.

## Validation

At 01:59:37 EDT on 26 October 2026, the full profile compiled successfully.
The compile list contains every Black Chrome REDscript file, the game-side
Black Chrome archive/Xl files are present, and no downloaded archive remains.
Runtime native startup remains covered by the current RED4ext/build smoke-test
policy; the source review does not claim every individual cyberware effect has
been exercised in an encounter.

