module BlurBegone

// The menu sets a few of these; a dev tool can reach the rest. Keep field names and defaults in sync with
// src/Settings.cpp, which applies them before the script runs.
public native func SetEnabled(enabled: Bool) -> Void;
public native func SetGlassCategory(category: Int32, blurMode: Int32, blurStrength: Float, refraction: Float, light: Float) -> Void;
public native func SetRestoreRefraction(enabled: Bool) -> Void;
public native func SetBlackWindowPlanes(reflections: Float, blur: Float, bumps: Float) -> Void;
public native func SetBlackWindowTint(hue: Float, saturation: Float) -> Void;
public native func SetBlackWindowHidden(hidden: Bool) -> Void;
// Linear, alpha 1
public native func BlackWindowTintColour(hue: Float, saturation: Float) -> HDRColor;
public native func SetMaterialCategory(category: Int32, customize: Bool, ior: Float, maxDepth: Float, fresnelShift: Float, reflections: Float, opacity: Float, normalStrength: Float, blur: Float) -> Void;
public native func SetMaxRefractionDepth(depth: Float) -> Void;
public native func SetCyberwareBlur(strength: Float) -> Void;
public native func SetGlassDirt(strength: Float) -> Void;
public native func SetWindows(bumps: Float, blur: Float) -> Void;
public native func SetWindowTextureScale(scale: Float) -> Void;
public native func SetClothingBumps(bumps: Float) -> Void;
public native func SetFrostedGlass(blur: Float, bumps: Float) -> Void;
public native func SetPaintedWindows(bumps: Float, blur: Float) -> Void;
public native func SetPaintedTextureScale(scale: Float) -> Void;
public native func SetBlackWindowTextureScale(scale: Float) -> Void;
// File name of a 1.x archive still installed, or empty
public native func OldArchive() -> String;
// Minimum ReFRACT version when the installed one is too old to share glass with, else empty
public native func ReFRACTUpdateNeeded() -> String;
// False means none of the ways to the D3D12 device caught it, so nothing is patched
public native func DeviceHooked() -> Bool;

