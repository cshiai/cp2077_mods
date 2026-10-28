module ReFRACT

// Fixed source profile: constants are reviewed in Git; no Mod Settings/CET runtime layer.

// Matches Glass::InteriorRt and Settings.cpp. Dithered shows as Checkerboard, rename it and saved settings vanish
enum InteriorRtReflections {
  Simple = 0,
  Dithered = 1,
  Full = 2
}

// Keep in sync with GlassLayerNames in src/Settings.cpp
enum GlassRtLayerMode {
  Off = 0,
  ExceptInCars = 1,
  Always = 2
}

public native func SetEnabled(enabled: Bool) -> Void;
public native func SetFixes(refractionFix: Bool, thinGlass: Bool, vehicleInteriorReflections: Bool, crystalDomeReflections: Bool) -> Void;
public native func SetInteriorRtReflections(mode: Int32) -> Void;
public native func SetLayersFirstPersonOnly(enabled: Bool) -> Void;
public native func SetFirstPersonVehicle(inside: Bool) -> Void;
public native func SetInVehicle(inside: Bool) -> Void;
public native func SetInteriorOnlyInVehicle(enabled: Bool) -> Void;
public native func SetInteriorReflections(strength: Float) -> Void;
public native func SetBlackGlass(enabled: Bool, power: Float) -> Void;
// TDBID.None() on foot. Returns the car's crystal dome override, or -1 if it has none
// Vehicle mods can dial Full's cabin reflection per car with a <record>.refractInteriorReflections flat, 0 to 1
public native func SetVehicle(record: TweakDBID, appearance: CName, name: String) -> Float;
// True once per launch when another mod hogged the root signature and Full or the Glass RT Layer fell back to Simple
public native func TakeLayerBlockedWarning() -> Bool;
public native func DeviceHooked() -> Bool;
public native func SetDitherBlend(percent: Int32) -> Void;
public native func SetGlassLayer(enabled: Bool) -> Void;
public native func SetBackGlassLayer(enabled: Bool) -> Void;
public native func SetThirdLayer(enabled: Bool) -> Void;
public native func SetCrystalDomeStrength(strength: Float) -> Void;
// Saved per car and appearance, does nothing on foot
public native func SetCrystalDomeOverride(enabled: Bool, strength: Float) -> Void;
// on: see-through
public native func SetCrystalDomeOn(on: Bool) -> Void;
public native func SetCrystalDomeCheckerboard(on: Bool) -> Void;
public native func SetCarGlassCheckerboard(enabled: Bool) -> Void;
public native func SetCrystalDomeCabinShadows(on: Bool) -> Void;
public native func SetCrystalDomeSkyShade(on: Bool) -> Void;
public native func SetCrystalDomeScanlines(on: Bool) -> Void;
public native func SetFrontRefractionWins(enabled: Bool) -> Void;
public native func SetFireflyFilter(enabled: Bool) -> Void;
public native func SetFireflyStrength(percent: Int32) -> Void;
public native func SetRenderMode(tracedReflections: Bool, rayReconstruction: Bool) -> Void;
// Empty unless Blur Begone is too old, then the version we need. ReFRACT sits out until then
public native func BlurBegoneUpdateNeeded() -> String;

public class ReFRACTSettings extends ScriptableSystem {

  // ReFRACT 1.5.0's native D3D12 command-list hook is disabled on the
  // current Proton/MSVCP runtime.  The crash dumps stop in its _Mtx_lock
  // path (1a190/1a220) before any REDscript gameplay code runs; keeping the
  // native plugin loaded but inactive avoids the unsafe hook and its render
  // overhead until a rebuilt native companion is available.
  public let enabled: Bool = false;

  public let refractionFix: Bool = true;

  public let thinGlass: Bool = true;

  public let frontRefractionWins: Bool = true;

  public let vehicleInteriorReflections: Bool = true;

  public let interiorRtReflections: InteriorRtReflections = InteriorRtReflections.Full;

  public let ditherBlend: Int32 = 50;

  public let fullFirstPersonOnly: Bool = true;

  public let interiorOnlyInVehicle: Bool = true;

  public let interiorReflectionStrength: Float = 1.0;

  public let crystalDomeReflections: Bool = true;

