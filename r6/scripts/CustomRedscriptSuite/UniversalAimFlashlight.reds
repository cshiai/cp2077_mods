// Universal Aiming & Tactical Flashlight (Patch 2.50)
// Companion Redscript module for UniversalAimFlashlight.dll (RED4ext v1.31.0).
//
// Features:
// 1. Dynamically attaches two camera-bound gameLightComponent spotlights to PlayerPuppet
//    during OnRequestComponents via the native EnsureAimFlashlightComponents() bridge:
//      - n"Flashlight"     : Main tactical spotlight (shadows + inverse-square falloff)
//      - n"FlashlightFill" : Wide peripheral bounce/fill light for pitch-black interiors
// 2. Automatically turns the tactical flashlight ON when aiming with any weapon
//    (AimingStateEvents.OnEnter) and dynamically adapts beam range/cone/intensity to
//    the equipped weapon class (Sniper/Precision vs. Standard Ranged vs. Shotgun/CQB).
// 3. Automatically turns the flashlight OFF when exiting aim (AimingStateEvents.OnExit
//    and PlayerPuppet.OnUpperBodyStateChange), unless manual persistent mode is active.
// 4. Unlocks CDPR's double-tap Scanner Hold (Tab / LB) gesture in retail builds so the
//    flashlight can also be toggled ON/OFF manually at any time outside of aiming.

@addMethod(Entity)
public final native func CreateAimFlashlightComponent(name: CName) -> ref<IComponent>;

@addMethod(PlayerPuppet)
private final func EnsureAimFlashlightComponents() -> Void {
  let mainLight: ref<IComponent> = this.CreateAimFlashlightComponent(n"Flashlight");
  if IsDefined(mainLight) {
    this.AddComponent(mainLight);
  };
  let fillLight: ref<IComponent> = this.CreateAimFlashlightComponent(n"FlashlightFill");
  if IsDefined(fillLight) {
    this.AddComponent(fillLight);
  };
}

@addField(PlayerPuppet)
private let m_aimFlashlightManualOverride: Bool;

@addField(PlayerPuppet)
private let m_aimFlashlightActiveFromAim: Bool;

@addMethod(PlayerPuppet)
public final func ComputeWeaponMuzzleLightPosition(weapon: ref<WeaponObject>) -> Vector4 {
  // Default muzzle-tip position (1.05m forward of camera, 5cm below bore axis, 2cm right)
  let forwardY: Float = 1.05;
  let verticalZ: Float = -0.05;
  let rightX: Float = 0.02;

  if IsDefined(weapon) && weapon.IsRanged() {
    let muzzleOffset: Vector4 = weapon.GetMuzzleOffset();
    let sightOffset: Vector4 = weapon.HasScope() ? weapon.GetScopeOffset() : weapon.GetIronSightOffset();
    let barrelDeltaY: Float = muzzleOffset.Y - sightOffset.Y;
    let barrelDeltaZ: Float = muzzleOffset.Z - sightOffset.Z;

    // Eye relief from camera to optic/sight is ~0.35m; place light 0.25m past the muzzle tip
    // so the cone never touches the scope lens, barrel, or muzzle brake.
    if barrelDeltaY > 0.05 {
      forwardY = ClampF(0.60 + barrelDeltaY, 1.00, 1.65);
    } else {
      if muzzleOffset.Y > 0.20 {
        forwardY = ClampF(0.55 + muzzleOffset.Y, 1.00, 1.65);
      };
    };

    if AbsF(barrelDeltaZ) > 0.001 && AbsF(barrelDeltaZ) < 0.30 {
      verticalZ = ClampF(barrelDeltaZ - 0.03, -0.10, -0.03);
    };
  };

  return new Vector4(rightX, forwardY, verticalZ, 1.00);
}

@addMethod(PlayerPuppet)
public final func ApplyWeaponFlashlightProfile(weapon: ref<WeaponObject>, enable: Bool) -> Void {
  let mainLight: ref<gameLightComponent> = this.FindComponentByName(n"Flashlight") as gameLightComponent;
  let fillLight: ref<gameLightComponent> = this.FindComponentByName(n"FlashlightFill") as gameLightComponent;
  if !IsDefined(mainLight) {
    return;
  };

  if !enable {
    if mainLight.IsOn() {
      mainLight.ToggleLight(false, false);
    };
    if IsDefined(fillLight) && fillLight.IsOn() {
      fillLight.ToggleLight(false, false);
    };
    return;
  };

  let muzzleLightPos: Vector4 = this.ComputeWeaponMuzzleLightPosition(weapon);
  mainLight.SetLocalPosition(muzzleLightPos);
  if IsDefined(fillLight) {
    fillLight.SetLocalPosition(muzzleLightPos);
  };

  let weaponType: gamedataItemType = gamedataItemType.Invalid;
  if IsDefined(weapon) {
    let itemRecord: ref<Item_Record> = RPGManager.GetItemRecord(weapon.GetItemID());
    if IsDefined(itemRecord) && IsDefined(itemRecord.ItemType()) {
      weaponType = itemRecord.ItemType().Type();
    };
  };

  let mainSettings: gameLightSettings = mainLight.GetDefaultSettings();
  mainSettings.strength = 1.00;

  if Equals(weaponType, gamedataItemType.Wea_SniperRifle) || Equals(weaponType, gamedataItemType.Wea_PrecisionRifle) {
    // Ultra-long-throw precision spotter beam (160m throw, 6500 lm)
    mainSettings.radius = 160.00;
    mainSettings.innerAngle = 14.00;
    mainSettings.outerAngle = 36.00;
    mainSettings.intensity = 6500.00;
  } else {
    if Equals(weaponType, gamedataItemType.Wea_Shotgun) || Equals(weaponType, gamedataItemType.Wea_ShotgunDual) || Equals(weaponType, gamedataItemType.Wea_LightMachineGun) || Equals(weaponType, gamedataItemType.Wea_HeavyMachineGun) || (IsDefined(weapon) && weapon.IsMelee()) {
      // High-output wide CQB flood beam (90m throw, 3800 lm)
      mainSettings.radius = 90.00;
      mainSettings.innerAngle = 30.00;
      mainSettings.outerAngle = 70.00;
      mainSettings.intensity = 3800.00;
    } else {
      // High-output tactical beam for Handguns, Revolvers, SMGs, Assault Rifles, Unarmed (120m throw, 4500 lm)
      mainSettings.radius = 120.00;
      mainSettings.innerAngle = 22.00;
      mainSettings.outerAngle = 55.00;
      mainSettings.intensity = 4500.00;
    };
  };

  mainLight.SetParameters(mainSettings, 0.03);

  if IsDefined(fillLight) {
    let fillSettings: gameLightSettings = fillLight.GetDefaultSettings();
    fillSettings.strength = 1.00;
    fillSettings.radius = 55.00;
    fillSettings.innerAngle = 42.00;
    fillSettings.outerAngle = 95.00;
    fillSettings.intensity = 1800.00;
    fillLight.SetParameters(fillSettings, 0.03);
  };
}