public class BlurBegoneSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Off renders all glass vanilla, for comparing.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Max Refraction Depth")
  @runtimeProperty("ModSettings.description", "How thick glass may act when bending what's behind it. The game often uses 2.5 m, which shifts things far and can leave cutouts; real panes are a few mm. 10 = vanilla. Applies as areas load.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.05")
  @runtimeProperty("ModSettings.max", "10.0")
  public let maxRefractionDepth: Float = 10.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Glass & Plastic")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "Blur behind windows, vinyl curtains, showcases, bottles and other glass or plastic, car light covers included. Smudged glass is under Dirt. 0 = clear, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let worldBlur: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Glass & Plastic")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Dirt")
  @runtimeProperty("ModSettings.description", "Smudges on glass that only blurs in patches, like the Dollhouse booth walls, metro doors and scope lenses. Frosted plastic and curtains stay under Blur. 0 = clean, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let worldDirt: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Glass & Plastic")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Refraction")
  @runtimeProperty("ModSettings.description", "How much glass and plastic bend what's behind them. 0 = straight through, 1 = vanilla. Some GPUs only do on or off; the log says.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let worldRefraction: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Glass & Plastic")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Reflections")
  @runtimeProperty("ModSettings.description", "Reflections on glass and plastic. 0 = none, 1 = vanilla, 2 = double. With ReFRACT before 1.4.0, below 1 also darkens tinted glass in fog.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let worldReflections: Float = 0.35;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Glass & Plastic")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Restore Refraction")
  @runtimeProperty("ModSettings.description", "Gives refraction back to about 150 glass materials the game leaves flat, like shower doors and vending machines, using Blur Begone's old values and smoother surfaces. Also gives about 90 that already refract, like vinyl curtains and shop freezers, thinner and calmer glass, and cyber tubes more depth. Reaches things as they load. Off = vanilla.")
  public let restoreRefraction: Bool = true;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Facade Windows")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Bumps")
  @runtimeProperty("ModSettings.description", "Ripples in the reflections on building windows with a fake room behind them, the ones on most facades. 0 = smooth, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let windowBumps: Float = 0.05;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Facade Windows")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "How frosted the room behind those windows looks, and how smudged their reflections are. 0 = clear, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let windowBlur: Float = 0.5;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Facade Windows")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Scale Window Textures")
  @runtimeProperty("ModSettings.description", "Repeats the smudges and scratches on those windows so they come out smaller and finer, like Blur Begone 1.x. Off = vanilla size.")
  public let windowTextureScaling: Bool = true;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Facade Windows")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Texture Scale")
  @runtimeProperty("ModSettings.description", "How many times the smudges repeat across each window, both ways. 1 = vanilla, 2 = a 2x2 grid, like Blur Begone 1.x.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "4.0")
  public let windowTextureScale: Float = 2.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Painted Windows")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Bumps")
  @runtimeProperty("ModSettings.description", "Ripples in the reflections on windows painted onto building walls, the dark glossy ones with nothing behind them. 0 = smooth, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let paintedBumps: Float = 0.05;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Painted Windows")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "How smudged and streaky the reflections on those windows are. 0 = mirror sharp, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let paintedBlur: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Painted Windows")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Scale Window Textures")
  @runtimeProperty("ModSettings.description", "Repeats the streaks and smudges on those windows so they come out smaller and finer. Off = vanilla size.")
  public let paintedTextureScaling: Bool = false;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Painted Windows")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Texture Scale")
  @runtimeProperty("ModSettings.description", "How many times as often they repeat, both ways. 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "4.0")
  public let paintedTextureScale: Float = 2.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Reflections")
  @runtimeProperty("ModSettings.description", "How bright the reflections are on the flat black planes some buildings use as windows, like on the Pacifica mall. 1 = vanilla, 2.55 = Blur Begone 1.x.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.55")
  public let blackWindowReflections: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "How smudged their reflections are. 0 = mirror sharp, 1 = vanilla, 0.5 = Blur Begone 1.x.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let blackWindowBlur: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Bumps")
  @runtimeProperty("ModSettings.description", "Ripples in their reflections. 0 = smooth, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let blackWindowBumps: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Scale Window Textures")
  @runtimeProperty("ModSettings.description", "Repeats the smudges and scratches on those planes so they come out smaller and finer. Off = vanilla size.")
  public let blackWindowTextureScaling: Bool = false;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Texture Scale")
  @runtimeProperty("ModSettings.description", "How many times as often they repeat, both ways. 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "4.0")
  public let blackWindowTextureScale: Float = 2.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Tint Hue")
  @runtimeProperty("ModSettings.description", "Colour of their tint, around the colour wheel: 0 red, 60 yellow, 120 green, 180 cyan, 240 blue, 300 magenta.")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "360.0")
  public let blackWindowTintHue: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Black Windows")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Tint Saturation")
  @runtimeProperty("ModSettings.description", "How strongly that colour tints their reflections. 0 = no tint, 1 = full colour. Reflections sets how bright it is.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let blackWindowTintSaturation: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Frosted Glass")
  @runtimeProperty("ModSettings.category.order", "5")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "Blur behind frosted panels, shutters and doors in apartments, and see-through umbrellas. Apartment windows made of the same glass follow Glass & Plastic. 0 = clear, 1 = vanilla frost.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let frostedBlur: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Frosted Glass")
  @runtimeProperty("ModSettings.category.order", "5")
  @runtimeProperty("ModSettings.displayName", "Bumps")
  @runtimeProperty("ModSettings.description", "Ripples in that frosted glass. 0 = smooth, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let frostedBumps: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Clothing")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.displayName", "Blur")
  @runtimeProperty("ModSettings.description", "Blur behind sheer clothing, stockings and visors. 0 = clear, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let clothingBlur: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Clothing")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.displayName", "Cyberware Blur")
  @runtimeProperty("ModSettings.description", "Blur behind frosted cyberware covers, like Gorilla Arms. Below 1 they turn see-through. 0 = clear, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let cyberwareBlur: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Clothing")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.displayName", "Bumps")
  @runtimeProperty("ModSettings.description", "How wavy things look through sheer clothing, stockings and visors. 0 = smooth, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let clothingBumps: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Clothing")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.displayName", "Refraction")
  @runtimeProperty("ModSettings.description", "How much sheer clothing, stockings and visors bend what's behind them. 0 = straight through, 1 = vanilla.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let clothingRefraction: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Clothing")
  @runtimeProperty("ModSettings.category.order", "6")
  @runtimeProperty("ModSettings.displayName", "Reflections")
  @runtimeProperty("ModSettings.description", "Reflections on sheer clothing, stockings and visors. 0 = none, 1 = vanilla, 2 = double.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let clothingReflections: Float = 0.35;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Vehicles")
  @runtimeProperty("ModSettings.category.order", "7")
  @runtimeProperty("ModSettings.displayName", "Reflections")
  @runtimeProperty("ModSettings.description", "Reflections on vehicle glass, inside (with ReFRACT) and out. 0 = none, 1 = vanilla, 2 = double.")
  @runtimeProperty("ModSettings.step", "0.01")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let vehiclesReflections: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "9")
  @runtimeProperty("ModSettings.displayName", "Enable Hotkey")
  @runtimeProperty("ModSettings.description", "Lets a key turn Blur Begone on and off in game, for comparing. Needs Codeware.")
  public let hotkeyEnabled: Bool = false;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "9")
  @runtimeProperty("ModSettings.displayName", "Toggle Key")
  @runtimeProperty("ModSettings.description", "Turns Blur Begone on and off until Enabled, Enable Hotkey or this key changes.")
  public let toggleKey: EInputKey = EInputKey.IK_F8;

  @runtimeProperty("ModSettings.mod", "Blur Begone")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "9")
  @runtimeProperty("ModSettings.displayName", "Black Window Planes")
  @runtimeProperty("ModSettings.description", "Off hides the black window planes, for finding them. Ray-traced and path-traced reflections and shadows still see them.")
  public let blackWindowPlanes: Bool = true;

  @if(ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
    this.Apply();
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    this.Apply();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
    ModSettings.UnregisterListenerToModifications(this);
    this.UnregisterToggleKey();
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    this.UnregisterToggleKey();
  }

  public cb func OnModSettingsChange() {
    this.Apply();
  }

  // Set by the toggle key, on top of Enabled
  private let toggled: Bool;
  private let keyInput: ref<IScriptable>;
  // Any mod's Apply calls OnModSettingsChange, closing the menu included, so the toggle only resets when these change
  private let enabledApplied: Bool;
  private let hotkeyApplied: Bool;
  private let keyApplied: EInputKey;

  @if(ModuleExists("Codeware"))
  private func RegisterToggleKey() -> Void {
    this.keyInput = GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Input/Key", this, n"OnKeyInput")
      .SetLifetime(CallbackLifetime.Forever);
  }

  @if(!ModuleExists("Codeware"))
  private func RegisterToggleKey() -> Void {}

  // Registered Forever, so it outlives this system and fires twice after a save load unless dropped
  @if(ModuleExists("Codeware"))
  private func UnregisterToggleKey() -> Void {
    let handler = this.keyInput as CallbackSystemHandler;
    if IsDefined(handler) {
      handler.Unregister();
    }
    this.keyInput = null;
  }

  @if(!ModuleExists("Codeware"))
  private func UnregisterToggleKey() -> Void {}

  @if(ModuleExists("Codeware"))
  protected cb func OnKeyInput(event: ref<KeyInputEvent>) -> Void {
    if NotEquals(event.GetKey(), this.toggleKey) || NotEquals(event.GetAction(), EInputAction.IACT_Release) {
      return;
    }
    this.toggled = !this.toggled;
    let enabled = NotEquals(this.enabled, this.toggled);
    SetEnabled(enabled);
    this.ShowMessage(enabled ? "Blur Begone on" : "Blur Begone off", 2.0);
  }

  // Delayed so the message lands after the loading screen
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if Equals(this.Warning(), "") {
      return;
    }
    let warning = new BlurBegoneWarning();
    warning.settings = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(warning, 5.0, false);
  }

  // One message, since a second would replace the first on screen
  private func Warning() -> String {
    let text = "";
    if NotEquals(OldArchive(), "") {
      text = "Blur Begone: delete the old " + OldArchive() + " from archive/pc/mod. It's from version 1 and overrides this one.";
    }
    let needed = ReFRACTUpdateNeeded();
    if NotEquals(needed, "") {
      if NotEquals(text, "") {
        text = text + " ";
      }
      text = text + "Blur Begone: this ReFRACT is too old to share glass with. Update ReFRACT to " + needed + " or later.";
    }
    if !DeviceHooked() {
      if NotEquals(text, "") {
        text = text + " ";
      }
      text = text + "Blur Begone couldn't reach the game's renderer, so glass looks vanilla. Please share the blurbegonenative log from red4ext/logs on the mod page.";
    }
    return text;
  }

  public func ShowWarning() -> Void {
    this.ShowMessage(this.Warning(), 10.0);
  }

  private func ShowMessage(text: String, duration: Float) -> Void {
    let message: SimpleScreenMessage;
    message.message = text;
    message.duration = duration;
    message.isShown = true;
    message.isInstant = true;
    let notifications = GetAllBlackboardDefs().UI_Notifications;
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(notifications)
      .SetVariant(notifications.OnscreenMessage, ToVariant(message), true);
  }

  // Native categories: 0 windows, 1 glass.mt, 2 clothing, 3 vehicles. Blur mode 1 is Scale.
  private func Apply() -> Void {
    if NotEquals(this.enabled, this.enabledApplied) || NotEquals(this.hotkeyEnabled, this.hotkeyApplied) ||
      NotEquals(this.toggleKey, this.keyApplied) {
      this.toggled = false;
    }
    if NotEquals(this.hotkeyEnabled, this.hotkeyApplied) {
      this.UnregisterToggleKey();
      if this.hotkeyEnabled {
        this.RegisterToggleKey();
      }
    }
    this.enabledApplied = this.enabled;
    this.hotkeyApplied = this.hotkeyEnabled;
    this.keyApplied = this.toggleKey;

    SetEnabled(NotEquals(this.enabled, this.toggled));
    SetRestoreRefraction(this.restoreRefraction);
    SetBlackWindowPlanes(this.blackWindowReflections, this.blackWindowBlur, this.blackWindowBumps);
    SetBlackWindowTint(this.blackWindowTintHue, this.blackWindowTintSaturation);
    SetBlackWindowHidden(!this.blackWindowPlanes);
    SetGlassCategory(0, 1, this.worldBlur, this.worldRefraction, this.worldReflections);
    SetGlassCategory(1, 1, this.worldBlur, this.worldRefraction, this.worldReflections);
    SetGlassCategory(2, 1, this.clothingBlur, this.clothingRefraction, this.clothingReflections);
    SetGlassCategory(3, 1, this.worldBlur, this.worldRefraction, this.vehiclesReflections);
    SetCyberwareBlur(this.cyberwareBlur);
    SetGlassDirt(this.worldDirt);
    SetClothingBumps(this.clothingBumps);
    SetWindows(this.windowBumps, this.windowBlur);
    SetWindowTextureScale(this.windowTextureScaling ? this.windowTextureScale : 1.0);
    SetPaintedWindows(this.paintedBumps, this.paintedBlur);
    SetPaintedTextureScale(this.paintedTextureScaling ? this.paintedTextureScale : 1.0);
    SetBlackWindowTextureScale(this.blackWindowTextureScaling ? this.blackWindowTextureScale : 1.0);
    SetFrostedGlass(this.frostedBlur, this.frostedBumps);
    SetMaxRefractionDepth(this.maxRefractionDepth);
  }
}

public class BlurBegoneWarning extends DelayCallback {
  public let settings: wref<BlurBegoneSettings>;

  public func Call() -> Void {
    if IsDefined(this.settings) {
      this.settings.ShowWarning();
    }
  }
}
