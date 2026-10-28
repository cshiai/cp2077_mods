import Phoenicia.BlackChrome.CyberDeckHelpers.*

@wrapMethod(Device)
protected final const func IsCyberdeckEquippedOnPlayer() -> Bool {
  let player = GetPlayer(this.GetGame());
  if !IsDefined(player) {
    return wrappedMethod();
  };
  return IsCyberdeckEquipped(player) || IsAuxCyberdeckEquipped(player) || wrappedMethod();
}

@wrapMethod(EquipmentSystem)
public final static func IsCyberdeckEquipped(owner: ref<GameObject>) -> Bool {
  if !IsDefined(owner) {
    return wrappedMethod(owner);
  };
    return IsCyberdeckEquipped(owner) || IsAuxCyberdeckEquipped(owner) || wrappedMethod(owner);
}

@wrapMethod(healthbarWidgetGameController)
protected final const func IsCyberdeckEquipped() -> Bool {
  let player = this.GetPlayerControlledObject();
  if !IsDefined(player) {
    return wrappedMethod();
  };
  return IsCyberdeckEquipped(player) || IsAuxCyberdeckEquipped(player) || IsAegis(player) || wrappedMethod();
}

@wrapMethod(RPGManager)
public final static func GetPlayerQuickHackListWithQuality(player: wref<PlayerPuppet>) -> array<PlayerQuickhackData> {
    let empty: array<PlayerQuickhackData>;
    if !IsDefined(player) {
        return empty;
    }
    if (!IsAuxCyberdeckEquipped(player) || IsCyberdeckEquipped(player)) {
        return wrappedMethod(player);
    }
    let actions: array<wref<ObjectAction_Record>>;
    let i: Int32;
    let itemRecord: wref<Item_Record>;
    let quickhackData: PlayerQuickhackData;
    let quickhackDataEmpty: PlayerQuickhackData;
    let auxCyberdeckId: ItemID;
    let tweakItemID: TweakDBID;
    let quickhackDataArray: array<PlayerQuickhackData> = player.GetCachedQuickHackList();
    let equipmentData = EquipmentSystem.GetData(player);
    if !IsDefined(equipmentData) {
        return wrappedMethod(player);
    }
    if ArraySize(quickhackDataArray) > 0 {
        ArrayClear(quickhackDataArray);
    };
    auxCyberdeckId = equipmentData.FindItemInEquipAreaByTag(n"BlackChrome.AuxCyberdeck", gamedataEquipmentArea.FrontalCortexCW);
    if !ItemID.IsValid(auxCyberdeckId) {
        return wrappedMethod(player);
    }
    itemRecord = RPGManager.GetItemRecord(auxCyberdeckId);
    if !IsDefined(itemRecord) {
        return wrappedMethod(player);
    }
    tweakItemID = itemRecord.GetID();
    
    if EquipmentSystem.IsCyberdeckEquipped(player) {
        itemRecord.ObjectActions(actions);
        i = 0;

        while i < ArraySize(actions) {
            if IsDefined(actions[i]) && IsDefined(actions[i].ObjectActionType()) {
                let actionType = actions[i].ObjectActionType().Type();
                if Equals(actionType, gamedataObjectActionType.DeviceQuickHack) || Equals(actionType, gamedataObjectActionType.PuppetQuickHack) || Equals(actionType, gamedataObjectActionType.VehicleQuickHack) {
                    quickhackData = quickhackDataEmpty;
                    quickhackData.actionRecord = actions[i];
                    quickhackData.quality = itemRecord.Quality().Value();
                    ArrayPush(quickhackDataArray, quickhackData);
                };
            };
            i += 1;
        };
    };

    RPGManager.RemoveDuplicatedHacks(quickhackDataArray);
    PlayerPuppet.ChacheQuickHackList(player, quickhackDataArray);
    return quickhackDataArray;
}

@wrapMethod(CyberdeckTooltip)
private final func UpdateCyberwareQuickHackMenuLinkModule() -> Void {
    let tags: array<CName>;
    ArrayPush(tags, n"BlackChrome.AuxCyberdeck");
    if IsDefined(this.m_itemData) && this.m_itemData.HasAnyTag(tags) {
        inkWidgetRef.SetVisible(this.m_itemCWQuickHackMenuLinkContainer, false);
    } else {
        wrappedMethod();
    }
}

@wrapMethod(CyberdeckTooltip)
private final func NEW_UpdateCyberwareQuickHackMenuLinkModule() -> Void {
    let tags: array<CName>;
    ArrayPush(tags, n"BlackChrome.AuxCyberdeck");
    if IsDefined(this.m_itemData) && this.m_itemData.HasAnyTag(tags) {
        inkWidgetRef.SetVisible(this.m_itemCWQuickHackMenuLinkContainer, false);
    } else {
        wrappedMethod();
    }
}
