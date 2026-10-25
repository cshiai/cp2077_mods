// ============================================================================
// UniversalSlotsAndAttachments.reds (Cyberpunk 2077 v2.5)
// 100% Pure Redscript — Zero TweakXL / Zero tweakdb.bin edits
// ============================================================================
// 1. Cyberdecks — Duplicate Quickhacks & All Blueprint Program Slots Unlocked:
//    - Allows multiple copies of the same quickhack (any tier or same tier) to
//      sit in multiple cyberdeck slots simultaneously without evicting existing
//      copies (`ItemModificationSystem.RemoveOtherShards`,
//      `RPGManager.RemoveDuplicatedHacks`, `InventoryDataManagerV2.DistinctPrograms`).
//    - Keeps all copies of quickhacks visible in the cyberdeck part picker
//      (`InventoryDataManagerV2.GetPlayerInventoryPartsDataForItem`).
//    - Unlocks all quality-gated slots on cyberdecks regardless of tier.
//
// 2. Cyberware Arms — Unlocking Unused Vanilla Blueprint Mod Slots + Monowire Slot:
//    - Exposes the 2 unused vanilla blueprint slots already present in
//      `tweakdb.bin` on every Cyberware Arm (`Cyb_StrongArms`, `Cyb_MantisBlades`,
//      `Cyb_NanoWires`, `Cyb_Launcher`):
//        * Gorilla Arms: `AttachmentSlots.StrongArmsBattery` +
//                        `AttachmentSlots.ArmsCyberwareGeneralSlot`
//        * Mantis Blades: `AttachmentSlots.MantisBladesRotor` +
//                         `AttachmentSlots.ArmsCyberwareGeneralSlot`
//        * Monowire:      `AttachmentSlots.NanoWiresBattery` +
//                         `AttachmentSlots.ArmsCyberwareGeneralSlot` +
//                         `AttachmentSlots.NanoWiresQuickhackSlot` (unlocked
//                         without requiring the Relic perk)
//        * Projectile Launcher: `AttachmentSlots.ProjectileLauncherWiring` +
//                               `AttachmentSlots.ArmsCyberwareGeneralSlot`
//    - Allows weapon mods to be installed and swapped in those Cyberware Arm slots.
//
// 3. Weapons — Universal Attachments & Mods Unlocker + Iconic Upgrade Compatibility:
//    - Unlocks all existing weapon blueprint slots (`Scope`, `PowerModule`,
//      `WeaponMod1..2`, `Tech_Handgun_WeaponMod1..4`, `GenericWeaponMod1..4`)
//      immediately at Tier 1+ (`RPGManager.IsSlotAvailable`,
//      `RPGManager.ShouldSlotBeAvailable`, `InventoryDataManagerV2.ShouldSlotBeAvailable`).
//    - Removes the per-weapon `SlotPartList` scope/muzzle restriction in
//      `InventoryDataManagerV2.GetPlayerInventoryPartsDataForItem` so any scope
//      (`Prt_ShortScope`, `Prt_LongScope`, `Prt_PowerSniperScope`,
//      `Prt_TechSniperScope`) fits any `Scope` slot and any muzzle/silencer
//      (`Prt_Muzzle`, `Prt_HandgunMuzzle`, `Prt_RifleMuzzle`) fits any
//      `PowerModule` slot.
//    - Allows cross-family weapon mod slotting across all ranged/melee weapon
//      mod slots (`PlacementSlotsContains`, `IsMatchingSlot`, `GetMatchingSlot`).
//    - Protects Iconic weapons from having mods or attachments stripped by
//      `CraftingSystem.ClearNonIconicSlots`, working seamlessly with
//      `UniversalIconicWeapons.reds`.
//
// 4. Two-Column Attachment & Mod Slot UI (`InventoryWeaponItemChooser`,
//    `InventoryGenericItemChooser`):
//    - Arranges weapon attachments and mod slots in a clean 2-column layout.
// ============================================================================

@if(ModuleExists("SlotsSlotsSlots.Core"))
import SlotsSlotsSlots.Core.*

public abstract class UniversalSlotsHelper {

  public final static func AppendUnique( slots: script_ref<array<TweakDBID>>, slotID: TweakDBID) -> Void {
    if !ArrayContains(Deref(slots), slotID) {
      ArrayPush(Deref(slots), slotID);
    }
  }

  public final static func AppendAllUnique(slots: script_ref<array<TweakDBID>>, extra: array<TweakDBID>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(extra) {
      UniversalSlotsHelper.AppendUnique(slots, extra[i]);
      i += 1;
    }
  }

  public final static func IsRangedWeaponType(type: gamedataItemType) -> Bool {
    switch type {
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_Rifle:
      case gamedataItemType.Wea_SubmachineGun:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_PrecisionRifle:
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
        return true;
      default:
        return false;
    }
  }

