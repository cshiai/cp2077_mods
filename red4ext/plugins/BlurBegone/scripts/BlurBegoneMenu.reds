module BlurBegone

// Greys out and locks options whose parents above them are off; Mod Settings' own dependencies hide them instead, and
// only on Apply.
// Never register a Mod Settings listener from here: it calls listeners under a spin lock, so registering during its
// Apply hangs the game. Its Refresh wrapper skips wrappedMethod while the menu is open, so that isn't wrapped either.

// The widgets a greyed entry had clickable, given back when it unlocks
@addField(SettingsSelectorController)
public let blurBegoneLocked: array<wref<inkWidget>>;

@addField(SettingsSelectorController)
public let blurBegoneSwatch: wref<inkWidget>;

@addField(SettingsSelectorController)
public let blurBegoneWatcher: ref<IScriptable>;

@addMethod(SettingsSelectorController)
public func BlurBegoneLabels() -> ref<inkCompoundWidget> {
  return inkWidgetRef.Get(this.m_LabelText).GetParentWidget() as inkCompoundWidget;
}

@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorController)
public func Setup(entry: ref<ConfigVar>, isPreGame: Bool) -> Void {
  wrappedMethod(entry, isPreGame);
  if BlurBegoneMenu.IsOurs(this) {
    let values = BlurBegoneMenuValues.Pending();
    BlurBegoneMenu.Lock(this, values);
    BlurBegoneMenu.AddSwatch(this, values);
  }
}

@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorController)
protected cb func OnLeft(e: ref<inkPointerEvent>) -> Bool {
  if !BlurBegoneMenu.Allows(this) {
    return false;
  }
  let handled = wrappedMethod(e);
  BlurBegoneMenu.Changed(this);
  return handled;
}

@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorController)
protected cb func OnRight(e: ref<inkPointerEvent>) -> Bool {
  if !BlurBegoneMenu.Allows(this) {
    return false;
  }
  let handled = wrappedMethod(e);
  BlurBegoneMenu.Changed(this);
  return handled;
}

@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorController)
protected cb func OnShortcutPress(e: ref<inkPointerEvent>) -> Bool {
  if !BlurBegoneMenu.Allows(this) {
    return false;
  }
  let handled = wrappedMethod(e);
  BlurBegoneMenu.Changed(this);
  return handled;
}

// Held keys on sliders, and no slider is another row's parent
@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorController)
protected cb func OnShortcutRepeat(e: ref<inkPointerEvent>) -> Bool {
  if !BlurBegoneMenu.Allows(this) {
    return false;
  }
  let handled = wrappedMethod(e);
  BlurBegoneMenu.Repaint(this, n"None", 0.0);
  return handled;
}

// Backs up the widget lock. Mod Settings' own wrapper here doesn't call through, so this only runs when it's outside it.
@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorControllerKeyBinding)
protected cb func OnRelease(e: ref<inkPointerEvent>) -> Bool {
  if !BlurBegoneMenu.Allows(this) {
    return false;
  }
  return wrappedMethod(e);
}

@if(ModuleExists("ModSettingsModule"))
@wrapMethod(SettingsSelectorControllerKeyBinding)
private final func ResetValue() -> Void {
  if BlurBegoneMenu.Allows(this) {
    wrappedMethod();
  }
}

public abstract class BlurBegoneMenu {

  public static func IsOurs(item: ref<SettingsSelectorController>) -> Bool {
    return IsDefined(item) && StrBeginsWith(NameToString(item.GetGroupPath()), "/mods/Blur Begone/");
  }

  @if(ModuleExists("ModSettingsModule"))
  public static func Allows(item: ref<SettingsSelectorController>) -> Bool {
    return !BlurBegoneMenu.IsOurs(item) || BlurBegoneMenuValues.Pending().Applies(item.GetVarName());
  }

  // One switch can unlock several rows
  @if(ModuleExists("ModSettingsModule"))
  public static func Changed(item: ref<SettingsSelectorController>) -> Void {
    if !BlurBegoneMenu.IsOurs(item) {
      return;
    }
    let list = item.GetRootWidget().GetParentWidget() as inkCompoundWidget;
    if !IsDefined(list) {
      return;
    }
    let values = BlurBegoneMenuValues.Pending();
    let i = 0;
    while i < list.GetNumChildren() {
      let entry = list.GetWidgetByIndex(i).GetController() as SettingsSelectorController;
      if BlurBegoneMenu.IsOurs(entry) {
        BlurBegoneMenu.Lock(entry, values);
      }
      i += 1;
    }
    BlurBegoneMenu.Repaint(item, n"None", 0.0);
  }

