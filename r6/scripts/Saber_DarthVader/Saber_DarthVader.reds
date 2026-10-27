// Darth Vader's Lightsaber – fixed, CET-free REDscript implementation.
// The weapon remains a vanilla katana record, while the blade, audio, and
// bullet-deflection behavior are owned by this module.
module SaberDarthVader

@if(ModuleExists("Audioware"))
import Audioware.*
import Codeware.Localization.PlayerGender

public func Saber_Record() -> TweakDBID {
  return t"Items.Saber_DarthVader";
}

public func Saber_Is(weapon: ref<ItemObject>) -> Bool {
  return IsDefined(weapon) && Equals(ItemID.GetTDBID(weapon.GetItemID()), Saber_Record());
}

// m_saberLitActive is deliberately checked before resolving the active weapon.
// Most callers are perk/stat queries; the common false path is therefore O(1).
public func Saber_PlayerHoldsSaber(player: ref<GameObject>) -> Bool {
  if !IsDefined(player) || !player.IsPlayer() { return false; }
  let puppet: ref<PlayerPuppet> = player as PlayerPuppet;
  if IsDefined(puppet) && !puppet.m_saberLitActive { return false; }
  let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(player);
  return Saber_Is(weapon) && weapon.saberOn;
}

@addField(PlayerPuppet)
public let m_saberLitActive: Bool;

public func Saber_SetPlayerLitFlag(weapon: ref<WeaponObject>, active: Bool) -> Void {
  if !IsDefined(weapon) { return; }
  let player: ref<PlayerPuppet> = weapon.GetOwner() as PlayerPuppet;
  if IsDefined(player) {
    player.m_saberLitActive = active;
  }
}

public func Saber_SfxVariants(id: CName) -> Int32 {
  switch id {
    case n"saber_on": return 4;
    case n"saber_off": return 4;
    case n"saber_swing": return 9;
    case n"saber_hit": return 7;
    case n"saber_block": return 7;
    case n"saber_deflect": return 14;
    default: return 1;
  }
}

public func Saber_SfxVolume() -> Float { return 0.32; }
public func Saber_HumVolume() -> Float { return 0.22; }

// Audioware is optional.  When installed the supplied SWBF2 events are used;
// otherwise this branch intentionally uses only vanilla Wwise events.
@if(ModuleExists("Audioware"))
public func Saber_HasSwbf2Bank(game: GameInstance) -> Bool {
  return GameInstance.GetAudioSystemExt(game).Duration(n"saber_on_1") > 0.0;
}

@if(ModuleExists("Audioware"))
public func Saber_PlaySfx(game: GameInstance, id: CName) -> Void {
  let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
  if !IsDefined(player) { return; }
  if Saber_HasSwbf2Bank(game) {
    let variant = StringToName(NameToString(id) + "_" + IntToString(RandRange(1, Saber_SfxVariants(id) + 1)));
    let settings = new AudioSettingsExt();
    settings.volume = Saber_SfxVolume();
    GameInstance.GetAudioSystemExt(game).Play(variant, player.GetEntityID(), n"", scnDialogLineType.None, settings);
  } else {
    GameObject.PlaySoundEvent(player, Saber_FallbackSfx(id));
  }
}

@if(ModuleExists("Audioware"))
public func Saber_Hum(game: GameInstance, on: Bool) -> Void {
  let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
  if !IsDefined(player) { return; }
  if Saber_HasSwbf2Bank(game) {
    if on {
      let settings = new AudioSettingsExt();
      settings.volume = Saber_HumVolume();
      settings.loop = true;
      GameInstance.GetAudioSystemExt(game).Play(n"saber_hum_1", player.GetEntityID(), n"", scnDialogLineType.None, settings);
    } else {
      GameInstance.GetAudioSystemExt(game).Stop(n"saber_hum_1", player.GetEntityID(), n"", null);
    }
  } else {
    let audio = GameInstance.GetAudioSystem(game);
    if on { audio.Play(n"w_melee_katana_handling_soft", player.GetEntityID()); } else { audio.Stop(n"w_melee_katana_handling_soft", player.GetEntityID()); }
  }
}

@if(ModuleExists("Audioware"))
public func Saber_MuteKatana(game: GameInstance, mute: Bool) -> Void {
  if mute && !Saber_HasSwbf2Bank(game) { return; }
  let manager = new AudioEventManager();
  for name in Saber_KatanaEvents() {
    if mute { manager.Mute(name); } else { manager.Unmute(name); }
  }
}

public func Saber_FallbackSfx(id: CName) -> CName {
  switch id {
    case n"saber_on": return n"w_melee_katana_equip";
    case n"saber_off": return n"w_melee_katana_unequip";
    case n"saber_swing": return n"w_cyb_mantis_impact_flesh";
    case n"saber_hit": return n"w_cyb_mantis_impact_flesh";
    case n"saber_block": return n"w_melee_perks_katana_bullet_deflecting";
    case n"saber_deflect": return n"w_melee_perks_katana_bullet_deflecting";
    default: return n"w_melee_katana_handling_medium";
  }
}

