# FX Begone 2.3.0 + Load Begone 3.1.2 integration review

## Imported payloads

The two 26 October 2026 downloads were extracted to a temporary directory and
reviewed before installation:

* **FX Begone 2.3.0** — `FXBegoneNative.dll`, `FXBegone.reds`, and the
  generated `FXBegoneSettings.reds` registry.
* **Load Begone 3.1.2** — `LoadBegone.archive`, `LoadBegone.dll`,
  `LoadBegone.Native.reds`, `Config.reds`, `LoadingScreen.reds`, and
  `MainMenu.reds`.

The downloaded ZIP files and temporary extraction directory were deleted. No
download archive is tracked in the repository.

## Adversarial findings

### FX Begone

The native plugin is RED4ext-native and has no CET/Lua dependency. Its original
REDscript registry exposed a very large Mod Settings surface (effect toggles,
a low-health slider, debug switch, and a global “all effects off” switch). The
native DLL already accepts the resulting toggle/slider arrays through
`SetToggles()` and `SetSliders()`, so the menu was not required for the core
functionality.

The integrated profile therefore:

* removes every `@runtimeProperty("ModSettings.*", ...)` annotation;
* removes Mod Settings listener registration/unregistration and the change
  callback;
* applies the upstream defaults once from `OnAttach()`;
* keeps all effect toggles enabled, low-health threshold at `40.0`, and
  `allEffectsOff` disabled, preserving the package's default behavior; and
* keeps the native companion and REDscript companion together under
  `red4ext/plugins/FXBegone/`.

FX Begone's loop cleanup only stops effects reported by the native plugin on
the player; it does not remove gameplay status effects or alter saves.

### Load Begone

Load Begone is a RED4ext/native + REDscript/archive mod, not a CET mod. Its
original `LoadBegoneConfig` used Mod Settings annotations and a listener to
mutate a fresh config object. The fixed profile removes all annotations and
listener code; `LoadBegoneReadConfig()` now returns the source defaults.

The preserved fixed defaults are: launch into the last save, allow Esc to
return to the menu, zero extra delay, skip continuation prompts and recap
videos, skip the start screen and mod-verification popup, bypass the Dogtown
checkpoint, use 4× checkpoint timing if the native checkpoint path falls back,
and disable the checkpoint speed limit. These are now Git-controlled values,
not runtime parameters.

The 3.1.2 merge adds the upstream loading-screen callback bridge (recap-screen
tracking and voice-language handoff), start-screen busy detection, recap
metadata replay, and guarded black overlays that keep loading UI hidden until
the save transition is safe. The new native entry points are all wrapped with
`ModuleExists("LoadBegone.Native")` fallbacks, and the fixed profile still
contains no Mod Settings annotations or listeners.

The native API remains guarded with `ModuleExists("LoadBegone.Native")`, so a
missing native plugin fails closed for native-only operations rather than
creating a hard compile dependency. The archive, DLL, and REDscript API are
copied as one unit.

One intentional behavior remains visible: the fixed `skipModWarning` default
turns off the game's `EnableModVerification` user setting when Load Begone
loads a modded save. This is upstream behavior, not a hidden settings system;
change the source default if that policy is not desired.

## Framework integration fix

The initial sync script only supplied framework script directories to `scc`.
The new plugin scripts were therefore copied but not compiled. The sync loop
now also discovers:

```text
red4ext/plugins/FXBegone/scripts
red4ext/plugins/LoadBegone/scripts
```

The successful compile log now explicitly lists `FXBegone.reds`,
`FXBegoneSettings.reds`, and `LoadBegone.Native.reds` before writing
`final.redscripts.modded`.

## Validation

At 01:02:55 EDT on 26 October 2026:

* `sync_and_compile.sh` completed successfully;
* the compiler output contained both new plugin script paths;
* the game-side archive, DLLs, and scripts were present;
* no Mod Settings/CET references remained in either imported profile's source;
* shell syntax and Git whitespace checks passed; and
* no downloaded archive remained outside the source tree.

The current Steam build `26161058` is the guarded baseline and the latest
runtime log shows both native plugins loading cleanly. A focused in-game load/
FX smoke test remains useful, but the profile no longer blocks this build.

