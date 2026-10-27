// RelentlessLiveDismember by Cazanu - living limb-loss rules.
module CazanuLimbSurvival

// Fractions of maximum health, measured using the game's accumulated wound damage.
// These are independent of health damage: a lethal hit still kills normally.
public abstract class Settings {
  public static func Enabled() -> Bool = true
  public static func ArmThreshold() -> Float = 0.15
  public static func LegThreshold() -> Float = 0.25
  // Keep the survivor floor small enough that a protected limb is not a
  // second health bar.  The requested tuning range is 3--5%; 5% is the
  // default and is centralized so it can be tuned without touching damage
  // plumbing.
  public static func SurvivorHealthFloor() -> Float = 0.05
}

// Resolve all shapes reported for one hit transaction.  Melee sweeps can
// contain a torso/head shape followed by the actual arm/leg shape; looking
// only at index 0 silently loses the limb strike.  The loop is bounded by the
// hit event's own result array and never invents a limb from a zone alone.

// Match Shellrain's record-name exclusions. Metal hit shapes alone are not
// enough: ordinary human enemies can have cybernetic limbs.
public abstract class NPCFilter {
  public static func MechanicalRecord(record: TweakDBID) -> Bool {
    let name = StrLower(TDBID.ToStringDEBUG(record));
    return StrContains(name, "android") || StrContains(name, "drone")
      || StrContains(name, "robot") || StrContains(name, "turret")
      || StrContains(name, "sentry") || StrContains(name, "mech_")
      || StrContains(name, "_mech") || StrContains(name, "mechanical")
      || StrContains(name, "chimera") || StrContains(name, "minotaur")
      || StrContains(name, "cerberus") || StrContains(name, "basilisk")
      || StrContains(name, "flathead") || StrContains(name, "adam_smasher")
      || StrContains(name, "militech_barghest");
  }

  public static func QualifyingRarity(rarity: gamedataNPCRarity) -> Bool {
    // Living limb survival is intentionally one fit for all human enemy
    // rarities. Keep this compatibility seam for diagnostics/callers.
    return true;
  }
}

@addField(NPCPuppet)
private let cls_mechanicalChecked: Bool;
@addField(NPCPuppet)
private let cls_mechanicalExcluded: Bool;
@addField(NPCPuppet)
public let cls_accumFrameWoundsDamage: Float;
@addField(NPCPuppet)
public let cls_accumFrameDismemberDamage: Float;
@addField(NPCPuppet)
public let cls_lastLimbHitTime: Float;
@addField(NPCPuppet)
public let cls_lastLimbDismemberTime: Float;
@addField(NPCPuppet)
public let cls_forceSurviveCurrentLimbHit: Bool;
@addField(NPCPuppet)
public let cls_saberSeveredCount: Int32;
@addField(NPCPuppet)
public let cls_lastSaberSeverTime: Float;

@addMethod(NPCPuppet)
public final func CLS_IsMechanical() -> Bool {
  if !this.cls_mechanicalChecked {
    let record = this.GetRecord();
    // Retry if initialization has not supplied a record yet, without
    // excluding all ordinary humans when a record cannot be resolved.
    if !IsDefined(record) { return false; }
    this.cls_mechanicalExcluded = NPCFilter.MechanicalRecord(record.GetID());
    this.cls_mechanicalChecked = true;
  }
  return this.cls_mechanicalExcluded;
}

@addMethod(NPCPuppet)
public final func CLS_IsEligibleHumanTarget() -> Bool {
  return !this.CLS_IsMechanical() && this.IsHuman()
    && !this.IsCharacterCivilian() && !this.IsPlayerCompanion() && !this.IsCrowd();
}

// Darth Vader's lightsaber is an explicit deterministic exception to the
// limb-shape gates above. It applies only to living, non-mechanical
// humanoid NPCs and never to V or vendors.
@addMethod(NPCPuppet)
public final func CLS_IsEligibleSaberTarget() -> Bool {
  return this.IsHuman() && !this.CLS_IsMechanical() && !this.IsPlayer() && !this.IsVendor();
}

// Accumulate wound and dismemberment frame damage across multishot projectiles
// and pair HitDismembermentFactor with HitWoundsFactor so crafted weapons with
// high dismemberment modifiers reliably trigger living limb loss.
@wrapMethod(NPCPuppet)
private final func SetHitEventData(hitEvent: ref<gameHitEvent>, hitReactionFactor: Float, hitWoundsFactor: Float, hitDismembermentFactor: Float) -> Void {
  wrappedMethod(hitEvent, hitReactionFactor, hitWoundsFactor, hitDismembermentFactor);
  if Settings.Enabled() && this.CLS_IsEligibleHumanTarget() && IsDefined(hitEvent) && IsDefined(hitEvent.attackComputed) {
    let baseDmg: Float = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    let effectiveFactor: Float = MaxF(hitWoundsFactor, MaxF(hitDismembermentFactor, 1.0));
    this.cls_accumFrameWoundsDamage += baseDmg * effectiveFactor;
    this.cls_accumFrameDismemberDamage += baseDmg * effectiveFactor;
  }
}

