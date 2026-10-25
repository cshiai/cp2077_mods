// RelentlessLiveDismember by Cazanu - diagnostics disabled in the release build.
module CazanuLimbSurvival

public abstract class Diagnostics {
  public static func Enabled() -> Bool = false
  public static func HitsPerNPC() -> Int32 = 12

  public static func Enum(typeName: String, value: Int32) -> String {
    return EnumValueToString(typeName, Cast<Int64>(value));
  }

  public static func Write(message: String) -> Void {
    if Diagnostics.Enabled() {
      FTLog("[LimbSurvival] " + message);
    }
  }
}

@addField(HitReactionComponent)
private let cls_diagHits: Int32;
@addField(HitReactionComponent)
private let cls_diagActive: Bool;
@addField(HitReactionComponent)
private let cls_diagFleshCalled: Bool;
@addField(HitReactionComponent)
private let cls_diagCyberCalled: Bool;
@addField(HitReactionComponent)
private let cls_diagNativeDismember: Bool;
@addField(HitReactionComponent)
private let cls_diagNativeWoundBase: Bool;
@addField(HitReactionComponent)
private let cls_diagSurvivalSelected: Bool;
@addField(HitReactionComponent)
private let cls_diagBodyPerk: Bool;

// An outer trace also catches paths which return BEFORE either wound condition,
// notably shotgun Body-perk executions. Never change or repeat the native call.
@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  if !Diagnostics.Enabled() || this.cls_diagHits >= Diagnostics.HitsPerNPC()
    || !IsDefined(this.m_ownerNPC) || !IsDefined(this.m_attackData) {
    wrappedMethod();
    return;
  }
  let instigator = this.m_attackData.GetInstigator();
  if !IsDefined(instigator) || !instigator.IsPlayer() {
    wrappedMethod();
    return;
  }
  this.cls_diagHits += 1;
  this.cls_diagActive = true;
  this.cls_diagFleshCalled = false;
  this.cls_diagCyberCalled = false;
  this.cls_diagNativeDismember = false;
  this.cls_diagNativeWoundBase = false;
  this.cls_diagSurvivalSelected = false;
  this.cls_diagBodyPerk = false;
  this.CLS_LogHitStart();

  wrappedMethod();

  let npc = this.m_ownerNPC;
  Diagnostics.Write(s"END npc=\(EntityID.ToDebugString(npc.GetEntityID())) hit=\(this.cls_diagHits) fleshCheck=\(this.cls_diagFleshCalled) cyberCheck=\(this.cls_diagCyberCalled) nativeDismember=\(this.cls_diagNativeDismember) nativeWoundBase=\(this.cls_diagNativeWoundBase) survivalSelected=\(this.cls_diagSurvivalSelected) bodyPerkExecuted=\(this.cls_diagBodyPerk) aliveFlag=\(this.m_isAlive) actualAlive=\(ScriptedPuppet.IsAlive(npc)) aboutToDie=\(npc.IsAboutToDie()) reaction=\(Diagnostics.Enum("animHitReactionType", EnumInt(this.m_reactionType)))");
  this.cls_diagActive = false;
  if this.cls_diagHits == Diagnostics.HitsPerNPC() {
    Diagnostics.Write(s"LIMIT npc=\(EntityID.ToDebugString(npc.GetEntityID())); further hit logs suppressed for this NPC.");
  }
}

@wrapMethod(HitReactionComponent)
protected final func ProcessBodyPerkDismembement() -> Void {
  if this.cls_diagActive {
    this.cls_diagBodyPerk = true;
  }
  wrappedMethod();
}

