// Cazanu - bounded, read-only survival follow-up diagnostics.
module CazanuLimbSurvival

public class CLS_SurvivalSnapshotEvent extends Event {
  public let scheduledAfter: Float;
}

@addField(NPCPuppet)
private let cls_followupDiagnosticsStarted: Bool;
@addField(NPCPuppet)
private let cls_woundedEventLogCount: Int32;
@addField(NPCPuppet)
private let cls_forcedDeathLogCount: Int32;
@addField(NPCPuppet)
private let cls_incapacitatedLogCount: Int32;
@addField(NPCPuppet)
private let cls_aiActionLogCount: Int32;
@addField(NPCPuppet)
private let cls_woundedActionLogCount: Int32;

// Core calls this once it has reserved the first surviving limb loss. Events
// only observe this NPC; there is no recurring timer or gameplay-state change.
@addMethod(NPCPuppet)
public final func CLS_StartFollowupDiagnostics() -> Void {
  if !Diagnostics.Enabled() || this.cls_followupDiagnosticsStarted
    || !this.CLS_IsTrackedSurvivor() {
    return;
  }
  this.cls_followupDiagnosticsStarted = true;
  this.CLS_QueueSurvivalSnapshot(0.25);
  this.CLS_QueueSurvivalSnapshot(3.0);
  this.CLS_QueueSurvivalSnapshot(8.0);
}

@addMethod(NPCPuppet)
private final func CLS_QueueSurvivalSnapshot(delay: Float) -> Void {
  let evt = new CLS_SurvivalSnapshotEvent();
  evt.scheduledAfter = delay;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, evt, delay, true);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_SurvivalSnapshotEvent(evt: ref<CLS_SurvivalSnapshotEvent>) -> Bool {
  if !Diagnostics.Enabled() || !this.CLS_IsTrackedSurvivor() {
    return false;
  }
  let id = Cast<StatsObjectID>(this.GetEntityID());
  let health = GameInstance.GetStatPoolsSystem(this.GetGame()).GetStatPoolValue(id, gamedataStatPoolType.Health, false);
  let canUseLegs = GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(id, gamedataStatType.CanUseLegs);
  let armLeft = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedArmLeft")
    || StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedHandLeft");
  let armRight = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedArmRight")
    || StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedHandRight");
  let legLeft = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegLeft");
  let legRight = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegRight");
  let woundType = StatusEffectSystem.ObjectHasStatusEffectOfType(this, gamedataStatusEffectType.Wounded);
  let woundTag = StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"Wounded");
  let context: ScriptExecutionContext;
  let condition = TweakDBInterface.GetAIActionORRecord(t"Condition.WoundedLegs");
  let hasContext = AIHumanComponent.GetScriptContext(this, context);
  let woundedLegsCondition = false;
  if hasContext && IsDefined(condition) {
    woundedLegsCondition = AIScriptUtils.CallCheckSubCondition(context, condition);
  }
  Diagnostics.Write(s"FOLLOWUP npc=\(EntityID.ToDebugString(this.GetEntityID())) after=\(evt.scheduledAfter)s hp=\(health) alive=\(ScriptedPuppet.IsAlive(this)) aboutToDie=\(this.IsAboutToDie()) aboutToDefeat=\(this.IsAboutToBeDefeated()) ragdoll=\(this.IsRagdolling()) armLeft=\(armLeft) armRight=\(armRight) legLeft=\(legLeft) legRight=\(legRight) canUseLegs=\(canUseLegs) woundedType=\(woundType) woundedTag=\(woundTag) aiContext=\(hasContext) woundedLegsRecord=\(IsDefined(condition)) woundedLegsCondition=\(woundedLegsCondition)");
  Diagnostics.Write(s"ACTIVITY npc=\(EntityID.ToDebugString(this.GetEntityID())) after=\(evt.scheduledAfter)s record=\(TDBID.ToStringDEBUG(this.GetRecordID())) \(this.CLS_ActivityState())");
  let effects: array<ref<StatusEffect>>;
  GameInstance.GetStatusEffectSystem(this.GetGame()).GetAppliedEffects(this.GetEntityID(), effects);
  let effectNames = "";
  let effectIndex = 0;
  while effectIndex < ArraySize(effects) && effectIndex < 32 {
    if IsDefined(effects[effectIndex]) && IsDefined(effects[effectIndex].GetRecord()) {
      effectNames += s" [\(TDBID.ToStringDEBUG(effects[effectIndex].GetRecord().GetID()))]";
    }
    effectIndex += 1;
  }
  Diagnostics.Write(s"EFFECTS npc=\(EntityID.ToDebugString(this.GetEntityID())) after=\(evt.scheduledAfter)s total=\(ArraySize(effects)) scanned=\(effectIndex) records=\(effectNames)");
  if evt.scheduledAfter < 1.0 {
    Diagnostics.Write(s"RECORDS npc=\(EntityID.ToDebugString(this.GetEntityID())) armLeft=\(IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.DismemberedArmLeft"))) armRight=\(IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.DismemberedArmRight"))) legLeft=\(IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.DismemberedLegLeft"))) legRight=\(IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.DismemberedLegRight"))) legSequence=\(IsDefined(TweakDBInterface.GetAIActionSequenceRecord(t"StatusEffectActions.DismemberedLegSequence"))) legDeath=\(IsDefined(TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.DismemberedLegDeath")))");
  }
  return true;
}