  // The row keeps its hover so its description can say why it's grey; its own clicks and keys hit the wraps above. A key
  // binding's row locks too: Mod Settings takes that click without calling through.
  public static func Lock(item: ref<SettingsSelectorController>, values: ref<BlurBegoneMenuValues>) -> Void {
    let applies = values.Applies(item.GetVarName());
    let root = item.GetRootWidget();
    root.SetOpacity(applies ? 1.0 : 0.2);
    if applies {
      for widget in item.blurBegoneLocked {
        if IsDefined(widget) {
          widget.SetInteractive(true);
        }
      }
      ArrayClear(item.blurBegoneLocked);
    } else {
      if ArraySize(item.blurBegoneLocked) == 0 {
        let locked: array<wref<inkWidget>>;
        BlurBegoneMenu.Disable(root, IsDefined(item as SettingsSelectorControllerKeyBinding), locked);
        item.blurBegoneLocked = locked;
      }
    }
  }

  private static func Disable(widget: ref<inkWidget>, itself: Bool, out locked: array<wref<inkWidget>>) -> Void {
    if !IsDefined(widget) {
      return;
    }
    if itself && widget.IsInteractive() {
      widget.SetInteractive(false);
      ArrayPush(locked, widget);
    }
    let compound = widget as inkCompoundWidget;
    if IsDefined(compound) {
      let i = 0;
      while i < compound.GetNumChildren() {
        BlurBegoneMenu.Disable(compound.GetWidgetByIndex(i), true, locked);
        i += 1;
      }
    }
  }

  private static func IsTint(name: CName) -> Bool {
    return Equals(name, n"blackWindowTintHue") || Equals(name, n"blackWindowTintSaturation");
  }

  // Right end of the label column. The hue row shows the pure hue, or it'd sit white at saturation 0
  public static func AddSwatch(item: ref<SettingsSelectorController>, values: ref<BlurBegoneMenuValues>) -> Void {
    let labels = item.BlurBegoneLabels();
    if !BlurBegoneMenu.IsTint(item.GetVarName()) || !IsDefined(labels) || IsDefined(item.blurBegoneSwatch) {
      return;
    }
    let swatch = new inkRectangle();
    swatch.SetName(n"blurBegoneSwatch");
    swatch.SetAnchor(inkEAnchor.CenterRight);
    swatch.SetAnchorPoint(new Vector2(1.0, 0.5));
    swatch.SetMargin(new inkMargin(0.0, 0.0, 40.0, 0.0));
    swatch.SetSize(new Vector2(44.0, 44.0));
    swatch.SetInteractive(false);
    swatch.Reparent(labels);
    item.blurBegoneSwatch = swatch;
    BlurBegoneMenu.Paint(item, values.tintHue, values.tintSaturation);

    let watcher = new BlurBegoneSwatchWatcher();
    watcher.row = item;
    item.blurBegoneWatcher = watcher;
    let slider = BlurBegoneMenu.FindSlider(item.GetRootWidget());
    if IsDefined(slider) {
      slider.RegisterToCallback(n"OnSliderValueChanged", watcher, n"OnSliderValueChanged");
    }
  }

  private static func FindSlider(widget: ref<inkWidget>) -> ref<inkSliderController> {
    if !IsDefined(widget) {
      return null;
    }
    let slider = widget.GetControllerByType(n"inkSliderController") as inkSliderController;
    if IsDefined(slider) {
      return slider;
    }
    let compound = widget as inkCompoundWidget;
    if IsDefined(compound) {
      let i = 0;
      while i < compound.GetNumChildren() {
        slider = BlurBegoneMenu.FindSlider(compound.GetWidgetByIndex(i));
        if IsDefined(slider) {
          return slider;
        }
        i += 1;
      }
    }
    return null;
  }