  public final static func IsMeleeWeaponType(type: gamedataItemType) -> Bool {
    switch type {
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_Chainsword:
      case gamedataItemType.Wea_Axe:
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Melee:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Hammer:
      case gamedataItemType.Wea_TwoHandedClub:
      case gamedataItemType.Wea_Fists:
        return true;
      default:
        return false;
    }
  }

  public final static func IsCyberwareArmType(type: gamedataItemType) -> Bool {
    switch type {
      case gamedataItemType.Cyb_StrongArms:
      case gamedataItemType.Cyb_MantisBlades:
      case gamedataItemType.Cyb_NanoWires:
      case gamedataItemType.Cyb_Launcher:
        return true;
      default:
        return false;
    }
  }

  public final static func IsRangedWeaponModType(partType: gamedataItemType) -> Bool {
    switch partType {
      case gamedataItemType.Prt_Mod:
      case gamedataItemType.Prt_RangedMod:
      case gamedataItemType.Prt_PowerMod:
      case gamedataItemType.Prt_TechMod:
      case gamedataItemType.Prt_SmartMod:
      case gamedataItemType.Prt_AR_SMG_LMGMod:
      case gamedataItemType.Prt_HandgunMod:
      case gamedataItemType.Prt_Precision_Sniper_RifleMod:
      case gamedataItemType.Prt_ShotgunMod:
        return true;
      default:
        return false;
    }
  }

  public final static func IsMeleeWeaponModType(partType: gamedataItemType) -> Bool {
    switch partType {
      case gamedataItemType.Prt_Mod:
      case gamedataItemType.Prt_MeleeMod:
      case gamedataItemType.Prt_BladeMod:
      case gamedataItemType.Prt_BluntMod:
      case gamedataItemType.Prt_ThrowableMod:
        return true;
      default:
        return false;
    }
  }

  public final static func IsAnyWeaponModType(partType: gamedataItemType) -> Bool {
    return UniversalSlotsHelper.IsRangedWeaponModType(partType)
      || UniversalSlotsHelper.IsMeleeWeaponModType(partType)
      || RPGManager.IsWeaponMod(partType);
  }

  public final static func IsScopePartType(partType: gamedataItemType) -> Bool {
    switch partType {
      case gamedataItemType.Prt_ShortScope:
      case gamedataItemType.Prt_LongScope:
      case gamedataItemType.Prt_PowerSniperScope:
      case gamedataItemType.Prt_TechSniperScope:
        return true;
      default:
        return RPGManager.IsScopeAttachment(partType);
    }
  }

  public final static func IsMuzzlePartType(partType: gamedataItemType) -> Bool {
    switch partType {
      case gamedataItemType.Prt_Muzzle:
      case gamedataItemType.Prt_HandgunMuzzle:
      case gamedataItemType.Prt_RifleMuzzle:
        return true;
      default:
        return false;
    }
  }

  public final static func GetCyberwareArmModSlots(type: gamedataItemType) -> array<TweakDBID> {
    let slots: array<TweakDBID>;
    switch type {
      case gamedataItemType.Cyb_StrongArms:
        ArrayPush(slots, t"AttachmentSlots.StrongArmsBattery");
        ArrayPush(slots, t"AttachmentSlots.ArmsCyberwareGeneralSlot");
        break;
      case gamedataItemType.Cyb_MantisBlades:
        ArrayPush(slots, t"AttachmentSlots.MantisBladesRotor");
        ArrayPush(slots, t"AttachmentSlots.ArmsCyberwareGeneralSlot");
        break;
      case gamedataItemType.Cyb_NanoWires:
        ArrayPush(slots, t"AttachmentSlots.NanoWiresBattery");
        ArrayPush(slots, t"AttachmentSlots.ArmsCyberwareGeneralSlot");
        break;
      case gamedataItemType.Cyb_Launcher:
        ArrayPush(slots, t"AttachmentSlots.ProjectileLauncherWiring");
        ArrayPush(slots, t"AttachmentSlots.ArmsCyberwareGeneralSlot");
        break;
      default:
        break;
    }
    return slots;
  }

  public final static func GetAllCyberwareArmModSlots() -> array<TweakDBID> {
    return [
      t"AttachmentSlots.StrongArmsBattery",
      t"AttachmentSlots.MantisBladesRotor",
      t"AttachmentSlots.NanoWiresBattery",
      t"AttachmentSlots.ProjectileLauncherWiring",
      t"AttachmentSlots.ArmsCyberwareGeneralSlot"
    ];
  }