// Alive alone does not imply an NPC can run combat or wounded behavior.
// Tick/LOD reads are observations; never force an AI tick or change its state.
@addMethod(NPCPuppet)
private final func CLS_ActivityState() -> String {
  let state = s"attached=\(this.IsAttached()) alive=\(ScriptedPuppet.IsAlive(this)) active=\(this.IsActive()) incapacitated=\(this.IsIncapacitated()) defeated=\(ScriptedPuppet.IsDefeated(this)) unconscious=\(ScriptedPuppet.IsUnconscious(this)) turnedOff=\(ScriptedPuppet.IsTurnedOff(this)) highLevel=\(Diagnostics.Enum("gamedataNPCHighLevelState", EnumInt(this.GetHighLevelStateFromBlackboard())))";
  let ai = this.GetAIControllerComponent();
  if IsDefined(ai) {
    state += s" aiPresent=true aiTicks=\(ai.GetUpdateTickCount()) aiLOD=\(ai.GetLOD()) aiHighLevel=\(Diagnostics.Enum("gamedataNPCHighLevelState", EnumInt(ai.GetHighLevelState())))";
  } else {
    state += " aiPresent=false";
  }
  return state;
}

@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  this.CLS_TraceCrawlTransition("incapacitated_enter");
  let trace = Diagnostics.Enabled() && this.CLS_IsTrackedSurvivor()
    && this.cls_incapacitatedLogCount < 8;
  if trace {
    this.cls_incapacitatedLogCount += 1;
    Diagnostics.Write(s"INCAPACITATED_ENTER npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_incapacitatedLogCount)/8 \(this.CLS_ActivityState())");
  }
  wrappedMethod();
  this.CLS_TraceCrawlTransition("incapacitated_exit");
  this.CLS_QueueCrawlDeathSnapshots(false);
  if trace {
    Diagnostics.Write(s"INCAPACITATED_EXIT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_incapacitatedLogCount)/8 \(this.CLS_ActivityState())");
    if this.cls_incapacitatedLogCount == 8 {
      Diagnostics.Write(s"INCAPACITATED_LIMIT npc=\(EntityID.ToDebugString(this.GetEntityID())); further incapacitation traces suppressed.");
    }
  }
}

// Bounded action lifecycle evidence, not a claimed current animation getter.
// Activate starts with phase=Inactive and animationLoaded=false normally;
// a deferred record is unresolved until native Update retries selection.
@addMethod(NPCPuppet)
public final func CLS_LogAIAction(stage: CName, record: wref<AIAction_Record>, phase: EAIActionPhase, initialized: Bool, animationLoaded: Bool, failed: Bool, retryPending: Bool) -> Void {
  if !Diagnostics.Enabled() || !this.CLS_IsTrackedSurvivor()
    || (this.cls_aiActionLogCount >= 32 && this.cls_woundedActionLogCount >= 24) {
    return;
  }
  let recordName = "unresolved";
  if IsDefined(record) && !retryPending {
    recordName = TDBID.ToStringDEBUG(record.GetID());
  }
  // Preserve status-effect action evidence even when ordinary combat actions
  // exhaust the general budget before a wound reaction completes.
  if (StrContains(recordName, "StatusEffectActions.") || StrContains(recordName, "CazanuLimbSurvival.")) && this.cls_woundedActionLogCount < 24 {
    this.cls_woundedActionLogCount += 1;
    Diagnostics.Write(s"AI_WOUNDED_ACTION npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_woundedActionLogCount)/24 stage=\(NameToString(stage)) record=\(recordName) phase=\(Diagnostics.Enum("EAIActionPhase", EnumInt(phase))) initialized=\(initialized) failed=\(failed)");
    if this.cls_woundedActionLogCount == 24 {
      Diagnostics.Write(s"AI_WOUNDED_ACTION_LIMIT npc=\(EntityID.ToDebugString(this.GetEntityID())); further status-effect action traces suppressed.");
    }
  }
  if this.cls_aiActionLogCount >= 32 {
    return;
  }
  this.cls_aiActionLogCount += 1;
  Diagnostics.Write(s"AI_ACTION npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_aiActionLogCount)/32 stage=\(NameToString(stage)) record=\(recordName) phase=\(Diagnostics.Enum("EAIActionPhase", EnumInt(phase))) initialized=\(initialized) animationLoaded=\(animationLoaded) failed=\(failed) retryPending=\(retryPending)");
  if this.cls_aiActionLogCount == 32 {
    Diagnostics.Write(s"AI_ACTION_LIMIT npc=\(EntityID.ToDebugString(this.GetEntityID())); further action traces suppressed; absence after this line is not inactivity.");
  }
}

