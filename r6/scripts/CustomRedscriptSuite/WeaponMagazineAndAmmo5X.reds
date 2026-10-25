// WeaponMagazineAndAmmo5X:
// 1. Keeps weapon magazine capacity unchanged (1x vanilla) and actively strips any
//    previously saved MagazineCapacityBase modifiers from existing save-game weapons.
// 2. Increases max reserve/backup ammo capacity by 10x+ (surpassing 999 across all ammo
//    types: 9,000 Handgun, 9,000 Rifle, 1,500 Shotgun, 1,200 Sniper) at both the TweakDB
//    record level (Ammo.*_inline0.value) and the per-item gameItemData level.
// 3. Removes the "999+" / "9999+" UI display clamps on weapon cards and ammo stacks in
//    InventoryItemDisplayController, and ensures Crafting and Vendor ammo cap checks
//    use the 10x reserve ammo limits.

module WeaponMagazineAndAmmo5X

public class AmmoCapacity10XTweak extends ScriptableTweak {

  protected cb func OnApply() -> Void {
    WeaponMagazineAndAmmo5XHelper.ApplyAmmoTweakDBRecords();
  }
}

public class WeaponMagazineAndAmmo5XHelper {

  public final static func GetTargetAmmoCap(ammoTDBID: TweakDBID) -> Float {
    switch ammoTDBID {
      case t"Ammo.HandgunAmmo":
        // Vanilla: 1 + 899 = 900 -> 10x = 9,000
        return 9000.00;
      case t"Ammo.RifleAmmo":
        // Vanilla: 1 + 899 = 900 -> 10x = 9,000
        return 9000.00;
      case t"Ammo.ShotgunAmmo":
        // Vanilla: 1 + 100 = 101 -> 15x = 1,500 (surpasses 999)
        return 1500.00;
      case t"Ammo.SniperRifleAmmo":
        // Vanilla: 1 + 75 = 76 -> ~16x = 1,200 (surpasses 999)
        return 1200.00;
      default:
        return 9000.00;
    };
  }

  public final static func ApplyAmmoTweakDBRecords() -> Void {
    // BaseStats.Quantity on every item starts at 1.0, and Ammo.*_inline0 is an
    // Additive ConstantStatModifier on BaseStats.Quantity.
    TweakDBManager.SetFlat(t"Ammo.HandgunAmmo_inline0.value", 8999.00);
    TweakDBManager.UpdateRecord(t"Ammo.HandgunAmmo_inline0");
    TweakDBManager.UpdateRecord(t"Ammo.HandgunAmmo");

    TweakDBManager.SetFlat(t"Ammo.RifleAmmo_inline0.value", 8999.00);
    TweakDBManager.UpdateRecord(t"Ammo.RifleAmmo_inline0");
    TweakDBManager.UpdateRecord(t"Ammo.RifleAmmo");

    TweakDBManager.SetFlat(t"Ammo.ShotgunAmmo_inline0.value", 1499.00);
    TweakDBManager.UpdateRecord(t"Ammo.ShotgunAmmo_inline0");
    TweakDBManager.UpdateRecord(t"Ammo.ShotgunAmmo");

    TweakDBManager.SetFlat(t"Ammo.SniperRifleAmmo_inline0.value", 1199.00);
    TweakDBManager.UpdateRecord(t"Ammo.SniperRifleAmmo_inline0");
    TweakDBManager.UpdateRecord(t"Ammo.SniperRifleAmmo");
  }

