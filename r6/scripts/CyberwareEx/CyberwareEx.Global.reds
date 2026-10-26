// CyberwareEx 1.6.0
import CyberwareEx.{CompatibilityManager, ConflictsPopup, RequirementsPopup}
import CyberwareEx.*

public abstract class CyberwareEx {
    public static func Version() -> String = "1.6.0"

    public static func ResetSlot(game: GameInstance, areaType: gamedataEquipmentArea) {
        let player = GetPlayer(game);
        if !IsDefined(player) { return; }
        let data = EquipmentSystem.GetData(player);
        if !IsDefined(data) { return; }
        let overrideManager = new OverrideManager();
        overrideManager.Initialize(data);
        overrideManager.ResetSlot(areaType, true);
    }

    public static func ResetAllSlots(game: GameInstance) {
        let player = GetPlayer(game);
        if !IsDefined(player) { return; }
        let data = EquipmentSystem.GetData(player);
        if !IsDefined(data) { return; }
        let overrideManager = new OverrideManager();
        overrideManager.Initialize(data);
        for override in OverrideConfig.SlotOverrides() {
            overrideManager.ResetSlot(override.areaType, true);
        }
    }

    public static func UpgradeSlot(game: GameInstance, areaType: gamedataEquipmentArea, opt count: Int32) {
        if IsOverrideMode() {
            let player = GetPlayer(game);
            if !IsDefined(player) { return; }
            let data = EquipmentSystem.GetData(player);
            if !IsDefined(data) { return; }
            let overrideManager = new OverrideManager();
            overrideManager.Initialize(data);
            if count == 0 {
                count = 1;
            }
            while (count > 0) {
                overrideManager.UpgradeSlot(areaType, true);
                count -= 1;
            }
        }
    }

    public static func UpgradeAllSlotsToMax(game: GameInstance) {
        if IsOverrideMode() {
            let player = GetPlayer(game);
            if !IsDefined(player) { return; }
            let data = EquipmentSystem.GetData(player);
            if !IsDefined(data) { return; }
            let overrideManager = new OverrideManager();
            overrideManager.Initialize(data);
            for override in OverrideConfig.SlotOverrides() {
                while (overrideManager.UpgradeSlot(override.areaType, true)) {}
            }
        }
    }
}

@replaceMethod(Device)
protected final const func IsCyberdeckEquippedOnPlayer() -> Bool {
    let player = GetPlayer(this.GetGame());
    return IsDefined(player) && CyberwareHelper.IsCyberdeckEquipped(player);
}

@replaceMethod(EquipmentSystem)
public final static func IsCyberdeckEquipped(owner: ref<GameObject>) -> Bool {
    if !IsDefined(owner) { return false; }
    let stats = GameInstance.GetStatsSystem(owner.GetGame());
    return IsDefined(stats) && stats.GetStatBoolValue(Cast(owner.GetEntityID()), gamedataStatType.HasCyberdeck);
}

@addMethod(EquipmentSystemPlayerData)
public func HasTaggedItem(equipArea: gamedataEquipmentArea, requiredTag: CName) -> Bool {
    return ItemID.IsValid(this.GetTaggedItem(equipArea, [requiredTag]));
}

@addMethod(EquipmentSystemPlayerData)
public func GetTaggedItem(equipArea: gamedataEquipmentArea, requiredTag: CName) -> ItemID {
    return this.GetTaggedItem(equipArea, [requiredTag]);
}

@addMethod(EquipmentSystemPlayerData)
public func GetTaggedItem(equipArea: gamedataEquipmentArea, requiredTags: array<CName>) -> ItemID {
    let equipAreaIndex = this.GetEquipAreaIndex(equipArea);
    if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(this.m_equipment.equipAreas) {
        return ItemID.None();
    }
    let numSlots = ArraySize(this.m_equipment.equipAreas[equipAreaIndex].equipSlots);
    let slotIndex = 0;

    while slotIndex < numSlots {
        let itemID = this.m_equipment.equipAreas[equipAreaIndex].equipSlots[slotIndex].itemID;

        if ItemID.IsValid(itemID) && this.CheckTagsInItem(itemID, requiredTags) {
            return itemID;
        }

        slotIndex += 1;
    }

    return ItemID.None();
}

@addMethod(EquipmentSystemPlayerData)
public func ApplyAreaPowerUps(equipArea: gamedataEquipmentArea) {
    let equipAreaIndex = this.GetEquipAreaIndex(equipArea);
    if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(this.m_equipment.equipAreas) {
        return;
    }
    let numSlots = ArraySize(this.m_equipment.equipAreas[equipAreaIndex].equipSlots);
    let slotIndex = 0;

    while slotIndex < numSlots {
        PowerUpCyberwareEffector.PowerUpCyberwareInSlot(this.m_owner, equipArea, slotIndex);
        slotIndex += 1;
    }
}

@wrapMethod(EquipmentSystemPlayerData)
public final const func GetActiveItem(equipArea: gamedataEquipmentArea, opt isLeftHandWeapon: Bool) -> ItemID {
    if Equals(equipArea, gamedataEquipmentArea.SystemReplacementCW) {
        let deckID = this.GetTaggedItem(equipArea, n"Cyberdeck");
        if ItemID.IsValid(deckID) {
            return deckID;
        }
    }

    return wrappedMethod(equipArea, isLeftHandWeapon);
}

