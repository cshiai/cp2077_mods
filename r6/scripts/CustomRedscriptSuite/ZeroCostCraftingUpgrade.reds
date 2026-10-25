// ZeroCostCraftingUpgrade: dependency-free 0-material crafting/upgrading with standard 1x yield.
// Makes crafting items, upgrading weapons/iconic items, and upgrading cyberware
// at Ripperdocs require 0 crafting components while preserving Crafting Skill XP,
// and preserves the normal 1x crafting yield for both non-stackable gear and
// stackable items/ammo.

module ZeroCostCraftingUpgrade

@wrapMethod(CraftingSystem)
public final const func HasIngredients(const required: script_ref<array<IngredientData>>) -> Bool {
  return true;
}

@wrapMethod(CraftingSystem)
public final const func EnoughIngredientsForCrafting(itemData: wref<gameItemData>) -> Bool {
  return true;
}

@wrapMethod(CraftingSystem)
public final const func EnoughIngredientsForUpgrading(itemData: wref<gameItemData>) -> Bool {
  return true;
}

@wrapMethod(CraftingSystem)
public final const func GetItemCraftingCost(itemData: wref<gameItemData>) -> array<IngredientData> {
  let ingredients: array<IngredientData> = wrappedMethod(itemData);
  let i: Int32 = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].quantity = 0;
    i += 1;
  };
  return ingredients;
}

@wrapMethod(CraftingSystem)
public final const func GetItemCraftingCost(itemRecord: wref<Item_Record>) -> array<IngredientData> {
  let ingredients: array<IngredientData> = wrappedMethod(itemRecord);
  let i: Int32 = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].quantity = 0;
    i += 1;
  };
  return ingredients;
}

@wrapMethod(CraftingSystem)
public final const func GetItemCraftingCost(record: wref<Item_Record>, const craftingData: script_ref<array<wref<RecipeElement_Record>>>) -> array<IngredientData> {
  let ingredients: array<IngredientData> = wrappedMethod(record, craftingData);
  let i: Int32 = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].quantity = 0;
    i += 1;
  };
  return ingredients;
}

@wrapMethod(CraftingSystem)
public final const func GetItemBaseUpgradeCost(itemType: gamedataItemType, quality: gamedataQuality) -> array<IngredientData> {
  let ingredients: array<IngredientData> = wrappedMethod(itemType, quality);
  let i: Int32 = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].quantity = 0;
    i += 1;
  };
  return ingredients;
}

@wrapMethod(CraftingSystem)
public final const func GetItemFinalUpgradeCost(itemData: wref<gameItemData>) -> array<IngredientData> {
  let ingredients: array<IngredientData> = wrappedMethod(itemData);
  let i: Int32 = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].quantity = 0;
    i += 1;
  };
  return ingredients;
}

@wrapMethod(CraftingSystem)
public final const func GetMaxCraftingAmount(itemData: wref<gameItemData>) -> Int32 {
  let result: Int32 = wrappedMethod(itemData);
  if result > 0 {
    return result;
  };
  return 1;
}

@wrapMethod(CraftingSystem)
private final func CraftItem(target: wref<GameObject>, itemRecord: ref<Item_Record>, amount: Int32, opt ammoBulletAmount: Int32) -> wref<gameItemData> {
  let effectiveAmount: Int32 = Max(1, amount);
  return wrappedMethod(target, itemRecord, effectiveAmount, ammoBulletAmount);
}

@wrapMethod(RPGManager)
public static final func GetCyberwareUpgradeCost(itemRecord: ref<Item_Record>) -> Int32 {
  return 0;
}

@wrapMethod(RPGManager)
public static final func CanAffordAndPerformCyberwareUpgrade(owner: ref<GameObject>, currentQuality: gamedataQuality, upgradeItemRecord: ref<Item_Record>, out costData: CyberwareUpgradeCostData) -> Bool {
  let result: Bool = wrappedMethod(owner, currentQuality, upgradeItemRecord, costData);
  costData.materialCount = 0;
  return result || IsDefined(upgradeItemRecord);
}