@wrapMethod(NPCPuppet)
public final const func GetTotalFrameWoundsDamage() -> Float {
  let vanillaVal: Float = wrappedMethod();
  if Settings.Enabled() && this.cls_accumFrameWoundsDamage > vanillaVal {
    return this.cls_accumFrameWoundsDamage;
  }
  return vanillaVal;
}

@wrapMethod(NPCPuppet)
public final const func GetTotalFrameDismembermentDamage() -> Float {
  let vanillaVal: Float = wrappedMethod();
  if Settings.Enabled() && this.cls_accumFrameDismemberDamage > vanillaVal {
    return this.cls_accumFrameDismemberDamage;
  }
  return vanillaVal;
}

@wrapMethod(NPCPuppet)
protected cb func OnResetTotalFrameDamage(evt: ref<ResetFrameDamage>) -> Bool {
  this.cls_accumFrameWoundsDamage = 0.0;
  this.cls_accumFrameDismemberDamage = 0.0;
  return wrappedMethod(evt);
}

// Suppress stale potential-death events if a limb survival clamp kept health positive.
@wrapMethod(NPCPuppet)
protected cb func OnPotentialDeath(evt: ref<gamePotentialDeathEvent>) -> Bool {
  // Only the direct limb-hit transaction may defer a potential-death event.
  // A tracked survivor must still be killable by ordinary follow-up damage or
  // natural bleeding/burning/poison/electrocution.
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
  let saberSurvivorWindow: Bool = this.cls_saberSeveredCount > 0
    && now - this.cls_lastSaberSeverTime >= 0.0
    && now - this.cls_lastSaberSeverTime <= 8.0
    && this.CLS_CountMissingLimbsOnPuppet() < 4;
  if this.cls_saberSeveredCount > 0 && !saberSurvivorWindow {
    this.cls_forceSurviveCurrentLimbHit = false;
  }
  if Settings.Enabled() && this.cls_forceSurviveCurrentLimbHit {
    let pools = GameInstance.GetStatPoolsSystem(this.GetGame());
    if IsDefined(pools) {
      let hp: Float = pools.GetStatPoolValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatPoolType.Health, false);
      if hp > 1.0 && !this.IsDead() && !this.IsAboutToDie() {
        return false;
      }
    }
  }
  return wrappedMethod(evt);
}

// Keep the native ProcessWoundsAndDismemberment pipeline. It handles quest
// protection, explosions, executions, traversal, wound appearance and AI updates.
// Only redirect eligible living limb hits from crippled flesh to the native
// surviving-dismemberment branch; do not change the hit material to cyberware.
@addField(HitReactionComponent)
private let cls_legWoundAcceptedAt: Float;

// Ensure rapid-fire and multishot ranged weapons do not skip SetCumulatedDamages
// and ProcessWoundsAndDismemberment during the 1.00s m_globalHitTimer window.
@wrapMethod(HitReactionComponent)
protected final func GetHitTimerAvailability() -> Bool {
  if Settings.Enabled() && IsDefined(this.m_ownerNPC) && this.m_ownerNPC.CLS_IsEligibleHumanTarget() {
    return true;
  }
  return wrappedMethod();
}

@wrapMethod(HitReactionComponent)
protected func SetCumulatedDamages(target: wref<GameObject>, out guardBreakImpulse: Float) -> Void {
  wrappedMethod(target, guardBreakImpulse);
  if IsDefined(this.m_ownerNPC) {
    this.m_ownerNPC.cls_accumFrameWoundsDamage = 0.0;
    this.m_ownerNPC.cls_accumFrameDismemberDamage = 0.0;
  }
}

// Prevent high-knockdown-impulse hits from calling this.m_ownerPuppet.Kill()
// inside GetHitIntensity before ProcessWoundsAndDismemberment() can evaluate limb survival.
@wrapMethod(HitReactionComponent)
protected final func GetHitIntensity(defeatedOverride: Bool) -> Void {
  if Settings.Enabled() && IsDefined(this.m_ownerNPC)
    && (this.m_ownerNPC.cls_forceSurviveCurrentLimbHit || this.CLS_CanSurviveLimbLoss()) {
    wrappedMethod(true);
    return;
  }
  wrappedMethod(defeatedOverride);
}

