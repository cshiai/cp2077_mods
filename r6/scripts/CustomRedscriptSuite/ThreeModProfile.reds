// ThreeModProfile: dependency-free no-carry-limit replacement.
// The +9000 transient StatsSystem modifier replaces the original TweakXL YAML.
// It is not saved to the save file and is deliberately finite but practically unlimited.

module ThreeModProfile

@addField(PlayerPuppet)
private let threeModCarryCapacityModifier: ref<gameStatModifierData>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.threeModCarryCapacityModifier) {
    this.threeModCarryCapacityModifier = RPGManager.CreateStatModifier(gamedataStatType.CarryCapacity, gameStatModifierType.Additive, 9000.0);
    stats.AddModifier(id, this.threeModCarryCapacityModifier);
  };

  return result;
}