@replaceMethod(EquipmentSystemPlayerData)
private final func EquipItem(itemID: ItemID, slotIndex: Int32, opt blockActiveSlotsUpdate: Bool, opt forceEquipWeapon: Bool) -> Void {
    let currentItem: ItemID;
    let currentItemData: ref<gameItemData>;
    let cyberwareType: CName;
    let equipArea: SEquipArea;
    let equipAreaIndex: Int32;
    let equipSlot: SEquipSlot;
    let equipmentArea: gamedataEquipmentArea;
    let i: Int32;
    let isLeftWeapon: Bool;
    let oppositeSlotIndex: Int32;
    let placementSlot: TweakDBID;
    let transactionSystem: ref<TransactionSystem>;
    let weaponRecord: ref<WeaponItem_Record>;
    if !IsDefined(this.m_owner) || !ItemID.IsValid(itemID) {
        return;
    }
    let itemData: ref<gameItemData> = RPGManager.GetItemData(this.m_owner.GetGame(), this.m_owner, itemID);
    if !this.IsEquippable(itemData) {
        return;
    }
    equipmentArea = EquipmentSystem.GetEquipAreaType(itemID);
    equipAreaIndex = this.GetEquipAreaIndex(equipmentArea);
    if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(this.m_equipment.equipAreas)
        || slotIndex < 0 || slotIndex >= ArraySize(this.m_equipment.equipAreas[equipAreaIndex].equipSlots) {
        return;
    }
    equipArea = this.m_equipment.equipAreas[equipAreaIndex];
    equipSlot = equipArea.equipSlots[slotIndex];
    currentItem = equipSlot.itemID;
    currentItemData = RPGManager.GetItemData(this.m_owner.GetGame(), this.m_owner, currentItem);
    if IsDefined(currentItemData) && currentItemData.HasTag(n"UnequipBlocked") {
        return;
    }
    if Equals(equipmentArea, gamedataEquipmentArea.Outfit) && this.IsVisualSetActive() {
        this.UnequipWardrobeSet();
    }
    transactionSystem = GameInstance.GetTransactionSystem(this.m_owner.GetGame());
    this.m_equipPending = true;
    if !this.HandleEquipWeapon(itemID, slotIndex, blockActiveSlotsUpdate, forceEquipWeapon, isLeftWeapon) {
        this.UnequipItem(equipAreaIndex, slotIndex);
        // Only enforce same-cyberwareType uniqueness for SystemReplacementCW (e.g. 1 Sandevistan + 1 Cyberdeck + 1 Berserk),
        // allowing multiple EyesCW, HandsCW, ArmsCW, LegsCW, and internal cyberware items to coexist across extra slots.
        if Equals(equipmentArea, gamedataEquipmentArea.SystemReplacementCW) {
            cyberwareType = TweakDBInterface.GetCName(ItemID.GetTDBID(itemID) + t".cyberwareType", n"None");
            i = 0;
            while i < ArraySize(this.m_equipment.equipAreas[equipAreaIndex].equipSlots) {
                if Equals(cyberwareType, TweakDBInterface.GetCName(ItemID.GetTDBID(this.m_equipment.equipAreas[equipAreaIndex].equipSlots[i].itemID) + t".cyberwareType", n"type")) {
                    this.UnequipItem(equipAreaIndex, i);
                }
                i += 1;
            }
        }
    }
    this.m_equipPending = false;
    this.m_equipment.equipAreas[equipAreaIndex].equipSlots[slotIndex].itemID = itemID;
    placementSlot = this.GetPlacementSlot(equipAreaIndex, slotIndex, isLeftWeapon);
    if Equals(itemData.GetItemType(), gamedataItemType.Cyb_StrongArms) {
        this.HandleStrongArmsEquip(itemID);
    }
    if placementSlot == t"AttachmentSlots.WeaponRight" || placementSlot == t"AttachmentSlots.WeaponLeft" {
        weaponRecord = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(itemID));
        if IsDefined(weaponRecord) && IsDefined(weaponRecord.HolsteredItem()) {
            EquipmentSystemPlayerData.UpdateArmSlot(this.m_owner as PlayerPuppet, itemID, true);
        }
    }
    if placementSlot != t"AttachmentSlots.WeaponRight" && placementSlot != t"AttachmentSlots.WeaponLeft" && placementSlot != t"AttachmentSlots.Consumable" {
        if !transactionSystem.HasItemInSlot(this.m_owner, placementSlot, itemID) {
            transactionSystem.RemoveItemFromSlot(this.m_owner, placementSlot);
            this.AddItemToSlot(transactionSystem, placementSlot, itemID, equipmentArea);
        }
    }
    this.ApplyEquipGLPs(itemID);
    this.ApplySlotGLPs(equipSlot.slotID);
    if itemData.UsesVariants() && NotEquals(equipArea.areaType, gamedataEquipmentArea.ArmsCW) || Equals(equipArea.areaType, gamedataEquipmentArea.RightArm) {
        itemData.AddStatsOnEquip(this.m_owner);
    }
    equipArea = this.m_equipment.equipAreas[equipAreaIndex];
    this.UpdateWeaponWheel();
    this.UpdateQuickWheel();
    this.UpdateUIBBAreaChanged(equipmentArea, slotIndex);
    oppositeSlotIndex = EquipmentSystemPlayerData.GetOppositeWeaponSlotIndex(slotIndex);
    this.SendPaperdollUpdate(equipArea, true, placementSlot, slotIndex, true);
    this.SendPaperdollUpdate(equipArea, ItemID.IsValid(equipArea.equipSlots[oppositeSlotIndex].itemID), isLeftWeapon ? t"AttachmentSlots.WeaponRight" : t"AttachmentSlots.WeaponLeft", oppositeSlotIndex, true);
    i = 0;
    while i < ArraySize(this.m_hotkeys) {
        if this.m_hotkeys[i].IsCompatible(itemData.GetItemType()) || this.m_hotkeys[i].IsCompatible(EquipmentSystem.GetEquipAreaType(itemData.GetID())) {
            this.AssignItemToHotkey(itemData.GetID(), this.m_hotkeys[i].GetHotkey());
        }
        i += 1;
    }
    EquipmentSystem.GetInstance(this.m_owner).Debug_FillESSlotData(slotIndex, this.m_equipment.equipAreas[equipAreaIndex].areaType, itemID, this.m_owner);
    if ItemID.IsValid(currentItem) && currentItem != itemID {
        transactionSystem.OnItemRemovedFromEquipmentSlot(this.m_owner, currentItem);
    }
    transactionSystem.OnItemAddedToEquipmentSlot(this.m_owner, itemID);
    if this.IsItemOfCategory(itemID, gamedataItemCategory.Cyberware) || Equals(equipArea.areaType, gamedataEquipmentArea.ArmsCW) {
        this.CheckCyberjunkieAchievement();
    }
    if EquipmentSystem.IsItemCyberdeck(itemID) {
        PlayerPuppet.ChacheQuickHackListCleanup(this.m_owner);
    }
}

@wrapMethod(EquipmentSystemPlayerData)
private final func UnequipItem(equipAreaIndex: Int32, slotIndex: Int32, opt forceRemove: Bool) {
    wrappedMethod(equipAreaIndex, slotIndex, forceRemove);

    if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(this.m_equipment.equipAreas) {
        return;
    }

    switch this.m_equipment.equipAreas[equipAreaIndex].areaType {
        case gamedataEquipmentArea.EyesCW:
        case gamedataEquipmentArea.LegsCW:
        case gamedataEquipmentArea.SystemReplacementCW:
            let slotIndex = 0;
            let numberOfSlots = ArraySize(this.m_equipment.equipAreas[equipAreaIndex].equipSlots);
            while slotIndex < numberOfSlots {
                let itemID = this.m_equipment.equipAreas[equipAreaIndex].equipSlots[slotIndex].itemID;
                if ItemID.IsValid(itemID) {
                    this.RemoveEquipGLPs(itemID);
                    this.ApplyEquipGLPs(itemID);
                }
                slotIndex += 1;
            }
            break;
    }
}

@replaceMethod(EquipmentSystemPlayerData)
public final func AssignItemToHotkey(newID: ItemID, hotkey: EHotkey) {
    if Equals(hotkey, EHotkey.INVALID) {
        return;
    }

    let hotkeyIndex: Int32 = EnumInt(hotkey);
    if hotkeyIndex < 0 || hotkeyIndex >= ArraySize(this.m_hotkeys) || !IsDefined(this.m_owner) {
        return;
    }

    let oldID = this.m_hotkeys[hotkeyIndex].GetItemID();
    if newID == oldID {
        if Equals(hotkey, EHotkey.LBRB) {
            this.SyncHotkeyData(hotkey);
        }
        return;
    }

    let transactionSystem = GameInstance.GetTransactionSystem(this.m_owner.GetGame());
    if !IsDefined(transactionSystem) { return; }

    let oldCategory = RPGManager.GetItemCategory(oldID);
    if NotEquals(oldCategory, gamedataItemCategory.Cyberware) {
        transactionSystem.OnItemRemovedFromEquipmentSlot(this.m_owner, oldID);
    }
    if Equals(oldCategory, gamedataItemCategory.Consumable) {
        this.RemoveEquipGLPs(oldID);
    }

    this.m_hotkeys[hotkeyIndex].StoreItem(newID);

    let newCategory = RPGManager.GetItemCategory(newID);
    if NotEquals(newCategory, gamedataItemCategory.Cyberware) {
        transactionSystem.OnItemAddedToEquipmentSlot(this.m_owner, newID);
    }
    if Equals(newCategory, gamedataItemCategory.Consumable) {
        this.ApplyEquipGLPs(newID);
    }

    this.SyncHotkeyData(hotkey);
}