@if(!ModuleExists("Audioware"))
public func Saber_PlaySfx(game: GameInstance, id: CName) -> Void {
  let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
  if IsDefined(player) {
    GameObject.PlaySoundEvent(player, Saber_FallbackSfx(id));
  }
}

@if(!ModuleExists("Audioware"))
public func Saber_Hum(game: GameInstance, on: Bool) -> Void {
  let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
  if !IsDefined(player) { return; }
  let audio = GameInstance.GetAudioSystem(game);
  if on {
    audio.Play(n"w_melee_katana_handling_soft", player.GetEntityID());
  } else {
    audio.Stop(n"w_melee_katana_handling_soft", player.GetEntityID());
  }
}

// Without Audioware there is no mute manager; native katana events remain active.
@if(!ModuleExists("Audioware"))
public func Saber_MuteKatana(game: GameInstance, mute: Bool) -> Void {}

public func Saber_KatanaEvents() -> array<CName> {
  return [
    n"w_melee_katana_whoosh", n"w_melee_katana_whoosh_fast", n"w_melee_katana_whoosh_large",
    n"w_melee_katana_hit_slash", n"w_melee_katana_hit_stab", n"w_melee_katana_blood",
    n"w_melee_katana_impact_basic", n"w_melee_katana_impact_block", n"w_melee_katana_impact_flesh", n"w_melee_katana_impact_power",
    n"w_melee_katana_ring_block", n"w_melee_katana_quickmelee",
    n"w_melee_katana_additional_handling", n"w_melee_katana_additional_handling_short", n"w_melee_katana_additional_ring",
    n"w_melee_katana_handling_medium", n"w_melee_katana_handling_soft", n"w_melee_katana_handling_strong",
    n"w_melee_katana_equip", n"w_melee_katana_unequip",
    n"w_melee_katana_first_equip", n"w_melee_katana_first_equip_01", n"w_melee_katana_first_equip_03",
    n"w_melee_katana_finisher_beheading", n"w_melee_katana_finisher_stab",
    n"w_melee_finisher_katana_cut", n"w_melee_finisher_katana_slash",
    n"w_melee_finisher_katana01_hit", n"w_melee_finisher_katana01_hit_final", n"w_melee_finisher_katana02",
    n"w_melee_perks_katana_bullet_deflecting", n"w_melee_katana_bending_sparks"
  ];
}

// --- blade extend / retract -------------------------------------------------
public func Saber_Stages() -> Int32 { return 8; }
public func Saber_StepTime() -> Float { return 0.035; }

@addField(WeaponObject) public let saberOn: Bool;
@addField(WeaponObject) public let saberStage: Int32;
@addField(WeaponObject) public let saberAnimGen: Int32;

// CName lookups avoid GetComponents(), NameToString(), and prefix scans on
// every animation step.  The eight names are stable in the shipped .app.
public func Saber_StageComponentName(index: Int32) -> CName {
  switch index {
    case 1: return n"saber_blade_1";
    case 2: return n"saber_blade_2";
    case 3: return n"saber_blade_3";
    case 4: return n"saber_blade_4";
    case 5: return n"saber_blade_5";
    case 6: return n"saber_blade_6";
    case 7: return n"saber_blade_7";
    case 8: return n"saber_blade_8";
    default: return n"saber_blade_1";
  }
}

public func Saber_ApplyStageTo(ent: ref<Entity>, stage: Int32) -> Void {
  if !IsDefined(ent) { return; }
  let i: Int32 = 1;
  while i <= Saber_Stages() {
    let component = ent.FindComponentByName(Saber_StageComponentName(i));
    if IsDefined(component) {
      component.Toggle(i == stage);
    }
    i += 1;
  }
  let glow = ent.FindComponentByName(n"saber_blade_glow");
  if IsDefined(glow) {
    glow.Toggle(stage >= 3);
  }
}

public func Saber_ApplyStage(weapon: ref<WeaponObject>) -> Void {
  Saber_ApplyStageTo(weapon, weapon.saberStage);
  let ts = GameInstance.GetTransactionSystem(weapon.GetGame());
  let data = weapon.GetItemData();
  if IsDefined(data) {
    let parts: array<InnerItemData>;
    data.GetItemParts(parts);
    for part in parts {
      Saber_ApplyStageTo(ts.GetItemInSlot(weapon, InnerItemData.GetSlotID(part)), weapon.saberStage);
    }
  }
  Saber_ApplyStageTo(ts.GetItemInSlot(weapon, t"AttachmentSlots.Grip"), weapon.saberStage);
}

