// RelentlessLiveDismember by Cazanu - arm wounds and weapon handling.
module CazanuLimbSurvival

public abstract class ArmCombat {
  // Unlike arm-only combat eligibility, attachment cleanup also covers an NPC
  // with leg wounds. Reservations close the gap before status effects arrive.
  public static func MissingWeaponSlot(npc: wref<NPCPuppet>, slot: TweakDBID) -> Bool {
    if NotEquals(slot, t"AttachmentSlots.WeaponLeft") && NotEquals(slot, t"AttachmentSlots.WeaponRight") {
      return false;
    }
    if !Settings.Enabled() || !IsDefined(npc) || !npc.CLS_IsTrackedSurvivor()
      || !npc.IsAttached() || !ScriptedPuppet.IsAlive(npc)
      || npc.IsAboutToDieOrDefeated() || ScriptedPuppet.IsDefeated(npc) {
      return false;
    }
    if Equals(slot, t"AttachmentSlots.WeaponLeft") {
      return npc.CLS_IsLimbReserved(gameDismBodyPart.LEFT_ARM) || ArmCombat.MissingLeft(npc);
    }
    if Equals(slot, t"AttachmentSlots.WeaponRight") {
      return npc.CLS_IsLimbReserved(gameDismBodyPart.RIGHT_ARM) || ArmCombat.MissingRight(npc);
    }
    return false;
  }

  public static func IsHandheldItem(item: ItemID) -> Bool {
    let kind = RPGManager.GetItemType(item);
    // Fists and implanted weapons are animation/cyberware equipment, not
    // separate objects to spawn as loose loot from a missing hand.
    return RPGManager.IsItemWeapon(item) && NotEquals(kind, gamedataItemType.Wea_Fists)
      && NotEquals(kind, gamedataItemType.Cyb_StrongArms)
      && NotEquals(kind, gamedataItemType.Cyb_MantisBlades)
      && NotEquals(kind, gamedataItemType.Cyb_NanoWires);
  }

  public static func RejectEquip(npc: wref<NPCPuppet>, context: ScriptExecutionContext, record: wref<AISubActionForceEquip_Record>) -> Bool {
    if !IsDefined(record) || !IsDefined(record.AttachmentSlot())
      || !ArmCombat.MissingWeaponSlot(npc, record.AttachmentSlot().GetID()) {
      return false;
    }
    let item: ItemID;
    return AISubActionForceEquip_Record_Implementation.GetItemID(context, record, item)
      && ArmCombat.IsHandheldItem(item);
  }

  public static func RemoveMissingHandEquipRequests(npc: wref<NPCPuppet>) -> Void {
    let controller = npc.GetAIControllerComponent();
    if !IsDefined(controller) { return; }
    let board = controller.GetActionBlackboard();
    if !IsDefined(board) { return; }
    let pending = FromVariant<array<NPCItemToEquip>>(board.GetVariant(GetAllBlackboardDefs().AIAction.ownerItemsToEquip));
    let kept: array<NPCItemToEquip>;
    let i = 0;
    while i < ArraySize(pending) {
      if !ArmCombat.MissingWeaponSlot(npc, pending[i].slotID) || !ArmCombat.IsHandheldItem(pending[i].itemID) {
        ArrayPush(kept, pending[i]);
      }
      i += 1;
    }
    if ArraySize(kept) != ArraySize(pending) {
      board.SetVariant(GetAllBlackboardDefs().AIAction.ownerItemsToEquip, ToVariant(kept));
    }
  }

  public static func Eligible(npc: wref<NPCPuppet>) -> Bool {
    return Settings.Enabled() && IsDefined(npc) && npc.CLS_IsTrackedSurvivor()
      && npc.IsAttached() && ScriptedPuppet.IsAlive(npc) && npc.IsActive()
      && !npc.IsAboutToDieOrDefeated() && !ScriptedPuppet.IsDefeated(npc)
      && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft")
      && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
  }

  public static func MissingLeft(npc: wref<NPCPuppet>) -> Bool {
    return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmLeft")
      || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedHandLeft");
  }

  public static func MissingRight(npc: wref<NPCPuppet>) -> Bool {
    return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmRight")
      || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedHandRight");
  }

