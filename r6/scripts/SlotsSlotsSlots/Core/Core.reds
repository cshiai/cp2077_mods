module SlotsSlotsSlots.Core

public class SSS {

  public static func Families() -> array<String> {
    return ["Power_AR_SMG_LMG", "Tech_AR_SMG_LMG", "Smart_AR_SMG_LMG", "Power_Handgun", "Tech_Handgun", "Smart_Handgun", "Power_Shotgun", "Tech_Shotgun", "Smart_Shotgun", "Power_Precision_Sniper_Rifle", "Tech_Precision_Sniper_Rifle", "Smart_Precision_Sniper_Rifle", "Blade", "Blunt", "Throwable"];
  }

  // string ArrayContains broken ingame, keep
  public static func HasString(arr: array<String>, s: String) -> Bool {
    for x in arr {
      if Equals(x, s) {
        return true;
      }
    }
    return false;
  }

  public static func IsFamily(fam: String) -> Bool {
    if Equals(fam, "Blade") || Equals(fam, "Blunt") || Equals(fam, "Throwable") {
      return true;
    }
    if !StrEndsWith(fam, "_AR_SMG_LMG") && !StrEndsWith(fam, "_Handgun") && !StrEndsWith(fam, "_Shotgun") && !StrEndsWith(fam, "_Precision_Sniper_Rifle") {
      return false;
    }
    return StrBeginsWith(fam, "Power_") || StrBeginsWith(fam, "Tech_") || StrBeginsWith(fam, "Smart_");
  }

  public static func IsMelee(fam: String) -> Bool {
    return Equals(fam, "Blade") || Equals(fam, "Blunt") || Equals(fam, "Throwable");
  }

  // yaml has 3..8
  public static func MaxSlots() -> Int32 {
    return 8;
  }

  public static func Normal() -> Int32 {
    return 0;
  }

  public static func Collectible() -> Int32 {
    return 1;
  }

  public static func Iconic() -> Int32 {
    return 2;
  }

  public static func Arms() -> Int32 {
    return 3;
  }

  public static func ArmsFamilies() -> array<String> {
    return ["Blunt", "Blade", "Tech_Shotgun"];
  }

  public static func Suffix(cat: Int32) -> String {
    if cat == SSS.Iconic() {
      return "_Iconic";
    }
    if cat == SSS.Arms() {
      return "_Arms";
    }
    return "";
  }

  public static func SlotId(fam: String, n: Int32) -> TweakDBID {
    return TDBID.Create("AttachmentSlots." + fam + "_WeaponMod" + IntToString(n));
  }

  public static func SlotIdCat(fam: String, n: Int32, cat: Int32) -> TweakDBID {
    return TDBID.Create("AttachmentSlots." + fam + "_WeaponMod" + IntToString(n) + SSS.Suffix(cat));
  }

  public static func ElementId(fam: String, n: Int32, cat: Int32) -> TweakDBID {
    return TDBID.Create("Items." + fam + "_WeaponMod" + IntToString(n) + SSS.Suffix(cat) + "Element");
  }

  public static func SlotEntityName(slot: TweakDBID) -> String {
    let rec: ref<AttachmentSlot_Record> = TweakDBInterface.GetAttachmentSlotRecord(slot);
    if !IsDefined(rec) {
      return "";
    }
    return rec.EntitySlotName();
  }

  public static func ElementSlot(elem: TweakDBID) -> TweakDBID {
    let rec: ref<ItemBlueprintElement_Record> = TweakDBInterface.GetItemBlueprintElementRecord(elem);
    if !IsDefined(rec) {
      return TDBID.None();
    }
    let slot: wref<AttachmentSlot_Record> = rec.Slot();
    if !IsDefined(slot) {
      return TDBID.None();
    }
    return slot.GetID();
  }

  public static func Children(root: TweakDBID) -> array<TweakDBID> {
    return FromVariant<array<TweakDBID>>(TweakDBInterface.GetFlat(root + t".childElements"));
  }

