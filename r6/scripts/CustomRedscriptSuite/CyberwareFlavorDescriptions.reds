// Restore the vanilla cyberware flavour-text panel without CET.
//
// Patch 2.0 deliberately hid Item_Record.localizedDescription for every
// cyberware item in ItemTooltipCommonController.ShouldHideDescription().
// The records and ArchiveXL translations are still present (including the
// Black Chrome descriptions), so this profile only removes that UI filter.
// Crafting/upgrading, grenades, consumables, recipes, and materials retain
// the vanilla hide rules.  The hook is deliberately a small replacement and
// does not touch item data, stats, or gameplay effectors.
@replaceMethod(ItemTooltipCommonController)
private func ShouldHideDescription(itemType: gamedataItemType) -> Bool {
  return (Equals(this.m_data.itemTweakID, t"Items.money")
    || Equals(this.m_tooltipDisplayContext, InventoryTooltipDisplayContext.Crafting)
    || Equals(this.m_tooltipDisplayContext, InventoryTooltipDisplayContext.Upgrading)
    || Equals(this.m_itemDisplayContext, ItemDisplayContext.Crafting)
    || Equals(itemType, gamedataItemType.Gad_Grenade)
    || Equals(itemType, gamedataItemType.Con_Inhaler)
    || Equals(itemType, gamedataItemType.Con_Injector)
    || Equals(itemType, gamedataItemType.Gen_CraftingMaterial)
    || Equals(itemType, gamedataItemType.Con_Skillbook));
}
