module SlotsSlotsSlots.Weapons
import SlotsSlotsSlots.Core.*

public class SSS_WeaponSettings {

  @runtimeProperty("ModSettings.mod", "Slots Slots Slots")
  @runtimeProperty("ModSettings.category", "Weapons")
  @runtimeProperty("ModSettings.displayName", "Mod slots on normal weapons")
  @runtimeProperty("ModSettings.description", "Mod slots on every non iconic weapon. Vanilla is 2.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "2")
  @runtimeProperty("ModSettings.max", "8")
  public let normal: Int32 = 4;

  @runtimeProperty("ModSettings.mod", "Slots Slots Slots")
  @runtimeProperty("ModSettings.category", "Weapons")
  @runtimeProperty("ModSettings.displayName", "Mod slots on iconic weapons")
  @runtimeProperty("ModSettings.description", "Mod slots on every iconic weapon, the iconic slot not counted. x-MOD2 iconics get 2 more.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "8")
  public let iconic: Int32 = 4;
}

public class SSS_Weapons {

  public static func Apply() -> Void {
    let s: ref<SSS_WeaponSettings> = new SSS_WeaponSettings();
    SSS_Iconics.Apply(s.iconic);
    SSS.ApplyWeaponBlueprints(s.normal, s.iconic, s.iconic + 2);
    SSS_Unlock.Apply(SSS.Normal(), s.normal);
    SSS_Unlock.Apply(SSS.Iconic(), s.iconic);
    SSS.ApplyPlacement();
  }
}

public class SSS_Iconics {

  public static func FamilyOf(item: ref<WeaponItem_Record>) -> String {
    let type: wref<ItemType_Record> = item.ItemType();
    if !IsDefined(type) {
      return "";
    }
    let fams: array<String> = SSS_Types.Families(type.Type());
    if ArraySize(fams) == 1 {
      return fams[0];
    }
    if ArraySize(fams) == 0 || !IsDefined(item.Evolution()) {
      return "";
    }

    let prefix: String;
    switch item.Evolution().Type() {
      case gamedataWeaponEvolution.Power:
        prefix = "Power_";
        break;
      case gamedataWeaponEvolution.Tech:
        prefix = "Tech_";
        break;
      case gamedataWeaponEvolution.Smart:
        prefix = "Smart_";
        break;
      default:
        return "";
    }
    for f in fams {
      if StrBeginsWith(f, prefix) {
        return f;
      }
    }
    return "";
  }

  // 0 none 1 iconic only 2 family 3 ours
  public static func Kind(bp: TweakDBID, root: TweakDBID) -> Int32 {
    let fam: String;
    let n: Int32;
    let col: Bool;
    let dedicated: Bool = false;

    if StrBeginsWith(TDBID.ToStringDEBUG(bp), "Items.SSS_") {
      return 3;
    }
    for child in SSS.Children(root) {
      let slot: TweakDBID = SSS.ElementSlot(child);
      if slot == t"AttachmentSlots.IconicWeaponModLegendary" || slot == t"AttachmentSlots.IconicMeleeWeaponMod1" {
        dedicated = true;
      } else {
        if SSS.ParseSlot(slot, fam, n, col) {
          return 2;
        }
      }
    }
    if dedicated {
      return 1;
    }
    return 0;
  }

  public static func Clone(bp: TweakDBID, root: TweakDBID, fam: String) -> TweakDBID {
    let name: String = TDBID.ToStringDEBUG(bp);
    if !StrBeginsWith(name, "Items.") {
      return TDBID.None();
    }
    let cloneName: String = "Items.SSS_" + StrMid(name, 6) + "__" + fam;
    let rootName: String = cloneName + "_inline0";
    let cloneId: TweakDBID = TDBID.Create(cloneName);
    let rootId: TweakDBID = TDBID.Create(rootName);

    if !IsDefined(TweakDBInterface.GetItemBlueprintElementRecord(rootId)) {
      if !TweakDBManager.CloneRecord(StringToName(rootName), root) {
        return TDBID.None();
      }
    }
    if !IsDefined(TweakDBInterface.GetItemBlueprintRecord(cloneId)) {
      if !TweakDBManager.CloneRecord(StringToName(cloneName), bp) {
        return TDBID.None();
      }
      TweakDBManager.SetFlat(cloneId + t".rootElement", ToVariant(rootId));
      TweakDBManager.UpdateRecord(cloneId);
    }
    return cloneId;
  }

  public static func Apply(iconic: Int32) -> Void {
    let seen: array<TweakDBID>;
    let kinds: array<Int32>;

    for rec in TweakDBInterface.GetRecords(n"gamedataWeaponItem_Record") {
      let item: ref<WeaponItem_Record> = rec as WeaponItem_Record;
      if IsDefined(item) && IsDefined(item.Blueprint()) && IsDefined(item.Blueprint().RootElement()) {
        let bp: TweakDBID = item.Blueprint().GetID();
        let root: TweakDBID = item.Blueprint().RootElement().GetID();
        let at: Int32 = ArrayFindFirst(seen, bp);
        let kind: Int32;
        let first: Bool = at < 0;

        if first {
          kind = SSS_Iconics.Kind(bp, root);
          ArrayPush(seen, bp);
          ArrayPush(kinds, kind);
        } else {
          kind = kinds[at];
        }

        if kind == 1 {
          let fam: String = SSS_Iconics.FamilyOf(item);
          if NotEquals(fam, "") {
            let clone: TweakDBID = SSS_Iconics.Clone(bp, root, fam);
            if TDBID.IsValid(clone) {
              SSS.SetFamilySlots(TweakDBInterface.GetItemBlueprintRecord(clone).RootElement().GetID(), fam, iconic, SSS.Iconic());
              TweakDBManager.SetFlat(item.GetID() + t".blueprint", ToVariant(clone));
              TweakDBManager.UpdateRecord(item.GetID());
            }
          }
        } else {
          if kind == 3 && first {
            let fam3: String = SSS_Iconics.FamilyOf(item);
            if NotEquals(fam3, "") {
              SSS.SetFamilySlots(root, fam3, iconic, SSS.Iconic());
            }
          }
        }
      }
    }
  }
}

public class SSS_WeaponsTweak extends ScriptableTweak {

  protected cb func OnApply() -> Void {
    SSS_Weapons.Apply();
  }
}

public class SSS_WeaponsSystem extends ScriptableSystem {

  private func OnAttach() -> Void {
    SSS_Weapons.Apply();
    SSS_Listen.Register(this);
  }

  private func OnDetach() -> Void {
    SSS_Listen.Unregister(this);
  }

  @if(ModuleExists("ModSettingsModule"))
  public func OnModSettingsChange() -> Void {
    SSS_Weapons.Apply();
  }
}