  public static func PlacementSlots(item: TweakDBID) -> array<TweakDBID> {
    return FromVariant<array<TweakDBID>>(TweakDBInterface.GetFlat(item + t".placementSlots"));
  }

  public static func ParseSlot(slot: TweakDBID, out fam: String, out n: Int32, out collectible: Bool) -> Bool {
    let cat: Int32;
    let ok: Bool = SSS.ParseSlotCat(slot, fam, n, cat);
    collectible = cat == SSS.Collectible();
    return ok;
  }

  public static func ParseSlotCat(slot: TweakDBID, out fam: String, out n: Int32, out cat: Int32) -> Bool {
    let left: String;
    let right: String;
    let name: String = SSS.SlotEntityName(slot);

    cat = SSS.Normal();
    if StrEndsWith(name, "_Collectible") {
      cat = SSS.Collectible();
      name = StrLeft(name, StrLen(name) - 12);
    } else {
      if StrEndsWith(name, "_Iconic") {
        cat = SSS.Iconic();
        name = StrLeft(name, StrLen(name) - 7);
      } else {
        if StrEndsWith(name, "_Arms") {
          cat = SSS.Arms();
          name = StrLeft(name, StrLen(name) - 5);
        }
      }
    }
    if !StrSplitLast(name, "_WeaponMod", left, right) {
      return false;
    }

    n = StringToInt(right, 0);
    if n <= 0 {
      return false;
    }
    fam = left;
    return SSS.IsFamily(fam);
  }

  public static func SameList(a: array<TweakDBID>, b: array<TweakDBID>) -> Bool {
    if ArraySize(a) != ArraySize(b) {
      return false;
    }
    let i: Int32 = 0;
    while i < ArraySize(a) {
      if a[i] != b[i] {
        return false;
      }
      i += 1;
    }
    return true;
  }

  public static func SetFamilySlots(root: TweakDBID, fam: String, count: Int32, cat: Int32) -> Bool {
    let f: String;
    let n: Int32;
    let col: Bool;
    let flat: TweakDBID = root + t".childElements";
    let children: array<TweakDBID> = SSS.Children(root);
    let kept: array<TweakDBID>;
    let block: array<TweakDBID>;
    let result: array<TweakDBID>;
    let at: Int32 = -1;

    for child in children {
      if SSS.ParseSlot(SSS.ElementSlot(child), f, n, col) && !col && Equals(f, fam) {
        if at < 0 {
          at = ArraySize(kept);
        }
      } else {
        ArrayPush(kept, child);
      }
    }
    if at < 0 {
      at = ArraySize(kept);
    }

    n = 1;
    while n <= count && n <= SSS.MaxSlots() {
      let e: TweakDBID = SSS.ElementId(fam, n, cat);
      if IsDefined(TweakDBInterface.GetItemBlueprintElementRecord(e)) {
        ArrayPush(block, e);
      }
      n += 1;
    }

    let i: Int32 = 0;
    while i < at {
      ArrayPush(result, kept[i]);
      i += 1;
    }
    for e in block {
      ArrayPush(result, e);
    }
    while i < ArraySize(kept) {
      ArrayPush(result, kept[i]);
      i += 1;
    }

    if SSS.SameList(result, children) {
      return false;
    }
    TweakDBManager.SetFlat(flat, ToVariant(result));
    TweakDBManager.UpdateRecord(root);
    return true;
  }

  public static func IsArmsBlueprint(bp: TweakDBID) -> Bool {
    return bp == t"Items.StrongArmsBlueprint" || bp == t"Items.MantisBladesBlueprint" || bp == t"Items.NanoWiresBlueprint" || bp == t"Items.ProjectileLauncherBlueprint";
  }

