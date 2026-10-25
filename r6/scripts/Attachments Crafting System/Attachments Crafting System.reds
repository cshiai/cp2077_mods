module AttachmentsCraftingSystem

@wrapMethod(PlayerPuppet)
  protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {	
	if (evt.itemData.HasTag(n"Muzzle_Brake") || evt.itemData.HasTag(n"Silenced") || evt.itemData.HasTag(n"ShortScope") || evt.itemData.HasTag(n"LongScope") || evt.itemData.HasTag(n"SniperScope")) && evt.itemData.HasTag(n"itemPart") && !evt.itemData.HasTag(n"CraftableAndUpgradableScopes") {
	  let qualityValue: Float = evt.itemData.GetStatValueByType(gamedataStatType.Quality);
	  let itemTDBID: TweakDBID = ItemID.GetTDBID(evt.itemData.GetID());
	  let itemTDBIDString = TDBID.ToStringDEBUG(itemTDBID);
	  let newItemTDBIDString: String;
		newItemTDBIDString = StrReplace(itemTDBIDString, "_legendary", "");
		newItemTDBIDString = StrReplace(newItemTDBIDString, "_Generated", "");
		newItemTDBIDString = StrReplace(newItemTDBIDString, "_Craftable", "");
      switch qualityValue {
        case 0.0:
          newItemTDBIDString = newItemTDBIDString + "_Common";
          break;
        case 1.0:
          newItemTDBIDString = newItemTDBIDString + "_Uncommon";
          break;
        case 2.0:
          newItemTDBIDString = newItemTDBIDString + "_Rare";
          break;
        case 3.0:
          newItemTDBIDString = newItemTDBIDString + "_Epic";
          break;
        case 4.0:
          newItemTDBIDString = newItemTDBIDString + "_Legendary";
          break;
        default:
          newItemTDBIDString = newItemTDBIDString + "_Common";
      };
	  let newItemTDBID = TDBID.Create(newItemTDBIDString);
	  let newItemRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(newItemTDBID);
	  let newItemID = ItemID.FromTDBID(newItemTDBID);
	  let transactionSys: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
	  if IsDefined(newItemRecord) && transactionSys.GiveItem(this, newItemID, 1) {
		transactionSys.RemoveItem(this, evt.itemData.GetID(), 1);
	  };
	};
	return wrappedMethod(evt);
  }


@wrapMethod(PlayerPuppet)
  protected cb func OnGameLoadedFactReset(evt: ref<GameLoadedFactReset>) -> Bool {
	let result = wrappedMethod(evt);	
	let questSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
	if questSystem.GetFact(n"CraftableAndUpgradableScopes") > 0 {
	  return result;
	};
    let i: Int32;
    let itemList: array<wref<gameItemData>>;
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
    transactionSystem.GetItemList(this, itemList);
    i = 0;
    while i < ArraySize(itemList) {
      if (itemList[i].HasTag(n"Muzzle_Brake") || itemList[i].HasTag(n"Silenced") || itemList[i].HasTag(n"ShortScope") || itemList[i].HasTag(n"LongScope") || itemList[i].HasTag(n"SniperScope")) && itemList[i].HasTag(n"itemPart") && !itemList[i].HasTag(n"CraftableAndUpgradableScopes") {
        
	  let qualityValue: Float = itemList[i].GetStatValueByType(gamedataStatType.Quality);
	  let itemTDBID: TweakDBID = ItemID.GetTDBID(itemList[i].GetID());
	  let itemTDBIDString = TDBID.ToStringDEBUG(itemTDBID);
	  let newItemTDBIDString: String;
		newItemTDBIDString = StrReplace(itemTDBIDString, "_legendary", "");
		newItemTDBIDString = StrReplace(newItemTDBIDString, "_Generated", "");
		newItemTDBIDString = StrReplace(newItemTDBIDString, "_Craftable", "");
      switch qualityValue {
        case 0.0:
          newItemTDBIDString = newItemTDBIDString + "_Common";
          break;
        case 1.0:
          newItemTDBIDString = newItemTDBIDString + "_Uncommon";
          break;
        case 2.0:
          newItemTDBIDString = newItemTDBIDString + "_Rare";
          break;
        case 3.0:
          newItemTDBIDString = newItemTDBIDString + "_Epic";
          break;
        case 4.0:
          newItemTDBIDString = newItemTDBIDString + "_Legendary";
          break;
        default:
          newItemTDBIDString = newItemTDBIDString + "_Common";
      };
	  let newItemTDBID = TDBID.Create(newItemTDBIDString);
	  let newItemRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(newItemTDBID);
	  let newItemID = ItemID.FromTDBID(newItemTDBID);
	  let transactionSys: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
	  if IsDefined(newItemRecord) && transactionSys.GiveItem(this, newItemID, 1) {
		transactionSys.RemoveItem(this, itemList[i].GetID(), 1);
	  };
      };
      i += 1;
    };	
	questSystem.SetFact(StringToName("CraftableAndUpgradableScopes"), 1);
	return result;
  }