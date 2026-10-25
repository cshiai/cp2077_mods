// Pure redscript Instant Upgrade & No Upgrade Double-Check / Long-Press for Cyberpunk 2077 2.5
// 1. Removes the hold/long-press requirement on weapon/item upgrading and crafting in the Crafting/Upgrade menu
//    (single click/press on either the item card or the Upgrade/Craft button completes immediately).
// 2. Removes the tooltip delay when upgrading items so stat previews update immediately on rapid clicks.
// 3. Removes the Ripperdoc cyberware upgrade double-check confirmation popup (RipperdocTokenPopup),
//    intro/outro animations, and long-press hold, performing cyberware upgrades in a single keypress
//    while keeping the slot focused for rapid multi-tier upgrading.

// --- 1. Inventory Item Upgrading & Crafting: Instant Click (0 Hold Time) ---

@wrapMethod(CraftingMainLogicController)
private final func StartProcess() -> Void {
  if !this.m_isCraftable {
    return;
  }
  this.m_isProcessing = false;
  if IsDefined(this.m_progressButtonController) {
    this.m_progressButtonController.Unlock();
    this.m_progressButtonController.Start();
  } else {
    let finishedProccess: ref<ProgressBarFinishedProccess> = new ProgressBarFinishedProccess();
    this.QueueEvent(finishedProccess);
  }
  if IsDefined(this.m_craftingGameController) {
    this.m_craftingGameController.EnableTabs();
  }
}

@wrapMethod(ProgressBarButton)
public final func Start() -> Void {
  if this.m_isLocked || !this.m_available {
    return;
  }
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.Stop(true);
    this.m_animProxy = null;
  }
  inkWidgetRef.SetScale(this.m_craftingFill, new Vector2(0.00, 1.00));
  if IsDefined(this.m_progressController) {
    this.m_progressController.SetBarProgress(0.00);
  }
  let finishedProccess: ref<ProgressBarFinishedProccess> = new ProgressBarFinishedProccess();
  this.QueueEvent(finishedProccess);
  this.PlaySound(n"Item", n"OnCrafted");
  this.PlayLibraryAnimation(n"craft_complete_feedback");
  this.m_justFinished = true;
}

@wrapMethod(ProgressBarButton)
public final func UpdateCraftProcess(evt: ref<inkPointerEvent>) -> Void {
  if this.m_justFinished {
    return;
  }
  wrappedMethod(evt);
}

@wrapMethod(UpgradingScreenController)
protected cb func OnHoldFinished(evt: ref<ProgressBarFinishedProccess>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.m_isProcessing = false;
  if IsDefined(this.m_craftingGameController) {
    this.m_craftingGameController.EnableTabs();
  }
  return result;
}

@wrapMethod(CraftingLogicController)
protected cb func OnHoldFinished(evt: ref<ProgressBarFinishedProccess>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.m_isProcessing = false;
  if IsDefined(this.m_craftingGameController) {
    this.m_craftingGameController.EnableTabs();
  }
  return result;
}

// Remove the delayed tooltip timer when upgrading so rapid-clicking updates stats immediately
@wrapMethod(UpgradingScreenController)
private final func UpdateTooltipData() -> Void {
  wrappedMethod();
  this.UpdateTooltipRightAndShow();
}

// --- 2. Ripperdoc Cyberware Upgrading: No Double-Check Popup & No Long-Press ---

@replaceMethod(RipperDocGameController)
private final func StartCWUpgrade() -> Void {
  let equippedItemData: wref<UIInventoryItem> = this.m_hoveredItem;
  if !IsDefined(equippedItemData) {
    return;
  }
  this.m_isInEquipPopup = true;
  this.m_upgradeData = RPGManager.GetCyberwareUpgradeData(
    this.m_player,
    equippedItemData,
    this.m_upgradeItem,
    this.m_upgradeCostData,
    this.m_inventorySystem.GetCyberwareUpgradeSeed(),
    this.m_uiInventorySystem,
    RPGManager.ShouldShowCWChoice(this.m_player, equippedItemData)
  );
  if IsDefined(this.m_upgradeData) && IsDefined(this.m_upgradeData.option1GameItemData) {
    let closeData: ref<RipperdocTokenPopupCloseData> = new RipperdocTokenPopupCloseData();
    closeData.confirm = true;
    closeData.chosenOptionIndex = 0;
    closeData.chosenOptionData = this.m_upgradeData.option1GameItemData;
    closeData.costData = this.m_upgradeData.costData;
    this.OnBuyShardPopupClosed(closeData);
  } else {
    this.m_isInEquipPopup = false;
  }
}

// Keep the cyberware slot hovered & upgradable after an instant upgrade so rapid presses work seamlessly
@wrapMethod(RipperDocGameController)
private final func UpdateMinigrids() -> Void {
  wrappedMethod();
  if IsDefined(this.m_hoveredItemDisplay) && !this.m_isInEquipPopup {
    let refreshedItem: wref<UIInventoryItem> = this.m_hoveredItemDisplay.GetUIInventoryItem();
    if IsDefined(refreshedItem) {
      this.m_hoveredItem = refreshedItem;
      this.HighlightUpgradeResources(refreshedItem, false);
    }
  }
}

// Fallback: if RipperdocTokenPopup is ever opened directly, complete on single press without hold/outro delay
@wrapMethod(RipperdocTokenPopup)
protected cb func OnOption1Press(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(this.m_holdInputName) || evt.IsAction(n"click") {
    this.m_choice = 0;
    this.m_result = true;
    this.Close();
    return true;
  }
  return wrappedMethod(evt);
}

@wrapMethod(RipperdocTokenPopup)
protected cb func OnOption2Press(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(this.m_holdInputName) || evt.IsAction(n"click") {
    this.m_choice = 1;
    this.m_result = true;
    this.Close();
    return true;
  }
  return wrappedMethod(evt);
}

@wrapMethod(RipperdocTokenPopup)
protected cb func OnOption3Press(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(this.m_holdInputName) || evt.IsAction(n"click") {
    this.m_choice = 2;
    this.m_result = true;
    this.Close();
    return true;
  }
  return wrappedMethod(evt);
}