  // Test the slot actually being changed, not an assumption that every NPC
  // holds a gun in its right hand. Never restore the absent hand's ability.
  public static func SurvivingGun(npc: wref<NPCPuppet>, slot: TweakDBID) -> wref<WeaponObject> {
    let empty: wref<WeaponObject>;
    if !ArmCombat.Eligible(npc) {
      return empty;
    }
    let left = ArmCombat.MissingLeft(npc);
    let right = ArmCombat.MissingRight(npc);
    let hand: gamedataStatType;
    if left && !right && Equals(slot, t"AttachmentSlots.WeaponRight") {
      hand = gamedataStatType.CanUseRightHand;
    } else {
      if right && !left && Equals(slot, t"AttachmentSlots.WeaponLeft") {
        hand = gamedataStatType.CanUseLeftHand;
      } else {
        return empty;
      }
    }
    if GameInstance.GetStatsSystem(npc.GetGame()).GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), hand) <= 0.0 {
      return empty;
    }
    let weapon = GameInstance.GetTransactionSystem(npc.GetGame()).GetItemInSlot(npc, slot) as WeaponObject;
    if IsDefined(weapon) && weapon.IsRanged() {
      // Native WoundedShoot uses HandgunRight/LeftArmLookatCondition, whose
      // equipped-item predicates accept handgun and revolver types only. A
      // rifle retained here could lose its aiming look-at and stop shooting;
      // allow native wound entry to swap those guns for a compatible pistol.
      let weaponType = WeaponObject.GetWeaponType(weapon.GetItemID());
      if Equals(weaponType, gamedataItemType.Wea_Handgun)
        || Equals(weaponType, gamedataItemType.Wea_Revolver) {
        return weapon;
      }
    }
    return empty;
  }

  private static func ContainsSubAction(actionID: TweakDBID, subActionID: TweakDBID) -> Bool {
    let action = TweakDBInterface.GetAIActionRecord(actionID);
    if !IsDefined(action) {
      return false;
    }
    let i = 0;
    while i < action.GetStartupSubActionsCount() {
      let subAction = action.GetStartupSubActionsItem(i);
      if IsDefined(subAction) && Equals(subAction.GetID(), subActionID) {
        return true;
      }
      i += 1;
    }
    i = 0;
    while i < action.GetLoopSubActionsCount() {
      let subAction = action.GetLoopSubActionsItem(i);
      if IsDefined(subAction) && Equals(subAction.GetID(), subActionID) {
        return true;
      }
      i += 1;
    }
    return false;
  }

  // Resolve child records from the installed game. Inline record indices vary
  // between versions; only the native surviving arm-wound entry is affected.
  public static func IsWoundEntrySubAction(npc: wref<NPCPuppet>, id: TweakDBID) -> Bool {
    if ArmCombat.MissingLeft(npc) {
      return ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberLArmEntryDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberLArmEntryRevolverDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberLArmEntryLexingtonDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberLArmEntryKnifeDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberLArmEntryFistDefinition", id);
    }
    if ArmCombat.MissingRight(npc) {
      return ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberRArmEntryDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberRArmEntryRevolverDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberRArmEntryLexingtonDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberRArmEntryKnifeDefinition", id)
        || ArmCombat.ContainsSubAction(t"StatusEffectActions.SE_WoundedCyberRArmEntryFistDefinition", id);
    }
    return false;
  }
}

// The native left-arm entry drops WeaponRight, even when that is the healthy
// gun hand, then equips a replacement pistol. Preserve a compatible gun and
// let the original wound reaction and one-handed combat behavior continue.
@wrapMethod(AISubActionForceUnequip_Record_Implementation)
public static func Unequip(context: ScriptExecutionContext, record: wref<AISubActionForceUnequip_Record>) -> Bool {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if IsDefined(record) && IsDefined(record.AttachmentSlot()) {
    let weapon = ArmCombat.SurvivingGun(npc, record.AttachmentSlot().GetID());
    if IsDefined(weapon) && ArmCombat.IsWoundEntrySubAction(npc, record.GetID()) {
      npc.CLS_LogArmCombat(n"kept_gun_in_surviving_hand", weapon, record.GetID());
      return true;
    }
  }
  return wrappedMethod(context, record);
}

@wrapMethod(AISubActionForceEquip_Record_Implementation)
public static func Activate(context: ScriptExecutionContext, record: wref<AISubActionForceEquip_Record>) -> Void {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if ArmCombat.RejectEquip(npc, context, record) {
    ArmCombat.RemoveMissingHandEquipRequests(npc);
    return;
  }
  wrappedMethod(context, record);
}