  public static func ApplyWeaponBlueprints(normal: Int32, iconic: Int32, xmod2: Int32) -> Void {
    let fam: String;
    let n: Int32;
    let col: Bool;

    for rec in TweakDBInterface.GetRecords(n"gamedataItemBlueprint_Record") {
      let bp: ref<ItemBlueprint_Record> = rec as ItemBlueprint_Record;
      if IsDefined(bp) && !SSS.IsArmsBlueprint(bp.GetID()) {
        let root: wref<ItemBlueprintElement_Record> = bp.RootElement();
        if IsDefined(root) {
          let family: String = "";
          let collectibles: Int32 = 0;
          let dedicated: Bool = false;

          for child in SSS.Children(root.GetID()) {
            let slot: TweakDBID = SSS.ElementSlot(child);
            if slot == t"AttachmentSlots.IconicWeaponModLegendary" || slot == t"AttachmentSlots.IconicMeleeWeaponMod1" {
              dedicated = true;
            } else {
              if SSS.ParseSlot(slot, fam, n, col) {
                if Equals(family, "") {
                  family = fam;
                }
                if col && Equals(fam, family) {
                  collectibles += 1;
                }
              }
            }
          }

          if NotEquals(family, "") {
            let target: Int32 = normal;
            let cat: Int32 = SSS.Normal();
            if collectibles > 0 {
              target = xmod2 - collectibles;
              cat = SSS.Iconic();
            } else {
              if dedicated {
                target = iconic;
                cat = SSS.Iconic();
              }
            }
            SSS.SetFamilySlots(root.GetID(), family, target, cat);
          }
        }
      }
    }
  }

  public static func HasMoreModsMoreFun() -> Bool {
    let slots: array<TweakDBID> = SSS.PlacementSlots(t"Items.PowerMod1_Base");
    return ArrayContains(slots, t"AttachmentSlots.Tech_Handgun_WeaponMod1");
  }

  public static func ApplyPlacement() -> Void {
    let fam: String;
    let n: Int32;
    let col: Bool;
    let crossFamily: Bool = SSS.HasMoreModsMoreFun();

    for rec in TweakDBInterface.GetRecords(n"gamedataItem_Record") {
      let item: ref<Item_Record> = rec as Item_Record;
      if IsDefined(item) && item.GetPlacementSlotsCount() > 0 {
        let id: TweakDBID = item.GetID();
        let slots: array<TweakDBID> = SSS.PlacementSlots(id);
        let fams: array<String>;
        let ranged: Bool = false;
        let melee: Bool = false;

        for slot in slots {
          if SSS.ParseSlot(slot, fam, n, col) {
            if !SSS.HasString(fams, fam) {
              ArrayPush(fams, fam);
            }
            if SSS.IsMelee(fam) {
              melee = true;
            } else {
              ranged = true;
            }
          }
        }

        if ArraySize(fams) > 0 {
          if crossFamily {
            for f in SSS.Families() {
              if !SSS.HasString(fams, f) && ((SSS.IsMelee(f) && melee) || (!SSS.IsMelee(f) && ranged)) {
                ArrayPush(fams, f);
              }
            }
          }

          let result: array<TweakDBID> = slots;
          for f in fams {
            for c in [SSS.Normal(), SSS.Iconic(), SSS.Arms()] {
              n = 1;
              while n <= SSS.MaxSlots() {
                let s: TweakDBID = SSS.SlotIdCat(f, n, c);
                if !ArrayContains(result, s) && IsDefined(TweakDBInterface.GetAttachmentSlotRecord(s)) {
                  ArrayPush(result, s);
                }
                n += 1;
              }
            }
          }

          if ArraySize(result) != ArraySize(slots) {
            TweakDBManager.SetFlat(id + t".placementSlots", ToVariant(result));
            TweakDBManager.UpdateRecord(id);
          }
        }
      }
    }
  }
}

enum SSS_UnlockMode {
  ByRarity = 0,
  VanillaPairs = 1,
  AllCommon = 2
}

public class SSS_UnlockSettings {