@wrapMethod(TweakAIActionAbstract)
protected func Activate(context: ScriptExecutionContext) -> Void {
  wrappedMethod(context);
  if Diagnostics.Enabled() {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if IsDefined(npc) {
      npc.CLS_LogAIAction(n"activate", this.m_actionRecord, this.m_actionPhase, this.m_initializedAfterActivation, this.m_animationLoaded, this.m_failureStatus, this.m_shouldCallGetActionRecordAgain);
    }
  }
}

@wrapMethod(TweakAIActionAbstract)
protected func Deactivate(context: ScriptExecutionContext) -> Void {
  if Diagnostics.Enabled() {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if IsDefined(npc) {
      npc.CLS_LogAIAction(n"deactivate", this.m_actionRecord, this.m_actionPhase, this.m_initializedAfterActivation, this.m_animationLoaded, this.m_failureStatus, this.m_shouldCallGetActionRecordAgain);
    }
  }
  wrappedMethod(context);
}

@addMethod(NPCPuppet)
private final func CLS_ShouldLogWoundedEvent(record: ref<StatusEffect_Record>) -> Bool {
  if !Diagnostics.Enabled() || !this.CLS_IsTrackedSurvivor()
    || this.cls_woundedEventLogCount >= 16 || !IsDefined(record)
    || !IsDefined(record.StatusEffectType()) {
    return false;
  }
  if NotEquals(record.StatusEffectType().Type(), gamedataStatusEffectType.Wounded) {
    return false;
  }
  this.cls_woundedEventLogCount += 1;
  return true;
}

@wrapMethod(NPCPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  if this.CLS_ShouldLogWoundedEvent(evt.staticData) {
    Diagnostics.Write(s"WOUND_APPLY npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_woundedEventLogCount)/16 record=\(TDBID.ToStringDEBUG(evt.staticData.GetID())) new=\(evt.isNewApplication) stacks=\(evt.stackCount)");
  }
  return wrappedMethod(evt);
}

@wrapMethod(NPCPuppet)
protected cb func OnStatusEffectRemoved(evt: ref<RemoveStatusEffect>) -> Bool {
  if this.CLS_ShouldLogWoundedEvent(evt.staticData) {
    Diagnostics.Write(s"WOUND_REMOVE npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_woundedEventLogCount)/16 record=\(TDBID.ToStringDEBUG(evt.staticData.GetID())) final=\(evt.isFinalRemoval) stacks=\(evt.stackCount)");
  }
  return wrappedMethod(evt);
}

@addMethod(NPCPuppet)
public final func CLS_LogAIForcedDeath(record: wref<AISubActionForceDeath_Record>) -> Void {
  if !Diagnostics.Enabled() || !this.CLS_IsTrackedSurvivor()
    || this.cls_forcedDeathLogCount >= 8 || !IsDefined(record) {
    return;
  }
  this.cls_forcedDeathLogCount += 1;
  let deathAction = TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.DismemberedLegDeath");
  let fromLegDeath = IsDefined(deathAction) && deathAction.LoopSubActionsContains(record);
  let fromExtendedLegDeath = Equals(record.GetID(), t"CazanuLimbSurvival.LegFinalDeath");
  let health = GameInstance.GetStatPoolsSystem(this.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatPoolType.Health, false);
  Diagnostics.Write(s"AI_FORCE_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_forcedDeathLogCount)/8 record=\(TDBID.ToStringDEBUG(record.GetID())) fromDismemberedLegDeath=\(fromLegDeath) fromExtendedLegDeath=\(fromExtendedLegDeath) delay=\(record.Delay()) hp=\(health) alive=\(ScriptedPuppet.IsAlive(this)) aboutToDie=\(this.IsAboutToDie())");
}