  public final static func GetAllRangedWeaponModSlots() -> array<TweakDBID> {
    return [
      t"AttachmentSlots.GenericWeaponMod1",
      t"AttachmentSlots.GenericWeaponMod2",
      t"AttachmentSlots.GenericWeaponMod3",
      t"AttachmentSlots.GenericWeaponMod4",
      t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod1",
      t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod2",
      t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod1_Collectible",
      t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod2_Collectible",
      t"AttachmentSlots.Tech_AR_SMG_LMG_WeaponMod1",
      t"AttachmentSlots.Tech_AR_SMG_LMG_WeaponMod2",
      t"AttachmentSlots.Smart_AR_SMG_LMG_WeaponMod1",
      t"AttachmentSlots.Smart_AR_SMG_LMG_WeaponMod2",
      t"AttachmentSlots.Power_Handgun_WeaponMod1",
      t"AttachmentSlots.Power_Handgun_WeaponMod2",
      t"AttachmentSlots.Power_Handgun_WeaponMod1_Collectible",
      t"AttachmentSlots.Power_Handgun_WeaponMod2_Collectible",
      t"AttachmentSlots.Tech_Handgun_WeaponMod1",
      t"AttachmentSlots.Tech_Handgun_WeaponMod2",
      t"AttachmentSlots.Tech_Handgun_WeaponMod3",
      t"AttachmentSlots.Tech_Handgun_WeaponMod4",
      t"AttachmentSlots.Smart_Handgun_WeaponMod1",
      t"AttachmentSlots.Smart_Handgun_WeaponMod2",
      t"AttachmentSlots.Smart_Handgun_WeaponMod1_Collectible",
      t"AttachmentSlots.Smart_Handgun_WeaponMod2_Collectible",
      t"AttachmentSlots.Power_Precision_Sniper_Rifle_WeaponMod1",
      t"AttachmentSlots.Power_Precision_Sniper_Rifle_WeaponMod2",
      t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod1",
      t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod2",
      t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod1_Collectible",
      t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod2_Collectible",
      t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod1",
      t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod2",
      t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod1_Collectible",
      t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod2_Collectible",
      t"AttachmentSlots.Power_Shotgun_WeaponMod1",
      t"AttachmentSlots.Power_Shotgun_WeaponMod2",
      t"AttachmentSlots.Power_Shotgun_WeaponMod1_Collectible",
      t"AttachmentSlots.Power_Shotgun_WeaponMod2_Collectible",
      t"AttachmentSlots.Tech_Shotgun_WeaponMod1",
      t"AttachmentSlots.Tech_Shotgun_WeaponMod2",
      t"AttachmentSlots.Smart_Shotgun_WeaponMod1",
      t"AttachmentSlots.Smart_Shotgun_WeaponMod2"
    ];
  }

  public final static func GetAllMeleeWeaponModSlots() -> array<TweakDBID> {
    return [
      t"AttachmentSlots.MeleeWeaponMod1",
      t"AttachmentSlots.MeleeWeaponMod2",
      t"AttachmentSlots.MeleeWeaponMod3",
      t"AttachmentSlots.Blade_WeaponMod1",
      t"AttachmentSlots.Blade_WeaponMod2",
      t"AttachmentSlots.Blade_WeaponMod1_Collectible",
      t"AttachmentSlots.Blade_WeaponMod2_Collectible",
      t"AttachmentSlots.Blunt_WeaponMod1",
      t"AttachmentSlots.Blunt_WeaponMod2",
      t"AttachmentSlots.Blunt_WeaponMod1_Collectible",
      t"AttachmentSlots.Blunt_WeaponMod2_Collectible",
      t"AttachmentSlots.Throwable_WeaponMod1",
      t"AttachmentSlots.Throwable_WeaponMod2",
      t"AttachmentSlots.Throwable_WeaponMod1_Collectible",
      t"AttachmentSlots.Throwable_WeaponMod2_Collectible"
    ];
  }