  @runtimeProperty("ModSettings.mod", "Slots Slots Slots")
  @runtimeProperty("ModSettings.category", "Slot unlock")
  @runtimeProperty("ModSettings.displayName", "Slot unlock")
  @runtimeProperty("ModSettings.description", "By rarity: more slots open at each rarity, all at Legendary. Vanilla pairs: odd slots at Uncommon, even at Rare. All from Common: every slot open on any rarity.")
  @runtimeProperty("ModSettings.displayValues.ByRarity", "By rarity")
  @runtimeProperty("ModSettings.displayValues.VanillaPairs", "Vanilla pairs")
  @runtimeProperty("ModSettings.displayValues.AllCommon", "All from Common")
  public let mode: SSS_UnlockMode = SSS_UnlockMode.ByRarity;
}

public class SSS_Unlock {

  public static func Quality(tier: Int32) -> String {
    switch tier {
      case 0:
        return "Common";
      case 1:
        return "Uncommon";
      case 2:
        return "Rare";
      case 3:
        return "Epic";
      default:
        return "Legendary";
    }
  }

  // 5+ max common opens, else /4
  public static func OpenAt(tier: Int32, max: Int32) -> Int32 {
    if max >= 5 {
      return FloorF(Cast<Float>((tier + 1) * max) / 5.0 + 0.5);
    }
    return FloorF(Cast<Float>(tier * max) / 4.0 + 0.5);
  }

  public static func Tier(n: Int32, max: Int32, mode: SSS_UnlockMode) -> Int32 {
    if Equals(mode, SSS_UnlockMode.AllCommon) {
      return 0;
    }
    if Equals(mode, SSS_UnlockMode.VanillaPairs) {
      if n % 2 == 1 {
        return 1;
      }
      return 2;
    }
    let t: Int32 = 0;
    while t < 4 {
      if SSS_Unlock.OpenAt(t, max) >= n {
        return t;
      }
      t += 1;
    }
    return 4;
  }

  // keep vanilla flat type
  public static func Set(slot: TweakDBID, quality: String, asName: Bool) -> Void {
    let flat: TweakDBID = slot + t".unlockedBy";
    if asName {
      if !TweakDBManager.SetFlat(flat, ToVariant(StringToName(quality))) {
        TweakDBManager.SetFlat(flat, ToVariant(quality));
      }
    } else {
      if !TweakDBManager.SetFlat(flat, ToVariant(quality)) {
        TweakDBManager.SetFlat(flat, ToVariant(StringToName(quality)));
      }
    }
  }

  public static func Apply(cat: Int32, max: Int32) -> Void {
    let mode: SSS_UnlockMode = (new SSS_UnlockSettings()).mode;
    let unlockedByFlat: Variant = TweakDBInterface.GetFlat(t"AttachmentSlots.Power_Handgun_WeaponMod1.unlockedBy");
    let asName: Bool = Equals(VariantTypeName(unlockedByFlat), n"CName");
    let fams: array<String> = SSS.Families();
    if cat == SSS.Arms() {
      fams = SSS.ArmsFamilies();
    }
    for fam in fams {
      let n: Int32 = 1;
      while n <= SSS.MaxSlots() {
        let slot: TweakDBID = SSS.SlotIdCat(fam, n, cat);
        if IsDefined(TweakDBInterface.GetAttachmentSlotRecord(slot)) {
          SSS_Unlock.Set(slot, SSS_Unlock.Quality(SSS_Unlock.Tier(n, max, mode)), asName);
        }
        n += 1;
      }
    }
  }
}

public class SSS_Listen {

  @if(ModuleExists("ModSettingsModule"))
  public static func Register(obj: ref<IScriptable>) -> Void {
    ModSettings.RegisterListenerToModifications(obj);
  }

  @if(!ModuleExists("ModSettingsModule"))
  public static func Register(obj: ref<IScriptable>) -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  public static func Unregister(obj: ref<IScriptable>) -> Void {
    ModSettings.UnregisterListenerToModifications(obj);
  }

  @if(!ModuleExists("ModSettingsModule"))
  public static func Unregister(obj: ref<IScriptable>) -> Void {}
}

public class SSS_CoreTweak extends ScriptableTweak {

  protected cb func OnApply() -> Void {
    SSS.ApplyPlacement();
  }
}