// Once a leg is reserved, treat subsequent hits on the survivor as Twitch immediately
// without waiting for the asynchronous BaseStatusEffect.DismemberedLeg* application.
@wrapMethod(HitReactionComponent)
protected final func GetReactionType(guardBreakImpulse: Float, newHitEvent: ref<gameHitEvent>) -> animHitReactionType {
  if Settings.Enabled() && this.m_isAlive && IsDefined(this.m_ownerNPC)
    && (this.m_ownerNPC.CLS_IsLimbReserved(gameDismBodyPart.LEFT_LEG) || this.m_ownerNPC.CLS_IsLimbReserved(gameDismBodyPart.RIGHT_LEG)) {
    return animHitReactionType.Twitch;
  }
  return wrappedMethod(guardBreakImpulse, newHitEvent);
}

// Prevent ForceDismember or Body perk dismemberment from bypassing WoundedCyberConditions
// into the lethal ProcessWoundsAndDismemberment Kill() fallback on living limb hits.
@wrapMethod(HitReactionComponent)
protected final func DismembermentConditions() -> Bool {
  if this.CLS_IsCurrentReservedLivingLimb() || this.CLS_CanSurviveLimbLoss() {
    return false;
  }
  return wrappedMethod();
}

@wrapMethod(HitReactionComponent)
protected final func TryTriggerBodyPerkDismembement(remainingHealth: Float) -> Bool {
  if this.CLS_IsCurrentReservedLivingLimb() || this.CLS_CanSurviveLimbLoss() {
    return false;
  }
  return wrappedMethod(remainingHealth);
}

// The first pellet queues the leg wound. A later pellet in that same blast
// can otherwise replace Pain with Knockdown and its standing recovery action.
// Run native wounds first so a fatal hit or a newly lost limb keeps its result.
@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  wrappedMethod();
  if !IsDefined(this.m_ownerNPC) || !IsDefined(this.m_attackData) {
    return;
  }
  if IsDefined(this.m_ownerNPC) {
    this.m_ownerNPC.cls_forceSurviveCurrentLimbHit = false;
  }
  if NotEquals(this.m_reactionType, animHitReactionType.Knockdown)
    || !this.CLS_IsCurrentReservedLivingLimb()
    || this.m_attackData.HasFlag(hitFlag.Nonlethal)
    || NotEquals(this.m_attackData.GetAttackType(), gamedataAttackType.Ranged) {
    return;
  }
  let shape = this.GetHitShapeUserData();
  if !IsDefined(shape) {
    return;
  }
  let zone = HitShapeUserDataBase.GetHitReactionZone(shape);
  if NotEquals(zone, EHitReactionZone.LegLeft) && NotEquals(zone, EHitReactionZone.LegRight) {
    return;
  }
  let elapsed = this.GetCurrentTime() - this.cls_legWoundAcceptedAt;
  // Match the native short multi-pellet Twitch grace window. Later attacks
  // and head/torso hits keep their normal reactions and damage handling.
  if elapsed < 0.0 || elapsed > 0.09 { return; }
  this.m_reactionType = animHitReactionType.Twitch;
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"LEG_PELLET_GUARD npc=\(EntityID.ToDebugString(this.m_ownerNPC.GetEntityID())) elapsed=\(elapsed) Knockdown->Twitch; preserving accepted leg wound");
  }
}

@wrapMethod(HitReactionComponent)
protected final func WoundedFleshConditions(dismembermentCheck: Bool, woundedBaseConditions: Bool) -> Bool {
  if this.cls_diagActive {
    this.cls_diagFleshCalled = true;
    this.cls_diagNativeDismember = dismembermentCheck;
    this.cls_diagNativeWoundBase = woundedBaseConditions;
  }
  if !dismembermentCheck && this.CLS_IsCurrentReservedLivingLimb() {
    return false;
  }
  if !dismembermentCheck && this.CLS_CanSurviveLimbLoss() {
    return false;
  }
  return wrappedMethod(dismembermentCheck, woundedBaseConditions);
}

@wrapMethod(HitReactionComponent)
protected final func WoundedCyberConditions(dismembermentCheck: Bool, woundedBaseConditions: Bool) -> Bool {
  if this.cls_diagActive {
    this.cls_diagCyberCalled = true;
    this.cls_diagNativeDismember = dismembermentCheck;
    this.cls_diagNativeWoundBase = woundedBaseConditions;
  }
  if !dismembermentCheck && this.CLS_IsCurrentReservedLivingLimb() {
    return false;
  }
  if !dismembermentCheck && this.CLS_CanSurviveLimbLoss() {
    // Status effects are queued. Reserve synchronously before the native call
    // so another pellet cannot request this limb again in the same frame.
    let part = HitShapeUserDataBase.GetDismembermentBodyPart(this.GetHitShapeUserData());
    if Equals(part, gameDismBodyPart.LEFT_LEG) || Equals(part, gameDismBodyPart.RIGHT_LEG) {
      this.cls_legWoundAcceptedAt = this.GetCurrentTime();
    }
    this.m_ownerNPC.CLS_ReserveLimb(part);
    if this.cls_diagActive {
      this.cls_diagSurvivalSelected = true;
    }
    return true;
  }
  return wrappedMethod(dismembermentCheck, woundedBaseConditions);
}

