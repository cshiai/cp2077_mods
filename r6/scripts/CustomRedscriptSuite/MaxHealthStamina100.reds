// MaxHealthStamina100: dependency-free 2x max HP (+100%) and max stamina.
// Multiplier 2.0 doubles the vanilla Health stat while preserving
// perks, cyberware, and other additive modifiers. The modifiers are transient
// and are not written into save data.

module MaxHealthStamina100

@addField(PlayerPuppet)
private let maxHealthStamina100HealthModifier: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let maxHealthStamina100StaminaModifier: ref<gameStatModifierData>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.maxHealthStamina100HealthModifier) {
    this.maxHealthStamina100HealthModifier = RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Multiplier, 2.0);
    stats.AddModifier(id, this.maxHealthStamina100HealthModifier);
  };

  if !IsDefined(this.maxHealthStamina100StaminaModifier) {
    this.maxHealthStamina100StaminaModifier = RPGManager.CreateStatModifier(gamedataStatType.Stamina, gameStatModifierType.Multiplier, 2.0);
    stats.AddModifier(id, this.maxHealthStamina100StaminaModifier);
  };

  return result;
}