@wrapMethod(EquipmentSystemPlayerData)
private final const func IsSlotLocked(slot: SEquipSlot, out visibleWhenLocked: Bool) -> Bool {
    if !slot.visibleWhenLocked {
        return wrappedMethod(slot, visibleWhenLocked);
    }
    visibleWhenLocked = true;
    return false;
}

@replaceMethod(EquipmentSystemPlayerData)
private final func InitializeEquipmentArea(equipAreaRecord: ref<EquipmentArea_Record>, out equipArea: SEquipArea) {
    if !IsDefined(equipAreaRecord) {
        return;
    }
    let equipSlotRecords: array<wref<EquipSlot_Record>>;
    equipAreaRecord.EquipSlots(equipSlotRecords);

    if CyberwareHelper.IsCyberwareArea(equipArea.areaType) {
        let numberOfRecords = ArraySize(equipSlotRecords);
        let numberOfSlots = ArraySize(equipArea.equipSlots);
        let savedFactSlots = 0;
        if IsDefined(this.m_owner) {
            savedFactSlots = GameInstance.GetQuestsSystem(this.m_owner.GetGame())
                .GetFact(CyberwareHelper.GetSlotCountFactName(equipArea.areaType));
        }
        let targetSlots = Max(numberOfSlots, Max(numberOfRecords, savedFactSlots));
        if targetSlots > numberOfRecords {
            let slotIndex = numberOfRecords;
            while slotIndex < targetSlots {
                let equipSlotID = CyberwareHelper.CreateEquipSlotRecord(equipArea.areaType, slotIndex);
                ArrayPush(equipSlotRecords, TweakDBInterface.GetEquipSlotRecord(equipSlotID));
                slotIndex += 1;
            }
        }
    }

    this.InitializeEquipSlotsFromRecords(equipSlotRecords, equipArea.equipSlots);
}

@replaceMethod(EquipmentSystemPlayerData)
private final func InitializeEquipSlotsFromRecords(slotRecords: array<wref<EquipSlot_Record>>, out equipSlots: array<SEquipSlot>) {
    let numberOfRecords = ArraySize(slotRecords);
    let numberOfSlots = ArraySize(equipSlots);
    let finalSize = Max(numberOfRecords, numberOfSlots);
    let i = 0;
    while i < finalSize {
        let savedID = i < numberOfSlots ? equipSlots[i].itemID : ItemID.None();
        if i < numberOfRecords {
            let equipSlot: SEquipSlot;
            this.InitializeEquipSlotFromRecord(slotRecords[i], equipSlot);
            if ItemID.IsValid(savedID) {
                equipSlot.itemID = savedID;
            }
            if i < numberOfSlots {
                equipSlots[i] = equipSlot;
            } else {
                ArrayPush(equipSlots, equipSlot);
            }
        } else {
            this.InitializeEquipSlotFromRecord(TweakDBInterface.GetEquipSlotRecord(t"EquipmentArea.SimpleEquipSlot"), equipSlots[i]);
            if ItemID.IsValid(savedID) {
                equipSlots[i].itemID = savedID;
            }
        }
        i += 1;
    }
}

@if(!ModuleExists("CyberarmOverhaul"))
@wrapMethod(EquipmentSystemPlayerData)
private final const func UpdateQuickWheel() {
    wrappedMethod();

    let i = 0;
    while i < ArraySize(this.m_hotkeys) {
        let itemID = this.m_hotkeys[i].GetItemID();
        if ItemID.IsValid(itemID) {
            if this.CheckTagsInItem(itemID, [n"ProjectileLauncher"]) {
                if !this.IsEquipped(itemID) {
                    this.AssignNextValidItemToHotkey(itemID);
                }
                break;
            }
        }
        i += 1;
    }
}

@if(!ModuleExists("CyberarmOverhaul"))
@replaceMethod(EquipmentSystemPlayerData)
public final static func UpdateArmSlot(owner: ref<gamePuppet>, itemToDraw: ItemID, equipHolsteredItem: Bool) {
    let player = owner as PlayerPuppet;
    if !IsDefined(owner) || !ItemID.IsValid(itemToDraw) || (IsDefined(player) && player.IsJohnnyReplacer()) {
      return;
    }

    let equipmentData = EquipmentSystem.GetData(owner);

    if !IsDefined(equipmentData) {
      return;
    }

    if !equipmentData.IsEquipped(itemToDraw, gamedataEquipmentArea.ArmsCW) && itemToDraw != equipmentData.GetBaseFistsItemID() {
      return;
    }

    let transactionSystem = GameInstance.GetTransactionSystem(owner.GetGame());
    if !IsDefined(transactionSystem) { return; }
    let rightItem = transactionSystem.GetItemInSlot(owner, t"AttachmentSlots.WeaponRight");
    let leftItem = transactionSystem.GetItemInSlot(owner, t"AttachmentSlots.WeaponLeft");
    let rightWeaponID: ItemID = IsDefined(rightItem) ? rightItem.GetItemID() : ItemID.None();
    let leftWeaponID: ItemID = IsDefined(leftItem) ? leftItem.GetItemID() : ItemID.None();

    let rightRecord = ItemID.IsValid(rightWeaponID) ? TweakDBInterface.GetItemRecord(ItemID.GetTDBID(rightWeaponID)) : null;
    let leftRecord = ItemID.IsValid(leftWeaponID) ? TweakDBInterface.GetItemRecord(ItemID.GetTDBID(leftWeaponID)) : null;
    let cyberArmsInUse = IsDefined(rightRecord) && rightRecord.TagsContains(n"Meleeware");
    let launcherInUse = IsDefined(leftRecord) && leftRecord.TagsContains(n"ProjectileLauncher");

    let meleeWareID = ItemID.None();
    let slotIndex = 0;
    let equipAreaIndex = equipmentData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if equipAreaIndex < 0 || equipAreaIndex >= ArraySize(equipmentData.m_equipment.equipAreas) { return; }
    let numberOfSlots = ArraySize(equipmentData.m_equipment.equipAreas[equipAreaIndex].equipSlots);
    while slotIndex < numberOfSlots {
        let itemID = equipmentData.m_equipment.equipAreas[equipAreaIndex].equipSlots[slotIndex].itemID;
        if ItemID.IsValid(itemID) {
            meleeWareID = itemID;
            let itemRecord = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
            if IsDefined(itemRecord) && !itemRecord.TagsContains(n"ProjectileLauncher") {
                break;
            }
        }
        slotIndex += 1;
    }

    if !ItemID.IsValid(meleeWareID) {
        meleeWareID = equipmentData.GetBaseFistsItemID();
    }

    if !launcherInUse && !cyberArmsInUse {
        let meleeRecord = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(meleeWareID));
        if !IsDefined(meleeRecord) || !IsDefined(meleeRecord.HolsteredItem()) { return; }
        let holsteredArmsID = ItemID.CreateQuery(meleeRecord.HolsteredItem().GetID());

        if !transactionSystem.HasItem(owner, holsteredArmsID) {
            transactionSystem.GiveItem(owner, holsteredArmsID, 1);
        }

        EquipmentSystemPlayerData.ForceQualityAndDuplicateStatsShard(owner, meleeWareID, holsteredArmsID);

        if !equipmentData.IsEquipped(holsteredArmsID) {
            equipmentData.EquipItem(holsteredArmsID, false, false);
        }
    } else {
        equipmentData.UnequipItem(equipmentData.GetEquipAreaIndex(gamedataEquipmentArea.RightArm), 0, true);
    }
}