@wrapMethod(AISubActionForceEquip_Record_Implementation)
public static func Equip(context: ScriptExecutionContext, record: wref<AISubActionForceEquip_Record>) -> Bool {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if ArmCombat.RejectEquip(npc, context, record) {
    ArmCombat.RemoveMissingHandEquipRequests(npc);
    npc.CLS_QueueArmWeaponCleanup();
    return false;
  }
  if IsDefined(record) && IsDefined(record.AttachmentSlot()) {
    let weapon = ArmCombat.SurvivingGun(npc, record.AttachmentSlot().GetID());
    if IsDefined(weapon) && ArmCombat.IsWoundEntrySubAction(npc, record.GetID()) {
      // Activate queued the native replacement. Complete its bookkeeping just
      // as a successful native Equip does, without replacing the retained gun.
      AIActionHelper.ClearItemsToEquip(npc);
      npc.CLS_LogArmCombat(n"kept_gun_instead_of_replacement", weapon, record.GetID());
      return true;
    }
  }
  return wrappedMethod(context, record);
}

// Replacement wound pistols are not necessarily in the character's original
// equipment list. The native unregistered-item cleanup branch would select
// WaitBeforeRemovingUnhandledWeapon for them. Treat a usable one-handed gun
// in the surviving hand as intentional wound equipment, not an orphan item.
@wrapMethod(CheckUnregisteredWeapon)
protected func Check(context: ScriptExecutionContext) -> AIbehaviorConditionOutcomes {
  let result = wrappedMethod(context);
  if NotEquals(result, AIbehaviorConditionOutcomes.True) {
    return result;
  }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  let weapon = ArmCombat.SurvivingGun(npc, t"AttachmentSlots.WeaponRight");
  if !IsDefined(weapon) {
    weapon = ArmCombat.SurvivingGun(npc, t"AttachmentSlots.WeaponLeft");
  }
  if IsDefined(weapon) {
    if !npc.cls_armGunAcceptedLogged {
      npc.cls_armGunAcceptedLogged = true;
      npc.CLS_LogArmCombat(n"accepted_wounded_handgun", weapon, t"ItemHandling.WaitBeforeRemovingUnhandledWeapon");
    }
    return AIbehaviorConditionOutcomes.False;
  }
  return result;
}

@addField(NPCPuppet)
private let cls_armCombatLogCount: Int32;
@addField(NPCPuppet)
private let cls_armGunAcceptedLogged: Bool;

@addMethod(NPCPuppet)
public final func CLS_LogArmCombat(stage: CName, weapon: wref<WeaponObject>, record: TweakDBID) -> Void {
  if !Diagnostics.Enabled() || this.cls_armCombatLogCount >= 8 || !IsDefined(weapon) {
    return;
  }
  this.cls_armCombatLogCount += 1;
  Diagnostics.Write(s"ARM_COMBAT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_armCombatLogCount)/8 stage=\(NameToString(stage)) weapon=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(weapon.GetItemID()))) record=\(TDBID.ToStringDEBUG(record)) missingLeft=\(ArmCombat.MissingLeft(this)) missingRight=\(ArmCombat.MissingRight(this))");
}

// Observe actual native shooting requests after the wound. Do not manufacture
// shots, ignore ammunition, or bypass target/aim/friendly-fire checks.
@wrapMethod(AISubActionShootWithWeapon_Record_Implementation)
public static func Shoot(context: ScriptExecutionContext, record: wref<AISubActionShootWithWeapon_Record>, duration: Float, weapon: wref<WeaponObject>, requestedTriggerMode: gamedataTriggerMode, targetPosition: Vector4, target: wref<GameObject>, opt offset: Vector4, opt predictionTime: Float, opt muzzleOffset: Vector4, opt weaponCustomEvent: CName) -> Void {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if IsDefined(npc) && IsDefined(weapon) && npc.CLS_IsTrackedSurvivor() {
    let ts = GameInstance.GetTransactionSystem(npc.GetGame());
    if (ArmCombat.MissingWeaponSlot(npc, t"AttachmentSlots.WeaponLeft") && weapon == ts.GetItemInSlot(npc, t"AttachmentSlots.WeaponLeft"))
      || (ArmCombat.MissingWeaponSlot(npc, t"AttachmentSlots.WeaponRight") && weapon == ts.GetItemInSlot(npc, t"AttachmentSlots.WeaponRight")) {
      AIWeapon.OnStopShooting(weapon, 0.0);
      npc.CLS_QueueArmWeaponCleanup();
      return;
    }
  }
  wrappedMethod(context, record, duration, weapon, requestedTriggerMode, targetPosition, target, offset, predictionTime, muzzleOffset, weaponCustomEvent);
  if Diagnostics.Enabled() && IsDefined(npc) && npc.cls_armCombatLogCount < 8
    && ArmCombat.Eligible(npc) && (ArmCombat.MissingLeft(npc) || ArmCombat.MissingRight(npc))
    && IsDefined(record) {
    npc.CLS_LogArmCombat(n"native_shoot", weapon, record.GetID());
  }
}