  // Slider values, not the vars: held keys and drags only set those on release. A dragged row passes its value in, its
  // m_newValue is a callback behind
  @if(ModuleExists("ModSettingsModule"))
  public static func Repaint(item: ref<SettingsSelectorController>, dragged: CName, draggedValue: Float) -> Void {
    if !BlurBegoneMenu.IsOurs(item) || !BlurBegoneMenu.IsTint(item.GetVarName()) {
      return;
    }
    let list = item.GetRootWidget().GetParentWidget() as inkCompoundWidget;
    if !IsDefined(list) {
      return;
    }
    let rows: array<ref<SettingsSelectorController>>;
    let hue = 0.0;
    let saturation = 0.0;
    let i = 0;
    while i < list.GetNumChildren() {
      let entry = list.GetWidgetByIndex(i).GetController() as SettingsSelectorController;
      let slider = entry as ModStngsSelectorControllerFloat;
      if BlurBegoneMenu.IsOurs(entry) && IsDefined(slider) && BlurBegoneMenu.IsTint(entry.GetVarName()) {
        let value = Equals(entry.GetVarName(), dragged) ? draggedValue : slider.m_newValue;
        if Equals(entry.GetVarName(), n"blackWindowTintHue") {
          hue = value;
        } else {
          saturation = value;
        }
        ArrayPush(rows, entry);
      }
      i += 1;
    }
    for row in rows {
      BlurBegoneMenu.Paint(row, hue, saturation);
    }
  }

  private static func Paint(item: ref<SettingsSelectorController>, hue: Float, saturation: Float) -> Void {
    if IsDefined(item.blurBegoneSwatch) {
      let shown = Equals(item.GetVarName(), n"blackWindowTintHue") ? 1.0 : saturation;
      item.blurBegoneSwatch.SetTintColor(BlurBegoneMenu.TintColour(hue, shown));
    }
  }

  // The tint multiplies in linear and ink colours are gamma encoded
  public static func TintColour(hue: Float, saturation: Float) -> HDRColor {
    let linear = BlackWindowTintColour(hue, saturation);
    let gamma = 1.0 / 2.2;
    return new HDRColor(PowF(linear.Red, gamma), PowF(linear.Green, gamma), PowF(linear.Blue, gamma), 1.0);
  }
}

public class BlurBegoneSwatchWatcher extends IScriptable {
  public let row: wref<SettingsSelectorController>;

  @if(ModuleExists("ModSettingsModule"))
  protected cb func OnSliderValueChanged(slider: wref<inkSliderController>, progress: Float, value: Float) -> Bool {
    if IsDefined(this.row) {
      BlurBegoneMenu.Repaint(this.row, this.row.GetVarName(), value);
    }
    return false;
  }
}

// What the menu shows, applied or not
public class BlurBegoneMenuValues {
  public let enabled: Bool;
  public let windowTextureScaling: Bool;
  public let paintedTextureScaling: Bool;
  public let blackWindowTextureScaling: Bool;
  public let hotkeyEnabled: Bool;
  public let tintHue: Float;
  public let tintSaturation: Float;

  @if(ModuleExists("ModSettingsModule"))
  public static func Pending() -> ref<BlurBegoneMenuValues> {
    let values = new BlurBegoneMenuValues();
    for category in ModSettings.GetCategories(n"Blur Begone") {
      for entry in ModSettings.GetVars(n"Blur Begone", category) {
        values.Read(entry);
      }
    }
    return values;
  }

  @if(ModuleExists("ModSettingsModule"))
  private func Read(entry: ref<ConfigVar>) -> Void {
    let number = entry as ModConfigVarFloat;
    if IsDefined(number) {
      switch entry.GetName() {
        case n"blackWindowTintHue":
          this.tintHue = number.GetValue();
          break;
        case n"blackWindowTintSaturation":
          this.tintSaturation = number.GetValue();
          break;
      }
      return;
    }
    let flag = entry as ModConfigVarBool;
    if !IsDefined(flag) {
      return;
    }
    switch entry.GetName() {
      case n"enabled":
        this.enabled = flag.GetValue();
        break;
      case n"windowTextureScaling":
        this.windowTextureScaling = flag.GetValue();
        break;
      case n"paintedTextureScaling":
        this.paintedTextureScaling = flag.GetValue();
        break;
      case n"blackWindowTextureScaling":
        this.blackWindowTextureScaling = flag.GetValue();
        break;
      case n"hotkeyEnabled":
        this.hotkeyEnabled = flag.GetValue();
        break;
    }
  }

  // The toggle key can turn Blur Begone on with Enabled off, so Debug never needs Enabled
  public func Applies(name: CName) -> Bool {
    switch name {
      case n"enabled":
      case n"hotkeyEnabled":
      case n"blackWindowPlanes":
        return true;
      case n"toggleKey":
        return this.hotkeyEnabled;
      case n"windowTextureScale":
        return this.enabled && this.windowTextureScaling;
      case n"paintedTextureScale":
        return this.enabled && this.paintedTextureScaling;
      case n"blackWindowTextureScale":
        return this.enabled && this.blackWindowTextureScaling;
    }
    return this.enabled;
  }
}
