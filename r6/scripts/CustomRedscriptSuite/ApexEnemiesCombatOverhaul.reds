// C1: Apex Enemies Combat Overhaul (Damage Scaling + Anti-Stunlock Poise + Melee Swarm)
// Pure Redscript (0 dependencies) for Cyberpunk 2077 v2.5:
// 1. Enemy Outgoing Damage Scaling: Scales enemy damage dealt to V by NPC PowerLevel and Rarity
//    so high-level/Elite/Boss enemies remain genuinely threatening against a high-HP player.
// 2. Anti-Stunlock Poise Scaling: Increases impact, stagger, and knockdown thresholds on
//    Officer, Elite, Boss, and MaxTac NPCs and shortens their stun recovery timers.
// 3. Melee Enemy Swarm: Pure-Redscript port of Melee Enemy Swarm so all melee enemies
//    rush V simultaneously instead of idling in passive SimpleCombat waiting for a ticket.

public static func AECO_ComputeLevelDamageMult(level: Float) -> Float {
  if level <= 10.0 {
    return 1.00;
  };
  if level <= 20.0 {
    return 1.00 + ((level - 10.0) / 10.0) * 0.35; // 1.00x -> 1.35x
  };
  if level <= 35.0 {
    return 1.35 + ((level - 20.0) / 15.0) * 0.40; // 1.35x -> 1.75x
  };
  if level <= 50.0 {
    return 1.75 + ((level - 35.0) / 15.0) * 0.50; // 1.75x -> 2.25x
  };
  if level <= 60.0 {
    return 2.25 + ((level - 50.0) / 10.0) * 0.50; // 2.25x -> 2.75x
  };
  return 2.75 + ((level - 60.0) / 30.0) * 0.50;
}

public static func AECO_ComputeRarityDamageMult(rarity: gamedataNPCRarity) -> Float {
  switch rarity {
    case gamedataNPCRarity.Officer:
      return 1.15;
    case gamedataNPCRarity.Elite:
      return 1.30;
    case gamedataNPCRarity.Boss:
    case gamedataNPCRarity.MaxTac:
      return 1.50;
    default:
      return 1.00;
  };
}

// --- 1. Enemy Outgoing Damage Scaling ---
@wrapMethod(DamageSystem)
private final func ProcessPlayerIncomingDamageMultiplier(hitEvent: ref<gameHitEvent>) -> Void {
  wrappedMethod(hitEvent);
  if !IsDefined(hitEvent) || !IsDefined(hitEvent.target) || !IsDefined(hitEvent.attackData) {
    return;
  };
  if !hitEvent.target.IsPlayer() {
    return;
  };
  let attacker: ref<NPCPuppet> = hitEvent.attackData.GetInstigator() as NPCPuppet;
  if !IsDefined(attacker) || ScriptedPuppet.IsPlayerCompanion(attacker) {
    return;
  };
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(attacker.GetGame());
  if !IsDefined(statsSystem) {
    return;
  };
  let npcLevel: Float = statsSystem.GetStatValue(Cast<StatsObjectID>(attacker.GetEntityID()), gamedataStatType.PowerLevel);
  if npcLevel < 1.0 {
    npcLevel = 1.0;
  };
  let mult: Float = AECO_ComputeLevelDamageMult(npcLevel) * AECO_ComputeRarityDamageMult(attacker.GetNPCRarity());
  if mult > 1.0 {
    hitEvent.attackComputed.MultAttackValue(mult);
  };
}

// --- 2. Anti-Stunlock Poise Scaling for Officer / Elite / Boss / MaxTac ---
@wrapMethod(HitReactionComponent)
protected final func GetDBParameters() -> Void {
  wrappedMethod();
  if !IsDefined(this.m_ownerNPC) || ScriptedPuppet.IsPlayerCompanion(this.m_ownerNPC) {
    return;
  };
  let rarity: gamedataNPCRarity = this.m_ownerNPC.GetNPCRarity();
  let poiseMult: Float = 1.0;
  let durationMult: Float = 1.0;
  switch rarity {
    case gamedataNPCRarity.Officer:
      poiseMult = 1.50;
      durationMult = 0.80;
      break;
    case gamedataNPCRarity.Elite:
      poiseMult = 2.25;
      durationMult = 0.65;
      break;
    case gamedataNPCRarity.Boss:
    case gamedataNPCRarity.MaxTac:
      poiseMult = 3.50;
      durationMult = 0.50;
      break;
    default:
      return;
  };

  this.m_currentImpactDamageThreshold *= poiseMult;
  this.m_currentStaggerDamageThreshold *= poiseMult;
  this.m_currentKnockdownDamageThreshold *= poiseMult;
  this.m_currentKnockdownDamageThresholdImpulse *= poiseMult;
  this.m_knockdownImpulseThreshold *= poiseMult;

  this.m_impactDamageDuration *= durationMult;
  this.m_staggerDamageDuration *= durationMult;
  this.m_knockdownDamageDuration *= durationMult;
  this.m_impactDamageDurationMelee *= durationMult;
  this.m_staggerDamageDurationMelee *= durationMult;
}

// --- 3. Melee Enemy Swarm (All At Once) ---
public static func AECO_IsMeleeArchetype(puppet: ref<ScriptedPuppet>) -> Bool {
  return AIActionHelper.CheckAbility(puppet, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsGenericMeleeArchetype"))
    || AIActionHelper.CheckAbility(puppet, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsFastMeleeArchetype"))
    || AIActionHelper.CheckAbility(puppet, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsStrongMeleeArchetype"));
}

@wrapMethod(SimpleCombatConditon)
protected func Check(context: ScriptExecutionContext) -> AIbehaviorConditionOutcomes {
  let puppet: ref<ScriptedPuppet> = AIBehaviorScriptBase.GetPuppet(context);
  if IsDefined(puppet) {
    let weapon: wref<WeaponObject> = ScriptedPuppet.GetActiveWeapon(puppet);
    if IsDefined(weapon) && weapon.IsMelee() && AECO_IsMeleeArchetype(puppet) {
      return AIbehaviorConditionOutcomes.False;
    };
  };
  return wrappedMethod(context);
}