@addMethod(HitReactionComponent)
private final func CLS_CanSurviveLimbLoss() -> Bool {
  return Equals(this.CLS_LimbBlockReason(), n"eligible");
}

@addMethod(HitReactionComponent)
private final func CLS_LimbBlockReason() -> CName {
  if !Settings.Enabled() || !IsDefined(this.m_ownerNPC) || !IsDefined(this.m_attackData) {
    return n"disabled_or_missing_context";
  }
  let npc = this.m_ownerNPC;
  if npc.CLS_IsMechanical() { return n"mechanical_npc"; }
  if !npc.IsHuman() || npc.IsCharacterCivilian() || npc.IsPlayerCompanion() || npc.IsCrowd() {
    return n"excluded_npc_type";
  }
  if !this.m_isAlive || !ScriptedPuppet.IsAlive(npc) || npc.IsDead() || npc.IsAboutToDie() {
    return n"dead_dying_defeated_or_killing_blow";
  }
  if !npc.cls_forceSurviveCurrentLimbHit
    && (npc.IsAboutToBeDefeated() || ScriptedPuppet.IsDefeated(npc) || this.m_attackData.HasFlag(hitFlag.WasKillingBlow)) {
    return n"dead_dying_defeated_or_killing_blow";
  }
  if !IsDefined(npc.GetDismembermentComponent()) || this.m_attackData.HasFlag(hitFlag.Nonlethal) {
    return n"no_dismemberment_component_or_nonlethal";
  }
  if (this.m_inWorkspot && !this.m_inCover) || npc.IsRagdolling() {
    return n"workspot_cover_or_ragdoll";
  }
  if Equals(this.m_reactionType, animHitReactionType.Death)
    || Equals(this.m_reactionType, animHitReactionType.Ragdoll) {
    return n"death_pain_or_ragdoll_reaction";
  }

  let shape = this.GetHitShapeUserData();
  if !IsDefined(shape) {
    return n"no_hit_shape";
  }
  let zone = HitShapeUserDataBase.GetHitReactionZone(shape);
  let threshold: Float;
  let part: gameDismBodyPart;
  switch zone {
    case EHitReactionZone.ArmLeft:
    case EHitReactionZone.HandLeft:
      part = gameDismBodyPart.LEFT_ARM;
      threshold = Settings.ArmThreshold();
      break;
    case EHitReactionZone.ArmRight:
    case EHitReactionZone.HandRight:
      part = gameDismBodyPart.RIGHT_ARM;
      threshold = Settings.ArmThreshold();
      break;
    case EHitReactionZone.LegLeft:
      part = gameDismBodyPart.LEFT_LEG;
      threshold = Settings.LegThreshold();
      break;
    case EHitReactionZone.LegRight:
      part = gameDismBodyPart.RIGHT_LEG;
      threshold = Settings.LegThreshold();
      break;
    default:
      return n"not_a_limb";
  }
  // Check both mappings: a chest hit must never become a surviving torso wound.
  if NotEquals(HitShapeUserDataBase.GetDismembermentBodyPart(shape), part) {
    return n"zone_bodypart_mismatch";
  }
  let material = shape.GetShapeType();
  if NotEquals(material, EHitShapeType.Flesh)
    && NotEquals(material, EHitShapeType.Cyberware)
    && NotEquals(material, EHitShapeType.Metal) {
    return n"unsupported_hit_material";
  }

  let index = EnumInt(zone);
  if index < 0 || index >= ArraySize(this.m_bodyPartWoundCumulatedDamages) {
    return n"invalid_damage_index";
  }
  let maxHealth = this.GetOwnerTotalHealth();
  if maxHealth <= 0.0 || threshold <= 0.0 {
    return n"invalid_health_or_threshold";
  }
  let healthScale = MaxF(1.0, npc.GetCustomScaledHealthMultiplier());
  let effectiveMaxHealth = maxHealth / healthScale;
  let cumulatedLimbDamage = MaxF(this.m_bodyPartWoundCumulatedDamages[index], this.m_bodyPartDismemberCumulatedDamages[index]);
  let reactionWeapon: ref<WeaponObject> = this.m_attackData.GetWeapon();
  let isSaberWeapon: Bool = IsDefined(reactionWeapon)
    && Equals(reactionWeapon.GetItemID().GetTDBID(), t"Items.Saber_DarthVader");
  if cumulatedLimbDamage < effectiveMaxHealth * threshold
    && !npc.cls_forceSurviveCurrentLimbHit
    && !this.m_attackData.HasFlag(hitFlag.ForceDismember)
    && !isSaberWeapon {
    return n"below_wound_threshold";
  }

  // GetTotalFrameDamage is scaled REACTION damage, not pending HP loss.
  // Do not subtract it from health: the native death/defeat/killing-blow flags
  // above identify fatal hits without treating reaction damage as health damage.
  let statPools = GameInstance.GetStatPoolsSystem(npc.GetGame());
  if !IsDefined(statPools) {
    return n"missing_stat_pool";
  }
  let health = statPools.GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, false);
  if health <= 0.0 {
    return n"no_health_remaining";
  }
  if this.CLS_IsLimbAlreadyMissing(part) {
    return n"limb_already_selected_or_missing";
  }
  return n"eligible";
}