@wrapMethod(PlayerDevelopmentData)
private final func HandleAddingPerkLevel(i: Int32, j: Int32) {
    // Preserve vanilla perk bookkeeping first.  This hook used to omit the
    // wrapped call entirely, which could leave perk progression/state stale.
    wrappedMethod(i, j);
    if i < 0 || i >= ArraySize(this.m_attributesData)
        || j < 0 || j >= ArraySize(this.m_attributesData[i].unlockedPerks)
        || !IsDefined(this.m_owner) {
        return;
    }
    if Equals(this.m_attributesData[i].unlockedPerks[j].type, gamedataNewPerkType.Tech_Central_Milestone_3) && this.m_attributesData[i].unlockedPerks[j].currLevel == 3 {
        EquipmentSystem.GetData(this.m_owner).ApplyAreaPowerUps(gamedataEquipmentArea.MusculoskeletalSystemCW);
    }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    let result: Bool = wrappedMethod();

    if this.IsControlledByLocalPeer() || IsHost() {
        this.RegisterInputListener(this, n"ToggleSprint");
    }

    return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if this.PlayerLastUsedPad() && Equals(ListenerAction.GetName(action), n"ToggleSprint")
        && Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_RELEASED) {
        let psmBlackboard = this.GetPlayerStateMachineBlackboard();
        let isFocusMode = Equals(IntEnum<gamePSMVision>(psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision)), gamePSMVision.Focus);
        if isFocusMode {
            if QuickHackableHelper.TryToCycleOverclockedState(this) {
                let dpadAction = new DPADActionPerformed();
                dpadAction.action = EHotkey.LBRB;
                dpadAction.state = EUIActionState.COMPLETED;
                dpadAction.successful = true;

                GameInstance.GetUISystem(this.GetGame()).QueueEvent(dpadAction);
                return true;
            }
        }
    }
    return wrappedMethod(action, consumer);
}

@replaceMethod(PlayerPuppet)
private final func ActivateIconicCyberware() {
    let equipmentData = EquipmentSystem.GetData(this);
    let characterData = PlayerDevelopmentSystem.GetData(this);
    if !IsDefined(equipmentData) || !IsDefined(characterData) { return; }

    let hasBerserk = equipmentData.HasTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Berserk");
    let hasSandevistan = equipmentData.HasTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Sandevistan");
    let hasOverclock = equipmentData.HasTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Cyberdeck")
        && characterData.IsNewPerkBought(gamedataNewPerkType.Intelligence_Central_Milestone_3) == 3;

    let numberOfAbilities = (hasBerserk ? 1 : 0) + (hasSandevistan ? 1 : 0) + (hasOverclock ? 1 : 0);
    if numberOfAbilities == 0 {
        return;
    }

    let isOnlyOneAbility = numberOfAbilities == 1;
    let isCombinedAbilityMode = IsCombinedAbilityMode();

    let statsSystem = GameInstance.GetStatsSystem(this.GetGame());
    if !IsDefined(statsSystem) { return; }
    let playerStatsId = Cast<StatsObjectID>(this.GetEntityID());
    let canUseBerserk = statsSystem.GetStatBoolValue(playerStatsId, gamedataStatType.HasBerserk);
    let canUseSandevistan = statsSystem.GetStatBoolValue(playerStatsId, gamedataStatType.HasSandevistan);

    let psmBlackboard = this.GetPlayerStateMachineBlackboard();
    if !IsDefined(psmBlackboard) { return; }
    let meleeWeaponState = IntEnum<gamePSMMeleeWeapon>(psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.MeleeWeapon));

    let isFocusMode = Equals(IntEnum<gamePSMVision>(psmBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision)), gamePSMVision.Focus);
    let isBlocking = Equals(meleeWeaponState, gamePSMMeleeWeapon.Block) || Equals(meleeWeaponState, gamePSMMeleeWeapon.BlockAttack)
        || Equals(meleeWeaponState, gamePSMMeleeWeapon.Deflect) || Equals(meleeWeaponState, gamePSMMeleeWeapon.DeflectAttack);
    let isInVehicle = psmBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.MountedToVehicle);

    let attempted = false;
    let activated = false;

    if hasOverclock && (isOnlyOneAbility || isFocusMode || isCombinedAbilityMode) {
        attempted = true;
        if QuickHackableHelper.TryToCycleOverclockedState(this) {
            activated = true;
        }
    }

    if hasBerserk && !isFocusMode && (isOnlyOneAbility || ((isBlocking || !hasSandevistan)) || isCombinedAbilityMode) {
        if canUseBerserk && !isInVehicle {
            let berserkItem = equipmentData.GetTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Berserk");

            attempted = true;
            if ItemActionsHelper.UseItem(this, berserkItem) {
                activated = true;
            }
        }
    }

    if hasSandevistan && !isFocusMode && (isOnlyOneAbility || ((!isBlocking || !hasBerserk)) || isCombinedAbilityMode) {
        if canUseSandevistan && TimeDilationHelper.CanUseTimeDilation(this) {
            let sandevistanItem = equipmentData.GetTaggedItem(gamedataEquipmentArea.SystemReplacementCW, n"Sandevistan");

            attempted = true;
            if ItemActionsHelper.UseItem(this, sandevistanItem) {
                activated = true;
            }
        }
    }

    if attempted {
        if activated {
            this.IconicCyberwareActivated();
        } else {
            let audioEvent = new SoundPlayEvent();
            audioEvent.soundName = n"ui_grenade_empty";

            this.QueueEvent(audioEvent);
        }

        let dpadAction = new DPADActionPerformed();
        dpadAction.action = EHotkey.LBRB;
        dpadAction.state = EUIActionState.COMPLETED;
        dpadAction.successful = activated;

        GameInstance.GetUISystem(this.GetGame()).QueueEvent(dpadAction);
    }
}

@wrapMethod(PlayerPuppet)
protected cb func OnCleanUpTimeDilationEvent(evt: ref<CleanUpTimeDilationEvent>) -> Bool {
    let timeSystem = GameInstance.GetTimeSystem(this.GetGame());
    if IsDefined(timeSystem) && timeSystem.IsTimeDilationActive() {
        return false;
    }
    return wrappedMethod(evt);
}

@addField(QuestTrackerGameController)
private let m_cyberwareExPopup: ref<inkGameNotificationToken>;

@wrapMethod(QuestTrackerGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();

    if !CompatibilityManager.IsUserNotified() {
        if !CompatibilityManager.CheckRequirements() {
            this.m_cyberwareExPopup = RequirementsPopup.Show(this);
            this.m_cyberwareExPopup.RegisterListener(this, n"OnCyberwareExPopupClose");
        } else {
            if IsDefined(this.m_player) && !CompatibilityManager.CheckConflicts(this.m_player.GetGame()) {
                this.m_cyberwareExPopup = ConflictsPopup.Show(this);
                this.m_cyberwareExPopup.RegisterListener(this, n"OnCyberwareExPopupClose");
            }
        }
        CompatibilityManager.MarkAsNotified();
    }
    return result;
}

