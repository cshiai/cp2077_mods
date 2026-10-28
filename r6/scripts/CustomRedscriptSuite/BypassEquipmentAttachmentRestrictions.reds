// BypassEquipmentAttachmentRestrictions: dependency-free bypass for equipment,
// cyberware slot/capacity, weapon attachment, and weapon-mod restrictions on 2.5:
// 1. Bypasses player level, stat, and perk prerequisites for equipping items.
// 2. Unlocks perk-locked equipment/cyberware slots and adds +9000 transient
//    Cyberware Capacity (Humanity).
// 3. Bypasses tier/quality restrictions when installing weapon mods/attachments
//    and allows all installed weapon mods to be freely uninstalled/swapped.

module BypassEquipmentAttachmentRestrictions

@addField(PlayerPuppet)
private let bypassEquipHumanityModifier: ref<gameStatModifierData>;

@addMethod(PlayerPuppet)
public final func ApplyBypassEquipHumanity() -> Void {
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  if !IsDefined(stats) { return; }
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.bypassEquipHumanityModifier) {
    this.bypassEquipHumanityModifier = RPGManager.CreateStatModifier(gamedataStatType.Humanity, gameStatModifierType.Additive, 9000.0);
  };
  if IsDefined(this.bypassEquipHumanityModifier) {
    // Stat containers are rebuilt during save/load and equipment refreshes;
    // reattach the same transient modifier instead of trusting the stale ref.
    stats.RemoveModifier(id, this.bypassEquipHumanityModifier);
    stats.AddModifier(id, this.bypassEquipHumanityModifier);
  }
}

public func BypassIsConvenienceEquipment(itemData: wref<gameItemData>) -> Bool {
  if !IsDefined(itemData) || RPGManager.IsItemBroken(itemData) || itemData.HasTag(n"UnequipBlocked") {
    return false;
  }
  let itemID = itemData.GetID();
  let area = EquipmentSystem.GetEquipAreaType(itemID);
  return RPGManager.IsItemWeapon(itemID) || BypassIsCyberwareArea(area)
    || Equals(itemData.GetItemType(), gamedataItemType.Clo_Head)
    || Equals(itemData.GetItemType(), gamedataItemType.Clo_OuterChest)
    || Equals(itemData.GetItemType(), gamedataItemType.Clo_InnerChest)
    || Equals(itemData.GetItemType(), gamedataItemType.Clo_Legs)
    || Equals(itemData.GetItemType(), gamedataItemType.Clo_Feet);
}

public func BypassIsCyberwareArea(area: gamedataEquipmentArea) -> Bool {
  switch area {
    case gamedataEquipmentArea.ArmsCW:
    case gamedataEquipmentArea.CardiovascularSystemCW:
    case gamedataEquipmentArea.EyesCW:
    case gamedataEquipmentArea.FrontalCortexCW:
    case gamedataEquipmentArea.HandsCW:
    case gamedataEquipmentArea.IntegumentarySystemCW:
    case gamedataEquipmentArea.LegsCW:
    case gamedataEquipmentArea.MusculoskeletalSystemCW:
    case gamedataEquipmentArea.NervousSystemCW:
    case gamedataEquipmentArea.SystemReplacementCW:
      return true;
  }
  return false;
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.ApplyBypassEquipHumanity();
  return result;
}

@wrapMethod(PlayerPuppet)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
  wrappedMethod(playerPuppet);
  this.ApplyBypassEquipHumanity();
}

@wrapMethod(PlayerPuppet)
protected func OnResurrected() -> Void {
  wrappedMethod();
  this.ApplyBypassEquipHumanity();
}

@wrapMethod(EquipmentSystemPlayerData)
public final const func IsEquippable(itemData: wref<gameItemData>) -> Bool {
  if !IsDefined(itemData) {
    return false;
  };
  if wrappedMethod(itemData) {
    return true;
  }
  // Only waive ordinary player equipment prerequisites.  Broken, quest-
  // protected, and non-equipment records retain vanilla rejection.
  return BypassIsConvenienceEquipment(itemData);
}

@wrapMethod(EquipmentSystemPlayerData)
private final const func CheckEquipPrereqs(itemID: ItemID, randomVariant: Int32) -> Bool {
  let vanilla: Bool = wrappedMethod(itemID, randomVariant);
  if vanilla || !ItemID.IsValid(itemID) || !IsDefined(this.m_owner) {
    return vanilla;
  }
  let itemData: ref<gameItemData> = RPGManager.GetItemData(this.m_owner.GetGame(), this.m_owner, itemID);
  return BypassIsConvenienceEquipment(itemData);
}