@addMethod(HitReactionComponent)
private final func CLS_IsLimbAlreadyMissing(part: gameDismBodyPart) -> Bool {
  let npc = this.m_ownerNPC;
  if npc.CLS_IsLimbReserved(part) {
    return true;
  }
  // Arm and hand wounds share one limb. Other limbs can still qualify later.
  switch part {
    case gameDismBodyPart.LEFT_ARM:
      return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmLeft")
        || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedHandLeft");
    case gameDismBodyPart.RIGHT_ARM:
      return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmRight")
        || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedHandRight");
    case gameDismBodyPart.LEFT_LEG:
      return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft");
    case gameDismBodyPart.RIGHT_LEG:
      return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
  }
  return true;
}

@addMethod(HitReactionComponent)
private final func CLS_IsCurrentReservedLivingLimb() -> Bool {
  if !Settings.Enabled() || !IsDefined(this.m_ownerNPC) || !IsDefined(this.m_attackData)
    || !this.m_isAlive || !ScriptedPuppet.IsAlive(this.m_ownerNPC)
    || this.m_ownerNPC.IsAboutToDieOrDefeated() || ScriptedPuppet.IsDefeated(this.m_ownerNPC)
    || this.m_attackData.HasFlag(hitFlag.WasKillingBlow) {
    return false;
  }
  let shape = this.GetHitShapeUserData();
  if !IsDefined(shape) {
    return false;
  }
  // Do not suppress the head/torso branch, even if a chest shape maps to an arm.
  let zone = HitShapeUserDataBase.GetHitReactionZone(shape);
  switch zone {
    case EHitReactionZone.ArmLeft:
    case EHitReactionZone.HandLeft:
    case EHitReactionZone.ArmRight:
    case EHitReactionZone.HandRight:
    case EHitReactionZone.LegLeft:
    case EHitReactionZone.LegRight:
      return this.m_ownerNPC.CLS_IsLimbReserved(HitShapeUserDataBase.GetDismembermentBodyPart(shape));
  }
  return false;
}

// Four nonpersistent flags per NPC; no world list, polling, or per-pellet tasks.
@addField(NPCPuppet)
private let cls_leftArmReserved: Bool;
@addField(NPCPuppet)
private let cls_rightArmReserved: Bool;
@addField(NPCPuppet)
private let cls_leftLegReserved: Bool;
@addField(NPCPuppet)
private let cls_rightLegReserved: Bool;

@addMethod(NPCPuppet)
public final func CLS_IsLimbReserved(part: gameDismBodyPart) -> Bool {
  if this.CLS_IsMechanical() { return false; }
  switch part {
    case gameDismBodyPart.LEFT_ARM: return this.cls_leftArmReserved;
    case gameDismBodyPart.RIGHT_ARM: return this.cls_rightArmReserved;
    case gameDismBodyPart.LEFT_LEG: return this.cls_leftLegReserved;
    case gameDismBodyPart.RIGHT_LEG: return this.cls_rightLegReserved;
  }
  return false;
}

@addMethod(NPCPuppet)
public final func CLS_IsTrackedSurvivor() -> Bool {
  return (this.cls_leftArmReserved || this.cls_rightArmReserved
    || this.cls_leftLegReserved || this.cls_rightLegReserved) && this.CLS_IsEligibleHumanTarget();
}

