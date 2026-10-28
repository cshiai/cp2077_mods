module Phoenicia.BlackChrome

public class UseSmartPumpEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    this.ExecuteAction(owner);
  }

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    this.ExecuteAction(owner);
  }

  private final func ExecuteAction(owner: ref<GameObject>) -> Void {
    if !IsDefined(owner) {
      return;
    };
    let equipmentData = EquipmentSystem.GetData(owner);
    if !IsDefined(equipmentData) {
      return;
    };
    let action: ref<BaseItemAction>;
    let actionID: TweakDBID;
    let consumableItemId: ItemID = equipmentData.FindItemInEquipAreaByTag(n"BlackChrome.SmartPumps", gamedataEquipmentArea.CardiovascularSystemCW);
    if !ItemID.IsValid(consumableItemId) {
      return;
    };
    let useAction = ItemActionsHelper.GetUseAction(consumableItemId);
    if !IsDefined(useAction) {
      return;
    };
    actionID = useAction.GetID();
    action = ItemActionsHelper.SetupItemAction(owner.GetGame(), owner, RPGManager.GetItemData(owner.GetGame(), owner, consumableItemId), actionID, true);
    if IsDefined(action) {
      action.ProcessRPGAction(owner.GetGame());
    };
  }
}

public class UseBerserkEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    this.ExecuteAction(owner);
  }

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    this.ExecuteAction(owner);
  }

  private final func ExecuteAction(owner: ref<GameObject>) -> Void {
    if !IsDefined(owner) {
      return;
    };
    let equipmentData = EquipmentSystem.GetData(owner);
    if !IsDefined(equipmentData) {
      return;
    };
    let action: ref<BaseItemAction>;
    let actionID: TweakDBID;
    let berserkId: ItemID = equipmentData.FindItemInEquipAreaByTag(n"BlackChrome.UndyingBerserk", gamedataEquipmentArea.SystemReplacementCW);
    if !ItemID.IsValid(berserkId) {
      return;
    };

    let useAction = ItemActionsHelper.GetItemActionByType(berserkId, n"UseBerserk");
    if !IsDefined(useAction) {
      return;
    };
    actionID = useAction.GetID();
    action = ItemActionsHelper.SetupItemAction(owner.GetGame(), owner, RPGManager.GetItemData(owner.GetGame(), owner, berserkId), actionID, true);
    if IsDefined(action) {
      action.ProcessRPGAction(owner.GetGame());
    };
  }
}
