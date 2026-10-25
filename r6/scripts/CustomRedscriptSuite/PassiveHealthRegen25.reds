// PassiveHealthRegen25: dependency-free redscript replacement for the local 2.5% YAML.
// Enforces 2.5% max-HP/sec health regeneration with 0 delay and 0 restrictions
// both in combat and out of combat:
// 1. Applies transient StatsSystem modifiers enabling in/out-of-combat health regen,
//    0..100% thresholds, 0 start/damage-change delay, and +2.5% max-HP/sec rate.
// 2. Applies a direct StatPoolModifier (enabled=true, 0..100%, 2.5%/s, startDelay=0,
//    delayOnChange=false) to gamedataStatPoolType.Health and marks the Health stat
//    pool active across player attach, resurrection, combat/stealth transitions,
//    and status-effect pool-modifier applications/reverts.

module PassiveHealthRegen25

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatRateMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25OutOfCombatRateMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatEnabledMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25OutOfCombatEnabledMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatStartThresholdMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25OutOfCombatStartThresholdMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatEndThresholdMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25OutOfCombatEndThresholdMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatDelayMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25OutOfCombatDelayMod: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let passiveHealthRegen25InCombatStartDelayMod: ref<gameStatModifierData>;

@addMethod(PlayerPuppet)
public final func ApplyPassiveHealthRegen25() -> Void {
  let game = this.GetGame();
  let stats = GameInstance.GetStatsSystem(game);
  let statPools = GameInstance.GetStatPoolsSystem(game);
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.passiveHealthRegen25InCombatEnabledMod) {
    this.passiveHealthRegen25InCombatEnabledMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatRegenEnabled, gameStatModifierType.Additive, 1.0);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatEnabledMod);
  };

  if !IsDefined(this.passiveHealthRegen25OutOfCombatEnabledMod) {
    this.passiveHealthRegen25OutOfCombatEnabledMod = RPGManager.CreateStatModifier(gamedataStatType.HealthOutOfCombatRegenEnabled, gameStatModifierType.Additive, 1.0);
    stats.AddModifier(id, this.passiveHealthRegen25OutOfCombatEnabledMod);
  };

  if !IsDefined(this.passiveHealthRegen25InCombatStartThresholdMod) {
    this.passiveHealthRegen25InCombatStartThresholdMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatRegenStartThreshold, gameStatModifierType.Multiplier, 0.0);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatStartThresholdMod);
  };

  if !IsDefined(this.passiveHealthRegen25OutOfCombatStartThresholdMod) {
    this.passiveHealthRegen25OutOfCombatStartThresholdMod = RPGManager.CreateStatModifier(gamedataStatType.HealthOutOfCombatRegenStartThreshold, gameStatModifierType.Multiplier, 0.0);
    stats.AddModifier(id, this.passiveHealthRegen25OutOfCombatStartThresholdMod);
  };

  if !IsDefined(this.passiveHealthRegen25InCombatEndThresholdMod) {
    this.passiveHealthRegen25InCombatEndThresholdMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatRegenEndThreshold, gameStatModifierType.Additive, 100.0);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatEndThresholdMod);
  };

  if !IsDefined(this.passiveHealthRegen25OutOfCombatEndThresholdMod) {
    this.passiveHealthRegen25OutOfCombatEndThresholdMod = RPGManager.CreateStatModifier(gamedataStatType.HealthOutOfCombatRegenEndThreshold, gameStatModifierType.Additive, 100.0);
    stats.AddModifier(id, this.passiveHealthRegen25OutOfCombatEndThresholdMod);
  };

  if !IsDefined(this.passiveHealthRegen25InCombatDelayMod) {
    this.passiveHealthRegen25InCombatDelayMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatRegenDelayOnChange, gameStatModifierType.Multiplier, 0.0);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatDelayMod);
  };

  if !IsDefined(this.passiveHealthRegen25OutOfCombatDelayMod) {
    this.passiveHealthRegen25OutOfCombatDelayMod = RPGManager.CreateStatModifier(gamedataStatType.HealthOutOfCombatRegenDelayOnChange, gameStatModifierType.Multiplier, 0.0);
    stats.AddModifier(id, this.passiveHealthRegen25OutOfCombatDelayMod);
  };

  if !IsDefined(this.passiveHealthRegen25InCombatStartDelayMod) {
    this.passiveHealthRegen25InCombatStartDelayMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatStartDelay, gameStatModifierType.Multiplier, 0.0);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatStartDelayMod);
  };

  if !IsDefined(this.passiveHealthRegen25InCombatRateMod) {
    this.passiveHealthRegen25InCombatRateMod = RPGManager.CreateStatModifier(gamedataStatType.HealthInCombatRegenRateBase, gameStatModifierType.Additive, 2.5);
    stats.AddModifier(id, this.passiveHealthRegen25InCombatRateMod);
  };

  if !IsDefined(this.passiveHealthRegen25OutOfCombatRateMod) {
    this.passiveHealthRegen25OutOfCombatRateMod = RPGManager.CreateStatModifier(gamedataStatType.HealthOutOfCombatRegenRateBase, gameStatModifierType.Additive, 2.5);
    stats.AddModifier(id, this.passiveHealthRegen25OutOfCombatRateMod);
  };

  let regenMod: StatPoolModifier;
  regenMod.enabled = true;
  regenMod.rangeBegin = 0.0;
  regenMod.rangeEnd = 100.0;
  regenMod.startDelay = 0.0;
  regenMod.valuePerSec = 2.5;
  regenMod.delayOnChange = false;
  statPools.RequestSettingModifier(id, gamedataStatPoolType.Health, gameStatPoolModificationTypes.Regeneration, regenMod);
  statPools.RequestMarkingStatPoolActive(id, gamedataStatPoolType.Health);
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.ApplyPassiveHealthRegen25();
  return result;
}