@addMethod(QuestTrackerGameController)
protected cb func OnCyberwareExPopupClose(data: ref<inkGameNotificationData>) {
    this.m_cyberwareExPopup = null;
}

// CyberNinjaParkour owns this high-risk hook when present.  Keep CyberwareEx
// as a transparent wrapper instead of a competing replacement so load order
// cannot silently discard one feature.
@wrapMethod(DoubleJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(EquippedDecisions)
protected final const func ToUnequipCycle(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    let isDualEquipRequest = this.CheckSlotMatchAndCompareRequestType(stateContext, this.stateMachineInstanceData, this.stateMachineInitData, EquipmentManipulationRequestType.DualEquip);
    if this.IsLeftHandLogic(this.stateMachineInstanceData) && !isDualEquipRequest {
        let minActiveState = EnumInt(gamePSMLeftHandCyberware.Equipped);
        let maxActiveState = EnumInt(gamePSMLeftHandCyberware.CatchAction);
        let leftHandCyberwareState = scriptInterface.localBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.LeftHandCyberware);
        if leftHandCyberwareState >= minActiveState && leftHandCyberwareState <= maxActiveState {
            return false;
        }
    }

    return wrappedMethod(stateContext, scriptInterface);
}

@replaceMethod(TimeDilationFocusModeDecisions)
protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if !this.IsInVisionModeActiveState(stateContext, scriptInterface) {
        if this.IsTimeDilationActive(stateContext, scriptInterface, TimeDilationHelper.GetFocusModeKey()) {
            let timeSystem = scriptInterface.GetTimeSystem();
            let easeOutCurve = TweakDBInterface.GetCName(t"timeSystem.focusModeTimeDilation.easeOutCurve", n"");
            let applyTimeDilationToPlayer = TweakDBInterface.GetBool(t"timeSystem.focusModeTimeDilation.applyTimeDilationToPlayer", false);

            timeSystem.UnsetTimeDilation(TimeDilationHelper.GetFocusModeKey(), easeOutCurve);

            if applyTimeDilationToPlayer {
                timeSystem.UnsetTimeDilationOnLocalPlayerZero(TimeDilationHelper.GetFocusModeKey(), easeOutCurve);

                if this.IsTimeDilationActive(stateContext, scriptInterface, TimeDilationHelper.GetSandevistanKey()) {
                    timeSystem.SetTimeDilationOnLocalPlayerZero(TimeDilationHelper.GetSandevistanKey(), 1.0, 999.0, n"", n"");
                }
            }
        }
        return false;
    }

    if this.IsPlayerInBraindance(scriptInterface) {
        return false;
    }

    if !this.ShouldActivate(stateContext, scriptInterface) {
        return false;
    }

    if this.IsTimeDilationActive(stateContext, scriptInterface, TimeDilationHelper.GetSandevistanKey()) {
        if !this.IsTimeDilationActive(stateContext, scriptInterface, TimeDilationHelper.GetFocusModeKey()) {
            let timeSystem = scriptInterface.GetTimeSystem();
            let timeDilation = TweakDBInterface.GetFloat(t"timeSystem.focusModeTimeDilation.timeDilation", 0.0);
            let playerDilation = TweakDBInterface.GetFloat(t"timeSystem.focusModeTimeDilation.playerTimeDilation", 0.0);
            let easeInCurve = TweakDBInterface.GetCName(t"timeSystem.focusModeTimeDilation.easeInCurve", n"");
            let easeOutCurve = TweakDBInterface.GetCName(t"timeSystem.focusModeTimeDilation.easeOutCurve", n"");
            let applyTimeDilationToPlayer = TweakDBInterface.GetBool(t"timeSystem.focusModeTimeDilation.applyTimeDilationToPlayer", false);

            timeSystem.SetTimeDilation(TimeDilationHelper.GetFocusModeKey(), timeDilation, 999.0, easeInCurve, easeOutCurve);

            if applyTimeDilationToPlayer {
                timeSystem.SetTimeDilationOnLocalPlayerZero(TimeDilationHelper.GetFocusModeKey(), playerDilation, 999.0, easeInCurve, easeOutCurve);
            }
        }

        return false;
    }

    return this.GetBoolFromTimeSystemTweak("focusModeTimeDilation", "enableTimeDilation");
}

@replaceMethod(ChargedHotkeyItemCyberwareController)
protected func UpdateCurrentItem() {
    let cyberwareType = this.GetRootWidget().GetName();

    let playerData = this.m_equipmentSystem.GetPlayerData(this.GetPlayerControlledObject());
    let activeItemID = playerData.GetTaggedItem(gamedataEquipmentArea.SystemReplacementCW, cyberwareType);
    
    if ItemID.IsValid(activeItemID) {
        let previousItem = this.m_currentItem;
        
        this.m_currentItem = this.m_inventoryManager.GetInventoryItemDataFromItemID(activeItemID);
        this.m_currentItem.Quantity = 0;

        this.m_hotkeyItemController.Setup(this.m_currentItem, ItemDisplayContext.DPAD_RADIAL);
        this.ResolveState();
        
        if previousItem.ID != this.m_currentItem.ID {
            this.UpdateStatListener();
            this.UpdateChargeValue(
                this.GetStatPoolCurrentValue(this.m_currentStatPoolType, true),
                this.GetStatPoolMaxPoints(this.m_currentStatPoolType) / 100.00,
                false
            );
        }

        switch this.GetItemType(this.m_currentItem.ID, n"None") {
            case this.c_cyberdeckKey:
                this.GetRootWidget().SetVisible(this.IsCyberdeckOverloadPerkPresent());
                break;
            case this.c_sandevistanKey:
                this.UpdateSandevistanVisibility();
                break;
            case this.c_berserkKey:
                this.GetRootWidget().SetVisible(Equals(PlayerPuppet.GetCurrentVehicleState(this.GetPlayer()), gamePSMVehicle.Default));
                break;
            case this.c_capacityBoosterKey:
                this.GetRootWidget().SetVisible(false);
                break;
            default:
                this.GetRootWidget().SetVisible(true);
        }
    } else {
        this.m_currentItem = this.m_inventoryManager.GetInventoryItemDataFromItemID(ItemID.None());
        this.m_hotkeyItemController.Setup(this.m_currentItem, ItemDisplayContext.DPAD_RADIAL);
        this.GetRootWidget().SetVisible(false);
    }
}

