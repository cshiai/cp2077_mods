// ============================================================================
// UniversalSlotsAndAttachments.reds (Cyberpunk 2077 v2.5)
// 100% Pure Redscript — Zero TweakXL / Zero tweakdb.bin edits
// ============================================================================
// 1. Cyberware Arms — Unlocking Unused Vanilla Blueprint Mod Slots + Monowire Slot:
//    - Exposes the 2 unused vanilla blueprint slots already present in
//      `tweakdb.bin` on every Cyberware Arm (`Cyb_StrongArms`, `Cyb_MantisBlades`,
//      `Cyb_NanoWires`, `Cyb_Launcher`):
//        * Gorilla Arms: `AttachmentSlots.StrongArmsBattery` +
//                        `AttachmentSlots.ArmsCyberwareGeneralSlot`
//        * Mantis Blades: `AttachmentSlots.MantisBladesRotor` +
//                         `AttachmentSlots.ArmsCyberwareGeneralSlot`
//        * Monowire:      `AttachmentSlots.NanoWiresBattery` +
//                         `AttachmentSlots.ArmsCyberwareGeneralSlot`
//        * Projectile Launcher: `AttachmentSlots.ProjectileLauncherWiring` +
//                               `AttachmentSlots.ArmsCyberwareGeneralSlot`
//    - Allows weapon mods to be installed and swapped in those Cyberware Arm slots.
//
// 2. Weapons — Universal Attachments & Mods Unlocker + Iconic Upgrade Compatibility:
//    - Unlocks all existing weapon blueprint slots (`Scope`, `PowerModule`,
//      `WeaponMod1..2`, `Tech_Handgun_WeaponMod1..4`, `GenericWeaponMod1..4`)
//      immediately at Tier 1+ (`RPGManager.IsSlotAvailable`,
//      `RPGManager.ShouldSlotBeAvailable`, `InventoryDataManagerV2.ShouldSlotBeAvailable`).
//    - Extends the vanilla placement checks so the supported scope, muzzle,
//      and weapon-mod families can use the additional source-controlled slots.
//    - Allows cross-family weapon mod slotting across all ranged/melee weapon
//      mod slots (`PlacementSlotsContains`, `IsMatchingSlot`, `GetMatchingSlot`).
//    - Protects Iconic weapons from having mods or attachments stripped by
//      `CraftingSystem.ClearNonIconicSlots`, working seamlessly with
//      `UniversalIconicWeapons.reds`.
//
// 3. Two-Column Attachment & Mod Slot UI (`InventoryWeaponItemChooser`,
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
    return SSS_Ids.IsRanged(slotID);
  }

  @if(!ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSRangedSlot(slotID: TweakDBID) -> Bool {
    return false;
  }

  @if(ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSMeleeSlot(slotID: TweakDBID) -> Bool {
    return SSS_Ids.IsMelee(slotID);
  }

  @if(!ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSMeleeSlot(slotID: TweakDBID) -> Bool {
    return false;
  }

  @if(ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSArmsSlot(slotID: TweakDBID) -> Bool {
    return SSS_Ids.IsArms(slotID);
  }

  @if(!ModuleExists("SlotsSlotsSlots.Core"))
  public final static func IsSSSArmsSlot(slotID: TweakDBID) -> Bool {
    return false;
  }

  public final static func IsRangedWeaponModSlot(slotID: TweakDBID) -> Bool {
    switch slotID {
      case t"AttachmentSlots.GenericWeaponMod1":
      case t"AttachmentSlots.GenericWeaponMod2":
      case t"AttachmentSlots.GenericWeaponMod3":
      case t"AttachmentSlots.GenericWeaponMod4":
      case t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod1":
      case t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod2":
      case t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod1_Collectible":
      case t"AttachmentSlots.Power_AR_SMG_LMG_WeaponMod2_Collectible":
      case t"AttachmentSlots.Tech_AR_SMG_LMG_WeaponMod1":
      case t"AttachmentSlots.Tech_AR_SMG_LMG_WeaponMod2":
      case t"AttachmentSlots.Smart_AR_SMG_LMG_WeaponMod1":
      case t"AttachmentSlots.Smart_AR_SMG_LMG_WeaponMod2":
      case t"AttachmentSlots.Power_Handgun_WeaponMod1":
      case t"AttachmentSlots.Power_Handgun_WeaponMod2":
      case t"AttachmentSlots.Power_Handgun_WeaponMod1_Collectible":
      case t"AttachmentSlots.Power_Handgun_WeaponMod2_Collectible":
      case t"AttachmentSlots.Tech_Handgun_WeaponMod1":
      case t"AttachmentSlots.Tech_Handgun_WeaponMod2":
      case t"AttachmentSlots.Tech_Handgun_WeaponMod3":
      case t"AttachmentSlots.Tech_Handgun_WeaponMod4":
      case t"AttachmentSlots.Smart_Handgun_WeaponMod1":
      case t"AttachmentSlots.Smart_Handgun_WeaponMod2":
      case t"AttachmentSlots.Smart_Handgun_WeaponMod1_Collectible":
      case t"AttachmentSlots.Smart_Handgun_WeaponMod2_Collectible":
      case t"AttachmentSlots.Power_Precision_Sniper_Rifle_WeaponMod1":
      case t"AttachmentSlots.Power_Precision_Sniper_Rifle_WeaponMod2":
      case t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod1":
      case t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod2":
      case t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod1_Collectible":
      case t"AttachmentSlots.Tech_Precision_Sniper_Rifle_WeaponMod2_Collectible":
      case t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod1":
      case t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod2":
      case t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod1_Collectible":
      case t"AttachmentSlots.Smart_Precision_Sniper_Rifle_WeaponMod2_Collectible":
      case t"AttachmentSlots.Power_Shotgun_WeaponMod1":
      case t"AttachmentSlots.Power_Shotgun_WeaponMod2":
      case t"AttachmentSlots.Power_Shotgun_WeaponMod1_Collectible":
      case t"AttachmentSlots.Power_Shotgun_WeaponMod2_Collectible":
      case t"AttachmentSlots.Tech_Shotgun_WeaponMod1":
      case t"AttachmentSlots.Tech_Shotgun_WeaponMod2":
      case t"AttachmentSlots.Smart_Shotgun_WeaponMod1":
      case t"AttachmentSlots.Smart_Shotgun_WeaponMod2":
        return true;
      default:
        return UniversalSlotsHelper.IsSSSRangedSlot(slotID);
    }
  }

  public final static func IsMeleeWeaponModSlot(slotID: TweakDBID) -> Bool {
    switch slotID {
      case t"AttachmentSlots.MeleeWeaponMod1":
      case t"AttachmentSlots.MeleeWeaponMod2":
      case t"AttachmentSlots.MeleeWeaponMod3":
      case t"AttachmentSlots.Blade_WeaponMod1":
      case t"AttachmentSlots.Blade_WeaponMod2":
      case t"AttachmentSlots.Blade_WeaponMod1_Collectible":
      case t"AttachmentSlots.Blade_WeaponMod2_Collectible":
      case t"AttachmentSlots.Blunt_WeaponMod1":
      case t"AttachmentSlots.Blunt_WeaponMod2":
      case t"AttachmentSlots.Blunt_WeaponMod1_Collectible":
      case t"AttachmentSlots.Blunt_WeaponMod2_Collectible":
      case t"AttachmentSlots.Throwable_WeaponMod1":
      case t"AttachmentSlots.Throwable_WeaponMod2":
      case t"AttachmentSlots.Throwable_WeaponMod1_Collectible":
      case t"AttachmentSlots.Throwable_WeaponMod2_Collectible":
        return true;
      default:
        return UniversalSlotsHelper.IsSSSMeleeSlot(slotID);
    }
  }

  public final static func IsCyberwareArmModSlot(slotID: TweakDBID) -> Bool {
    switch slotID {
      case t"AttachmentSlots.StrongArmsBattery":
      case t"AttachmentSlots.MantisBladesRotor":
      case t"AttachmentSlots.NanoWiresBattery":
      case t"AttachmentSlots.ProjectileLauncherWiring":
      case t"AttachmentSlots.ArmsCyberwareGeneralSlot":
        return true;
      default:
        return UniversalSlotsHelper.IsSSSArmsSlot(slotID);
    }
  }

  public final static func IsUniversalPartCompatibleWithSlot(partType: gamedataItemType, slotID: TweakDBID) -> Bool {
    if slotID == t"AttachmentSlots.Scope" && UniversalSlotsHelper.IsScopePartType(partType) {
      return true;
    }
    if slotID == t"AttachmentSlots.PowerModule" && UniversalSlotsHelper.IsMuzzlePartType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsRangedWeaponModSlot(slotID) && UniversalSlotsHelper.IsAnyWeaponModType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsMeleeWeaponModSlot(slotID) && UniversalSlotsHelper.IsAnyWeaponModType(partType) {
      return true;
    }
    if UniversalSlotsHelper.IsCyberwareArmModSlot(slotID) && UniversalSlotsHelper.IsAnyWeaponModType(partType) {
      return true;
    }
    return false;
  }

  public final static func IsVanillaCyberdeckProgramSlot(slotID: TweakDBID) -> Bool {
    switch slotID {
      case t"AttachmentSlots.CyberdeckProgram1":
      case t"AttachmentSlots.CyberdeckProgram2":
      case t"AttachmentSlots.CyberdeckProgram3":
      case t"AttachmentSlots.CyberdeckProgram4":
      case t"AttachmentSlots.CyberdeckProgram5":
      case t"AttachmentSlots.CyberdeckProgram6":
      case t"AttachmentSlots.CyberdeckProgram7":
      case t"AttachmentSlots.CyberdeckProgram8":
        return true;
      default:
        return false;
    }
  }

  public final static func NormalizeSlotForUI(slotID: TweakDBID) -> TweakDBID {
    if UniversalSlotsHelper.IsCyberwareArmModSlot(slotID) {
      return t"AttachmentSlots.GenericWeaponMod1";
    }
    return slotID;
  }
}

// ============================================================================
// 1. Unlock All Blueprint Slots Regardless of Quality/Tier + Monowire Slot
// ============================================================================

@replaceMethod(BackpackMainGameController)
private final func PopulateInventory() -> Void {
  if !IsDefined(this.m_uiInventorySystem) {
    return;
  }
  let filterManager = ItemCategoryFliterManager.Make();
  filterManager.AddFilterToCheck(ItemFilterCategory.Quest);

  let tagsToFilterOut: array<CName> = [n"HideInBackpackUI"];
  this.m_uiInventorySystem.FlushTempData();

  let playerItems = this.m_uiInventorySystem.GetPlayerItemsMap();
  let values: array<wref<IScriptable>>;
  playerItems.GetValues(values);
  let wrappedItems: array<ref<IScriptable>>;
  ArrayClear(this.m_junkItems);

  let i = 0;
  while i < ArraySize(values) {
    let uiInventoryItem = values[i] as UIInventoryItem;
    let includeItem = IsDefined(uiInventoryItem)
      && !ItemID.HasFlag(uiInventoryItem.GetID(), gameEItemIDFlag.Preview)
      && !uiInventoryItem.HasAnyTag(tagsToFilterOut);
    if includeItem && ArrayContains(this.m_itemDropQueueItems, uiInventoryItem.ID) {
      let quantity = uiInventoryItem.GetQuantity(true);
      let dropItem = this.GetDropQueueItem(uiInventoryItem.ID);
      if dropItem.quantity >= quantity {
        includeItem = false;
      } else {
        uiInventoryItem.SetQuantity(quantity - dropItem.quantity);
      }
    }
    if includeItem {
      if uiInventoryItem.IsJunk() {
        ArrayPush(this.m_junkItems, uiInventoryItem);
      }
      let wrappedItem = new WrappedInventoryItemData();
      wrappedItem.DisplayContextData = this.m_itemDisplayContext;
      wrappedItem.IsNew = uiInventoryItem.IsNew();
      wrappedItem.IsPlayerFavourite = uiInventoryItem.IsPlayerFavourite();
      wrappedItem.Item = uiInventoryItem;
      wrappedItem.NotificationListener = this.m_immediateNotificationListener;
      filterManager.AddItem(uiInventoryItem.GetFilterCategory());
      ArrayPush(wrappedItems, wrappedItem);
    }
    i += 1;
  }

  filterManager.SortFiltersList();
  filterManager.AddFilter(ItemFilterCategory.AllItems);
  this.RefreshFilterButtons(filterManager.GetFiltersList());
  this.m_backpackItemsDataSource.Reset(wrappedItems);
}

@wrapMethod(BackpackMainGameController)
public final func EquipItem(itemData: wref<UIInventoryItem>) -> Void {
  if IsDefined(itemData)
    && Equals(itemData.GetItemType(), gamedataItemType.Prt_Program)
    && IsDefined(this.m_player)
    && IsDefined(this.m_InventoryManager) {
    let equipData = EquipmentSystem.GetData(this.m_player);
    let deckID: ItemID = IsDefined(equipData)
      ? equipData.GetTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Cyberdeck")
      : ItemID.None();
    if !ItemID.IsValid(deckID)
      || ItemModificationSystem.HasThisShardInstalled(this.m_player, deckID, itemData.GetID()) {
      this.ShowNotification(this.m_player.GetGame(), UIMenuNotificationType.InventoryActionBlocked);
      return;
    }

    let allSlots = ItemModificationSystem.GetAllSlots(this.m_player, deckID);
    let targetSlot: TweakDBID = TDBID.None();
    let shardType = TweakDBInterface.GetCName(ItemID.GetTDBID(itemData.GetID()) + t".shardType", n"");
    let i = 0;

    while i < ArraySize(allSlots) {
      if UniversalSlotsHelper.IsVanillaCyberdeckProgramSlot(allSlots[i].slotID)
        && ItemID.IsValid(allSlots[i].installedPart)
        && NotEquals(shardType, n"")
        && Equals(TweakDBInterface.GetCName(ItemID.GetTDBID(allSlots[i].installedPart) + t".shardType", n""), shardType) {
        targetSlot = allSlots[i].slotID;
        break;
      }
      i += 1;
    }

    if !TDBID.IsValid(targetSlot) {
      i = 0;
      while i < ArraySize(allSlots) {
        if UniversalSlotsHelper.IsVanillaCyberdeckProgramSlot(allSlots[i].slotID)
          && !ItemID.IsValid(allSlots[i].installedPart) {
          targetSlot = allSlots[i].slotID;
          break;
        }
        i += 1;
      }
    }

    if !TDBID.IsValid(targetSlot) {
      i = 0;
      while i < ArraySize(allSlots) {
        if UniversalSlotsHelper.IsVanillaCyberdeckProgramSlot(allSlots[i].slotID)
          && ItemID.IsValid(allSlots[i].installedPart) {
          targetSlot = allSlots[i].slotID;
          break;
        }
        i += 1;
      }
    }

    if TDBID.IsValid(targetSlot) {
      this.m_InventoryManager.InstallPart(deckID, itemData.GetID(), targetSlot);
      this.m_InventoryManager.MarkToRebuild();
      this.RefreshUINextFrame();
      return;
    }
  }

  wrappedMethod(itemData);
}

@wrapMethod(InventoryDataManagerV2)
private final func ShouldSlotBeAvailable(itemData: wref<gameItemData>, attachmentSlotRecord: wref<AttachmentSlot_Record>, owner: wref<GameObject>, itemId: ItemID) -> Bool {
  if IsDefined(attachmentSlotRecord) {
    return true;
  }
  return wrappedMethod(itemData, attachmentSlotRecord, owner, itemId);
}

@replaceMethod(UIInventoryItemModsManager)
private final func GetAttachements(owner: wref<GameObject>, inventoryItem: wref<UIInventoryItem>) -> Void {
  // UIInventoryItemModsManager.Make() calls FetchModsDataPackages() before
  // this method.  `m_mods` therefore already contains the item's OnEquip and
  // OnAttach gameplay-package descriptions (the functionality text shown in
  // the tooltip), followed by any attachment entries added here.  Do not
  // clear m_mods: doing so silently removed every vanilla and Black Chrome
  // cyberware function description while leaving stats and lore visible.
  // The manager is built once per UIInventoryItem, so its attachment arrays
  // start empty and need no destructive reset here.
  if !IsDefined(inventoryItem) || !IsDefined(inventoryItem.GetItemData()) {
    return;
  }
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
        if IsDefined(staticData) && staticData.TagsContains(n"DummyPart") {
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
  ArrayClear(Deref(mods));
  ArrayClear(Deref(dedicatedMods));
  if !IsDefined(itemData) {
    return;
  }
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
        if IsDefined(staticData) && staticData.TagsContains(n"DummyPart") {
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

// ============================================================================
// 2. Register Cyberware Arm & Weapon Mod Slots in Redscript Slot Tables
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

// Vanilla removes weapon scopes and muzzles that are absent from the weapon's
// SlotPartList even when the selected universal Scope/PowerModule slot accepts
// them.  Restore only those erased weapon parts here; leave the vanilla
// cyberdeck shard filtering and HasThisShardInstalled deduplication untouched.
@wrapMethod(InventoryDataManagerV2)
public final func GetPlayerInventoryPartsForItemRef(item: ItemID, const slotIDs: script_ref<array<TweakDBID>>, opt filteredItems: array<ItemModParams>, outputItems: script_ref<array<InventoryItemData>>) -> Void {
  wrappedMethod(item, slotIDs, filteredItems, outputItems);

  if NotEquals(RPGManager.GetItemCategory(item), gamedataItemCategory.Weapon) {
    return;
  }

  let slotIndex = 0;
  while slotIndex < ArraySize(Deref(slotIDs)) {
    let candidates = this.GetPlayerInventoryParts(Deref(slotIDs)[slotIndex]);
    let candidateIndex = 0;
    while candidateIndex < ArraySize(candidates) {
      let candidate = candidates[candidateIndex];
      let partType = InventoryItemData.GetItemType(candidate);
      if UniversalSlotsHelper.IsScopePartType(partType) || UniversalSlotsHelper.IsMuzzlePartType(partType) {
        let alreadyPresent = false;
        let outputIndex = 0;
        while outputIndex < ArraySize(Deref(outputItems)) {
          if InventoryItemData.GetID(Deref(outputItems)[outputIndex]) == InventoryItemData.GetID(candidate) {
            alreadyPresent = true;
            break;
          }
          outputIndex += 1;
        }

        if !alreadyPresent {
          let quantity = InventoryItemData.GetQuantity(candidate)
            - this.GetQunatityToFilterOut(InventoryItemData.GetID(candidate), filteredItems);
          if quantity > 0 {
            InventoryItemData.SetQuantity(candidate, quantity);
            InventoryItemData.SetIsRequirementMet(candidate, true);
            ArrayPush(Deref(outputItems), candidate);
          }
        }
      }
      candidateIndex += 1;
    }
    slotIndex += 1;
  }

  // The vanilla query also removes weapon mods that are absent from the
  // weapon's SlotPartList.  SSS and the universal placement rules deliberately
  // make every weapon-mod family interchangeable, so recover those parts from
  // the complete player inventory as well (including duplicate stack IDs).
  let allInventoryItems = this.GetPlayerInventoryData();
  let inventoryIndex = 0;
  while inventoryIndex < ArraySize(allInventoryItems) {
    let candidate = allInventoryItems[inventoryIndex];
    let partType = InventoryItemData.GetItemType(candidate);
    let matchesRequestedSlot = false;
    let requestedSlotIndex = 0;
    while requestedSlotIndex < ArraySize(Deref(slotIDs)) {
      if UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, Deref(slotIDs)[requestedSlotIndex]) {
        matchesRequestedSlot = true;
        break;
      }
      requestedSlotIndex += 1;
    }
    if !InventoryItemData.IsEmpty(candidate)
      && InventoryItemData.IsPart(candidate)
      && matchesRequestedSlot
      && (UniversalSlotsHelper.IsAnyWeaponModType(partType)
        || UniversalSlotsHelper.IsScopePartType(partType)
        || UniversalSlotsHelper.IsMuzzlePartType(partType)) {
      let alreadyPresent = false;
      let outputIndex = 0;
      while outputIndex < ArraySize(Deref(outputItems)) {
        if InventoryItemData.GetID(Deref(outputItems)[outputIndex]) == InventoryItemData.GetID(candidate) {
          alreadyPresent = true;
          break;
        }
        outputIndex += 1;
      }

      if !alreadyPresent {
        let quantity = InventoryItemData.GetQuantity(candidate)
          - this.GetQunatityToFilterOut(InventoryItemData.GetID(candidate), filteredItems);
        if quantity > 0 {
          InventoryItemData.SetQuantity(candidate, quantity);
          InventoryItemData.SetIsRequirementMet(candidate, true);
          ArrayPush(Deref(outputItems), candidate);
        }
      }
    }
    inventoryIndex += 1;
  }
}

// ============================================================================
// 3. Universal Part & Mod Placement Compatibility (Scopes, Muzzles, Mods, Arms)
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

@replaceMethod(InventoryItemModeLogicController)
private final func IsMatchingSlot(const itemData: script_ref<InventoryItemData>, const partItemData: script_ref<InventoryItemData>, targetSlot: TweakDBID) -> Bool {
  if !TDBID.IsValid(targetSlot) {
    return false;
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
  if UniversalSlotsHelper.IsUniversalPartCompatibleWithSlot(partType, targetSlot) {
    return true;
  }
  if InventoryItemData.PlacementSlotsContains(partItemData, targetSlot) {
    return true;
  }
  if RPGManager.IsClothingMod(partType) {
    let validSlots: array<TweakDBID> = RPGManager.GetModsSlotIDs(InventoryItemData.GetItemType(itemData));
    return ArrayContains(validSlots, targetSlot);
  }
  return false;
}

@replaceMethod(InventoryItemModeLogicController)
private final func GetMatchingSlot(const itemData: script_ref<InventoryItemData>, const partItemData: script_ref<InventoryItemData>) -> TweakDBID {
  let attachments: array<ref<InventoryItemAttachments>> = InventoryItemData.GetAttachments(itemData);
  let selectedSlot: TweakDBID = IsDefined(this.m_selectedItemChooser) ? this.m_selectedItemChooser.GetSelectedSlotID() : TDBID.None();
  let i: Int32 = 0;

  // 1. If the currently selected slot is compatible and empty, use it immediately
  if TDBID.IsValid(selectedSlot) && this.IsMatchingSlot(itemData, partItemData, selectedSlot) {
    i = 0;
    while i < ArraySize(attachments) {
      if attachments[i].SlotID == selectedSlot && InventoryItemData.IsEmpty(attachments[i].ItemData) {
        return selectedSlot;
      }
      i += 1;
    }
  }

  // 2. Otherwise choose the first empty compatible slot in attachment order
  let firstCompatible: TweakDBID = TDBID.None();
  i = 0;
  while i < ArraySize(attachments) {
    let slotID: TweakDBID = attachments[i].SlotID;
    if this.IsMatchingSlot(itemData, partItemData, slotID) {
      if !TDBID.IsValid(firstCompatible) {
        firstCompatible = slotID;
      }
      if InventoryItemData.IsEmpty(attachments[i].ItemData) {
        return slotID;
      }
    }
    i += 1;
  }

  // 3. If all compatible slots are occupied, prefer the selected slot if compatible
  if TDBID.IsValid(selectedSlot) && this.IsMatchingSlot(itemData, partItemData, selectedSlot) {
    return selectedSlot;
  }

  // 4. Fallback to the first compatible slot (if any)
  return firstCompatible;
}

@replaceMethod(InventoryItemModeLogicController)
private final func EquipPart(const itemData: script_ref<InventoryItemData>, slotID: TweakDBID) -> Void {
  if !IsDefined(this.m_selectedItemChooser) {
    return;
  }
  let equippedItemData: InventoryItemData = this.m_selectedItemChooser.GetModifiedItemData();
  if this.m_InventoryManager.CanInstallPart(itemData) && TDBID.IsValid(slotID) {
    this.m_InventoryManager.InstallPart(InventoryItemData.GetID(equippedItemData), InventoryItemData.GetID(itemData), slotID);
    this.TelemetryLogPartInstalled(equippedItemData, itemData, slotID);
    this.SetPingTutorialFact(InventoryItemData.GetID(itemData), false);
  }
}

@replaceMethod(InventoryItemModeLogicController)
private final func HandleItemClick(const itemData: script_ref<InventoryItemData>, actionName: ref<inkActionName>, opt displayContext: ItemDisplayContext, opt isPlayerLocked: Bool) -> Void {
  let isClothing: Bool;
  let isEquippedItemBlocked: Bool;
  let item: ItemModParams;
  let localEquippedData: wref<gameItemData>;
  let shouldUpdate: Bool;
  if actionName.IsAction(n"drop_item") {
    if Equals(this.m_playerState, gamePSMVehicle.Default) && !InventoryItemData.IsEquipped(itemData) && RPGManager.CanItemBeDropped(this.m_player, InventoryItemData.GetGameItemData(itemData)) {
      if isPlayerLocked {
        this.ShowNotification(this.m_player.GetGame(), UIMenuNotificationType.InventoryActionBlocked);
        return;
      }
      if InventoryItemData.GetQuantity(itemData) > 1 {
        this.OpenQuantityPicker(itemData, QuantityPickerActionType.Drop);
      } else {
        item.itemID = InventoryItemData.GetID(itemData);
        item.quantity = 1;
        this.AddToDropQueue(item);
        this.RefreshAvailableItems(true);
        this.PlaySound(n"Item", n"OnDrop");
        this.PlayRumble(RumbleStrength.SuperLight, RumbleType.Pulse, RumblePosition.Right);
        if IsDefined(this.m_leftItemChooser) {
          this.m_leftItemChooser.RefreshItems(shouldUpdate, -1);
        }
        this.itemChooser.RefreshItems(shouldUpdate, -1);
      }
    }
  } else {
    if actionName.IsAction(n"preview_item") && (InventoryItemData.IsWeapon(Deref(itemData)) || InventoryItemData.IsGarment(Deref(itemData))) && !InventoryItemData.IsEmpty(itemData) && Equals(displayContext, ItemDisplayContext.Backpack) && this.m_pressedItemDisplay != null {
      this.PlaySound(n"MapPin", n"OnCreate");
      this.m_pressedItemDisplay = null;
      isClothing = this.IsEquipmentAreaClothing(InventoryItemData.GetEquipmentArea(itemData)) || Equals(InventoryItemData.GetEquipmentArea(itemData), gamedataEquipmentArea.Outfit);
      this.m_itemPreviewPopupToken = ItemPreviewHelper.ShowPreviewItem(this, itemData, isClothing, n"OnItemPreviewPopup");
    } else {
      if actionName.IsAction(n"click") && NotEquals(displayContext, ItemDisplayContext.Attachment) {
        if InventoryItemData.IsEquipped(itemData) || InventoryItemData.IsEmpty(itemData) {
            if IsDefined(this.itemChooser) && Equals(Deref(itemData), this.itemChooser.GetModifiedItemData()) {
            this.SelectItemChooserWithoutCallback(this.itemChooser);
          } else {
            if IsDefined(this.m_leftItemChooser) && Equals(Deref(itemData), this.m_leftItemChooser.GetModifiedItemData()) {
              this.SelectItemChooserWithoutCallback(this.m_leftItemChooser);
            }
          }
        } else {
          if !(InventoryItemData.IsEquipped(itemData) && Equals(this.m_currentHotkey, EHotkey.INVALID)) {
            if !IsDefined(this.m_selectedItemChooser) {
              return;
            }
            localEquippedData = InventoryItemData.GetGameItemData(this.m_selectedItemChooser.GetModifiedItemData());
            shouldUpdate = true;
            isEquippedItemBlocked = IsDefined(localEquippedData) && localEquippedData.HasTag(n"UnequipBlocked");
            if isEquippedItemBlocked || !InventoryGPRestrictionHelper.CanEquip(itemData, this.m_player) {
              this.ShowNotification(this.m_player.GetGame(), this.DetermineUIMenuNotificationType());
              return;
            }
            if Equals(InventoryItemData.GetItemType(itemData), gamedataItemType.Clo_Outfit) {
              if this.m_outfitInCooldown {
                return;
              }
              if this.ScheduleOutfitCooldownReset() {
                this.SetOutfitCooldown(true);
              }
            }
            this.EquipItem(itemData, this.m_selectedItemChooser.GetSlotIndex());
            this.PlayRumble(RumbleStrength.Heavy, RumbleType.Pulse, RumblePosition.Right);
            this.m_inventoryController.HandleCyberwareStyleUpdate(InventoryItemData.GetEquipmentArea(itemData), Deref(itemData).SlotID, true);
            if ArrayContains(this.m_lastEquipmentAreas, gamedataEquipmentArea.Outfit) {
              if NotEquals(this.m_wardrobeSystem.GetActiveClothingSetIndex(), gameWardrobeClothingSetIndex.INVALID) && InventoryItemData.IsEmpty(itemData) {
                shouldUpdate = false;
              }
            }
            if IsDefined(this.m_leftItemChooser) {
              this.m_leftItemChooser.RefreshItems(shouldUpdate, -1);
            }
            if IsDefined(this.itemChooser) {
              this.itemChooser.RefreshItems(shouldUpdate, -1);
            }
            if !InventoryItemData.IsPart(itemData) {
              this.m_viewMode = ItemViewModes.Item;
              this.m_currentFilter = ItemFilterCategory.Invalid;
              this.RefreshAvailableItems();
            }
            this.NotifyItemUpdate();
          }
        }
      }
    }
  }
}

@replaceMethod(ItemModificationSystem)
private final func InstallItemPart(obj: ref<GameObject>, itemID: ItemID, partItemID: ItemID, opt slotID: TweakDBID) -> Bool {
  let partData: InnerItemData;
  let partInstallRequest: ref<PartInstallRequest>;
  let previousItemType: gamedataItemType;
  let previousPartID: ItemID;
  let previousPartStillInstalled: Bool;
  let result: Bool;
  if !IsDefined(obj) || !ItemID.IsValid(itemID) || !ItemID.IsValid(partItemID) {
    return false;
  }
  let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(obj.GetGame());
  let partRecord: wref<Item_Record> = RPGManager.GetItemRecord(partItemID);
  if !IsDefined(ts) || !IsDefined(partRecord) || !IsDefined(partRecord.ItemType()) {
    return false;
  }
  let itemType: gamedataItemType = partRecord.ItemType().Type();
  let itemData: ref<gameItemData> = ts.GetItemData(obj, itemID);
  if !IsDefined(itemData) {
    return false;
  }
  if !IsDefined(TweakDBInterface.GetAttachmentSlotRecord(slotID)) {
    slotID = EquipmentSystem.GetPlacementSlot(partItemID);
  }
  if !TDBID.IsValid(slotID) {
    return false;
  }
  itemData.GetItemPart(partData, slotID);
  previousPartID = InnerItemData.GetItemID(partData);
  if ItemID.IsValid(previousPartID) {
    // GLPs are keyed by ItemID, not by attachment slot.  Do not remove the
    // package globally when another slot still contains the same deterministic
    // mod; otherwise duplicate mods stop stacking after a replacement.
    let allSlots = ItemModificationSystem.GetAllSlots(obj, itemID);
    let slotIndex = 0;
    while slotIndex < ArraySize(allSlots) {
      if allSlots[slotIndex].slotID != slotID
        && allSlots[slotIndex].installedPart == previousPartID {
        previousPartStillInstalled = true;
        break;
      }
      slotIndex += 1;
    }
    if !previousPartStillInstalled {
      this.RemovePartEquipGLPs(obj, previousPartID);
    }
  }
  result = ts.ForcePartInSlot(obj, itemID, partItemID, slotID);
  if Equals(itemType, gamedataItemType.Prt_Program) {
    this.RemoveOtherShards(obj, itemID, partItemID);
  }
  previousItemType = RPGManager.GetItemType(previousPartID);
  if result && ItemID.IsValid(previousPartID) && (RPGManager.IsWeaponMod(previousPartID) || Equals(previousItemType, gamedataItemType.CyberwareStatsShard) || RPGManager.IsClothingMod(previousPartID)) {
    ts.RemoveItem(obj, previousPartID, 1);
  }
  if result {
    partInstallRequest = new PartInstallRequest();
    partInstallRequest.owner = obj;
    partInstallRequest.itemID = itemID;
    partInstallRequest.partID = partItemID;
    let systems = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance());
    if IsDefined(systems) {
      let equipmentSystem = systems.Get(n"EquipmentSystem");
      let uiSystem = systems.Get(n"UIInventoryScriptableSystem");
      if IsDefined(equipmentSystem) { equipmentSystem.QueueRequest(partInstallRequest); }
      if IsDefined(uiSystem) { uiSystem.QueueRequest(partInstallRequest); }
    }
  }
  PlayerPuppet.ChacheQuickHackListCleanup(obj as PlayerPuppet);
  return result;
}

@wrapMethod(InventoryDataManagerV2)
private final func GetInventoryItemDataInternal(owner: wref<GameObject>, itemData: wref<gameItemData>, opt itemRecord: wref<Item_Record>) -> InventoryItemData {
  let result: InventoryItemData = wrappedMethod(owner, itemData, itemRecord);
  let rec: wref<Item_Record> = itemRecord;
  if !IsDefined(rec) && IsDefined(itemData) {
    rec = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemData.GetID()));
  }
  if IsDefined(rec) && rec.IsPart() {
    InventoryItemData.SetIsPart(result, true);
    InventoryItemData.SetIsRequirementMet(result, true);
    InventoryItemData.SetIsEquippable(result, true);
    if ArraySize(result.PlacementSlots) == 0 {
      let placementSlots: array<wref<AttachmentSlot_Record>>;
      rec.PlacementSlots(placementSlots);
      let i: Int32 = 0;
      while i < ArraySize(placementSlots) {
        InventoryItemData.AddPlacementSlot(result, placementSlots[i].GetID());
        i += 1;
      }
    }
  }
  return result;
}

// ============================================================================
// 4. Iconic Weapon Compatibility: Never Strip Mods/Attachments from Iconic Weapons
// ============================================================================

@wrapMethod(CraftingSystem)
private final func ClearNonIconicSlots(itemData: wref<gameItemData>) -> Void {
  return;
}

// ============================================================================
// 5. UI Slot Labels, Icons & Two-Column Slot Layout
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
  let firstSlot = inkCompoundRef.GetWidgetByIndex(this.m_slotsContainer, 0);
  if !IsDefined(firstSlot) {
    return;
  }
  let grid: ref<inkUniformGrid> = firstSlot.GetParentWidget() as inkUniformGrid;
  if !IsDefined(grid) {
    return;
  }
  grid.SetOrientation(inkEOrientation.Horizontal);
  grid.SetWrappingWidgetCount(2u);
}
