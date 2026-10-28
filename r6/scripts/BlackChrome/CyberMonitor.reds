@if(!ModuleExists("ChipwareExpansion.ZetatechProcessor"))
@wrapMethod(RipperDocGameController)
private final func EquipCyberware(itemData: wref<gameItemData>) -> Bool {
    this.m_uiInventorySystem.FlushCyberwareStats();
    return wrappedMethod(itemData);
}

@if(!ModuleExists("ChipwareExpansion.ZetatechProcessor"))
@wrapMethod(RipperDocGameController)
private final func UnequipCyberware(itemData: wref<gameItemData>, opt itemToEquip: wref<gameItemData>, opt skipRefresh: Bool) -> Bool {
    this.m_uiInventorySystem.FlushCyberwareStats();
    return wrappedMethod(itemData, itemToEquip, skipRefresh);
}

@if(!ModuleExists("ChipwareExpansion.ZetatechProcessor"))
@wrapMethod(RipperDocGameController)
protected cb func OnBuyShardPopupClosed(data: ref<inkGameNotificationData>) -> Bool {
    let result: Bool = wrappedMethod(data);
    let resultData: ref<RipperdocTokenPopupCloseData> = data as RipperdocTokenPopupCloseData;

    if IsDefined(resultData) && resultData.confirm {
        this.m_uiInventorySystem.FlushCyberwareStats();
    }
    return result;
}