@replaceMethod(CyberwareInventoryMiniGrid)
public final func GetSlotToEquipe(itemID: ItemID) -> Int32 {
    let equipArea = this.GetEquipmentArea();
    let cyberwareType = TweakDBInterface.GetCName(ItemID.GetTDBID(itemID) + t".cyberwareType", n"None");

    // If the user explicitly selected an unlocked empty slot, equip directly into it
    let i = 0;
    while i < ArraySize(this.m_gridData) {
        if this.m_gridData[i].GetSlotIndex() == this.m_selectedSlotIndex && !this.m_gridData[i].IsLocked() && !IsDefined(this.m_gridData[i].GetUIInventoryItem()) {
            if !Equals(equipArea, gamedataEquipmentArea.SystemReplacementCW) {
                return this.m_selectedSlotIndex;
            }
        }
        i += 1;
    }

    let slotIndex = ArraySize(this.m_gridData) - 1;
    let emptyIndex = -1;
    let matchingTypeIndex = -1;
    while slotIndex >= 0 {
        if !this.m_gridData[slotIndex].IsLocked() {
            if !IsDefined(this.m_gridData[slotIndex].GetUIInventoryItem()) {
                emptyIndex = this.m_gridData[slotIndex].GetSlotIndex();
            } else {
                let equippedType = TweakDBInterface.GetCNameDefault(this.m_gridData[slotIndex].GetUIInventoryItem().GetTweakDBID() + t".cyberwareType");
                if Equals(cyberwareType, equippedType) {
                    matchingTypeIndex = this.m_gridData[slotIndex].GetSlotIndex();
                    if Equals(equipArea, gamedataEquipmentArea.SystemReplacementCW) {
                        return matchingTypeIndex;
                    }
                }
            }
        }
        slotIndex -= 1;
    }
    if emptyIndex != -1 {
        return emptyIndex;
    }
    if matchingTypeIndex != -1 {
        return matchingTypeIndex;
    }
    return this.m_selectedSlotIndex != -1 ? this.m_selectedSlotIndex : 0;
}

@replaceMethod(gameuiInventoryGameController)
private final func RefreshPlayerCyberware() {
    let player = this.GetPlayerControlledObject();
    let playerData = EquipmentSystem.GetData(player);

    let cyberwareAreas: array<gamedataEquipmentArea>;
    ArrayPush(cyberwareAreas, gamedataEquipmentArea.SystemReplacementCW);
    ArrayPush(cyberwareAreas, gamedataEquipmentArea.ArmsCW);
    ArrayPush(cyberwareAreas, gamedataEquipmentArea.HandsCW);

    let maxSlotWidgets = 3;
    let requiredSlotWidgets = 0;

    ArrayClear(this.m_cyberwareItems);
    let dummyItems: array<InventoryItemData>;

    let i = 0;
    while i < ArraySize(cyberwareAreas) {
        let areaIndex = playerData.GetEquipAreaIndex(cyberwareAreas[i]);
        let slotIndex = 0;
        let numberOfSlots = ArraySize(playerData.m_equipment.equipAreas[areaIndex].equipSlots);
        while slotIndex < numberOfSlots {
            let itemID = playerData.m_equipment.equipAreas[areaIndex].equipSlots[slotIndex].itemID;
            if ItemID.IsValid(itemID) {
                let itemData = this.m_InventoryManager.GetItemDataFromIDInLoadout(itemID);
                let abilities: array<InventoryItemAbility>;
                let attachments: array<ref<InventoryItemAttachments>>;
                this.m_InventoryManager.GetAttachements(player, itemID, itemData.GameItemData, attachments, abilities, false);
                if ArraySize(attachments) > 0 {
                    ArrayPush(this.m_cyberwareItems, itemData);
                    requiredSlotWidgets = ArraySize(this.m_cyberwareItems);
                    if requiredSlotWidgets == maxSlotWidgets {
                        break;
                    }
                } else {
                    ArrayPush(dummyItems, itemData);
                }
            }
            slotIndex += 1;
        }
        i += 1;
    }

    i = 0;
    while requiredSlotWidgets < maxSlotWidgets && i < ArraySize(dummyItems) {
        ArrayPush(this.m_cyberwareItems, dummyItems[i]);
        requiredSlotWidgets += 1;
        i += 1;
    }

    inkCompoundRef.RemoveAllChildren(this.m_cyberwareSlotRootRefs);
    inkWidgetRef.SetVisible(this.m_cyberwareHolder, requiredSlotWidgets > 0);

    if requiredSlotWidgets > 0 {
        i = 0;
        while i < requiredSlotWidgets {
            let slotSpawnData = new CyberwareSlotSpawnData();
            slotSpawnData.index = i;
            ItemDisplayUtils.SpawnCommonSlotAsync(this, this.m_cyberwareSlotRootRefs, n"itemDisplay", n"OnSlotSpawned", slotSpawnData);
            i += 1;
        }
    }
}

@replaceMethod(gameuiInventoryGameController)
protected cb func OnSlotSpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    if !IsDefined(widget) {
        return false;
    }
    let controller = widget.GetController() as InventoryItemDisplayController;
    let data = userData as CyberwareSlotSpawnData;
    if !IsDefined(controller) || !IsDefined(data) || data.index < 0 || data.index >= ArraySize(this.m_cyberwareItems) {
        return false;
    }
    let itemData = this.m_cyberwareItems[data.index];
    controller.Setup(itemData, InventoryItemData.GetEquipmentArea(itemData), "", InventoryItemData.GetSlotIndex(itemData));
    return true;
}

@replaceMethod(healthbarWidgetGameController)
protected final const func IsCyberdeckEquipped() -> Bool {
    return CyberwareHelper.IsCyberdeckEquipped(this.GetPlayerControlledObject());
}

@wrapMethod(HotkeyConsumableWidgetController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();

    let container = inkWidgetRef.Get(this.m_container) as inkCompoundWidget;
    if IsDefined(container) && container.GetNumChildren() > 0 {
        let widget = container.GetWidgetByIndex(container.GetNumChildren() - 1);
        if IsDefined(widget) { widget.SetName(n"Sandevistan"); }
    }
    return result;
}

@wrapMethod(HotkeysWidgetController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();

    this.FixHudSlotSize();
    this.SpawnCyberwareExtraSlots();
    return result;
}

@addMethod(HotkeysWidgetController)
protected func SpawnCyberwareExtraSlots() {
    let container = inkWidgetRef.Get(this.m_dpadHintsPanel) as inkCompoundWidget;
    if !IsDefined(container) { return; }

    let cyberwarePos = 0;
    let cyberwareWidget: wref<inkWidget>;
    let numWidgets = container.GetNumChildren();
    while cyberwarePos < container.GetNumChildren() {
        cyberwareWidget = container.GetWidgetByIndex(cyberwarePos);
        if IsDefined(cyberwareWidget) && Equals(cyberwareWidget.GetName(), n"cyberware") {
            break;
        }

        cyberwarePos += 1;
    }

    if cyberwarePos >= numWidgets {
        return;
    }

    let cyberwares = [cyberwareWidget];
    ArrayPush(cyberwares, this.SpawnFromLocal(container, n"cyberware"));
    ArrayPush(cyberwares, this.SpawnFromLocal(container, n"cyberware"));

    let i = 0;
    let cyberwareTypes = [n"Cyberdeck", n"Sandevistan", n"Berserk"];
    while i < ArraySize(cyberwareTypes) {
        if IsDefined(cyberwares[i]) { cyberwares[i].SetName(cyberwareTypes[i]); }
        if i >= 1 {
            container.ReorderChild(cyberwares[i], cyberwarePos + i);
        }
        i += 1;
    }

}

@if(ModuleExists("CustomQuickslots"))
@addMethod(HotkeysWidgetController)
protected func FixHudSlotSize() {}

@if(!ModuleExists("CustomQuickslots"))
@addMethod(HotkeysWidgetController)
protected func FixHudSlotSize() {
    let root = this.GetRootWidget();
    if !IsDefined(root) { return; }
    let hudEntryInfo = root.GetUserData(n"inkHudEntryInfo") as inkHudEntryInfo;
    if IsDefined(hudEntryInfo) { hudEntryInfo.size = Vector2(2400, 300); }
}