public class SaberStepCallback extends DelayCallback {
  public let weapon: wref<WeaponObject>;
  public let gen: Int32;
  public let waitLeft: Float;
  public let playSound: Bool;

  public func Call() -> Void {
    let w = this.weapon;
    if !IsDefined(w) || w.saberAnimGen != this.gen { return; }
    if this.waitLeft > 0.0 {
      Saber_ApplyStage(w);
      this.waitLeft -= Saber_StepTime();
      this.Schedule();
      return;
    }
    if this.playSound {
      this.playSound = false;
      Saber_PlaySfx(w.GetGame(), w.saberOn ? n"saber_on" : n"saber_off");
      Saber_Hum(w.GetGame(), w.saberOn);
    }
    let target = w.saberOn ? Saber_Stages() : 0;
    if w.saberStage != target {
      w.saberStage += w.saberOn ? 1 : -1;
      Saber_ApplyStage(w);
    }
    if w.saberStage != target { this.Schedule(); }
  }

  public func Schedule() -> Void {
    let delay = GameInstance.GetDelaySystem(this.weapon.GetGame());
    if IsDefined(delay) {
      delay.DelayCallback(this, Saber_StepTime(), false);
    }
  }
}

public func Saber_SetOn(weapon: ref<WeaponObject>, on: Bool, delay: Float) -> Void {
  if !IsDefined(weapon) || Equals(weapon.saberOn, on) { return; }
  weapon.saberOn = on;
  Saber_SetPlayerLitFlag(weapon, on);
  weapon.saberAnimGen += 1;
  let cb = new SaberStepCallback();
  cb.weapon = weapon;
  cb.gen = weapon.saberAnimGen;
  cb.waitLeft = delay;
  cb.playSound = true;
  cb.Schedule();
}

// --- draw / holster ---------------------------------------------------------
@wrapMethod(WeaponObject)
protected cb func OnSetActiveWeapon(evt: ref<SetActiveWeaponEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if Saber_Is(this) {
    Saber_SetPlayerLitFlag(this, false);
    Saber_MuteKatana(this.GetGame(), true);
    this.saberOn = false;
    this.saberStage = 0;
    Saber_ApplyStage(this);
    Saber_SetOn(this, true, 0.3);
  }
  return result;
}

@wrapMethod(WeaponObject)
protected cb func OnRemoveActiveWeapon(evt: ref<RemoveActiveWeaponEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if Saber_Is(this) {
    Saber_SetPlayerLitFlag(this, false);
    this.saberAnimGen += 1;
    Saber_Hum(this.GetGame(), false);
    if this.saberOn { Saber_PlaySfx(this.GetGame(), n"saber_off"); }
    this.saberOn = false;
    this.saberStage = 0;
    Saber_ApplyStage(this);
    Saber_MuteKatana(this.GetGame(), false);
  }
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  if Equals(ListenerAction.GetName(action), n"Reload") && ListenerAction.IsButtonJustPressed(action) {
    let weapon = GameObject.GetActiveWeapon(this);
    if Saber_Is(weapon) {
      Saber_SetOn(weapon, !weapon.saberOn, 0.0);
    }
  }
  return wrappedMethod(action, consumer);
}

// Keep cached state correct across save/load and entity teardown.
@wrapMethod(PlayerPuppet)
protected cb func OnTakeControl(ri: EntityResolveComponentsInterface) -> Bool {
  let result: Bool = wrappedMethod(ri);
  this.m_saberLitActive = false;
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  this.m_saberLitActive = false;
  return wrappedMethod();
}

