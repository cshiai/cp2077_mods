module SlotsSlotsSlots.Core

public class SSS_UISettings {

  @runtimeProperty("ModSettings.mod", "Slots Slots Slots")
  @runtimeProperty("ModSettings.category", "Interface")
  @runtimeProperty("ModSettings.displayName", "Two column slots")
  @runtimeProperty("ModSettings.description", "Attachment and mod slots in two columns instead of one.")
  public let twoColumns: Bool = true;
}

public class SSS_UI {

  public static func BaseSlot(slot: TweakDBID) -> TweakDBID {
    let fam: String;
    let n: Int32;
    let cat: Int32;
    if SSS.ParseSlotCat(slot, fam, n, cat) && (n >= 3 || cat == SSS.Iconic() || cat == SSS.Arms()) && cat != SSS.Collectible() {
      return SSS.SlotId(fam, 1);
    }
    return slot;
  }
}

@wrapMethod(UIItemsHelper)
public final static func GetSlotShadowIcon(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> CName {
  return wrappedMethod(SSS_UI.BaseSlot(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetLootingShadowIcon(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> CName {
  return wrappedMethod(SSS_UI.BaseSlot(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetSlotName(slotID: TweakDBID, itemType: gamedataItemType, equipmentArea: gamedataEquipmentArea) -> String {
  return wrappedMethod(SSS_UI.BaseSlot(slotID), itemType, equipmentArea);
}

@wrapMethod(UIItemsHelper)
public final static func GetEmptySlotName(slotId: TweakDBID) -> String {
  return wrappedMethod(SSS_UI.BaseSlot(slotId));
}

@addField(InventoryWeaponItemChooser)
let m_sssAttachRow: wref<inkHorizontalPanel>;

@wrapMethod(InventoryWeaponItemChooser)
protected func RebuildParts() -> Void {
  wrappedMethod();
  if IsDefined(this.m_sssAttachRow) || !(new SSS_UISettings()).twoColumns {
    return;
  }
  let scope: ref<inkWidget> = inkWidgetRef.Get(this.m_scopeRootContainer);
  if !IsDefined(scope) {
    return;
  }
  let vpanel: ref<inkCompoundWidget> = scope.GetParentWidget() as inkCompoundWidget;
  if !IsDefined(vpanel) {
    return;
  }
  let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
  row.SetName(n"sss_attachRow");
  row.Reparent(vpanel);
  this.m_sssAttachRow = row;
  let sil: ref<inkWidget> = inkWidgetRef.Get(this.m_silencerRootContainer);
  let mag: ref<inkWidget> = inkWidgetRef.Get(this.m_magazineRootContainer);
  scope.Reparent(row);
  if IsDefined(sil) {
    sil.Reparent(row);
  }
  if IsDefined(mag) {
    mag.Reparent(row);
  }
}

@wrapMethod(InventoryGenericItemChooser)
protected func RebuildSlots() -> Void {
  wrappedMethod();
  if NotEquals(this.equipmentArea, gamedataEquipmentArea.Weapon) || !(new SSS_UISettings()).twoColumns {
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