@wrapMethod(InventoryItemDisplayController)
public final func SetPerkRequiredCyberware(area: gamedataEquipmentArea) {
    wrappedMethod(area);

    let perkRecord = CyberwareHelper.GetRequiredPerkRecord(this.m_equipmentArea, this.m_slotIndex);
    if IsDefined(perkRecord) {
        inkImageRef.SetTexturePart(this.m_perkIcon, perkRecord.PerkIcon().AtlasPartName());
    }
}

@wrapMethod(InventoryItemDisplayController)
protected func UpdateLocked() {
    wrappedMethod();

    let root = this.GetRootWidget();
    if IsDefined(root) { root.SetVisible(!this.m_isLocked || this.m_visibleWhenLocked); }
}

@wrapMethod(ItemDisplayUtils)
public final static func SpawnCommonSlotAsync(logicController: ref<inkLogicController>, parent: inkWidgetRef,
                                              slotName: CName, opt callBack: CName, opt userData: ref<IScriptable>) {
    let slotUserData = userData as SlotUserData;
    if IsDefined(slotUserData) && slotUserData.isLocked {
        slotUserData.isPerkRequired = CyberwareHelper.IsPerkRequired(slotUserData.area, slotUserData.index);
    }
    wrappedMethod(logicController, parent, slotName, callBack, userData);
}

@wrapMethod(QuickhacksListGameController)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if !this.m_isUILocked && !this.GetPlayerControlledObject().GetHudManager().IsHackingMinigameActive() {
        if ListenerAction.IsButtonJustReleased(action) && ListenerAction.IsAction(action, n"context_help") {
            if QuickHackableHelper.TryToCycleOverclockedState(this.GetPlayerControlledObject()) {
                let dpadAction = new DPADActionPerformed();
                dpadAction.action = EHotkey.LBRB;
                dpadAction.state = EUIActionState.COMPLETED;
                dpadAction.successful = true;

                GameInstance.GetUISystem(this.GetPlayerControlledObject().GetGame()).QueueEvent(dpadAction);
            }

            return false;
        }
    }

    return wrappedMethod(action, consumer);
}

@replaceMethod(QuickhacksListGameController)
private final func ToggleTutorialOverlay() {
}

@if(!ModuleExists("CyberarmOverhaul"))
@replaceMethod(RadialWheelController)
private final func GetValidCombatCyberware() -> InventoryItemData {
    let player = this.GetPlayer();
    let itemID = EquipmentSystem.GetData(player).GetActiveMeleeWare();
    let itemData: InventoryItemData;

    if ItemID.IsValid(itemID) {
        itemData = this.inventoryManager.GetItemDataFromIDInLoadout(itemID);
    }

    return itemData;
}

@wrapMethod(RipperDocGameController)
private final func Init() {
    wrappedMethod();

    let text = new inkText();
    text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    text.SetFontStyle(n"Regular");
    text.SetFontSize(28);
    text.SetOpacity(0.1);
    text.SetAnchor(inkEAnchor.TopRight);
    text.SetAnchorPoint(Vector2(1.0, 0.0));
    text.SetMargin(inkMargin(0, 160, 100, 0));
    text.SetHorizontalAlignment(textHorizontalAlignment.Left);
    text.SetVerticalAlignment(textVerticalAlignment.Top);
    text.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    text.BindProperty(n"tintColor", n"MainColors.Red");
    text.SetText(s"POWERED BY CYBERWARE-EX \(CyberwareEx.Version())");
    text.Reparent(this.GetRootCompoundWidget());
}

@wrapMethod(RipperDocGameController)
protected cb func OnSlotClick(evt: ref<ItemDisplayClickEvent>) -> Bool {
    if !IsDefined(evt) {
        return false;
    }
    if this.m_isActivePanel && IsDefined(evt.uiInventoryItem) && Equals(this.m_hoverArea, gamedataEquipmentArea.EyesCW) {
        if evt.actionName.IsAction(n"unequip_item") && evt.uiInventoryItem.IsEquipped() {
            this.m_isInEquipPopup = true;
            this.UnequipCyberware(evt.uiInventoryItem.GetItemData());
            return false;
        }
    }

    return wrappedMethod(evt);
}

@addField(RipperDocGameController)
private let m_overrideManager: ref<OverrideManager>;

@addField(RipperDocGameController)
private let m_overrideConfirmationToken: ref<inkGameNotificationToken>;

@wrapMethod(RipperDocGameController)
private final func Init() {
    wrappedMethod();

    this.m_overrideManager = new OverrideManager();
    this.m_overrideManager.Initialize(EquipmentSystem.GetData(this.m_player));
}

@wrapMethod(RipperDocGameController)
protected cb func OnSlotHover(evt: ref<ItemDisplayHoverOverEvent>) -> Bool {
    if !IsDefined(evt) || !IsDefined(evt.display) {
        return false;
    }
    this.m_hoveredItemDisplay = evt.display;
    let result: Bool = wrappedMethod(evt);

    if Equals(this.m_screen, CyberwareScreenType.Ripperdoc) {

        if Equals(this.m_filterMode, RipperdocModes.Default) && IsDefined(this.m_overrideManager) {
            let overrideState = this.m_overrideManager.GetOverrideState(evt.display.GetEquipmentArea());
            if overrideState.isOverridable {

                if overrideState.currentSlots != overrideState.defaultSlots {
                    this.m_buttonHintsController.AddButtonHint(n"disassemble_item",
                        GetLocalizedText("LocKey#53485") + ": " +
                        GetLocalizedTextByKey(n"UI-ResourceExports-Reset"));
                }

                if overrideState.currentSlots < overrideState.maxSlots {
                    this.m_buttonHintsController.AddButtonHint(n"drop_item",
                        GetLocalizedText("LocKey#53485") + ": " +
                        GetLocalizedTextByKey(n"UI-ResourceExports-Buy"));
                }
            }
        }

    }
    return result;
}

@wrapMethod(RipperDocGameController)
private final func SetButtonHintsUnhover() {
    wrappedMethod();

    this.m_buttonHintsController.RemoveButtonHint(n"drop_item");
}

@wrapMethod(RipperDocGameController)
protected cb func OnPreviewCyberwareClick(evt: ref<inkPointerEvent>) -> Bool {
    if !IsDefined(evt) {
        return false;
    }
    let result: Bool = wrappedMethod(evt);

    let slotController = this.GetCyberwareSlotControllerFromTarget(evt);
    if Equals(this.m_screen, CyberwareScreenType.Ripperdoc) && Equals(this.m_filterMode, RipperdocModes.Default)
        && IsDefined(this.m_overrideManager) && IsDefined(slotController) {
        let areaType = slotController.GetEquipmentArea();
        let overrideState = this.m_overrideManager.GetOverrideState(areaType);

        switch (true) {
            case evt.IsAction(n"drop_item"):
                if overrideState.currentSlots < overrideState.maxSlots {
                    if overrideState.canBuyOverride {
                        this.m_overrideConfirmationToken = OverrideConfirmationPopup.Show(this, OverrideAction.Upgrade, overrideState);
                        this.m_overrideConfirmationToken.RegisterListener(this, n"OnSlotUpgradeConfirmed");
                    } else {
                        this.ShowNotEnoughMoneyNotification();
                    }
                }
                break;
            case evt.IsAction(n"disassemble_item"):
                if overrideState.currentSlots != overrideState.defaultSlots {
                    if overrideState.canBuyReset {
                        this.m_overrideConfirmationToken = OverrideConfirmationPopup.Show(this, OverrideAction.Reset, overrideState);
                        this.m_overrideConfirmationToken.RegisterListener(this, n"OnSlotResetConfirmed");
                    } else {
                        this.ShowNotEnoughMoneyNotification();
                    }
                }
                break;
        }
    }
    return result;
}