  @if(ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSRangedSlot(slotID: TweakDBID) -> Bool {
    let slots: array<TweakDBID> = SSS_Ids.Ranged();
    return ArrayContains(slots, slotID);
  }

  @if(!ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSRangedSlot(slotID: TweakDBID) -> Bool {
    return false;
  }

  @if(ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSMeleeSlot(slotID: TweakDBID) -> Bool {
    let slots: array<TweakDBID> = SSS_Ids.Melee();
    return ArrayContains(slots, slotID);
  }

  @if(!ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSMeleeSlot(slotID: TweakDBID) -> Bool {
    return false;
  }

  public final static func IsRangedWeaponModSlot(slotID: TweakDBID) -> Bool {
    let slots: array<TweakDBID> = UniversalSlotsHelper.GetAllRangedWeaponModSlots();
    return ArrayContains(slots, slotID)
      || UniversalSlotsHelper.IsSSSRangedSlot(slotID);
  }

  public final static func IsMeleeWeaponModSlot(slotID: TweakDBID) -> Bool {
    let slots: array<TweakDBID> = UniversalSlotsHelper.GetAllMeleeWeaponModSlots();
    return ArrayContains(slots, slotID)
      || UniversalSlotsHelper.IsSSSMeleeSlot(slotID);
  }

  public final static func IsCyberwareArmModSlot(slotID: TweakDBID) -> Bool {
    let slots: array<TweakDBID> = UniversalSlotsHelper.GetAllCyberwareArmModSlots();
    return ArrayContains(slots, slotID);
  }

  public final static func IsUniversalPartCompatibleWithSlot(partType: gamedataItemType, slotID: TweakDBID) -> Bool {
    if slotID == t"AttachmentSlots.Scope" && UniversalSlotsHelper.IsScopePartType(partType) {
      return true;
    }
    if slotID == t"AttachmentSlots.PowerModule" && UniversalSlotsHelper.IsMuzzlePartType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsRangedWeaponModSlot(slotID) && UniversalSlotsHelper.IsRangedWeaponModType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsMeleeWeaponModSlot(slotID) && UniversalSlotsHelper.IsMeleeWeaponModType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsCyberwareArmModSlot(slotID) && UniversalSlotsHelper.IsAnyWeaponModType(partType) {
      return true;
    }
    return false;
  }

  public final static func NormalizeSlotForUI(slotID: TweakDBID) -> TweakDBID {
    if UniversalSlotsHelper.IsCyberwareArmModSlot(slotID) {
      return t"AttachmentSlots.GenericWeaponMod1";
    }
    return slotID;
  }
}

// ============================================================================
// 1. Cyberdecks: Allow Duplicate Quickhacks in Multiple Slots
// ============================================================================

@wrapMethod(ItemModificationSystem)
private final func RemoveOtherShards(obj: ref<GameObject>, item: ItemID, shardID: ItemID) -> Void {
  if Equals(RPGManager.GetItemType(shardID), gamedataItemType.Prt_Program) {
    return;
  }
  wrappedMethod(obj, item, shardID);
}

@wrapMethod(RPGManager)
private final static func RemoveDuplicatedHacks(commands: script_ref<array<PlayerQuickhackData>>) -> Void {
  // Allow duplicate quickhacks equipped across multiple cyberdeck slots
  return;
}

@wrapMethod(RPGManager)
private final static func RemoveDuplicatedHacks(deck: script_ref<array<wref<ObjectAction_Record>>>, splinter: script_ref<array<wref<ObjectAction_Record>>>) -> Void {
  // Allow duplicate quickhack actions from cyberdeck + monowire/splinter
  return;
}

@wrapMethod(InventoryDataManagerV2)
public final func DistinctPrograms(const items: script_ref<array<ItemID>>) -> array<ItemID> {
  return Deref(items);
}

// ============================================================================
// 2. Unlock All Blueprint Slots Regardless of Quality/Tier + Monowire Slot
// ============================================================================

@wrapMethod(InventoryDataManagerV2)
private final func ShouldSlotBeAvailable(itemData: wref<gameItemData>, attachmentSlotRecord: wref<AttachmentSlot_Record>, owner: wref<GameObject>, itemId: ItemID) -> Bool {
  if IsDefined(attachmentSlotRecord) {
    return true;
  }
  return wrappedMethod(itemData, attachmentSlotRecord, owner, itemId);
}

@replaceMethod(UIInventoryItemModsManager)
private final func GetAttachements(owner: wref<GameObject>, inventoryItem: wref<UIInventoryItem>) -> Void {
  let itemData: wref<gameItemData> = inventoryItem.GetItemData();
  let usedSlots: array<TweakDBID> = this.m_usedSlots;
  let emptySlots: array<TweakDBID> = this.m_emptySlots;
  let emptySlotsSize: Int32 = ArraySize(emptySlots);
  let usedSlotsSize: Int32 = ArraySize(usedSlots);
  if emptySlotsSize < 1 && usedSlotsSize < 1 {
    return;
  }
  let itemId: ItemID = inventoryItem.GetID();
  let inventorySlots: array<TweakDBID> = UIInventoryItemModsStaticData.GetAttachmentSlots(inventoryItem.GetItemType());
  let slotsData: array<AttachmentSlotCacheData>;
  let attachmentSlotRecord: wref<AttachmentSlot_Record>;
  let i: Int32 = 0;
  let limit: Int32 = ArraySize(inventorySlots);
  while i < limit {
    if emptySlotsSize > 0 && ArrayContains(emptySlots, inventorySlots[i]) {
      attachmentSlotRecord = TweakDBInterface.GetAttachmentSlotRecord(inventorySlots[i]);
      ArrayPush(slotsData, new AttachmentSlotCacheData(true, attachmentSlotRecord, IsDefined(attachmentSlotRecord), inventorySlots[i]));
      emptySlotsSize -= 1;
      ArrayRemove(emptySlots, inventorySlots[i]);
    }
    if usedSlotsSize > 0 && ArrayContains(usedSlots, inventorySlots[i]) {
      attachmentSlotRecord = TweakDBInterface.GetAttachmentSlotRecord(inventorySlots[i]);
      ArrayPush(slotsData, new AttachmentSlotCacheData(false, attachmentSlotRecord, IsDefined(attachmentSlotRecord), inventorySlots[i]));
      usedSlotsSize -= 1;
      ArrayRemove(usedSlots, inventorySlots[i]);
    }
    i += 1;
  }

  let partData: InnerItemData;
  let staticData: wref<Item_Record>;
  let attachmentType: InventoryItemAttachmentType;
  let attachmentData: ref<UIInventoryItemModAttachment>;
  i = 0;
  limit = ArraySize(slotsData);
  while i < limit {
    staticData = null;
    if IsDefined(slotsData[i].attachmentSlotRecord) && slotsData[i].shouldBeAvailable {
      if !slotsData[i].empty {
        itemData.GetItemPart(partData, slotsData[i].slotId);
        staticData = InnerItemData.GetStaticData(partData);
        if staticData.TagsContains(n"DummyPart") {
          // skip DummyPart
        } else {
          attachmentType = UIInventoryItemModsStaticData.IsAttachmentDedicated(slotsData[i].slotId) ? InventoryItemAttachmentType.Dedicated : InventoryItemAttachmentType.Generic;
          if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) && staticData == null {
            // skip empty dedicated
          } else {
            attachmentData = new UIInventoryItemModAttachment();
            attachmentData.IsEmpty = slotsData[i].empty;
            if staticData != null {
              if InnerItemData.HasStatData(partData, gamedataStatType.Quality) {
                attachmentData.Quality = RPGManager.GetInnerItemDataQuality(partData);
                if staticData.TagsContains(n"ChimeraMod") {
                  attachmentData.Quality = gamedataQuality.Iconic;
                }
              } else {
                attachmentData.Quality = gamedataQuality.Invalid;
              }
              this.FillSpecialAbilities(staticData, attachmentData.Abilities, itemData, partData);
              attachmentData.AbilitiesSize = ArraySize(attachmentData.Abilities);
              attachmentData.SlotName = LocKeyToString(staticData.DisplayName());
            } else {
              attachmentData.SlotName = GetLocalizedText(UIItemsHelper.GetEmptySlotName(slotsData[i].slotId));
              attachmentData.Quality = gamedataQuality.Invalid;
            }
            if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) {
              this.m_dedicatedMod = attachmentData;
            } else {
              ArrayPush(this.m_mods, attachmentData);
              ArrayPush(this.m_attachments, attachmentData);
            }
          }
        }
      } else {
        attachmentType = UIInventoryItemModsStaticData.IsAttachmentDedicated(slotsData[i].slotId) ? InventoryItemAttachmentType.Dedicated : InventoryItemAttachmentType.Generic;
        if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) && staticData == null {
          // skip empty dedicated
        } else {
          attachmentData = new UIInventoryItemModAttachment();
          attachmentData.IsEmpty = slotsData[i].empty;
          attachmentData.SlotName = GetLocalizedText(UIItemsHelper.GetEmptySlotName(slotsData[i].slotId));
          attachmentData.Quality = gamedataQuality.Invalid;
          if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) {
            this.m_dedicatedMod = attachmentData;
          } else {
            ArrayPush(this.m_mods, attachmentData);
            ArrayPush(this.m_attachments, attachmentData);
          }
        }
      }
    }
    i += 1;
  }
}