  public let crystalDomeStrength: Float = 0.45;

  public let crystalDomeOverride: Bool = false;

  public let crystalDomeVehicleStrength: Float = 0.45;

  public let crystalDomeScanlines: Bool = true;

  public let glassRtLayerMode: GlassRtLayerMode = GlassRtLayerMode.Off;

  public let backGlassLayer: Bool = true;

  public let blackGlassReflections: Bool = false;

  public let blackGlassStrength: Float = 1.0;

  public let halfRateTracing: Bool = true;

  public let crystalDomeCabinShadows: Bool = true;

  public let crystalDomeSkyShade: Bool = true;

  public let refractionFireflyFilter: Bool = true;

  public let fireflyStrength: Int32 = 50;



  private let renderListener: ref<ReFRACTRenderListener>;
  private let vehicleData: ref<IBlackboard>;
  private let mountedCallback: ref<CallbackHandle>;
  private let cameraCallback: ref<CallbackHandle>;
  // Fixed source profile: no Mod Settings listener or runtime toggle.
  private func OnAttach() -> Void {
    this.Apply();
  }

  private func OnDetach() -> Void {
    this.renderListener = null;
    this.UnwatchVehicle();
    this.ForgetVehicle();
  }

  // Not OnAttach: at boot the graphics settings all read off, path tracing too, which is a lie
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if !this.enabled {
      return;
    }
    this.WatchRenderMode();
    this.WatchVehicle();
    // Wait out the loading screen, or nobody sees it
    let warning = new ReFRACTWarning();
    warning.settings = this;
    let delay = GameInstance.GetDelaySystem(this.GetGameInstance());
    if IsDefined(delay) {
      delay.DelayCallback(warning, 5.0, false);
    }
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.UnwatchVehicle();
    this.ForgetVehicle();
  }

  public func ShowWarning() -> Void {
    let update = BlurBegoneUpdateNeeded();
    if NotEquals(update, "") {
      this.ShowMessage("ReFRACT is off: this Blur Begone is too old for it. Update Blur Begone to " + update + " or later to use both.", 10.0);
    } else {
      if !DeviceHooked() {
        this.ShowMessage("ReFRACT couldn't reach the game's renderer, so glass looks vanilla. Please share the refractnative log from red4ext/logs on the mod page.", 10.0);
      } else {
        this.WarnIfBlocked();
      }
    }
  }

  // Shaders can still be compiling at load, so ask again when we get in a car
  private func WarnIfBlocked() -> Void {
    if TakeLayerBlockedWarning() {
      this.ShowMessage("ReFRACT: another mod took the room glass needs for its RT layers (the RenoDX build on Nexus does), so Full and the Glass RT Layer work like Simple. Update RenoDX from its GitHub, or set Interior RT Reflections to Simple and Glass RT Layer to Off to hide this.", 12.0);
    }
  }

  private func ShowMessage(text: String, duration: Float) -> Void {
    let message: SimpleScreenMessage;
    message.message = text;
    message.duration = duration;
    message.isShown = true;
    message.isInstant = true;
    let notifications = GetAllBlackboardDefs().UI_Notifications;
    let blackboard = GameInstance.GetBlackboardSystem(this.GetGameInstance());
    if IsDefined(blackboard) {
      let notificationBoard = blackboard.Get(notifications);
      if IsDefined(notificationBoard) {
        notificationBoard.SetVariant(notifications.OnscreenMessage, ToVariant(message), true);
      }
    }
  }

  private func Apply() -> Void {
    SetEnabled(this.enabled);
    if !this.enabled {
      return;
    }
    SetFixes(this.refractionFix, this.thinGlass, this.vehicleInteriorReflections, this.crystalDomeReflections);
    SetInteriorRtReflections(EnumInt(this.interiorRtReflections));
    SetLayersFirstPersonOnly(this.fullFirstPersonOnly);
    SetInteriorOnlyInVehicle(this.interiorOnlyInVehicle);
    SetInteriorReflections(this.interiorReflectionStrength);
    SetCrystalDomeStrength(this.crystalDomeStrength);
    // Only saves what differs from this car's entry, and nothing on foot
    SetCrystalDomeOverride(this.crystalDomeOverride, this.crystalDomeVehicleStrength);
    SetDitherBlend(this.ditherBlend);
    SetGlassLayer(NotEquals(this.glassRtLayerMode, GlassRtLayerMode.Off));
    SetThirdLayer(Equals(this.glassRtLayerMode, GlassRtLayerMode.Always));
    SetBackGlassLayer(this.backGlassLayer);
    SetBlackGlass(this.blackGlassReflections, this.blackGlassStrength);
    SetFrontRefractionWins(this.frontRefractionWins);
    SetFireflyFilter(this.refractionFireflyFilter);
    SetFireflyStrength(this.fireflyStrength);
    SetCrystalDomeCheckerboard(this.halfRateTracing);
    SetCarGlassCheckerboard(this.halfRateTracing);
    SetCrystalDomeCabinShadows(this.crystalDomeCabinShadows);
    SetCrystalDomeSkyShade(this.crystalDomeSkyShade);
    SetCrystalDomeScanlines(this.crystalDomeScanlines);
  }

  private func WatchRenderMode() -> Void {
    // PlayerAttach can repeat during a save reload without a fully ordered
    // detach. Keep one ConfigVarListener instead of stacking callbacks.
    if IsDefined(this.renderListener) {
      this.ApplyRenderMode();
      return;
    }
    this.renderListener = new ReFRACTRenderListener();
    this.renderListener.settings = this;
    this.renderListener.Register(n"/graphics/raytracing");
    this.renderListener.Register(n"/graphics/presets");
    this.ApplyRenderMode();
  }

  public func ApplyRenderMode() -> Void {
    let game = this.GetGameInstance();
    SetRenderMode(ReFRACTRenderMode.TracedReflections(game), ReFRACTRenderMode.RayReconstruction(game));
  }

  // The HUD's vehicle blackboard sees every vehicle and seat
  private func WatchVehicle() -> Void {
    this.UnwatchVehicle();
    let defs = GetAllBlackboardDefs().UI_ActiveVehicleData;
    this.vehicleData = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(defs);
    if !IsDefined(this.vehicleData) {
      return;
    }
    this.mountedCallback = this.vehicleData.RegisterListenerBool(defs.IsPlayerMounted, this, n"OnMountedChanged");
    this.cameraCallback = this.vehicleData.RegisterListenerBool(defs.IsTPPCameraOn, this, n"OnCameraChanged");
    this.UpdateMounted();
  }

  private func UnwatchVehicle() -> Void {
    if IsDefined(this.vehicleData) {
      let defs = GetAllBlackboardDefs().UI_ActiveVehicleData;
      this.vehicleData.UnregisterListenerBool(defs.IsPlayerMounted, this.mountedCallback);
      this.vehicleData.UnregisterListenerBool(defs.IsTPPCameraOn, this.cameraCallback);
    }
    this.vehicleData = null;
    this.mountedCallback = null;
    this.cameraCallback = null;
  }

  private func ForgetVehicle() -> Void {
    SetFirstPersonVehicle(false);
    SetInVehicle(false);
    SetVehicle(TDBID.None(), n"", "");
    SetCrystalDomeOn(false);
  }

  protected cb func OnMountedChanged(value: Bool) -> Bool {
    this.UpdateMounted();
    return true;
  }

  protected cb func OnCameraChanged(value: Bool) -> Bool {
    this.UpdateCamera();
    return true;
  }

  private func UpdateCamera() -> Void {
    if !IsDefined(this.vehicleData) {
      return;
    }
    let defs = GetAllBlackboardDefs().UI_ActiveVehicleData;
    let mounted = this.vehicleData.GetBool(defs.IsPlayerMounted);
    SetInVehicle(mounted);
    SetFirstPersonVehicle(mounted && !this.vehicleData.GetBool(defs.IsTPPCameraOn));
  }

  private func UpdateMounted() -> Void {
    if !IsDefined(this.vehicleData) {
      return;
    }
    this.UpdateCamera();
    let vehicle = ReFRACTSettings.MountedVehicle(this.GetGameInstance());
    if this.vehicleData.GetBool(GetAllBlackboardDefs().UI_ActiveVehicleData.IsPlayerMounted) && IsDefined(vehicle) {
      this.ShowVehicleDome(SetVehicle(vehicle.GetRecordID(), vehicle.GetCurrentAppearanceName(), vehicle.GetDisplayName()));
      SetCrystalDomeOn(vehicle.GetVehiclePS().GetCrystalDomeState());
      this.WarnIfBlocked();
    } else {
      SetVehicle(TDBID.None(), n"", "");
      SetCrystalDomeOn(false);
    }
  }

  // Apply a saved per-vehicle override, or fall back to the fixed profile strength.
  private func ShowVehicleDome(saved: Float) -> Void {
    let override = saved >= 0.0;
    let strength = override ? saved : this.crystalDomeVehicleStrength;
    if Equals(this.crystalDomeOverride, override) && AbsF(this.crystalDomeVehicleStrength - strength) < 0.001 {
      return;
    }
    this.crystalDomeOverride = override;
    this.crystalDomeVehicleStrength = strength;
    SetCrystalDomeOverride(this.crystalDomeOverride, this.crystalDomeVehicleStrength);
  }

  public static func MountedVehicle(game: GameInstance) -> ref<VehicleObject> {
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return null;
    }
    return player.GetMountedVehicle();
  }
}