@addMethod(RipperDocGameController)
protected func ShowNotEnoughMoneyNotification() {
    let notification = new UIMenuNotificationEvent();
    notification.m_notificationType = UIMenuNotificationType.VNotEnoughMoney;

    this.QueueEvent(notification);
}

@addMethod(RipperDocGameController)
protected cb func OnSlotUpgradeConfirmed(data: ref<inkGameNotificationData>) -> Bool {
    if OverrideConfirmationPopup.IsConfirmed(data) {
        let areaType = OverrideConfirmationPopup.GetAreaType(data);
        let vendor = NotEquals(this.m_VendorDataManager.GetVendorName(), "")
            ? this.m_VendorDataManager.GetVendorInstance()
            : null;

        this.m_overrideManager.UpgradeSlot(areaType, false, vendor);

        this.UpdateMinigrids();
        this.UpdateMoney();
    }

    this.m_overrideConfirmationToken = null;
    return true;
}

@addMethod(RipperDocGameController)
protected cb func OnSlotResetConfirmed(data: ref<inkGameNotificationData>) -> Bool {
    if OverrideConfirmationPopup.IsConfirmed(data) {
        let areaType = OverrideConfirmationPopup.GetAreaType(data);
        let vendor = NotEquals(this.m_VendorDataManager.GetVendorName(), "")
            ? this.m_VendorDataManager.GetVendorInstance()
            : null;

        this.m_overrideManager.ResetSlot(areaType, false, vendor);

        this.UpdateMinigrids();
        this.UpdateMoney();
    }

    this.m_overrideConfirmationToken = null;
    return true;
}

@replaceMethod(RipperDocGameController)
private final func IsEquipmentAreaRequiringPerk(equipmentArea: gamedataEquipmentArea) -> Bool {
    return false;
}

@addMethod(RipperDocGameController)
private final func UpdateMoney() {
    let blackBoardDef = GetAllBlackboardDefs().UI_Vendor;
    let blackBoard = GameInstance.GetBlackboardSystem(this.GetPlayerControlledObject().GetGame()).Get(blackBoardDef);
    blackBoard.SignalVariant(blackBoardDef.VendorData);
}

@wrapMethod(RipperdocMetersArmor)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();

    if IsExtendedMode() || IsOverrideMode() || IsCustomMode() {
        let root = this.GetRootWidget();
        if !IsDefined(root) { return result; }

        let margin = root.GetMargin();
        margin.right = 370;
        root.SetMargin(margin);
    }
    return result;
}

@wrapMethod(RipperdocMetersArmor)
protected cb func OnIntroAnimationFinished_METER(proxy: ref<inkAnimProxy>) -> Bool {
    let result: Bool = wrappedMethod(proxy);

    if IsExtendedMode() || IsOverrideMode() || IsCustomMode() {
        let root = this.GetRootWidget();
        if !IsDefined(root) || !IsDefined(root.parentWidget) { return result; }
        let parent = root.parentWidget as inkCompoundWidget;
        if !IsDefined(parent) { return result; }
        let wrapper = parent.GetWidget(n"wrapper") as inkCompoundWidget;
        if !IsDefined(wrapper) { return result; }

        let oldIndex = ArrayFindFirst(parent.children.children, root);
        let newIndex = ArrayFindFirst(wrapper.children.children, wrapper.GetWidget(n"paperDollWrapper")) + 1;
        if newIndex < 0 { return result; }
        root.Reparent(wrapper, newIndex);

        let dummy = new inkCanvas();
        parent.AddChildWidget(dummy);
        parent.ReorderChild(dummy, oldIndex);
    }
    return result;
}

@wrapMethod(RipperdocMetersCapacity)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();

    if IsExtendedMode() || IsOverrideMode() || IsCustomMode() {
        let root = this.GetRootWidget();
        if !IsDefined(root) { return result; }

        let margin = root.GetMargin();
        margin.left = 240;
        root.SetMargin(margin);
    }
    return result;
}

@wrapMethod(RipperdocMetersCapacity)
protected cb func OnIntroAnimationFinished_METER(proxy: ref<inkAnimProxy>) -> Bool {
    let result: Bool = wrappedMethod(proxy);

    if IsExtendedMode() || IsOverrideMode() || IsCustomMode() {
        let root = this.GetRootWidget();
        if !IsDefined(root) || !IsDefined(root.parentWidget) { return result; }
        let parent = root.parentWidget as inkCompoundWidget;
        if !IsDefined(parent) { return result; }
        let wrapper = parent.GetWidget(n"wrapper") as inkCompoundWidget;
        if !IsDefined(wrapper) { return result; }

        let oldIndex = ArrayFindFirst(parent.children.children, root);
        let newIndex = ArrayFindFirst(wrapper.children.children, wrapper.GetWidget(n"paperDollWrapper")) + 1;
        if newIndex < 0 { return result; }
        root.Reparent(wrapper, newIndex);

        let dummy = new inkCanvas();
        parent.AddChildWidget(dummy);
        parent.ReorderChild(dummy, oldIndex);
    }
    return result;
}

@wrapMethod(RipperdocMetersCapacity)
private final func ConfigureBar(currentCapacity: Int32, addedCapacity: Int32, maxCapacity: Int32, overclockCapacity: Int32, isChange: Bool) {
    let finalCapacity = currentCapacity + addedCapacity;
    if (finalCapacity > Cast<Int32>(this.m_maxCapacityPossible)) {
        this.m_maxCapacityPossible = Cast<Float>(finalCapacity);
    }

    wrappedMethod(currentCapacity, addedCapacity, maxCapacity, overclockCapacity, isChange);
}

@addField(RipperdocPerkTooltipData)
public let equipArea: gamedataEquipmentArea;

@addField(RipperdocPerkTooltipData)
public let slotIndex: Int32;

@wrapMethod(RipperdocPerkTooltip)
public func SetData(tooltipData: ref<ATooltipData>) {
    let perkTooltipData = tooltipData as RipperdocPerkTooltipData;
    if !IsDefined(perkTooltipData) {
        wrappedMethod(tooltipData);
        return;
    }
    let perkRecord = CyberwareHelper.GetRequiredPerkRecord(perkTooltipData.equipArea, perkTooltipData.slotIndex);
    if IsDefined(perkRecord) {
        let requiredLevel = CyberwareHelper.GetRequiredPerkLevel(perkTooltipData.equipArea, perkTooltipData.slotIndex);
        let maxLevel = CyberwareHelper.GetRequiredPerkMaxLevel(perkTooltipData.equipArea, perkTooltipData.slotIndex);
        let requirementLabel = GetLocalizedText(perkRecord.Loc_name_key());
        if maxLevel > 1 {
            requirementLabel += s"\n(\(GetLocalizedItemNameByCName(n"Gameplay-RPG-Skills-LevelName")) \(requiredLevel))";
        }
        inkTextRef.SetText(this.m_perkName, requirementLabel);
        inkImageRef.SetTexturePart(this.m_perkIcon, perkRecord.PerkIcon().AtlasPartName());
    } else {
        wrappedMethod(tooltipData);
    }
}
