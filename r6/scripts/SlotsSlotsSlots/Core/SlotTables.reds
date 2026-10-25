module SlotsSlotsSlots.Core

public class SSS_Types {

  public static func IsRanged(type: gamedataItemType) -> Bool {
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

  public static func IsMelee(type: gamedataItemType) -> Bool {
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

  public static func Families(type: gamedataItemType) -> array<String> {
    let none: array<String>;
    switch type {
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_Rifle:
      case gamedataItemType.Wea_SubmachineGun:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
        return ["Power_AR_SMG_LMG", "Tech_AR_SMG_LMG", "Smart_AR_SMG_LMG"];
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
        return ["Power_Handgun", "Tech_Handgun", "Smart_Handgun"];
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_PrecisionRifle:
        return ["Power_Precision_Sniper_Rifle", "Tech_Precision_Sniper_Rifle", "Smart_Precision_Sniper_Rifle"];
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
        return ["Power_Shotgun", "Tech_Shotgun", "Smart_Shotgun"];
      case gamedataItemType.Wea_ShortBlade:
      case gamedataItemType.Wea_Machete:
      case gamedataItemType.Wea_LongBlade:
      case gamedataItemType.Wea_Sword:
      case gamedataItemType.Wea_Katana:
      case gamedataItemType.Wea_Chainsword:
        return ["Blade"];
      case gamedataItemType.Wea_Knife:
      case gamedataItemType.Wea_Axe:
        return ["Throwable"];
      case gamedataItemType.Wea_TwoHandedClub:
      case gamedataItemType.Wea_OneHandedClub:
      case gamedataItemType.Wea_Hammer:
        return ["Blunt"];
      default:
        return none;
    }
  }
}

@wrapMethod(RPGManager)
public final static func GetModsSlotIDs(type: gamedataItemType) -> [TweakDBID] {
  let arr: array<TweakDBID> = wrappedMethod(type);
  for fam in SSS_Types.Families(type) {
    arr = SSS_Ids.Concat(arr, SSS_Ids.Family(fam));
  }
  return arr;
}

@wrapMethod(UIInventoryItemModsStaticData)
public final static func GetAttachmentSlots(itemType: gamedataItemType) -> [TweakDBID] {
  let slots: array<TweakDBID> = wrappedMethod(itemType);
  if SSS_Types.IsRanged(itemType) {
    return SSS_Ids.Concat(slots, SSS_Ids.Ranged());
  }
  if SSS_Types.IsMelee(itemType) {
    return SSS_Ids.Concat(slots, SSS_Ids.Melee());
  }
  return slots;
}

@wrapMethod(InventoryDataManagerV2)
public final static func GetAttachmentSlotsForInventory() -> [TweakDBID] {
  let slots: array<TweakDBID> = wrappedMethod();
  slots = SSS_Ids.Concat(slots, SSS_Ids.Ranged());
  slots = SSS_Ids.Concat(slots, SSS_Ids.Melee());
  return SSS_Ids.Concat(slots, SSS_Ids.Arms());
}
