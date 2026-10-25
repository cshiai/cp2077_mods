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
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.bypassEquipHumanityModifier) {
    this.bypassEquipHumanityModifier = RPGManager.CreateStatModifier(gamedataStatType.Humanity, gameStatModifierType.Additive, 9000.0);
    stats.AddModifier(id, this.bypassEquipHumanityModifier);
  };
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
  if itemData == null {
    return false;
  };
  return !RPGManager.IsItemBroken(itemData);
}

@wrapMethod(EquipmentSystemPlayerData)
private final const func CheckEquipPrereqs(itemID: ItemID, randomVariant: Int32) -> Bool {
  return true;
}

@wrapMethod(EquipmentSystemPlayerData)
private final const func IsSlotLocked(slot: SEquipSlot, out visibleWhenLocked: Bool) -> Bool {
  visibleWhenLocked = true;
  return false;
}

@wrapMethod(EquipmentSystemPlayerData)
public final const func IsSlotLocked(equipAreaType: gamedataEquipmentArea, index: Int32, out visibleWhenLocked: Bool) -> Bool {
  visibleWhenLocked = true;
  return false;
}

@wrapMethod(InventoryDataManagerV2)
public final func IsSlotLocked(equipmentArea: gamedataEquipmentArea, slotIndex: Int32, out visibleWhenLocked: Bool) -> Bool {
  visibleWhenLocked = true;
  return false;
}

@wrapMethod(InventoryDataManagerV2)
public final func CanInstallPart(const itemData: script_ref<InventoryItemData>) -> Bool {
  if InventoryItemData.IsEmpty(itemData) || InventoryItemData.IsEquipped(itemData) {
    return false;
  };
  return true;
}

@wrapMethod(InventoryDataManagerV2)
public final func GetPlayerInventoryPartsForItemRef(item: ItemID, const slotIDs: script_ref<array<TweakDBID>>, opt filteredItems: array<ItemModParams>, outputItems: script_ref<array<InventoryItemData>>) -> Void {
  wrappedMethod(item, slotIDs, filteredItems, outputItems);
  let i: Int32 = 0;
  while i < ArraySize(Deref(outputItems)) {
    InventoryItemData.SetIsRequirementMet(Deref(outputItems)[i], true);
    i += 1;
  };
}

@wrapMethod(RPGManager)
public static final func GetFirstUnmetEquipRequirement(owner: ref<GameObject>, const equipRequirements: script_ref<array<SItemStackRequirementData>>) -> SItemStackRequirementData {
  let emptyRequirement: SItemStackRequirementData;
  return emptyRequirement;
}

@wrapMethod(RPGManager)
public static final func CanPartBeUnequipped(data: InventoryItemData, slotId: TweakDBID) -> Bool {
  return true;
}

@wrapMethod(RPGManager)
private static final func IsNonModifableSlot(slot: TweakDBID) -> Bool {
  return false;
}