@replaceMethod(InventoryDataManagerV2)
public final func GetAttachements(owner: wref<GameObject>, itemData: wref<gameItemData>, usedSlots: array<TweakDBID>, emptySlots: array<TweakDBID>, mods: script_ref<array<ref<MinimalItemTooltipModData>>>, dedicatedMods: script_ref<array<ref<MinimalItemTooltipModAttachmentData>>>) -> Void {
  let emptySlotsSize: Int32 = ArraySize(emptySlots);
  let usedSlotsSize: Int32 = ArraySize(usedSlots);
  if emptySlotsSize < 1 && usedSlotsSize < 1 {
    return;
  }
  let itemId: ItemID = itemData.GetID();
  let inventorySlots: array<TweakDBID> = InventoryDataManagerV2.GetAttachmentSlotsForInventory();
  let slotsData: array<AttachmentSlotCacheData>;
  let attachmentSlotRecord: wref<AttachmentSlot_Record>;
  let i: Int32 = 0;
  let limit: Int32 = ArraySize(inventorySlots);
  while i < limit {
    if emptySlotsSize > 0 && ArrayContains(emptySlots, inventorySlots[i]) {
      attachmentSlotRecord = TweakDBInterface.GetAttachmentSlotRecord(inventorySlots[i]);
      ArrayPush(slotsData, new AttachmentSlotCacheData(true, attachmentSlotRecord, IsDefined(attachmentSlotRecord), inventorySlots[i]));
      emptySlotsSize -= 1;
      ArrayRemove(emptySlots, inventorySlots[i]);
    }
    if usedSlotsSize > 0 && ArrayContains(usedSlots, inventorySlots[i]) {
      attachmentSlotRecord = TweakDBInterface.GetAttachmentSlotRecord(inventorySlots[i]);
      ArrayPush(slotsData, new AttachmentSlotCacheData(false, attachmentSlotRecord, IsDefined(attachmentSlotRecord), inventorySlots[i]));
      usedSlotsSize -= 1;
      ArrayRemove(usedSlots, inventorySlots[i]);
    }
    i += 1;
  }

  let partData: InnerItemData;
  let staticData: wref<Item_Record>;
  let attachmentType: InventoryItemAttachmentType;
  let attachmentData: ref<MinimalItemTooltipModAttachmentData>;
  i = 0;
  limit = ArraySize(slotsData);
  while i < limit {
    staticData = null;
    if IsDefined(slotsData[i].attachmentSlotRecord) && slotsData[i].shouldBeAvailable {
      if !slotsData[i].empty {
        itemData.GetItemPart(partData, slotsData[i].slotId);
        staticData = InnerItemData.GetStaticData(partData);
        if staticData.TagsContains(n"DummyPart") {
          // skip DummyPart
        } else {
          attachmentType = this.IsAttachmentDedicated(slotsData[i].slotId) ? InventoryItemAttachmentType.Dedicated : InventoryItemAttachmentType.Generic;
          if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) && staticData == null {
            // skip empty dedicated
          } else {
            attachmentData = new MinimalItemTooltipModAttachmentData();
            attachmentData.isEmpty = slotsData[i].empty;
            if staticData != null {
              if InnerItemData.HasStatData(partData, gamedataStatType.Quality) {
                attachmentData.qualityName = UIItemsHelper.QualityEnumToName(RPGManager.GetInnerItemDataQuality(partData));
              }
              this.FillSpecialAbilities(staticData, attachmentData.abilities, itemData, partData);
              attachmentData.abilitiesSize = ArraySize(attachmentData.abilities);
              attachmentData.slotName = LocKeyToString(staticData.DisplayName());
            } else {
              attachmentData.slotName = GetLocalizedText(UIItemsHelper.GetEmptySlotName(slotsData[i].slotId));
            }
            if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) {
              ArrayPush(Deref(dedicatedMods), attachmentData);
            } else {
              ArrayPush(Deref(mods), attachmentData);
            }
          }
        }
      } else {
        attachmentType = this.IsAttachmentDedicated(slotsData[i].slotId) ? InventoryItemAttachmentType.Dedicated : InventoryItemAttachmentType.Generic;
        if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) && staticData == null {
          // skip empty dedicated
        } else {
          attachmentData = new MinimalItemTooltipModAttachmentData();
          attachmentData.isEmpty = slotsData[i].empty;
          attachmentData.slotName = GetLocalizedText(UIItemsHelper.GetEmptySlotName(slotsData[i].slotId));
          if Equals(attachmentType, InventoryItemAttachmentType.Dedicated) {
            ArrayPush(Deref(dedicatedMods), attachmentData);
          } else {
            ArrayPush(Deref(mods), attachmentData);
          }
        }
      }
    }
    i += 1;
  }
}