public class CLS_ArmWeaponCleanupEvent extends Event {
  public let attempts: Int32;
}

@addField(NPCPuppet)
private let cls_armWeaponCleanupQueued: Bool;
@addField(NPCPuppet)
private let cls_armWeaponCleanupLogs: Int32;

@addMethod(NPCPuppet)
public final func CLS_QueueArmWeaponCleanup() -> Void {
  if this.cls_armWeaponCleanupQueued
    || (!ArmCombat.MissingWeaponSlot(this, t"AttachmentSlots.WeaponLeft")
      && !ArmCombat.MissingWeaponSlot(this, t"AttachmentSlots.WeaponRight")) { return; }
  this.cls_armWeaponCleanupQueued = true;
  this.QueueEvent(new CLS_ArmWeaponCleanupEvent());
}

@addMethod(NPCPuppet)
private final func CLS_DropMissingHandWeapon(slot: TweakDBID, attempt: Int32) -> Bool {
  if !ArmCombat.MissingWeaponSlot(this, slot) { return false; }
  let item = GameInstance.GetTransactionSystem(this.GetGame()).GetItemInSlot(this, slot);
  if !IsDefined(item) || !ArmCombat.IsHandheldItem(item.GetItemID()) { return false; }
  let weapon = item as WeaponObject;
  if IsDefined(weapon) && weapon.IsRanged() { AIWeapon.OnStopShooting(weapon, 0.0); }
  // ScriptedPuppet.DropItemFromSlot actually drops BOTH hands. The native
  // event with a valid slot detaches only this side and creates its loot drop.
  if attempt < 3 {
    let drop = new gameDropItemEvent();
    drop.slotId = slot;
    this.QueueEvent(drop);
  }
  if Diagnostics.Enabled() && this.cls_armWeaponCleanupLogs < 16 {
    this.cls_armWeaponCleanupLogs += 1;
    Diagnostics.Write(s"ARM_WEAPON_CLEANUP npc=\(EntityID.ToDebugString(this.GetEntityID())) slot=\(TDBID.ToStringDEBUG(slot)) item=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(item.GetItemID()))) attempt=\(attempt) dropRequested=\(attempt < 3)");
  }
  return true;
}

@addMethod(NPCPuppet)
protected cb func OnCLS_ArmWeaponCleanupEvent(evt: ref<CLS_ArmWeaponCleanupEvent>) -> Bool {
  // Check both sides without short-circuiting. Coalesce events and verify the
  // async native drop, with at most three requests per affected slot.
  let left = this.CLS_DropMissingHandWeapon(t"AttachmentSlots.WeaponLeft", evt.attempts);
  let right = this.CLS_DropMissingHandWeapon(t"AttachmentSlots.WeaponRight", evt.attempts);
  if (left || right) && evt.attempts < 3 {
    let verify = new CLS_ArmWeaponCleanupEvent();
    verify.attempts = evt.attempts + 1;
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, verify, 0.10, true);
  } else {
    this.cls_armWeaponCleanupQueued = false;
    if evt.attempts > 0 && Diagnostics.Enabled() && this.cls_armWeaponCleanupLogs < 16 {
      this.cls_armWeaponCleanupLogs += 1;
      Diagnostics.Write(s"ARM_WEAPON_CLEANUP npc=\(EntityID.ToDebugString(this.GetEntityID())) verifiedNoMissingHandWeapon=\(!left && !right) attached=\(this.IsAttached()) alive=\(ScriptedPuppet.IsAlive(this))");
    }
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
  let result = wrappedMethod(evt);
  if ArmCombat.MissingWeaponSlot(this, evt.GetSlotID()) {
    this.CLS_QueueArmWeaponCleanup();
  }
  return result;
}

@wrapMethod(NPCPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if IsDefined(evt.staticData) {
    let id = evt.staticData.GetID();
    if Equals(id, t"BaseStatusEffect.DismemberedArmLeft") || Equals(id, t"BaseStatusEffect.DismemberedHandLeft")
      || Equals(id, t"BaseStatusEffect.DismemberedArmRight") || Equals(id, t"BaseStatusEffect.DismemberedHandRight") {
      this.CLS_QueueArmWeaponCleanup();
    }
  }
  return result;
}