@wrapMethod(VehicleComponentPS)
public final func SetCrystalDomeState(value: Bool) -> Void {
  wrappedMethod(value);
  let vehicle = ReFRACTSettings.MountedVehicle(GetGameInstance());
  if IsDefined(vehicle) && Equals(vehicle.GetVehiclePS(), this) {
    SetCrystalDomeOn(value);
  }
}

// Mounting, dismounting and some mods flip the dome here and skip SetCrystalDomeState
@wrapMethod(VehicleComponent)
protected final func ToggleCrystalDome(on: Bool, opt instant: Bool, opt force: Bool, opt delay: Float, opt meshDelay: Float, opt fastStop: Bool) -> Void {
  wrappedMethod(on, instant, force, delay, meshDelay, fastStop);
  let mounted = ReFRACTSettings.MountedVehicle(GetGameInstance());
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  if IsDefined(mounted) && Equals(mounted, vehicle) {
    SetCrystalDomeOn(on);
  }
}

// Path tracing runs with RayTracing off, go figure, so check each switch on its own
public abstract class ReFRACTRenderMode {

  public static func TracedReflections(game: GameInstance) -> Bool {
    return ReFRACTRenderMode.Flag(game, n"/graphics/raytracing", n"RayTracedPathTracing") ||
      (ReFRACTRenderMode.Flag(game, n"/graphics/raytracing", n"RayTracing") &&
      ReFRACTRenderMode.Flag(game, n"/graphics/raytracing", n"RayTracedReflections"));
  }