@wrapMethod(UIInventoryItemModsManager)
private final func FilterNanoWireSlot(inventoryItem: wref<UIInventoryItem>) -> Void {
  // Keep Monowire's NanoWiresQuickhackSlot available at all times
  return;
}

// ============================================================================
// 3. Register Cyberware Arm & Weapon Mod Slots in Redscript Slot Tables
// ============================================================================

@wrapMethod(RPGManager)
public final static func GetModsSlotIDs(type: gamedataItemType) -> array<TweakDBID> {
  let arr: array<TweakDBID> = wrappedMethod(type);
  if UniversalSlotsHelper.IsRangedWeaponType(type) {
    UniversalSlotsHelper.AppendAllUnique(arr, UniversalSlotsHelper.GetAllRangedWeaponModSlots());
  } else if UniversalSlotsHelper.IsMeleeWeaponType(type) {
    UniversalSlotsHelper.AppendAllUnique(arr, UniversalSlotsHelper.GetAllMeleeWeaponModSlots());
  } else if UniversalSlotsHelper.IsCyberwareArmType(type) {
    UniversalSlotsHelper.AppendAllUnique(arr, UniversalSlotsHelper.GetCyberwareArmModSlots(type));
  }
  return arr;
}

@wrapMethod(UIInventoryItemModsStaticData)
public final static func GetAttachmentSlots(itemType: gamedataItemType) -> array<TweakDBID> {
  let slots: array<TweakDBID> = wrappedMethod(itemType);
  if UniversalSlotsHelper.IsRangedWeaponType(itemType) {
    UniversalSlotsHelper.AppendUnique(slots, t"AttachmentSlots.Scope");
    UniversalSlotsHelper.AppendUnique(slots, t"AttachmentSlots.PowerModule");
    UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetAllRangedWeaponModSlots());
  } else if UniversalSlotsHelper.IsMeleeWeaponType(itemType) {
    UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetAllMeleeWeaponModSlots());
  } else if UniversalSlotsHelper.IsCyberwareArmType(itemType) {
    UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetCyberwareArmModSlots(itemType));
  }
  return slots;
}