@addMethod(NPCPuppet)
public final func CLS_IsLimbAlreadyMissingOnPuppet(part: gameDismBodyPart) -> Bool {
  if this.CLS_IsLimbReserved(part) {
    return true;
  }
  switch part {
    case gameDismBodyPart.LEFT_ARM:
      return StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedArmLeft")
        || StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedHandLeft");
    case gameDismBodyPart.RIGHT_ARM:
      return StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedArmRight")
        || StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedHandRight");
    case gameDismBodyPart.LEFT_LEG:
      return StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegLeft");
    case gameDismBodyPart.RIGHT_LEG:
      return StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegRight");
  }
  return true;
}

@addMethod(NPCPuppet)
public final func CLS_ReserveLimb(part: gameDismBodyPart) -> Void {
  if this.CLS_IsMechanical() { return; }
  let firstLeg = (Equals(part, gameDismBodyPart.LEFT_LEG) || Equals(part, gameDismBodyPart.RIGHT_LEG))
    && !this.cls_leftLegReserved && !this.cls_rightLegReserved;
  switch part {
    case gameDismBodyPart.LEFT_ARM: this.cls_leftArmReserved = true; break;
    case gameDismBodyPart.RIGHT_ARM: this.cls_rightArmReserved = true; break;
    case gameDismBodyPart.LEFT_LEG: this.cls_leftLegReserved = true; break;
    case gameDismBodyPart.RIGHT_LEG: this.cls_rightLegReserved = true; break;
    default: return;
  }
  this.cls_lastLimbDismemberTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
  // Snapshot the actual equipped weapons and target before the native wound
  // status/AI transition; compare with the later seated decision for this NPC.
  if firstLeg {
    this.CLS_LogSeatedPreflight(n"first_leg_selected");
    // Choose before native wounded AI can replace a rifle/knife with a gun.
    this.CLS_SelectLegWound();
  }
  if Equals(part, gameDismBodyPart.LEFT_ARM) || Equals(part, gameDismBodyPart.RIGHT_ARM) {
    this.CLS_QueueArmWeaponCleanup();
  }
  this.CLS_StartFollowupDiagnostics();
}

@addMethod(NPCPuppet)
public final func CLS_CountMissingLimbsOnPuppet() -> Int32 {
  let count: Int32 = 0;
  if this.CLS_IsLimbAlreadyMissingOnPuppet(gameDismBodyPart.LEFT_ARM) { count += 1; }
  if this.CLS_IsLimbAlreadyMissingOnPuppet(gameDismBodyPart.RIGHT_ARM) { count += 1; }
  if this.CLS_IsLimbAlreadyMissingOnPuppet(gameDismBodyPart.LEFT_LEG) { count += 1; }
  if this.CLS_IsLimbAlreadyMissingOnPuppet(gameDismBodyPart.RIGHT_LEG) { count += 1; }
  return count;
}

@addMethod(NPCPuppet)
public final static func CLS_ResolveStruckLimbFromHitEvent(
  npc: ref<NPCPuppet>,
  hitEvent: ref<gameHitEvent>,
  out struckLimb: gameDismBodyPart,
  out isHeadHit: Bool
) -> Bool {
  isHeadHit = false;
  if !IsDefined(npc) || !IsDefined(hitEvent) {
    return false;
  }
  let shapes = hitEvent.hitRepresentationResult.hitShapes;
  let foundLimb: Bool = false;
  let index: Int32 = 0;
  while index < ArraySize(shapes) {
    let shape: ref<HitShapeUserDataBase> = shapes[index].userData as HitShapeUserDataBase;
    if IsDefined(shape) {
      let zone: EHitReactionZone = HitShapeUserDataBase.GetHitReactionZone(shape);
      if Equals(zone, EHitReactionZone.Head) {
        isHeadHit = true;
      }
      let part: gameDismBodyPart = HitShapeUserDataBase.GetDismembermentBodyPart(shape);
      let validZone: Bool = false;
      switch zone {
        case EHitReactionZone.ArmLeft:
        case EHitReactionZone.HandLeft:
          validZone = Equals(part, gameDismBodyPart.LEFT_ARM);
          break;
        case EHitReactionZone.ArmRight:
        case EHitReactionZone.HandRight:
          validZone = Equals(part, gameDismBodyPart.RIGHT_ARM);
          break;
        case EHitReactionZone.LegLeft:
          validZone = Equals(part, gameDismBodyPart.LEFT_LEG);
          break;
        case EHitReactionZone.LegRight:
          validZone = Equals(part, gameDismBodyPart.RIGHT_LEG);
          break;
        default:
          break;
      }
      if validZone && !foundLimb && !npc.CLS_IsLimbAlreadyMissingOnPuppet(part) {
        struckLimb = part;
        foundLimb = true;
      }
    }
    index += 1;
  }
  return foundLimb;
}