@addMethod(PlayerPuppet)
public final func SetAimFlashlightState(enable: Bool) -> Void {
  let rightWeapon: ref<WeaponObject> = GameInstance.GetTransactionSystem(this.GetGame()).GetItemInSlot(this, t"AttachmentSlots.WeaponRight") as WeaponObject;
  this.ApplyWeaponFlashlightProfile(rightWeapon, enable);
}

@addMethod(PlayerPuppet)
public final func OnAimFlashlightEnter(weapon: ref<WeaponObject>) -> Void {
  this.m_aimFlashlightActiveFromAim = true;
  this.ApplyWeaponFlashlightProfile(weapon, true);
}

@addMethod(PlayerPuppet)
public final func OnAimFlashlightExit() -> Void {
  this.m_aimFlashlightActiveFromAim = false;
  if !this.m_aimFlashlightManualOverride {
    this.ApplyWeaponFlashlightProfile(null, false);
  };
}

@wrapMethod(PlayerPuppet)
protected cb func OnRequestComponents(ri: EntityRequestComponentsInterface) -> Bool {
  this.EnsureAimFlashlightComponents();
  EntityRequestComponentsInterface.RequestComponent(ri, n"Flashlight", n"gameLightComponent", false);
  EntityRequestComponentsInterface.RequestComponent(ri, n"FlashlightFill", n"gameLightComponent", false);
  return wrappedMethod(ri);
}

@wrapMethod(PlayerPuppet)
protected cb func OnTakeControl(ri: EntityResolveComponentsInterface) -> Bool {
  let result: Bool = wrappedMethod(ri);
  this.m_aimFlashlightManualOverride = false;
  this.m_aimFlashlightActiveFromAim = false;
  this.SetAimFlashlightState(false);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnUpperBodyStateChange(newState: Int32) -> Bool {
  let result: Bool = wrappedMethod(newState);
  if newState != 6 && this.m_aimFlashlightActiveFromAim {
    this.OnAimFlashlightExit();
  };
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnToggleNewPlayerFlashlightEvent(evt: ref<ToggleNewPlayerFlashlightEvent>) -> Bool {
  this.m_aimFlashlightManualOverride = !this.m_aimFlashlightManualOverride;
  let shouldEnable: Bool = this.m_aimFlashlightManualOverride || this.m_aimFlashlightActiveFromAim;
  this.SetAimFlashlightState(shouldEnable);
  GameObject.PlaySoundEvent(this, n"ui_menu_onpress");
  return true;
}

@wrapMethod(PlayerVisionModeController)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  if IsFinal() && Equals(ListenerAction.GetName(action), this.m_inputActionsNames.m_buttonHold) {
    let time: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(this.m_owner.GetGame()));
    if ListenerAction.IsButtonJustPressed(action) {
      this.m_otherVars.m_buttonHoldPressTime = time;
      if time >= this.m_otherVars.m_buttonHoldTapTime + 0.25 {
        this.m_otherVars.m_buttonHoldTapCount = 0;
      };
      if this.m_otherVars.m_buttonHoldTapCount % 2 == 1 {
        let evt: ref<ToggleNewPlayerFlashlightEvent> = new ToggleNewPlayerFlashlightEvent();
        GetPlayer(this.m_owner.GetGame()).QueueEvent(evt);
        return true;
      };
    } else {
      if ListenerAction.IsButtonJustReleased(action) && time < this.m_otherVars.m_buttonHoldPressTime + 0.25 {
        this.m_otherVars.m_buttonHoldTapTime = time;
        this.m_otherVars.m_buttonHoldTapCount += 1;
      };
    };
  };
  return wrappedMethod(action, consumer);
}

@wrapMethod(AimingStateEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    let weapon: ref<WeaponObject> = this.GetWeaponObject(scriptInterface);
    player.OnAimFlashlightEnter(weapon);
  };
}

@wrapMethod(AimingStateEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    player.OnAimFlashlightExit();
  };
  wrappedMethod(stateContext, scriptInterface);
}