@wrapMethod(InventoryDataManagerV2)
public final static func GetAttachmentSlotsForInventory() -> array<TweakDBID> {
  let slots: array<TweakDBID> = wrappedMethod();
  UniversalSlotsHelper.AppendUnique(slots, t"AttachmentSlots.Scope");
  UniversalSlotsHelper.AppendUnique(slots, t"AttachmentSlots.PowerModule");
  UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetAllRangedWeaponModSlots());
  UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetAllMeleeWeaponModSlots());
  UniversalSlotsHelper.AppendAllUnique(slots, UniversalSlotsHelper.GetAllCyberwareArmModSlots());
  return slots;
}

// ============================================================================
// 4. Universal Part & Mod Placement Compatibility (Scopes, Muzzles, Mods, Arms)
// ============================================================================

@wrapMethod(InventoryDataManagerV2)
private final func PlacementSlotsContains(staticData: wref<Item_Record>, slotID: TweakDBID) -> Bool {
  if wrappedMethod(staticData, slotID) {
    return true;
  }
  if IsDefined(staticData) && IsDefined(staticData.ItemType()) {
    let partType: gamedataItemType = staticData.ItemType().Type();
    if UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, slotID) {
      return true;
    }
  }
  return false;
}

@wrapMethod(InventoryItemData)
public final static func PlacementSlotsContains(self: script_ref<InventoryItemData>, slot: TweakDBID) -> Bool {
  if wrappedMethod(self, slot) {
    return true;
  }
  let partType: gamedataItemType = InventoryItemData.GetItemType(self);
  if UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, slot) {
    return true;
  }
  return false;
}

@wrapMethod(InventoryItemModeLogicController)
private final func IsMatchingSlot(itemData: script_ref<InventoryItemData>, partItemData: script_ref<InventoryItemData>, targetSlot: TweakDBID) -> Bool {
  if wrappedMethod(itemData, partItemData, targetSlot) {
    return true;
  }
  let attachments: array<ref<InventoryItemAttachments>> = InventoryItemData.GetAttachments(itemData);
  let hasTargetSlot: Bool = false;
  let i: Int32 = 0;
  while i < ArraySize(attachments) {
    if attachments[i].SlotID == targetSlot {
      hasTargetSlot = true;
      break;
    }
    i += 1;
  }
  if !hasTargetSlot {
    return false;
  }
  let partType: gamedataItemType = InventoryItemData.GetItemType(partItemData);
  return UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, targetSlot);
}

@wrapMethod(InventoryItemModeLogicController)
private final func GetMatchingSlot(itemData: script_ref<InventoryItemData>, partItemData: script_ref<InventoryItemData>) -> TweakDBID {
  let res: TweakDBID = wrappedMethod(itemData, partItemData);
  if TDBID.IsValid(res) {
    return res;
  }
  let partType: gamedataItemType = InventoryItemData.GetItemType(partItemData);
  let attachments: array<ref<InventoryItemAttachments>> = InventoryItemData.GetAttachments(itemData);
  let i: Int32 = 0;
  while i < ArraySize(attachments) {
    let slotID: TweakDBID = attachments[i].SlotID;
    if UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, slotID) {
      return slotID;
    }
    i += 1;
  }
  return res;
}

// Replaces InventoryDataManagerV2.GetPlayerInventoryPartsDataForItem so that:
// 1. Scopes and Muzzles are NOT filtered out by the weapon's restrictive SlotPartList,
//    allowing any scope in any Scope slot and any muzzle/silencer in any PowerModule slot.
// 2. Cyberdeck quickhack shards are NOT deduplicated by shardType in the part picker,
//    allowing multiple copies of the same quickhack to be selected and installed.
@replaceMethod(InventoryDataManagerV2)
public final func GetPlayerInventoryPartsDataForItem(item: ItemID, slotIDs: script_ref<array<TweakDBID>>) -> array<wref<gameItemData>> {
  let tempItems: array<wref<gameItemData>> = this.GetPlayerInventoryItems();
  let inventoryItems: array<wref<gameItemData>>;
  let outputItems: array<wref<gameItemData>>;
  let currentItemRecord: wref<Item_Record>;
  let parts: array<InnerItemData>;
  let innerItemData: InnerItemData;
  let currentPartStaticData: wref<Item_Record>;
  let matchAnySlot: Bool;
  let i: Int32 = 0;
  let j: Int32 = 0;

  while i < ArraySize(tempItems) {
    currentItemRecord = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(tempItems[i].GetID()));
    if IsDefined(currentItemRecord) && currentItemRecord.IsPart() {
      matchAnySlot = false;
      ArrayClear(parts);
      tempItems[i].GetItemParts(parts);
      if ArraySize(parts) > 0 {
        innerItemData = parts[0];
        currentPartStaticData = InnerItemData.GetStaticData(innerItemData);
        j = 0;
        while j < ArraySize(Deref(slotIDs)) {
          if this.PlacementSlotsContains(currentPartStaticData, Deref(slotIDs)[j]) {
            matchAnySlot = true;
            break;
          }
          j += 1;
        }
      } else {
        j = 0;
        while j < ArraySize(Deref(slotIDs)) {
          if this.PlacementSlotsContains(currentItemRecord, Deref(slotIDs)[j]) {
            matchAnySlot = true;
            break;
          }
          j += 1;
        }
      }
      if matchAnySlot {
        ArrayPush(inventoryItems, tempItems[i]);
      }
    }
    i += 1;
  }

  i = 0;
  while i < ArraySize(inventoryItems) {
    ArrayPush(outputItems, inventoryItems[i]);
    i += 1;
  }
  return outputItems;
}