@wrapMethod(PlayerPuppet)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
  wrappedMethod(playerPuppet);
  this.ApplyPassiveHealthRegen25();
}

@wrapMethod(PlayerPuppet)
protected func OnResurrected() -> Void {
  wrappedMethod();
  this.ApplyPassiveHealthRegen25();
}

@wrapMethod(PlayerCombatController)
private final func VerifyActivation() -> Void {
  wrappedMethod();
  let player = this.m_owner as PlayerPuppet;
  if IsDefined(player) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(PlayerCombatController)
private final func ActivateCombat() -> Void {
  wrappedMethod();
  let player = this.m_owner as PlayerPuppet;
  if IsDefined(player) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(PlayerCombatController)
private final func ActivateOutOfCombat() -> Void {
  wrappedMethod();
  let player = this.m_owner as PlayerPuppet;
  if IsDefined(player) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(PlayerCombatController)
private final func ActivateStealth() -> Void {
  wrappedMethod();
  let player = this.m_owner as PlayerPuppet;
  if IsDefined(player) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(ModifyStatPoolModifierEffector)
protected func ActionOn(owner: ref<GameObject>) -> Void {
  wrappedMethod(owner);
  let player = owner as PlayerPuppet;
  if IsDefined(player) && Equals(this.m_poolType, gamedataStatPoolType.Health) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(ModifyStatPoolModifierEffector)
protected func ActionOff(owner: ref<GameObject>) -> Void {
  wrappedMethod(owner);
  let player = owner as PlayerPuppet;
  if IsDefined(player) && Equals(this.m_poolType, gamedataStatPoolType.Health) {
    player.ApplyPassiveHealthRegen25();
  };
}

@wrapMethod(ModifyStatPoolModifierEffector)
private final func RevertPoolModifier(gameInstance: GameInstance) -> Void {
  wrappedMethod(gameInstance);
  let player = this.m_owner as PlayerPuppet;
  if IsDefined(player) && Equals(this.m_poolType, gamedataStatPoolType.Health) {
    player.ApplyPassiveHealthRegen25();
  };
}
