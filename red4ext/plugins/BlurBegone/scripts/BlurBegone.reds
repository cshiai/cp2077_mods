module BlurBegone

// Fixed source profile: constants are reviewed in Git; no Mod Settings/CET runtime layer.
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
// Empty unless an old 1.x archive is still lying around
public native func OldArchive() -> String;
// Empty unless ReFRACT is too old to share glass with, then the version it needs
public native func ReFRACTUpdateNeeded() -> String;
// False means we never caught the D3D12 device, so nothing's patched
public native func DeviceHooked() -> Bool;

public class BlurBegoneSettings extends ScriptableSystem {

  public let enabled: Bool = true;

  public let maxRefractionDepth: Float = 10.0;

  public let worldBlur: Float = 0.0;

  public let worldDirt: Float = 1.0;

  public let worldRefraction: Float = 1.0;

  public let worldReflections: Float = 0.35;

  public let restoreRefraction: Bool = true;

  public let windowBumps: Float = 0.05;

  public let windowBlur: Float = 0.5;

  public let windowTextureScaling: Bool = true;

  public let windowTextureScale: Float = 2.0;

  public let paintedBumps: Float = 0.05;

  public let paintedBlur: Float = 1.0;

  public let paintedTextureScaling: Bool = false;

  public let paintedTextureScale: Float = 2.0;

  public let blackWindowReflections: Float = 1.0;

  public let blackWindowBlur: Float = 1.0;

  public let blackWindowBumps: Float = 1.0;

  public let blackWindowTextureScaling: Bool = false;

  public let blackWindowTextureScale: Float = 2.0;

  public let blackWindowTintHue: Float = 0.0;

  public let blackWindowTintSaturation: Float = 0.0;

  public let frostedBlur: Float = 0.0;

  public let frostedBumps: Float = 1.0;

  public let clothingBlur: Float = 0.0;

  public let cyberwareBlur: Float = 1.0;

  public let clothingBumps: Float = 1.0;

  public let clothingRefraction: Float = 1.0;

  public let clothingReflections: Float = 0.35;

  public let vehiclesReflections: Float = 1.0;



  public let blackWindowPlanes: Bool = true;

  // Fixed source profile: no Mod Settings listener or runtime toggle.
  private func OnAttach() -> Void {
    this.Apply();
  }

  private func OnDetach() -> Void {}

  // Wait out the loading screen, or nobody sees it
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if Equals(this.Warning(), "") {
      return;
    }
    let warning = new BlurBegoneWarning();
    warning.settings = this;
    let delay = GameInstance.GetDelaySystem(this.GetGameInstance());
    if IsDefined(delay) {
      delay.DelayCallback(warning, 5.0, false);
    }
  }

  // Only one fits, a second message just replaces the first
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
    let blackboard = GameInstance.GetBlackboardSystem(this.GetGameInstance());
    if IsDefined(blackboard) {
      let notificationBoard = blackboard.Get(notifications);
      if IsDefined(notificationBoard) {
        notificationBoard.SetVariant(notifications.OnscreenMessage, ToVariant(message), true);
      }
    }
  }

  // Categories go 0 windows, 1 glass, 2 clothing, 3 vehicles. Blur mode 1 is Scale
  private func Apply() -> Void {
    SetEnabled(this.enabled);
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