@addMethod(NPCPuppet)
public final func CLS_ExecuteSaberLimbSever(part: gameDismBodyPart, hitPos: Vector4, isFinalFourthLimb: Bool) -> Void {
  if !this.CLS_IsEligibleSaberTarget() || this.CLS_IsLimbAlreadyMissingOnPuppet(part) {
    return;
  }
  this.CLS_ReserveLimb(part);
  DismembermentComponent.RequestDismemberment(this, part, gameDismWoundType.CLEAN, hitPos, isFinalFourthLimb);
  switch part {
    case gameDismBodyPart.LEFT_ARM:
      StatusEffectHelper.ApplyStatusEffect(this, t"BaseStatusEffect.DismemberedArmLeft");
      break;
    case gameDismBodyPart.RIGHT_ARM:
      StatusEffectHelper.ApplyStatusEffect(this, t"BaseStatusEffect.DismemberedArmRight");
      break;
    case gameDismBodyPart.LEFT_LEG:
      StatusEffectHelper.ApplyStatusEffect(this, t"BaseStatusEffect.DismemberedLegLeft");
      break;
    case gameDismBodyPart.RIGHT_LEG:
      StatusEffectHelper.ApplyStatusEffect(this, t"BaseStatusEffect.DismemberedLegRight");
      break;
    default:
      break;
  }
  this.cls_saberSeveredCount = this.CLS_CountMissingLimbsOnPuppet();
}

// Convert ForceDismembermentEffector limb executions on living human enemies into
// non-lethal living limb loss instead of applying BaseStatusEffect.ForceKill.
@wrapMethod(ForceDismembermentEffector)
protected func ActionOn(owner: ref<GameObject>) -> Void {
  let npc: ref<NPCPuppet> = owner as NPCPuppet;
  if Settings.Enabled() && IsDefined(npc) && npc.CLS_IsEligibleHumanTarget()
    && ScriptedPuppet.IsAlive(npc) && !npc.IsDead() && !npc.IsAboutToDie() {
    let isLimb: Bool = Equals(this.m_bodyPart, gameDismBodyPart.LEFT_ARM)
      || Equals(this.m_bodyPart, gameDismBodyPart.RIGHT_ARM)
      || Equals(this.m_bodyPart, gameDismBodyPart.LEFT_LEG)
      || Equals(this.m_bodyPart, gameDismBodyPart.RIGHT_LEG);
    if isLimb {
      if !npc.CLS_IsLimbAlreadyMissingOnPuppet(this.m_bodyPart) {
        npc.CLS_ReserveLimb(this.m_bodyPart);
        DismembermentComponent.RequestDismemberment(npc, this.m_bodyPart, this.m_woundType, Vector4.EmptyVector(), false);
        switch this.m_bodyPart {
          case gameDismBodyPart.LEFT_ARM:
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.DismemberedArmLeft");
            break;
          case gameDismBodyPart.RIGHT_ARM:
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.DismemberedArmRight");
            break;
          case gameDismBodyPart.LEFT_LEG:
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft");
            break;
          case gameDismBodyPart.RIGHT_LEG:
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
            break;
          default:
            break;
        }
      }
      return;
    }
  }
  wrappedMethod(owner);
}