@wrapMethod(AISubActionForceDeath_Record_Implementation)
public static func ForceDeath(context: ScriptExecutionContext, record: wref<AISubActionForceDeath_Record>) -> Void {
  if Diagnostics.Enabled() {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if IsDefined(npc) {
      npc.CLS_LogAIForcedDeath(record);
    }
  }
  // Observe the native request; never cancel, duplicate, or delay it.
  wrappedMethod(context, record);
}

// Cazanu: bounded observations only. Terminal hits have their own budget so
// opening shotgun pellets cannot consume the evidence of a later execution.
public class CLS_CrawlDeathSnapshotEvent extends Event {
  public let afterSeconds: Float;
  public let confirmedDeath: Bool;
}

@addField(NPCPuppet)
private let cls_crawlTransitionLogs: Int32;
@addField(NPCPuppet)
private let cls_crawlDeathSnapshotsQueued: Bool;
@addField(NPCPuppet)
private let cls_crawlIncapSnapshotsQueued: Bool;
@addField(NPCPuppet)
private let cls_crawlDeathEventLogged: Bool;
@addField(HitReactionComponent)
private let cls_crawlHitLogs: Int32;
@addField(HitReactionComponent)
private let cls_crawlTerminalHitLogs: Int32;
@addField(HitReactionComponent)
private let cls_crawlAIReactionLogs: Int32;
@addField(HitReactionComponent)
private let cls_crawlTerminalAIReactionLogs: Int32;

@addMethod(NPCPuppet)
public final func CLS_IsDiagnosticCrawler() -> Bool {
  return Diagnostics.Enabled() && this.IsAttached() && this.CLS_IsTrackedSurvivor()
    && this.cls_legWoundMode == 1 && this.cls_extendedWoundStarted;
}

@addMethod(NPCPuppet)
public final func CLS_TraceCrawlTransition(stage: String) -> Void {
  if !this.CLS_IsDiagnosticCrawler() || this.cls_crawlTransitionLogs >= 48 { return; }
  this.cls_crawlTransitionLogs += 1;
  let hp = GameInstance.GetStatPoolsSystem(this.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatPoolType.Health, false);
  let slot = this.GetPuppetStateBlackboard().GetBool(GetAllBlackboardDefs().PuppetState.SlotAnimationInProgress);
  let position = this.GetWorldPosition();
  Diagnostics.Write(s"CRAWL_TRANSITION npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_crawlTransitionLogs)/48 stage=\(stage) hp=\(hp) aboutToDie=\(this.IsAboutToDie()) aboutToDefeat=\(this.IsAboutToBeDefeated()) ragdoll=\(this.IsRagdolling()) canRagdoll=\(ScriptedPuppet.CanRagdoll(this)) skipDeathAnimation=\(this.ShouldSkipDeathAnimation()) timedDeath=\(this.cls_groundedTimedDeath) crawlPreempted=\(this.cls_crawlDeadlinePreempted) woundPreempted=\(this.CLS_WoundDeadlinePreempted()) motion=\(this.cls_crawlMotionStarted) obstructed=\(this.cls_crawlMotionObstructed) workspot=\(GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this)) slot=\(slot) position=\(position.X),\(position.Y),\(position.Z) \(this.CLS_ActivityState())");
}

@addMethod(NPCPuppet)
private final func CLS_QueueCrawlDeathSnapshots(confirmedDeath: Bool) -> Void {
  if !this.CLS_IsDiagnosticCrawler() { return; }
  if confirmedDeath {
    if this.cls_crawlDeathSnapshotsQueued { return; }
    this.cls_crawlDeathSnapshotsQueued = true;
  } else {
    if this.cls_crawlIncapSnapshotsQueued { return; }
    this.cls_crawlIncapSnapshotsQueued = true;
  }
  let delays: array<Float> = [0.1, 0.5, 1.5];
  let index = 0;
  while index < ArraySize(delays) {
    let evt = new CLS_CrawlDeathSnapshotEvent();
    evt.afterSeconds = delays[index];
    evt.confirmedDeath = confirmedDeath;
    GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, evt, delays[index], true);
    index += 1;
  }
}