// Unlock the recipe for every save, without duplicating known entries.
public func Saber_EnsureRecipe(player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(player) { return; }
  let crafting = CraftingSystem.GetInstance(player.GetGame());
  if !IsDefined(crafting) { return; }
  let book = crafting.GetPlayerCraftBook();
  if IsDefined(book) && !book.KnowsRecipe(t"Items.Saber_DarthVader") {
    book.AddRecipe(t"Items.Saber_DarthVader");
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnMakePlayerVisibleAfterSpawn(evt: ref<EndGracePeriodAfterSpawn>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  Saber_EnsureRecipe(this);
  return result;
}

// --- no "hand along the blade" first-equip animation -----------------------
@wrapMethod(FirstEquipSystem)
public final const func HasPlayedFirstEquip(weaponID: TweakDBID) -> Bool {
  return Equals(weaponID, Saber_Record()) || wrappedMethod(weaponID);
}

@wrapMethod(EquipmentBaseTransition)
protected final const func HandleWeaponEquip(scriptInterface: ref<StateGameScriptInterface>, stateContext: ref<StateContext>, stateMachineInstanceData: StateMachineInstanceData, item: ItemID, isLeftWeapon: Bool) -> Void {
  if Equals(ItemID.GetTDBID(item), Saber_Record()) {
    let request = this.GetProcessedEquipmentManipulationRequest(stateMachineInstanceData, stateContext);
    if IsDefined(request) && Equals(request.equipAnim, gameEquipAnimationType.FirstEquip) {
      request.equipAnim = gameEquipAnimationType.Default;
    }
  }
  wrappedMethod(scriptInterface, stateContext, stateMachineInstanceData, item, isLeftWeapon);
}

// --- swings / hits ----------------------------------------------------------
@wrapMethod(MeleeAttackGenericEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let weapon = MeleeTransition.GetWeaponObject(scriptInterface);
  if Saber_Is(weapon) {
    if weapon.saberOn { Saber_PlaySfx(weapon.GetGame(), n"saber_swing"); }
    else { Saber_SetOn(weapon, true, 0.0); }
  }
}

@wrapMethod(WeaponObject)
protected cb func OnMeleeHitEvent(evt: ref<MeleeHitEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if Saber_Is(this) && this.saberOn && IsDefined(evt.instigator) && evt.instigator.IsPlayer() {
    Saber_PlaySfx(this.GetGame(), evt.hitBlocked ? n"saber_block" : n"saber_hit");
  }
  return result;
}

// --- bullet deflection without the perk while holding the lightsaber --------
@wrapMethod(PlayerDevelopmentData)
public final const func IsNewPerkBought(perkType: gamedataNewPerkType) -> Int32 {
  let level = wrappedMethod(perkType);
  if Equals(perkType, gamedataNewPerkType.Reflexes_Right_Milestone_2) && level < 2 && Saber_PlayerHoldsSaber(this.m_owner) {
    return 2;
  }
  if Equals(perkType, gamedataNewPerkType.Reflexes_Right_Perk_2_1) && level == 0 && Saber_PlayerHoldsSaber(this.m_owner) {
    return 1;
  }
  return level;
}

@wrapMethod(DamageSystem)
private final func ProcessBulletDeflect(hitEvent: ref<gameHitEvent>, isBulletTimeActive: Bool, blockingItem: wref<ItemObject>) -> Void {
  wrappedMethod(hitEvent, isBulletTimeActive, blockingItem);
  if Saber_Is(blockingItem) { Saber_PlaySfx(blockingItem.GetGame(), n"saber_deflect"); }
}

@wrapMethod(UIItemsHelper)
public final static func GetItemTypeKey(itemID: TweakDBID, itemType: gamedataItemType, weaponEvolutionType: gamedataWeaponEvolution) -> String {
  if Equals(itemID, Saber_Record()) { return "Lightsaber"; }
  return wrappedMethod(itemID, itemType, weaponEvolutionType);
}

@wrapMethod(InventoryItemDisplayController)
protected func NewUpdateWeaponType(itemData: ref<UIInventoryItem>) -> Void {
  wrappedMethod(itemData);
  if IsDefined(itemData) && Equals(itemData.GetTweakDBID(), Saber_Record()) {
    inkTextRef.SetText(this.m_weaponType, "Lightsaber");
  }
}

@wrapMethod(InventoryItemDisplayController)
protected func RefreshUI() -> Void {
  wrappedMethod();
  if Equals(ItemID.GetTDBID(InventoryItemData.GetID(this.m_itemData)), Saber_Record()) {
    inkTextRef.SetText(this.m_weaponType, "Lightsaber");
  }
}

public func Saber_DefendAngle() -> Float { return 100.0; }
public func Saber_DeflectStaminaRefund() -> Float { return 0.8; }

@wrapMethod(DamageManager)
private final static func CanBlockBullet(hitEvent: ref<gameHitEvent>) -> Bool {
  if wrappedMethod(hitEvent) { return true; }
  if !Saber_PlayerHoldsSaber(hitEvent.target) || !AttackData.IsRangedOnly(hitEvent.attackData.GetAttackType()) { return false; }
  let cameraForward = GameInstance.GetCameraSystem(hitEvent.target.GetGame()).GetActiveCameraForward();
  return Vector4.GetAngleBetween(hitEvent.hitDirection, cameraForward) > 180.0 - Saber_DefendAngle();
}

@wrapMethod(DamageSystem)
private final func ProcessBulletBlockAndDeflect(hitEvent: ref<gameHitEvent>) -> Void {
  let target = hitEvent.target;
  if !Saber_PlayerHoldsSaber(target) {
    wrappedMethod(hitEvent);
    return;
  }
  let pools = GameInstance.GetStatPoolsSystem(target.GetGame());
  let id = Cast<StatsObjectID>(target.GetEntityID());
  let before = pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, false);
  wrappedMethod(hitEvent);
  let after = pools.GetStatPoolValue(id, gamedataStatPoolType.Stamina, false);
  if after < before {
    pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.Stamina, (before - after) * Saber_DeflectStaminaRefund(), null, false, false);
  }
}