// Keep direct limb hits from crossing the survivor floor while the native
// dismemberment transaction is being completed. Saber survivor damage also
// receives the same floor for its short DOT protection window.
@wrapMethod(StatPoolsManager)
private final static func ApplyDamageSingle(hitEvent: ref<gameHitEvent>, dmgType: gamedataDamageType, initialDamageValue: Float, forReal: Bool, valuesLost: script_ref<[SDamageDealt]>) -> Void {
  if Settings.Enabled() && IsDefined(hitEvent) && IsDefined(hitEvent.target) && IsDefined(hitEvent.attackData) {
    let npc: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
    if IsDefined(npc) && (npc.CLS_IsEligibleHumanTarget() || npc.CLS_IsEligibleSaberTarget())
      && ScriptedPuppet.IsAlive(npc) && !npc.IsDead() && !npc.IsAboutToDie()
      && !hitEvent.attackData.HasFlag(hitFlag.Nonlethal) {
      let attackData: ref<AttackData> = hitEvent.attackData;
      let isDotOrEffect: Bool = AttackData.IsDoT(attackData)
        || AttackData.IsEffect(attackData.GetAttackType())
        || attackData.HasFlag(hitFlag.DamageOverTime)
        || attackData.HasFlag(hitFlag.BleedingDot);
      let weapon: ref<WeaponObject> = attackData.GetWeapon();
      let isSaberWeapon: Bool = IsDefined(weapon)
        && Equals(weapon.GetItemID().GetTDBID(), t"Items.Saber_DarthVader");

      // A direct lightsaber swing severs only the intact limb represented by
      // one of this hit event's actual limb shapes.
      if forReal && isSaberWeapon && npc.CLS_IsEligibleSaberTarget() && !isDotOrEffect {
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
        let missingBefore: Int32 = npc.CLS_CountMissingLimbsOnPuppet();
        let struckLimb: gameDismBodyPart;
        let saberHeadHit: Bool;
        let validLimbHit: Bool = NPCPuppet.CLS_ResolveStruckLimbFromHitEvent(npc, hitEvent, struckLimb, saberHeadHit);
        if missingBefore < 4 && validLimbHit {
          npc.CLS_ExecuteSaberLimbSever(struckLimb, hitEvent.hitPosition, missingBefore == 3);
          npc.cls_lastSaberSeverTime = now;
          npc.cls_saberSeveredCount = npc.CLS_CountMissingLimbsOnPuppet();
          if missingBefore == 3 {
            StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.ForceKill");
          }
        }
      }

      let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
      let missingLimbs: Int32 = 0;
      let recentSaberSurvivor: Bool = false;
      if npc.cls_saberSeveredCount > 0
        && now - npc.cls_lastSaberSeverTime >= 0.0
        && now - npc.cls_lastSaberSeverTime <= 8.0 {
        missingLimbs = npc.CLS_CountMissingLimbsOnPuppet();
        recentSaberSurvivor = missingLimbs < 4;
      }

      // The saber floor also covers Burning/Electrocuted/Bleeding DOT events,
      // whose AttackData may no longer carry the weapon ID.
      if recentSaberSurvivor {
        npc.cls_forceSurviveCurrentLimbHit = true;
        let targetID: StatsObjectID = Cast<StatsObjectID>(npc.GetEntityID());
        let statPoolsSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(npc.GetGame());
        let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
        if IsDefined(statPoolsSystem) && IsDefined(statsSystem) {
          let currentHealthValue: Float = statPoolsSystem.GetStatPoolValue(targetID, gamedataStatPoolType.Health, false);
          let maxHealth: Float = statsSystem.GetStatValue(targetID, gamedataStatType.Health);
          let minSafeHealth: Float = MaxF(maxHealth * 0.25, 5.0);
          if currentHealthValue > 0.0 && (currentHealthValue - initialDamageValue) < minSafeHealth {
            initialDamageValue = MaxF(0.0, currentHealthValue - minSafeHealth);
          }
        }
      }

      // Preserve the existing wound-floor behavior for non-saber limb hits.
      if !isDotOrEffect && !recentSaberSurvivor {
        let isUnreservedLimbHit: Bool;
        let isHeadHit: Bool = false;
        let struckLimb: gameDismBodyPart;
        isUnreservedLimbHit = NPCPuppet.CLS_ResolveStruckLimbFromHitEvent(npc, hitEvent, struckLimb, isHeadHit);
        if isUnreservedLimbHit {
          npc.cls_lastLimbHitTime = now;
        }

        let inSameBlastLimbWindow: Bool = npc.cls_lastLimbHitTime > 0.0 && (now - npc.cls_lastLimbHitTime) >= 0.0 && (now - npc.cls_lastLimbHitTime) <= 0.25;
        let inPostDismemberGraceWindow: Bool = npc.CLS_IsTrackedSurvivor() && npc.cls_lastLimbDismemberTime > 0.0 && (now - npc.cls_lastLimbDismemberTime) >= 0.0 && (now - npc.cls_lastLimbDismemberTime) <= 1.50;

        if !isHeadHit && (isUnreservedLimbHit || inSameBlastLimbWindow || inPostDismemberGraceWindow) {
          let targetID: StatsObjectID = Cast<StatsObjectID>(npc.GetEntityID());
          let statPoolsSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(npc.GetGame());
          let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
          if IsDefined(statPoolsSystem) && IsDefined(statsSystem) {
            let currentHealthValue: Float = statPoolsSystem.GetStatPoolValue(targetID, gamedataStatPoolType.Health, false);
            let maxHealth: Float = statsSystem.GetStatValue(targetID, gamedataStatType.Health);
            let minSafeHealth: Float = MaxF(maxHealth * Settings.SurvivorHealthFloor(), 1.0);
            if currentHealthValue > 0.0 && (currentHealthValue - initialDamageValue) < minSafeHealth {
              initialDamageValue = MaxF(0.0, currentHealthValue - minSafeHealth);
              if isUnreservedLimbHit || inSameBlastLimbWindow {
                npc.cls_forceSurviveCurrentLimbHit = true;
              }
            }
          }
        }
      }
    }
  }
  wrappedMethod(hitEvent, dmgType, initialDamageValue, forReal, valuesLost);
}