@addMethod(NPCPuppet)
protected cb func OnCLS_CrawlDeathSnapshotEvent(evt: ref<CLS_CrawlDeathSnapshotEvent>) -> Bool {
  this.CLS_TraceCrawlTransition(s"snapshot_after_\(evt.afterSeconds)s_confirmedDeath=\(evt.confirmedDeath)");
  return true;
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let trace = this.CLS_IsDiagnosticCrawler() && !this.cls_crawlDeathEventLogged;
  if trace {
    this.cls_crawlDeathEventLogged = true;
    this.CLS_TraceCrawlTransition("death_event_enter");
  }
  let result = wrappedMethod(evt);
  if trace {
    this.CLS_TraceCrawlTransition("death_event_exit");
    this.CLS_QueueCrawlDeathSnapshots(true);
  }
  return result;
}

@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  let npc = this.m_ownerNPC;
  let trace = IsDefined(npc) && npc.CLS_IsDiagnosticCrawler() && IsDefined(this.m_attackData);
  if trace {
    let terminal = this.m_attackData.HasFlag(hitFlag.WasKillingBlow) || npc.IsAboutToDie()
      || !ScriptedPuppet.IsAlive(npc) || Equals(this.m_reactionType, animHitReactionType.Death);
    if terminal {
      trace = this.cls_crawlTerminalHitLogs < 4;
      if trace { this.cls_crawlTerminalHitLogs += 1; }
    } else {
      trace = this.cls_crawlHitLogs < 4;
      if trace { this.cls_crawlHitLogs += 1; }
    }
  }
  if trace { this.CLS_TraceCrawlHit("enter"); }
  wrappedMethod();
  if trace { this.CLS_TraceCrawlHit("exit"); }
}

@addMethod(HitReactionComponent)
private final func CLS_TraceCrawlHit(stage: String) -> Void {
  let shape = this.GetHitShapeUserData();
  let zone = "missing";
  if IsDefined(shape) { zone = Diagnostics.Enum("EHitReactionZone", EnumInt(HitShapeUserDataBase.GetHitReactionZone(shape))); }
  Diagnostics.Write(s"CRAWL_HIT npc=\(EntityID.ToDebugString(this.m_ownerNPC.GetEntityID())) stage=\(stage) zone=\(zone) killingBlow=\(this.m_attackData.HasFlag(hitFlag.WasKillingBlow)) reaction=\(Diagnostics.Enum("animHitReactionType", EnumInt(this.m_reactionType))) defeatedPlayed=\(this.GetDefeatedHasBeenPlayed()) deathPlayed=\(this.GetDeathHasBeenPlayed())");
  this.m_ownerNPC.CLS_TraceCrawlTransition("hit_" + stage);
}

// This observes the same inputs used by Ragdoll Execution Fix. It neither
// replaces that mod nor assumes wrapper order proves which route it selected.
@wrapMethod(HitReactionComponent)
private final func SendDataToAIBehavior(reactionPlayed: animHitReactionType) -> Void {
  let npc = this.m_ownerNPC;
  let trace = IsDefined(npc) && npc.CLS_IsDiagnosticCrawler();
  if trace {
    if Equals(reactionPlayed, animHitReactionType.Death) || Equals(reactionPlayed, animHitReactionType.Ragdoll) {
      trace = this.cls_crawlTerminalAIReactionLogs < 4;
      if trace { this.cls_crawlTerminalAIReactionLogs += 1; }
    } else {
      trace = this.cls_crawlAIReactionLogs < 4;
      if trace { this.cls_crawlAIReactionLogs += 1; }
    }
  }
  if trace {
    Diagnostics.Write(s"CRAWL_AI_REACTION npc=\(EntityID.ToDebugString(npc.GetEntityID())) stage=enter reaction=\(Diagnostics.Enum("animHitReactionType", EnumInt(reactionPlayed))) defeatedPlayed=\(this.GetDefeatedHasBeenPlayed()) deathPlayed=\(this.GetDeathHasBeenPlayed()) canRagdoll=\(ScriptedPuppet.CanRagdoll(npc))");
  }
  wrappedMethod(reactionPlayed);
  if trace {
    Diagnostics.Write(s"CRAWL_AI_REACTION npc=\(EntityID.ToDebugString(npc.GetEntityID())) stage=exit lastStim=\(NameToString(this.m_lastStimName)) deathStim=\(NameToString(this.m_deathStimName))");
  }
}