  public final static func RestoreVanillaWeaponMagazine(game: GameInstance, itemData: ref<gameItemData>) -> Void {
    if !IsDefined(itemData) || !RPGManager.IsItemWeapon(itemData.GetID()) {
      return;
    };
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return;
    };
    let statsId: StatsObjectID = itemData.GetStatsObjectID();
    // Strip any saved MagazineCapacityBase modifiers baked into existing save-game weapons
    // so weapon magazine capacity returns to authentic 1x vanilla values.
    stats.RemoveSavedModifiers(statsId, gamedataStatType.MagazineCapacityBase);
  }

  public final static func ApplyAmmoCapacity(game: GameInstance, itemData: ref<gameItemData>) -> Void {
    if !IsDefined(itemData) {
      return;
    };
    let itemID: ItemID = itemData.GetID();
    let itemTDBID: TweakDBID = ItemID.GetTDBID(itemID);
    let itemRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(itemTDBID);
    let isAmmo: Bool = itemData.HasTag(n"Ammo")
      || Equals(itemData.GetItemType(), gamedataItemType.Con_Ammo)
      || (IsDefined(itemRecord) && itemRecord.TagsContains(n"Ammo"));
    if !isAmmo {
      return;
    };

    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return;
    };
    let statsId: StatsObjectID = itemData.GetStatsObjectID();
    let targetCap: Float = WeaponMagazineAndAmmo5XHelper.GetTargetAmmoCap(itemTDBID);

    // Clear any previously saved Quantity modifiers so we never double-stack across loads.
    stats.RemoveSavedModifiers(statsId, gamedataStatType.Quantity);

    let currentCap: Float = itemData.GetStatValueByType(gamedataStatType.Quantity);
    if currentCap < targetCap - 0.50 {
      let delta: Float = targetCap - currentCap;
      let modifier: ref<gameStatModifierData> = RPGManager.CreateStatModifier(
        gamedataStatType.Quantity,
        gameStatModifierType.Additive,
        delta
      );
      stats.AddSavedModifier(statsId, modifier);
      if itemData.GetStatValueByType(gamedataStatType.Quantity) < targetCap - 0.50 {
        stats.AddModifier(statsId, modifier);
      };
    };
  }

  public final static func ApplyInventory(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    };
    let game: GameInstance = player.GetGame();
    WeaponMagazineAndAmmo5XHelper.ApplyAmmoTweakDBRecords();

    let transaction: ref<TransactionSystem> = GameInstance.GetTransactionSystem(game);
    if !IsDefined(transaction) {
      return;
    };
    let items: array<wref<gameItemData>>;
    transaction.GetItemList(player, items);
    let i: Int32 = 0;
    while i < ArraySize(items) {
      let itemData: ref<gameItemData> = items[i];
      if IsDefined(itemData) {
        WeaponMagazineAndAmmo5XHelper.RestoreVanillaWeaponMagazine(game, itemData);
        WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(game, itemData);
      };
      i += 1;
    };
  }
}

@wrapMethod(PlayerPuppet)
private final func SetIconicWeaponsTier(itemData: ref<gameItemData>) -> Void {
  wrappedMethod(itemData);
  WeaponMagazineAndAmmo5XHelper.RestoreVanillaWeaponMagazine(this.GetGame(), itemData);
}

