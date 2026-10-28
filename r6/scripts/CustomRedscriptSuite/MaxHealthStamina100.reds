// MaxHealthStamina100: dependency-free 2x max HP (+100%) and max stamina.
// Multiplier 2.0 doubles the vanilla Health stat while preserving
// perks, cyberware, and other additive modifiers. The modifiers are transient
// and are not written into save data.

module MaxHealthStamina100

@addField(PlayerPuppet)
private let maxHealthStamina100HealthModifier: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let maxHealthStamina100StaminaModifier: ref<gameStatModifierData>;

@addMethod(PlayerPuppet)
private final func ApplyMaxHealthStamina100() -> Void {
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  if !IsDefined(stats) || !EntityID.IsDefined(this.GetEntityID()) {
    return;
  }
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.maxHealthStamina100HealthModifier) {
    this.maxHealthStamina100HealthModifier = RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Multiplier, 2.0);
  };
  if !IsDefined(this.maxHealthStamina100StaminaModifier) {
    this.maxHealthStamina100StaminaModifier = RPGManager.CreateStatModifier(gamedataStatType.Stamina, gameStatModifierType.Multiplier, 2.0);
  };
  if IsDefined(this.maxHealthStamina100HealthModifier) {
    stats.RemoveModifier(id, this.maxHealthStamina100HealthModifier);
    stats.AddModifier(id, this.maxHealthStamina100HealthModifier);
  };
  if IsDefined(this.maxHealthStamina100StaminaModifier) {
    stats.RemoveModifier(id, this.maxHealthStamina100StaminaModifier);
    stats.AddModifier(id, this.maxHealthStamina100StaminaModifier);
  };
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.ApplyMaxHealthStamina100();
  return result;
}

@wrapMethod(PlayerPuppet)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
  wrappedMethod(playerPuppet);
  this.ApplyMaxHealthStamina100();
}

@wrapMethod(PlayerPuppet)
protected func OnResurrected() -> Void {
  wrappedMethod();
  this.ApplyMaxHealthStamina100();
}