@replaceMethod(InventoryDataManagerV2)
public final func GetPlayerInventoryPartsForItemRef(item: ItemID, const slotIDs: script_ref<array<TweakDBID>>, opt filteredItems: array<ItemModParams>, outputItems: script_ref<array<InventoryItemData>>) -> Void {
  let inventoryItems: array<InventoryItemData> = this.GetPlayerPartsInventoryData(slotIDs);
  let isDeckOrMonoWire: Bool = GameInstance.GetTransactionSystem(this.m_Player.GetGame()).HasTag(this.m_Player, n"Cyberdeck", item)
    || Equals(RPGManager.GetItemType(item), gamedataItemType.Cyb_NanoWires);
  let quantityToFilterOut: Int32;
  let quantity: Int32;
  let i: Int32 = ArraySize(inventoryItems) - 1;

  while i >= 0 {
    quantityToFilterOut = this.GetQunatityToFilterOut(InventoryItemData.GetID(inventoryItems[i]), filteredItems);
    quantity = InventoryItemData.GetQuantity(inventoryItems[i]) - quantityToFilterOut;
    InventoryItemData.SetQuantity(inventoryItems[i], quantity);
    if quantity <= 0 {
      ArrayErase(inventoryItems, i);
    } else {
      InventoryItemData.SetIsRequirementMet(inventoryItems[i], true);
    }
    i -= 1;
  }

  i = 0;
  while i < ArraySize(inventoryItems) {
    if isDeckOrMonoWire {
      if !ItemModificationSystem.HasThisShardInstalled(this.m_Player, item, InventoryItemData.GetID(inventoryItems[i])) {
        ArrayPush(Deref(outputItems), inventoryItems[i]);
      }
    } else {
      ArrayPush(Deref(outputItems), inventoryItems[i]);
    }
    i += 1;
  }
}

// ============================================================================
// 5. Iconic Weapon Compatibility: Never Strip Mods/Attachments from Iconic Weapons
// ============================================================================

@wrapMethod(CraftingSystem)
private final func ClearNonIconicSlots(itemData: wref<gameItemData>) -> Void {
  if IsDefined(itemData) && RPGManager.IsItemIconic(itemData) {
    return;
  }
  wrappedMethod(itemData);
}

// ============================================================================
// 6. UI Slot Labels, Icons & Two-Column Slot Layout
// ============================================================================

@wrapMethod(UIItemsHelper)
public final static func GetSlotShadowIcon(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> CName {
  return wrappedMethod(UniversalSlotsHelper.NormalizeSlotForUI(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetLootingShadowIcon(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> CName {
  return wrappedMethod(UniversalSlotsHelper.NormalizeSlotForUI(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetSlotName(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> String {
  return wrappedMethod(UniversalSlotsHelper.NormalizeSlotForUI(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetEmptySlotName(slotId: TweakDBID) -> String {
  return wrappedMethod(UniversalSlotsHelper.NormalizeSlotForUI(slotId));
}

@wrapMethod(InventoryGenericItemChooser)
protected func RebuildSlots() -> Void {
  wrappedMethod();
  // Slots Slots Slots (Core/UI.reds) handles gamedataEquipmentArea.Weapon when present
  if Equals(this.equipmentArea, gamedataEquipmentArea.Weapon) {
    return;
  }
  if inkCompoundRef.GetNumChildren(this.m_slotsContainer) <= 0 {
    return;
  }
  let grid: ref<inkUniformGrid> = inkCompoundRef.GetWidgetByIndex(this.m_slotsContainer, 0).GetParentWidget() as inkUniformGrid;
  if !IsDefined(grid) {
    return;
  }
  grid.SetOrientation(inkEOrientation.Horizontal);
  grid.SetWrappingWidgetCount(2u);
}