@wrapMethod(EquipmentSystemPlayerData)
private final const func IsSlotLocked(slot: SEquipSlot, out visibleWhenLocked: Bool) -> Bool {
  return wrappedMethod(slot, visibleWhenLocked);
}

@wrapMethod(EquipmentSystemPlayerData)
public final const func IsSlotLocked(equipAreaType: gamedataEquipmentArea, index: Int32, out visibleWhenLocked: Bool) -> Bool {
  let vanilla: Bool = wrappedMethod(equipAreaType, index, visibleWhenLocked);
  if !vanilla || index < 0 || !BypassIsCyberwareArea(equipAreaType) {
    return vanilla;
  }
  visibleWhenLocked = true;
  return false;
}

@wrapMethod(InventoryDataManagerV2)
public final func IsSlotLocked(equipmentArea: gamedataEquipmentArea, slotIndex: Int32, out visibleWhenLocked: Bool) -> Bool {
  let vanilla: Bool = wrappedMethod(equipmentArea, slotIndex, visibleWhenLocked);
  if !vanilla || slotIndex < 0 || !BypassIsCyberwareArea(equipmentArea) {
    return vanilla;
  }
  visibleWhenLocked = true;
  return false;
}

@wrapMethod(InventoryDataManagerV2)
public final func CanInstallPart(const itemData: script_ref<InventoryItemData>) -> Bool {
  let vanilla: Bool = wrappedMethod(itemData);
  if vanilla || InventoryItemData.IsEmpty(itemData) {
    return vanilla;
  };
  let partID: ItemID = InventoryItemData.GetID(itemData);
  let partData: ref<gameItemData> = InventoryItemData.GetGameItemData(itemData);
  if !ItemID.IsValid(partID) || !IsDefined(partData) || partData.HasTag(n"UnequipBlocked") {
    return false;
  }
  let partType: gamedataItemType = partData.GetItemType();
  // IsEquipped is an ItemID-level flag.  It is true when one copy of a
  // deterministic/stackable mod is already installed on another weapon, so
  // rejecting it here hides valid duplicate installs from the chooser.
  return InventoryItemData.IsPart(itemData)
    && (RPGManager.IsWeaponMod(partID) || RPGManager.IsClothingMod(partID)
      || Equals(partType, gamedataItemType.CyberwareStatsShard)
      || Equals(partType, gamedataItemType.Prt_Program)
      || RPGManager.IsScopeAttachment(partType) || RPGManager.IsMuzzleAttachment(partType));
}

@wrapMethod(InventoryGPRestrictionHelper)
public static final func CanEquip(const itemData: script_ref<InventoryItemData>, player: wref<PlayerPuppet>) -> Bool {
  let vanilla: Bool = wrappedMethod(itemData, player);
  if vanilla {
    return true;
  }
  if InventoryItemData.IsPart(itemData) && !InventoryItemData.IsEmpty(itemData) {
    let partData: ref<gameItemData> = InventoryItemData.GetGameItemData(itemData);
    if IsDefined(partData) && !partData.HasTag(n"UnequipBlocked") {
      return true;
    }
  }
  return false;
}

@wrapMethod(InventoryDataManagerV2)
public final func GetPlayerInventoryPartsForItemRef(item: ItemID, const slotIDs: script_ref<array<TweakDBID>>, opt filteredItems: array<ItemModParams>, outputItems: script_ref<array<InventoryItemData>>) -> Void {
  wrappedMethod(item, slotIDs, filteredItems, outputItems);

  let i = 0;
  while i < ArraySize(Deref(outputItems)) {
    InventoryItemData.SetIsRequirementMet(Deref(outputItems)[i], true);
    i += 1;
  }
}

@wrapMethod(RPGManager)
public static final func GetFirstUnmetEquipRequirement(owner: ref<GameObject>, const equipRequirements: script_ref<array<SItemStackRequirementData>>) -> SItemStackRequirementData {
  let emptyRequirement: SItemStackRequirementData;
  return emptyRequirement;
}

@wrapMethod(RPGManager)
public static final func CanPartBeUnequipped(data: InventoryItemData, slotId: TweakDBID) -> Bool {
  return wrappedMethod(data, slotId);
}

@wrapMethod(RPGManager)
private static final func IsNonModifableSlot(slot: TweakDBID) -> Bool {
  return wrappedMethod(slot);
}