  // DLSS_D stays on with tracing off or another upscaler picked, the menu just greys it out
  public static func RayReconstruction(game: GameInstance) -> Bool {
    let scaling = GameInstance.GetSettingsSystem(game).GetVar(n"/graphics/presets", n"ResolutionScaling") as ConfigVarListString;
    return (ReFRACTRenderMode.Flag(game, n"/graphics/raytracing", n"RayTracedPathTracing") ||
      ReFRACTRenderMode.Flag(game, n"/graphics/raytracing", n"RayTracing")) &&
      ReFRACTRenderMode.Flag(game, n"/graphics/presets", n"DLSS_D") &&
      IsDefined(scaling) && Equals(scaling.GetValue(), "DLSS");
  }

  private static func Flag(game: GameInstance, group: CName, name: CName) -> Bool {
    let flag = GameInstance.GetSettingsSystem(game).GetVar(group, name) as ConfigVarBool;
    return IsDefined(flag) && flag.GetValue();
  }
}

public class ReFRACTRenderListener extends ConfigVarListener {
  public let settings: wref<ReFRACTSettings>;

  public func OnVarModified(groupPath: CName, varName: CName, varType: ConfigVarType, reason: ConfigChangeReason) -> Void {
    if IsDefined(this.settings) {
      this.settings.ApplyRenderMode();
    }
  }
}

public class ReFRACTWarning extends DelayCallback {
  public let settings: wref<ReFRACTSettings>;

  public func Call() -> Void {
    if IsDefined(this.settings) {
      this.settings.ShowWarning();
    }
  }
}