@wrapMethod(PlayerPuppet)
protected cb func OnMakePlayerVisibleAfterSpawn(evt: ref<EndGracePeriodAfterSpawn>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  WeaponMagazineAndAmmo5XHelper.ApplyInventory(this);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let itemData: ref<gameItemData> = evt.itemData;
  WeaponMagazineAndAmmo5XHelper.RestoreVanillaWeaponMagazine(this.GetGame(), itemData);
  WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(this.GetGame(), itemData);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemChangedEvent(evt: ref<ItemChangedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let itemData: ref<gameItemData> = evt.itemData;
  WeaponMagazineAndAmmo5XHelper.RestoreVanillaWeaponMagazine(this.GetGame(), itemData);
  WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(this.GetGame(), itemData);
  return result;
}

// Ensure Crafting System ammo cap checks (which use DryMakeItem preview gameItemData)
// always evaluate against the 10x ammo capacity.
@wrapMethod(CraftingSystem)
public final const func CanItemBeCrafted(itemData: wref<gameItemData>) -> Bool {
  if IsDefined(itemData) {
    WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(this.GetGameInstance(), itemData);
  };
  return wrappedMethod(itemData);
}

@wrapMethod(CraftingSystem)
public final const func GetMaxCraftingAmount(itemData: wref<gameItemData>) -> Int32 {
  if IsDefined(itemData) {
    WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(this.GetGameInstance(), itemData);
  };
  return wrappedMethod(itemData);
}

// Ensure Vendor ammo purchase quantity picker (which checks the vendor's UIInventoryItem)
// always evaluates against the 10x ammo capacity.
@wrapMethod(FullscreenVendorGameController)
private final func GetMaxQuantity(item: wref<UIInventoryItem>, opt isPlayerItem: Bool, opt isBuybackStack: Bool) -> Int32 {
  if IsDefined(item) && IsDefined(item.GetItemData()) && IsDefined(this.m_VendorDataManager) && IsDefined(this.m_VendorDataManager.GetVendorInstance()) {
    let game: GameInstance = this.m_VendorDataManager.GetVendorInstance().GetGame();
    WeaponMagazineAndAmmo5XHelper.ApplyAmmoCapacity(game, item.GetItemData());
  };
  return wrappedMethod(item, isPlayerItem, isBuybackStack);
}

// Remove the hardcoded "999+" clamp on weapon cards and "9999+" clamp on ammo stacks in Inventory UI.
@wrapMethod(InventoryItemDisplayController)
protected func NewUpdateQuantity(itemData: ref<UIInventoryItem>) -> Void {
  wrappedMethod(itemData);
  if itemData != null {
    let countTreshold: Int32 = Equals(this.m_itemDisplayContext, ItemDisplayContext.DPAD_RADIAL) ? 0 : 1;
    let quantity: Int32 = this.m_overrideQuantity > 0 ? this.m_overrideQuantity : itemData.GetQuantity();
    if quantity > countTreshold || Equals(itemData.GetItemType(), gamedataItemType.Con_Ammo) {
      if quantity > 9999 {
        inkTextRef.SetText(this.m_quantityText, IntToString(quantity));
      };
    } else {
      if itemData.IsWeapon() && NotEquals(itemData.GetWeaponType(), WeaponType.Melee) && !itemData.IsRecipe() {
        let ammo: Int32 = itemData.GetAmmo();
        if ammo > 999 {
          inkTextRef.SetText(this.m_quantityText, IntToString(ammo));
        };
      };
    };
  };
}

@wrapMethod(InventoryItemDisplayController)
protected func UpdateQuantity() -> Void {
  wrappedMethod();
  let itemInventory: InventoryItemData = this.GetItemData();
  if !InventoryItemData.IsEmpty(itemInventory) {
    let itemType: gamedataItemType = InventoryItemData.GetItemType(itemInventory);
    if Equals(this.m_itemDisplayContext, ItemDisplayContext.Crafting) && IsDefined(this.m_recipeData) && Equals(itemType, gamedataItemType.Con_Ammo) {
      return;
    };
    let countTreshold: Int32 = Equals(this.m_itemDisplayContext, ItemDisplayContext.DPAD_RADIAL) ? 0 : 1;
    let qty: Int32 = InventoryItemData.GetQuantity(itemInventory);
    if qty > countTreshold || Equals(itemType, gamedataItemType.Con_Ammo) {
      if qty > 9999 {
        inkTextRef.SetText(this.m_quantityText, IntToString(qty));
      };
    } else {
      if Equals(InventoryItemData.GetEquipmentArea(itemInventory), gamedataEquipmentArea.Weapon) && !InventoryItemData.GetGameItemData(itemInventory).HasTag(n"MeleeWeapon") {
        let ammo: Int32 = InventoryItemData.GetAmmo(itemInventory);
        if ammo > 999 {
          inkTextRef.SetText(this.m_quantityText, IntToString(ammo));
        };
      };
    };
  };
}