@addMethod(HitReactionComponent)
private final func CLS_LogHitStart() -> Void {
  let npc = this.m_ownerNPC;
  let shape = this.GetHitShapeUserData();
  let shapeInfo = "shape=missing";
  let woundDamage: Float = -1.0;
  let dismemberDamage: Float = -1.0;
  let threshold: Float = -1.0;
  let maxHealth = this.GetOwnerTotalHealth();
  if IsDefined(shape) {
    let zone = HitShapeUserDataBase.GetHitReactionZone(shape);
    let part = HitShapeUserDataBase.GetDismembermentBodyPart(shape);
    let index = EnumInt(zone);
    shapeInfo = s"zone=\(Diagnostics.Enum("EHitReactionZone", index)) part=\(Diagnostics.Enum("gameDismBodyPart", EnumInt(part))) material=\(Diagnostics.Enum("EHitShapeType", EnumInt(shape.GetShapeType())))";
    if index >= 0 && index < ArraySize(this.m_bodyPartWoundCumulatedDamages) {
      woundDamage = this.m_bodyPartWoundCumulatedDamages[index];
    }
    if index >= 0 && index < ArraySize(this.m_bodyPartDismemberCumulatedDamages) {
      dismemberDamage = this.m_bodyPartDismemberCumulatedDamages[index];
    }
    if Equals(part, gameDismBodyPart.LEFT_ARM) || Equals(part, gameDismBodyPart.RIGHT_ARM) {
      threshold = maxHealth * Settings.ArmThreshold();
    } else {
      if Equals(part, gameDismBodyPart.LEFT_LEG) || Equals(part, gameDismBodyPart.RIGHT_LEG) {
        threshold = maxHealth * Settings.LegThreshold();
      }
    }
  }
  let weaponInfo = "weapon=none";
  let weapon = this.m_attackData.GetWeapon();
  if IsDefined(weapon) {
    weaponInfo = s"weapon=\(TDBID.ToStringDEBUG(weapon.GetItemID().GetTDBID()))";
    if IsDefined(this.m_statsSystem) {
      let weaponID = Cast<StatsObjectID>(weapon.GetEntityID());
      let woundFactor = this.m_statsSystem.GetStatValue(weaponID, gamedataStatType.HitWoundsFactor);
      let reactionFactor = this.m_statsSystem.GetStatValue(weaponID, gamedataStatType.HitReactionFactor);
      weaponInfo += s" woundFactor=\(woundFactor) reactionFactor=\(reactionFactor)";
    }
  }
  let health = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, false);
  let frameReaction = npc.GetTotalFrameDamage();
  let reason = this.CLS_LimbBlockReason();
  shapeInfo += s" killingBlow=\(this.m_attackData.HasFlag(hitFlag.WasKillingBlow)) frameWoundDamage=\(npc.GetTotalFrameWoundsDamage())";
  Diagnostics.Write(s"BEGIN npc=\(EntityID.ToDebugString(npc.GetEntityID())) record=\(TDBID.ToStringDEBUG(npc.GetRecordID())) hit=\(this.cls_diagHits) \(weaponInfo) \(shapeInfo) hp=\(health)/\(maxHealth) frameReaction=\(frameReaction) oldGuardWouldReject=\(health - frameReaction <= 0.0) woundDamage=\(woundDamage) required=\(threshold) dismemberDamage=\(dismemberDamage) reason=\(NameToString(reason))");
  Diagnostics.Write(s"STATE npc=\(EntityID.ToDebugString(npc.GetEntityID())) aliveFlag=\(this.m_isAlive) actualAlive=\(ScriptedPuppet.IsAlive(npc)) aboutToDie=\(npc.IsAboutToDie()) aboutToDefeat=\(npc.IsAboutToBeDefeated()) defeated=\(ScriptedPuppet.IsDefeated(npc)) canDie=\(this.CanDieCondition()) human=\(npc.IsHuman()) civilian=\(npc.IsCharacterCivilian()) crowd=\(npc.IsCrowd()) hasDismemberment=\(IsDefined(npc.GetDismembermentComponent())) cover=\(this.m_inCover) workspot=\(this.m_inWorkspot) reaction=\(Diagnostics.Enum("animHitReactionType", EnumInt(this.m_reactionType))) attack=\(Diagnostics.Enum("gamedataAttackType", EnumInt(this.m_attackData.GetAttackType()))) forceDismember=\(this.m_attackData.HasFlag(hitFlag.ForceDismember)) nonlethal=\(this.m_attackData.HasFlag(hitFlag.Nonlethal))");
}
