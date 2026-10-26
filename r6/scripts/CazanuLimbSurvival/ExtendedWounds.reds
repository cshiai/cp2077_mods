// RelentlessLiveDismember by Cazanu - crawl40/50s, pain60s, or seated shooting25s.
module CazanuLimbSurvival

// Entity event service is fenced from the physics flush phase. Keep physical
// obstacle rays here, as with CrawlBlood's contact event, never in a system.
public class CLS_CrawlObstacleProbe extends Event {
  public let owner: wref<NPCPuppet>;
  public let generation: Int32;
  public let center: Vector4;
  public let forward: Vector4;
  public let time: Float;
}

public abstract class WoundTiming {
  public static func TotalSeconds() -> Float = 60.0
  public static func CrawlShortSeconds() -> Float = 40.0
  public static func CrawlLongSeconds() -> Float = 50.0
  public static func CrawlBlockedSeconds() -> Float = 3.0
  public static func ShootSeconds() -> Float = 25.0
  public static func ObstacleProbeCooldownSeconds() -> Float = 0.35

  public static func IsSequence(id: TweakDBID) -> Bool {
    return Equals(id, t"CazanuLimbSurvival.LegCrawlSequence")
      || Equals(id, t"CazanuLimbSurvival.LegStruggleSequence");
  }

  public static func Ready() -> Bool {
    return TweakDBInterface.GetBool(t"CazanuLimbSurvival.ExtendedSequenceReady", false);
  }

  public static func Eligible(npc: wref<NPCPuppet>) -> Bool {
    return Settings.Enabled() && IsDefined(npc) && npc.CLS_IsTrackedSurvivor()
      && npc.IsAttached() && ScriptedPuppet.IsAlive(npc) && npc.IsActive()
      && !npc.IsDead() && !npc.IsAboutToDie()
      && (npc.CLS_IsLimbReserved(gameDismBodyPart.LEFT_LEG)
        || npc.CLS_IsLimbReserved(gameDismBodyPart.RIGHT_LEG)
        || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft")
        || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight"));
  }
}

// TweakXL invokes this after TweakDB initialization. Only private records are
// created/edited: all source records and their shared child records stay intact.
// Resolve child IDs through the current records, never hard-code inline indices.
public class CLS_ExtendedWoundTweak extends ScriptableTweak {
  protected cb func OnApply() -> Void {
    TweakDBManager.SetFlat(n"CazanuLimbSurvival.ExtendedSequenceReady", false);
    if this.BuildSequence() {
      TweakDBManager.SetFlat(n"CazanuLimbSurvival.ExtendedSequenceReady", true);
    }
  }

  private func Clone(name: CName, source: TweakDBID) -> Bool {
    if IsDefined(TweakDBInterface.GetRecord(TDBID.Create(NameToString(name)))) {
      return true;
    }
    return TweakDBManager.CloneRecord(name, source);
  }

  private func TimedLoop(id: TweakDBID, duration: Float) -> Bool {
    let ok = TweakDBManager.SetFlat(id + t".duration", duration);
    ok = TweakDBManager.SetFlat(id + t".maxDuration", duration) && ok;
    // This helper configures a single timed phase. It does not replay clips.
    // Crawl replays clips; the pain controller supplies its own workspot.
    ok = TweakDBManager.SetFlat(id + t".animationDuration", 0.0) && ok;
    ok = TweakDBManager.SetFlat(id + t".useDurationFromAnimSlot", false) && ok;
    ok = TweakDBManager.SetFlat(id + t".repeat", -1) && ok;
    ok = TweakDBManager.UpdateRecord(id) && ok;
    let phase = TweakDBInterface.GetAIActionPhaseRecord(id);
    return ok && IsDefined(phase) && phase.Duration() == duration
      && phase.AnimationDuration() == 0.0 && !phase.UseDurationFromAnimSlot()
      && phase.Repeat() == -1;
  }

  private func RepeatingCrawl(id: TweakDBID, fallbackDuration: Float) -> Bool {
    let ok = this.TimedLoop(id, fallbackDuration);
    // Repeat=0 repeats this phase; -1 plays it only once. The actual clip
    // duration drives each cycle; the per-NPC timer ends the crawl at 40 or 50s.
    ok = TweakDBManager.SetFlat(id + t".useDurationFromAnimSlot", true) && ok;
    ok = TweakDBManager.SetFlat(id + t".repeat", 0) && ok;
    // The native motion controller checks the actual next movement step.
    // A separate progress watchdog handles a sustained nearby obstruction;
    // the old two-metre predicate must not cancel travel on clear ground.
    let noConditions: array<TweakDBID>;
    ok = TweakDBManager.SetFlat(id + t".toNextPhaseCondition", noConditions) && ok;
    ok = TweakDBManager.UpdateRecord(id) && ok;
    let phase = TweakDBInterface.GetAIActionPhaseRecord(id);
    return ok && IsDefined(phase) && phase.UseDurationFromAnimSlot()
      && phase.Repeat() == 0 && phase.Duration() == fallbackDuration
      && phase.GetToNextPhaseConditionCount() == 0;
  }

  private func BuildSequence() -> Bool {
    let crawl = TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.WoundedCrawlForward");
    // Keep the timed action free of slot animation so the scoped pain
    // workspot controller can supply a compatible grounded wounded loop.
    // Native wounded locomotion remains the fallback if loading fails.
    let struggle = TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.WoundedLegReactionDelay");
    let woundEntry = TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.SE_WoundedCyberLLegEntryDefinition");
    let death = TweakDBInterface.GetAIActionRecord(t"StatusEffectActions.DismemberedLegDeath");
    let sequence = TweakDBInterface.GetAIActionSequenceRecord(t"StatusEffectActions.DismemberedLegSequence");
    if !IsDefined(crawl) || !IsDefined(struggle) || !IsDefined(woundEntry)
      || !IsDefined(death) || !IsDefined(sequence) {
      return false;
    }
    if !IsDefined(crawl.Loop()) || !IsDefined(struggle.Loop()) || !IsDefined(woundEntry.AnimData())
      || !IsDefined(crawl.AnimData()) || !IsDefined(crawl.AnimData().AnimSlot()) {
      return false;
    }
    // The scoped crawl launcher below supports the native no-slide action.
    // Fail closed if a future game changes it to require slide targets.
    if IsDefined(crawl.AnimData().AnimSlot().StartupSlide())
      || IsDefined(crawl.AnimData().AnimSlot().LoopSlide())
      || IsDefined(crawl.AnimData().AnimSlot().RecoverySlide())
      || crawl.Loop().GetToNextPhaseConditionCount() == 0 {
      return false;
    }

    // All edits are private; the original crawl retains its path predicate.
    if !this.Clone(n"CazanuLimbSurvival.LegCrawlLoop", crawl.Loop().GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegCrawl", crawl.GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegStruggleLoop", struggle.Loop().GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegStruggle", struggle.GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegStruggleAnimData", woundEntry.AnimData().GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegCrawlSequence", sequence.GetID())
      || !this.Clone(n"CazanuLimbSurvival.LegStruggleSequence", sequence.GetID()) {
      return false;
    }
    let crawlFallback = MaxF(0.1, crawl.Loop().Duration());
    let ok = this.RepeatingCrawl(t"CazanuLimbSurvival.LegCrawlLoop", crawlFallback);
    ok = this.TimedLoop(t"CazanuLimbSurvival.LegStruggleLoop", WoundTiming.TotalSeconds() + 0.5) && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegCrawl.loop", t"CazanuLimbSurvival.LegCrawlLoop") && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggle.loop", t"CazanuLimbSurvival.LegStruggleLoop") && ok;
    // The pain controller owns animation. Launching SE_DefeatedLoop here
    // would compete with its workspot and roll a prone NPC onto their back.
    // Retain ragdollOnDeath for lethal follow-up hits. Native SendAnimData
    // returns immediately for an empty feature, so this data never launches
    // a slot animation or replaces the wounded locomotion underneath it.
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggleAnimData.animFeature", n"") && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggleAnimData.animSlot", TDBID.None()) && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggleAnimData.ragdollOnDeath", true) && ok;
    ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegStruggleAnimData") && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggle.animData", t"CazanuLimbSurvival.LegStruggleAnimData") && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggle.startup", TDBID.None()) && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegCrawl.allowBlendDuration", 0.0) && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggle.allowBlendDuration", 0.0) && ok;

    let subActions: array<TweakDBID>;
    let forceCount = 0;
    let i = 0;
    while i < death.GetLoopSubActionsCount() {
      let subAction = death.GetLoopSubActionsItem(i);
      if IsDefined(subAction as AISubActionForceDeath_Record) {
        forceCount += 1;
        if !this.Clone(n"CazanuLimbSurvival.LegFinalDeath", subAction.GetID()) {
          return false;
        }
        // Positive delay prevents native Activate/Deactivate from killing.
        // The scoped Update below uses the overall per-NPC deadline instead.
        ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegFinalDeath.delay", WoundTiming.TotalSeconds()) && ok;
        // Do not reuse the shotgun hit's heavy intensity for the timed finish.
        ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegFinalDeath.hitIntensity", EnumInt(EAIHitIntensity.Light)) && ok;
        ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegFinalDeath") && ok;
        ArrayPush(subActions, t"CazanuLimbSurvival.LegFinalDeath");
      }
      i += 1;
    }
    // Do not activate an incomplete sequence if the game changes its death path.
    if forceCount != 1 {
      return false;
    }
    // Keep the chosen pose until death. Do not copy the electric FX or play
    // SE_WoundedDeath: both belonged to the discarded cyber-limb ending.
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggle.loopSubActions", subActions) && ok;
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegCrawl.loopSubActions", subActions) && ok;
    ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegCrawl") && ok;
    ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegStruggle") && ok;
    let actions: array<TweakDBID>;
    ArrayPush(actions, t"StatusEffectActions.WoundedLegReactionDelay");
    ArrayPush(actions, t"CazanuLimbSurvival.LegCrawl");
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegCrawlSequence.actions", actions) && ok;
    ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegCrawlSequence") && ok;
    actions[1] = t"CazanuLimbSurvival.LegStruggle";
    ok = TweakDBManager.SetFlat(t"CazanuLimbSurvival.LegStruggleSequence.actions", actions) && ok;
    ok = TweakDBManager.UpdateRecord(t"CazanuLimbSurvival.LegStruggleSequence") && ok;
    let finalCrawl = TweakDBInterface.GetAIActionRecord(t"CazanuLimbSurvival.LegCrawl");
    let finalStruggle = TweakDBInterface.GetAIActionRecord(t"CazanuLimbSurvival.LegStruggle");
    let crawlSequence = TweakDBInterface.GetAIActionSequenceRecord(t"CazanuLimbSurvival.LegCrawlSequence");
    let painSequence = TweakDBInterface.GetAIActionSequenceRecord(t"CazanuLimbSurvival.LegStruggleSequence");
    return ok && IsDefined(finalCrawl.Loop()) && IsDefined(finalStruggle.Loop())
      && !IsDefined(finalCrawl.Startup()) && !IsDefined(finalCrawl.Recovery())
      && !IsDefined(finalStruggle.Startup()) && !IsDefined(finalStruggle.Recovery())
      && IsDefined(finalStruggle.AnimData())
      && !IsNameValid(finalStruggle.AnimData().AnimFeature())
      && !IsDefined(finalStruggle.AnimData().AnimSlot()) && finalStruggle.AnimData().RagdollOnDeath()
      && crawlSequence.GetActionsCount() == 2 && painSequence.GetActionsCount() == 2
      && Equals(crawlSequence.GetActionsItem(1).GetID(), t"CazanuLimbSurvival.LegCrawl")
      && Equals(painSequence.GetActionsItem(1).GetID(), t"CazanuLimbSurvival.LegStruggle")
      && Equals(finalCrawl.Loop().GetID(), t"CazanuLimbSurvival.LegCrawlLoop")
      && finalCrawl.Loop().Duration() == crawlFallback
      && finalCrawl.Loop().UseDurationFromAnimSlot() && finalCrawl.Loop().Repeat() == 0
      && finalCrawl.Loop().GetToNextPhaseConditionCount() == 0
      && finalCrawl.GetLoopSubActionsCount() == 1
      && Equals(finalCrawl.GetLoopSubActionsItem(0).GetID(), t"CazanuLimbSurvival.LegFinalDeath")
      && Equals(finalStruggle.Loop().GetID(), t"CazanuLimbSurvival.LegStruggleLoop")
      && finalStruggle.Loop().Duration() == WoundTiming.TotalSeconds() + 0.5
      && finalStruggle.GetLoopSubActionsCount() == 1
      && Equals(finalStruggle.GetLoopSubActionsItem(0).GetID(), t"CazanuLimbSurvival.LegFinalDeath");
  }
}

@addField(NPCPuppet)
private let cls_legWoundMode: Int32;
@addField(NPCPuppet)
private let cls_crawlWoundSeconds: Float;
@addField(NPCPuppet)
private let cls_legWoundGun: wref<WeaponObject>;
@addField(NPCPuppet)
private let cls_extendedWoundStarted: Bool;
@addField(NPCPuppet)
private let cls_extendedWoundStartTime: Float;
@addField(NPCPuppet)
private let cls_extendedWoundUnavailableLogged: Bool;
@addField(NPCPuppet)
private let cls_extendedPhaseLogCount: Int32;
@addField(NPCPuppet)
private let cls_groundedTimedDeath: Bool;
@addField(NPCPuppet)
private let cls_groundedTimedDeathAt: Float;
@addField(NPCPuppet)
private let cls_crawlMotionStarted: Bool;
@addField(NPCPuppet)
private let cls_crawlMotionSampleAt: Float;
@addField(NPCPuppet)
private let cls_crawlMotionAnchor: Vector4;
@addField(NPCPuppet)
private let cls_crawlMotionObstructed: Bool;
@addField(NPCPuppet)
private let cls_crawlMotionBlockedAt: Float;
@addField(NPCPuppet)
private let cls_crawlMotionLogCount: Int32;
@addField(NPCPuppet)
private let cls_crawlDeadlinePreempted: Bool;
@addField(NPCPuppet)
private let cls_crawlProbePending: Bool;
@addField(NPCPuppet)
private let cls_crawlProbeGeneration: Int32;
@addField(NPCPuppet)
private let cls_crawlProbeQueuedAt: Float;
@addField(NPCPuppet)
private let cls_crawlProbeBlocked: Bool;
@addField(NPCPuppet)
private let cls_crawlProbeTime: Float;
@addField(NPCPuppet)
private let cls_crawlProbePosition: Vector4;
@addField(NPCPuppet)
private let cls_crawlProbeForward: Vector4;

// Cazanu: a lethal follow-up on an active crawler must settle from its current
// pose. This latch records native death intent; it never kills or defeats an NPC.
@addField(NPCPuppet)
private let cls_crawlDamageDeath: Bool;
@addField(NPCPuppet)
private let cls_groundedDeathRagdollQueued: Bool;

public class CLS_GroundedDeathRagdollEvent extends Event {
  public let attempts: Int32;
}

@addMethod(NPCPuppet)
private final func CLS_PrepareCrawlDamageDeath() -> Void {
  if this.cls_crawlDamageDeath || !Settings.Enabled() || !this.IsAttached()
    || !this.CLS_IsTrackedSurvivor() || this.cls_legWoundMode != 1
    || !this.cls_extendedWoundStarted || !this.cls_crawlMotionStarted
    || this.cls_groundedTimedDeath || this.cls_crawlDeadlinePreempted
    || this.CLS_WoundDeadlinePreempted() || this.IsRagdolling()
    || (!this.IsDead() && !this.IsAboutToDie())
    || !this.GetPuppetStateBlackboard().GetBool(GetAllBlackboardDefs().PuppetState.SlotAnimationInProgress)
    || GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this)
    || !ScriptedPuppet.CanRagdoll(this) { return; }
  this.cls_crawlDamageDeath = true;
  this.SetSkipDeathAnimation(true);
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"CRAWL_DAMAGE_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=armed dead=\(this.IsDead()) aboutToDie=\(this.IsAboutToDie()) skipDeathAnimation=true nativeHealthAndKillUnchanged=true");
  }
}

@addMethod(NPCPuppet)
public final func CLS_IsDirectGroundedDeath() -> Bool {
  // A timed crawler must request its own physics after native death too.
  // Do not depend on another mod redirecting a Death/Ragdoll AI stimulus.
  // Also cover a timed pain/seat setup failure with no held workspot. A held
  // ground pose keeps its separate release-after-physics controller instead.
  let timedWithoutHeldPose = this.cls_groundedTimedDeath && this.cls_extendedWoundStarted
    && this.cls_legWoundMode >= 1 && this.cls_legWoundMode <= 3
    && !this.cls_seatedDeathPoseHeld;
  return (this.cls_crawlDamageDeath || timedWithoutHeldPose) && this.IsAttached()
    && !this.cls_crawlDeadlinePreempted && !this.CLS_WoundDeadlinePreempted()
    && (this.IsDead() || this.IsAboutToDie())
    && !GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this)
    && ScriptedPuppet.CanRagdoll(this);
}

@addMethod(NPCPuppet)
public final func CLS_StartGroundedDeathRagdoll() -> Void {
  if this.cls_groundedDeathRagdollQueued || !this.CLS_IsDirectGroundedDeath() || !this.IsDead() { return; }
  this.cls_groundedDeathRagdollQueued = true;
  this.CLS_ActivateGroundedDeathRagdoll(0);
}

@addMethod(NPCPuppet)
private final func CLS_ActivateGroundedDeathRagdoll(attempts: Int32) -> Void {
  if !this.CLS_IsDirectGroundedDeath() || !this.IsDead() { return; }
  if this.IsRagdolling() {
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"DIRECT_GROUND_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=physics_active mode=\(this.cls_legWoundMode) timed=\(this.cls_groundedTimedDeath) attempts=\(attempts)");
    }
    return;
  }
  if attempts >= 10 {
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"DIRECT_GROUND_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=physics_activation_timeout mode=\(this.cls_legWoundMode) timed=\(this.cls_groundedTimedDeath) attempts=\(attempts)");
    }
    return;
  }
  this.QueueEvent(CreateRagdollActivationRequestEvent(entragdollActivationRequestType.Forced,
    n"", false, false, n"Cazanu direct grounded death"));
  if Diagnostics.Enabled() && attempts == 0 {
    Diagnostics.Write(s"DIRECT_GROUND_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=physics_requested mode=\(this.cls_legWoundMode) timed=\(this.cls_groundedTimedDeath) powerPose=false momentum=false addedImpulse=false");
  }
  let verify = new CLS_GroundedDeathRagdollEvent();
  verify.attempts = attempts + 1;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, verify, 0.10, true);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_GroundedDeathRagdollEvent(evt: ref<CLS_GroundedDeathRagdollEvent>) -> Bool {
  this.CLS_ActivateGroundedDeathRagdoll(evt.attempts);
  return true;
}

@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  wrappedMethod();
  if IsDefined(this.m_ownerNPC) { this.m_ownerNPC.CLS_PrepareCrawlDamageDeath(); }
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  this.CLS_PrepareCrawlDamageDeath();
  let result = wrappedMethod(evt);
  // Native death has enabled the physics component. The shared once-only
  // guard also covers the alternate callback ordering through incapacitation.
  this.CLS_StartGroundedDeathRagdoll();
  return result;
}

@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  this.CLS_PrepareCrawlDamageDeath();
  wrappedMethod();
  this.CLS_StartGroundedDeathRagdoll();
}

@addMethod(NPCPuppet)
private final func CLS_ResetCrawlProbe() -> Void {
  this.cls_crawlProbeGeneration += 1;
  this.cls_crawlProbePending = false;
  this.cls_crawlProbeQueuedAt = 0.0;
  this.cls_crawlProbeBlocked = false;
}

@addMethod(NPCPuppet)
private final func CLS_CanProbeCrawlObstacle() -> Bool {
  return this.cls_legWoundMode == 1 && this.cls_crawlMotionStarted
    && !this.cls_crawlDeadlinePreempted && WoundTiming.Eligible(this)
    && !this.CLS_WoundDeadlinePreempted()
    && !GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this);
}

@addMethod(NPCPuppet)
private final func CLS_QueueCrawlObstacleProbe() -> Void {
  if this.cls_crawlProbePending || !this.CLS_CanProbeCrawlObstacle() { return; }
  let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
  if this.cls_crawlProbeQueuedAt > 0.0
    && now - this.cls_crawlProbeQueuedAt < WoundTiming.ObstacleProbeCooldownSeconds() { return; }
  let center = this.GetWorldPosition();
  let forward = this.GetWorldForward();
  if !CrawlBlood.Valid(center) || !CrawlBlood.Valid(forward) { return; }
  forward.Z = 0.0;
  forward.W = 0.0;
  if Vector4.Length(forward) < 0.001 { return; }
  this.cls_crawlProbeGeneration += 1;
  this.cls_crawlProbePending = true;
  this.cls_crawlProbeQueuedAt = now;
  let evt = new CLS_CrawlObstacleProbe();
  evt.owner = this;
  evt.generation = this.cls_crawlProbeGeneration;
  evt.center = center;
  evt.forward = Vector4.Normalize(forward);
  evt.time = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
  this.QueueEvent(evt);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_CrawlObstacleProbe(evt: ref<CLS_CrawlObstacleProbe>) -> Bool {
  if !IsDefined(evt) || evt.generation != this.cls_crawlProbeGeneration { return false; }
  this.cls_crawlProbePending = false;
  this.cls_crawlProbeBlocked = false;
  if !IsDefined(evt.owner) || evt.owner != this || !this.CLS_CanProbeCrawlObstacle()
    || !CrawlBlood.Fresh(this.GetGame(), evt.time)
    || !CrawlBlood.Valid(evt.center) || !CrawlBlood.Valid(evt.forward) { return false; }
  let at = this.GetWorldPosition();
  let heading = this.GetWorldForward();
  if !CrawlBlood.Valid(at) || !CrawlBlood.Valid(heading)
    || Vector4.DistanceSquared(at, evt.center) > 0.01 { return false; }
  heading.Z = 0.0;
  heading.W = 0.0;
  if Vector4.Length(heading) < 0.001
    || Vector4.Dot(Vector4.Normalize(heading), evt.forward) < 0.95 { return false; }
  let right = new Vector4(evt.forward.Y, -evt.forward.X, 0.0, 0.0);
  // A single center lane and the two high-value groups cover nav/static and
  // vehicle blockers.  Nav/influence checks above handle most loose props;
  // avoiding three lanes x three groups keeps this fallback cheap.
  let groups: array<CName> = [n"Static", n"Vehicle"];
  let queries = GameInstance.GetSpatialQueriesSystem(this.GetGame());
  if !IsDefined(queries) { return false; }
  let result: TraceResult;
  let lane = 0;
  while lane <= 0 {
    let from = evt.center + right * (Cast<Float>(lane) * 0.18);
    from.Z += 0.30;
    let to = from + evt.forward * 0.45;
    if !CrawlBlood.Valid(from) || !CrawlBlood.Valid(to) { return false; }
    let i = 0;
    while i < ArraySize(groups) {
      if queries.SyncRaycastByCollisionGroup(from, to, groups[i], result, false, false) {
        let position = new Vector4(result.position.X, result.position.Y, result.position.Z, 1.0);
        let normal = new Vector4(result.normal.X, result.normal.Y, result.normal.Z, 0.0);
        if CrawlBlood.Valid(position) && CrawlBlood.Valid(normal) && Vector4.Length(normal) > 0.001 {
          normal = Vector4.Normalize(normal);
          // An uphill floor is not an obstacle. Require a surface facing
          // this crawl, with a wall-like normal, within this short ray.
          let along = Vector4.Dot(position - from, evt.forward);
          if normal.Z < 0.65 && Vector4.Dot(normal, evt.forward) < -0.1
            && along >= 0.0 && along <= 0.46 {
            this.cls_crawlProbeBlocked = true;
            this.cls_crawlProbeTime = evt.time;
            this.cls_crawlProbePosition = evt.center;
            this.cls_crawlProbeForward = evt.forward;
            return true;
          }
        }
      }
      i += 1;
    }
    lane += 1;
  }
  return false;
}

@addMethod(NPCPuppet)
public final func CLS_LogCrawlMotion(message: String) -> Void {
  if !Diagnostics.Enabled() || this.cls_crawlMotionLogCount >= 12 { return; }
  this.cls_crawlMotionLogCount += 1;
  Diagnostics.Write(s"CRAWL_MOTION npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_crawlMotionLogCount)/12 \(message)");
}

@addMethod(NPCPuppet)
private final func CLS_CrawlNearbyObstacle(out reason: CName) -> Bool {
  let start = this.GetWorldPosition();
  let forward = this.GetWorldForward();
  if !CrawlBlood.Valid(start) || !CrawlBlood.Valid(forward) { return false; }
  forward.Z = 0.0;
  forward.W = 0.0;
  if Vector4.Length(forward) < 0.001 { return false; }
  let end = start + Vector4.Normalize(forward) * 0.45;
  if !CrawlBlood.Valid(end) { return false; }
  let navigation = GameInstance.GetAINavigationSystem(this.GetGame());
  if IsDefined(navigation) {
    // This is a local nav-wall query, not the original two-metre route test.
    // Explicit invalid endpoints mean a nearby nav boundary; OtherError is
    // inconclusive and must never count as proof of a blocked crawler.
    let wall = navigation.FindWallInLineForCharacter(start, end, 0.2, this);
    if IsDefined(wall) {
      if (Equals(wall.status, worldNavigationRequestStatus.OK) && wall.isHit)
        || Equals(wall.status, worldNavigationRequestStatus.InvalidStartingPosition)
        || Equals(wall.status, worldNavigationRequestStatus.InvalidEndPosition) {
        reason = n"near_nav_obstruction";
        return true;
      }
    }
  }
  let influence = this.GetInfluenceComponent();
  if IsDefined(influence) && Equals(influence.IsLineEmpty(start, end), gameinfluenceTestLineResult.Fail) {
    reason = n"near_dynamic_obstacle";
    return true;
  }
  // Probe only after actual progress stalls and nav/influence are clear.
  // A new event refreshes the cache; an expired or relocated hit is ignored.
  this.CLS_QueueCrawlObstacleProbe();
  if this.cls_crawlProbeBlocked && CrawlBlood.Fresh(this.GetGame(), this.cls_crawlProbeTime)
    && Vector4.DistanceSquared(start, this.cls_crawlProbePosition) <= 0.01
    && Vector4.Dot(Vector4.Normalize(forward), this.cls_crawlProbeForward) >= 0.95 {
    reason = n"near_physical_obstacle";
    return true;
  }
  return false;
}

@addMethod(NPCPuppet)
public final func CLS_CrawlBlockedTooLong(context: ScriptExecutionContext) -> Bool {
  if this.cls_legWoundMode != 1 || !WoundTiming.Eligible(this)
    || this.CLS_WoundDeadlinePreempted()
    || GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this) {
    this.cls_crawlMotionStarted = false;
    this.cls_crawlMotionObstructed = false;
    this.CLS_ResetCrawlProbe();
    return false;
  }
  let now = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  let at = this.GetWorldPosition();
  if !CrawlBlood.Valid(at) || now != now || AbsF(now) > 1000000000.0 {
    this.cls_crawlMotionStarted = false;
    this.cls_crawlMotionObstructed = false;
    this.CLS_ResetCrawlProbe();
    return false;
  }
  let sinceSample = now - this.cls_crawlMotionSampleAt;
  // This runs only from the active crawl's death subaction. Never carry a
  // stall across an interrupted action, a time reset, or a foreign workspot.
  if !this.cls_crawlMotionStarted || sinceSample < 0.0 || sinceSample > 1.0 {
    this.cls_crawlMotionStarted = true;
    this.cls_crawlMotionSampleAt = now;
    this.cls_crawlMotionAnchor = at;
    this.cls_crawlMotionObstructed = false;
    this.CLS_ResetCrawlProbe();
    return false;
  }
  if sinceSample < 0.2 { return false; }
  this.cls_crawlMotionSampleAt = now;
  let moved = at - this.cls_crawlMotionAnchor;
  if moved.X * moved.X + moved.Y * moved.Y >= 0.0036 {
    // Six centimetres of actual travel resets the stall. Ignore vertical
    // animation/navmesh settling, and allow movement across several samples.
    if this.cls_crawlMotionObstructed { this.CLS_LogCrawlMotion("progress_resumed"); }
    this.cls_crawlMotionAnchor = at;
    this.cls_crawlMotionObstructed = false;
    this.CLS_ResetCrawlProbe();
    return false;
  }
  let reason: CName;
  if !this.CLS_CrawlNearbyObstacle(reason) {
    if this.cls_crawlMotionObstructed { this.CLS_LogCrawlMotion("near_obstruction_cleared"); }
    this.cls_crawlMotionObstructed = false;
    return false;
  }
  if !this.cls_crawlMotionObstructed {
    this.cls_crawlMotionObstructed = true;
    this.cls_crawlMotionBlockedAt = now;
    if Diagnostics.Enabled() { this.CLS_LogCrawlMotion(s"blocked reason=\(reason) deathAfter=\(WoundTiming.CrawlBlockedSeconds())s"); }
    return false;
  }
  let blockedFor = now - this.cls_crawlMotionBlockedAt;
  if blockedFor < WoundTiming.CrawlBlockedSeconds() { return false; }
  if Diagnostics.Enabled() { this.CLS_LogCrawlMotion(s"blocked_death reason=\(reason) seconds=\(blockedFor)"); }
  return true;
}

@addMethod(NPCPuppet)
public final func CLS_LogExtendedPhase(message: String) -> Void {
  if !Diagnostics.Enabled() || this.cls_extendedPhaseLogCount >= 32 {
    return;
  }
  this.cls_extendedPhaseLogCount += 1;
  Diagnostics.Write(s"WOUND_PHASE npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_extendedPhaseLogCount)/32 \(message)");
}

@addMethod(NPCPuppet)
public final func CLS_SelectLegWound() -> TweakDBID {
  if this.cls_legWoundMode == 0 {
    let gun = SeatedCombat.EquippedOneHandedGun(this);
    this.cls_legWoundGun = gun;
    let armed = IsDefined(gun);
    let roll = RandRange(0, 100);
    if armed {
      this.cls_legWoundMode = roll < 70 ? 3 : 1;
    } else {
      this.cls_legWoundMode = roll < 70 ? 1 : 2;
    }
    // Cazanu: choose one of two crawl lifetimes once, with equal odds.
    // A second leg loss or an AI restart reuses the same duration.
    if this.cls_legWoundMode == 1 {
      this.cls_crawlWoundSeconds = RandRange(0, 2) == 0
        ? WoundTiming.CrawlShortSeconds() : WoundTiming.CrawlLongSeconds();
    }
    if Diagnostics.Enabled() {
      let firstItem = GameInstance.GetTransactionSystem(this.GetGame()).GetItemInSlot(this, t"AttachmentSlots.WeaponRight");
      Diagnostics.Write(s"LEG_OUTCOME npc=\(EntityID.ToDebugString(this.GetEntityID())) firstWeapon=\(SeatedCombat.SlotDiagnostic(firstItem)) gunGroup=\(armed) roll=\(roll) mode=\(this.cls_legWoundMode) (1=crawl40or50,2=pain60,3=shoot25) seconds=\(this.CLS_LegWoundSeconds()) selectedOnce=true");
    }
  }
  // Select once. A second missing leg or an AI restart cannot change modes.
  return this.cls_legWoundMode == 1 ? t"CazanuLimbSurvival.LegCrawlSequence" : t"CazanuLimbSurvival.LegStruggleSequence";
}

@addMethod(NPCPuppet)
public final func CLS_LegWoundSeconds() -> Float {
  if this.cls_legWoundMode == 3 { return WoundTiming.ShootSeconds(); }
  return this.cls_legWoundMode == 1 ? this.cls_crawlWoundSeconds : WoundTiming.TotalSeconds();
}

@addMethod(NPCPuppet)
public final func CLS_BeginExtendedWound(context: ScriptExecutionContext) -> Void {
  if this.cls_extendedWoundStarted {
    return;
  }
  this.cls_extendedWoundStarted = true;
  this.cls_extendedWoundStartTime = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"EXTENDED_SEQUENCE npc=\(EntityID.ToDebugString(this.GetEntityID())) mode=\(this.cls_legWoundMode) (1=crawl,2=pain,3=shoot) target=\(this.CLS_LegWoundSeconds())s ending=grounded; timer starts at chosen loop");
    this.CLS_QueueSurvivalSnapshot(25.0);
    this.CLS_QueueSurvivalSnapshot(this.CLS_LegWoundSeconds() - 2.0);
    this.CLS_QueueSurvivalSnapshot(this.CLS_LegWoundSeconds() + 5.0);
  }
  if this.cls_legWoundMode == 2 || this.cls_legWoundMode == 3 {
    this.CLS_TryStartSeated(context);
  }
}

// Only a successful first seated entry realigns the shared deadline; the
// controller's one-shot guard prevents second-limb hits from restarting it.
@addMethod(NPCPuppet)
public final func CLS_AlignSeatedWoundClock(context: ScriptExecutionContext) -> Void {
  this.cls_extendedWoundStartTime = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
}

@addMethod(NPCPuppet)
public final func CLS_TimeUntilWoundDeath(context: ScriptExecutionContext) -> Float {
  if !this.cls_extendedWoundStarted {
    return this.CLS_LegWoundSeconds();
  }
  let elapsed = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context)) - this.cls_extendedWoundStartTime;
  return MaxF(0.0, this.CLS_LegWoundSeconds() - elapsed);
}

@addMethod(NPCPuppet)
public final func CLS_ArmGroundedDeath(context: ScriptExecutionContext) -> Void {
  this.cls_groundedTimedDeath = true;
  this.cls_groundedTimedDeathAt = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  this.CLS_HoldSeatedDeathPose();
  // Only set immediately before this mod's terminal kill, never while wounded.
  // Normal Death dispatch can then select the native forced-ragdoll branch.
  if ScriptedPuppet.CanRagdoll(this) {
    this.SetSkipDeathAnimation(true);
  }
}

@addMethod(NPCPuppet)
public final func CLS_IsGroundedTimedDeath(context: ScriptExecutionContext) -> Bool {
  let elapsed = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context)) - this.cls_groundedTimedDeathAt;
  return this.cls_groundedTimedDeath && this.IsDead() && elapsed >= 0.0 && elapsed < 4.0;
}

@wrapMethod(TweakAIActionRecord)
public static func GetSequenceRecord(context: ScriptExecutionContext, sequenceID: TweakDBID, sequenceDebugName: script_ref<String>, out sequenceRecord: wref<AIActionSequence_Record>) -> Bool {
  let result = wrappedMethod(context, sequenceID, sequenceDebugName, sequenceRecord);
  if !result || !IsDefined(sequenceRecord) || NotEquals(sequenceRecord.GetID(), t"StatusEffectActions.DismemberedLegSequence") {
    return result;
  }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !WoundTiming.Eligible(npc) {
    return result;
  }
  let extended = TweakDBInterface.GetAIActionSequenceRecord(npc.CLS_SelectLegWound());
  if WoundTiming.Ready() && IsDefined(extended) && extended.GetActionsCount() == 2 {
    sequenceRecord = extended;
  } else if Diagnostics.Enabled() && !npc.cls_extendedWoundUnavailableLogged {
    npc.cls_extendedWoundUnavailableLogged = true;
    Diagnostics.Write(s"EXTENDED_SEQUENCE_UNAVAILABLE npc=\(EntityID.ToDebugString(npc.GetEntityID())); retaining native sequence; check TweakXL startup.");
  }
  return result;
}

// Native RunNextAction starts AND updates the next action synchronously. If
// an intermediate action succeeds immediately, let the next normal tick
// advance its iterator instead of escaping the chosen sequence early.
@wrapMethod(TweakAIActionSequence)
private final func RunNextAction(context: ScriptExecutionContext) -> AIbehaviorUpdateOutcome {
  if !IsDefined(this.m_sequenceRecord) || !WoundTiming.IsSequence(this.m_sequenceRecord.GetID())
    || TweakAIActionRecord.IsThisLastActionInSequence(this.m_sequenceRecord, this.m_sequenceIterator) {
    return wrappedMethod(context);
  }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  let retainSequence = WoundTiming.Eligible(npc);
  let result = wrappedMethod(context);
  if retainSequence && Equals(result, AIbehaviorUpdateOutcome.SUCCESS) {
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SEQUENCE_CONTINUE npc=\(EntityID.ToDebugString(npc.GetEntityID())) completedIndex=\(this.m_sequenceIterator); immediate action completed, continuing remaining wound stages next tick.");
    }
    return AIbehaviorUpdateOutcome.IN_PROGRESS;
  }
  return result;
}

@wrapMethod(TweakAIActionAbstract)
private final func CalculatePhaseDuration(context: ScriptExecutionContext, opt phaseDurationFromAnimSlot: Float) -> Void {
  wrappedMethod(context, phaseDurationFromAnimSlot);
  if !Equals(this.m_actionPhase, EAIActionPhase.Loop) || !IsDefined(this.m_actionRecord) {
    return;
  }
  let action = this.m_actionRecord.GetID();
  if NotEquals(action, t"CazanuLimbSurvival.LegCrawl") && NotEquals(action, t"CazanuLimbSurvival.LegStruggle") {
    return;
  }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !WoundTiming.Eligible(npc) {
    return;
  }
  if Equals(action, t"CazanuLimbSurvival.LegCrawl") {
    npc.CLS_BeginExtendedWound(context);
    let remaining = npc.CLS_TimeUntilWoundDeath(context) + 0.5;
    // Cap the AI cycle only. Compressing the animation to the last partial
    // cycle would speed it up. Keep the pose active through the kill tick.
    this.m_phaseDuration = MinF(this.m_phaseDuration, remaining);
    if Diagnostics.Enabled() {
      npc.CLS_LogExtendedPhase(s"action=LegCrawl cycle=\(this.m_phaseIteration) seconds=\(this.m_phaseDuration) slotSeconds=\(phaseDurationFromAnimSlot) remaining=\(remaining) animSeconds=\(this.m_phaseAnimationDuration) exitChecks=\(this.m_phaseRecord.GetToNextPhaseConditionCount())");
    }
  } else {
    npc.CLS_BeginExtendedWound(context);
    // Keep the timer action active through the terminal tick. The separate
    // controller owns the workspot and falls back to native wounded locomotion.
    this.m_phaseDuration = npc.CLS_TimeUntilWoundDeath(context) + 0.5;
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"STRUGGLE_DURATION npc=\(EntityID.ToDebugString(npc.GetEntityID())) seconds=\(this.m_phaseDuration) animation=ground_pain_controller slotOverride=\(IsDefined(this.m_actionRecord.AnimData().AnimSlot())) startupPresent=\(IsDefined(this.m_actionRecord.Startup()))");
    }
  }
}

@wrapMethod(TweakAIActionAbstract)
private final func RepeatPhase(context: ScriptExecutionContext) -> Bool {
  if Equals(this.m_actionPhase, EAIActionPhase.Loop) && IsDefined(this.m_actionRecord)
    && Equals(this.m_actionRecord.GetID(), t"CazanuLimbSurvival.LegCrawl") {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    // Never leave an infinite repeat running if eligibility or its budget ends.
    if !WoundTiming.Eligible(npc) || npc.CLS_TimeUntilWoundDeath(context) <= 0.0 {
      return false;
    }
  }
  return wrappedMethod(context);
}

@wrapMethod(TweakAIActionAbstract)
protected func Deactivate(context: ScriptExecutionContext) -> Void {
  if IsDefined(this.m_actionRecord)
    && Equals(this.m_actionRecord.GetID(), t"CazanuLimbSurvival.LegCrawl") {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if IsDefined(npc) {
      npc.CLS_TraceCrawlTransition("crawl_deactivate_before_reset");
      npc.cls_crawlMotionStarted = false;
      npc.cls_crawlMotionObstructed = false;
      npc.CLS_ResetCrawlProbe();
    }
  }
  wrappedMethod(context);
}

// Relaunch both animation and native root motion every crawl cycle. Native
// motion already checks nearby nav boundaries, collisions and dynamic objects;
// suppressing it based on a two-metre route query causes crawling in place.
@wrapMethod(TweakAIActionAbstract)
private final func PlayAnimationOnSlot(context: ScriptExecutionContext, animFeature: wref<AnimFeature_AIAction>) -> Void {
  if !IsDefined(this.m_actionRecord)
    || NotEquals(this.m_actionRecord.GetID(), t"CazanuLimbSurvival.LegCrawl")
    || !Equals(this.m_actionPhase, EAIActionPhase.Loop) {
    wrappedMethod(context, animFeature);
    return;
  }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !WoundTiming.Eligible(npc) {
    wrappedMethod(context, animFeature);
    return;
  }
  let proxy = npc.GetAIControllerComponent().GetActionAnimationScriptProxy();
  if !IsDefined(proxy) {
    wrappedMethod(context, animFeature);
    return;
  }
  let animData = this.m_actionRecord.AnimData();
  let slot = animData.AnimSlot();
  let slideParams: ActionAnimationSlideParams;
  let slideTarget: wref<GameObject>;
  npc.GetPuppetStateBlackboard().SetBool(GetAllBlackboardDefs().PuppetState.SlotAnimationInProgress, true);
  proxy.Stop();
  let clipSeconds = proxy.GetPhaseDuration(animData.AnimFeature(), animFeature);
  this.CalculatePhaseDuration(context, clipSeconds);
  if AbsF(this.m_phaseAnimationDuration - clipSeconds) >= 0.01 {
    animFeature.stateDuration = this.m_phaseAnimationDuration;
  } else if animFeature.stateDuration > 0.0 {
    animFeature.stateDuration = 0.0;
  }
  proxy.Setup(animData.AnimFeature(), animFeature, slot.UseRootMotion(),
    slot.UsePoseMatching(), slot.ResetRagdollOnStart(), slot.UseDynamicObjectsCheck(),
    animData.UpdateMovePolicy(), slideParams, slideTarget, animData.MarginToPlayer());
  proxy.Launch();
  if Diagnostics.Enabled() {
    npc.CLS_LogExtendedPhase(s"action=LegCrawl rootMotion=\(slot.UseRootMotion()) nativeCollisionChecks=\(slot.UseDynamicObjectsCheck()) remaining=\(npc.CLS_TimeUntilWoundDeath(context))");
  }
}

@wrapMethod(AISubActionForceDeath_Record_Implementation)
public final static func ForceDeath(context: ScriptExecutionContext, record: wref<AISubActionForceDeath_Record>) -> Void {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if IsDefined(npc) && WoundTiming.Eligible(npc)
    && (npc.CLS_IsLimbReserved(gameDismBodyPart.LEFT_LEG) || npc.CLS_IsLimbReserved(gameDismBodyPart.RIGHT_LEG))
    && !npc.cls_groundedTimedDeath && npc.CLS_TimeUntilWoundDeath(context) > 0.0 {
    npc.CLS_BeginExtendedWound(context);
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SUPPRESSED_PREMATURE_FORCEDEATH npc=\(EntityID.ToDebugString(npc.GetEntityID())) remaining=\(npc.CLS_TimeUntilWoundDeath(context))s");
    }
    return;
  }
  wrappedMethod(context, record);
}

@wrapMethod(AISubActionForceDeath_Record_Implementation)
public static func Update(context: ScriptExecutionContext, record: wref<AISubActionForceDeath_Record>, duration: Float) -> AIbehaviorUpdateOutcome {
  if IsDefined(record) && Equals(record.GetID(), t"CazanuLimbSurvival.LegFinalDeath") {
    let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if !WoundTiming.Eligible(npc) || !npc.cls_extendedWoundStarted || npc.cls_groundedTimedDeath {
      return AIbehaviorUpdateOutcome.SUCCESS;
    }
    // A foreign workspot cancels our deadline even if the old wounded AI
    // action resumes after our separate controller has already released it.
    if npc.CLS_WoundDeadlinePreempted() {
      return AIbehaviorUpdateOutcome.SUCCESS;
    }
    // A crawler has no owned workspot. Any workspot belongs to another
    // controller, so permanently release this crawler's terminal deadline.
    // This excludes both the stuck finish and the chosen timed finish.
    if npc.cls_legWoundMode == 1 && (npc.cls_crawlDeadlinePreempted
      || GameInstance.GetWorkspotSystem(npc.GetGame()).IsActorInWorkspot(npc)) {
      npc.cls_crawlDeadlinePreempted = true;
      npc.cls_crawlMotionStarted = false;
      npc.cls_crawlMotionObstructed = false;
      npc.CLS_ResetCrawlProbe();
      return AIbehaviorUpdateOutcome.SUCCESS;
    }
    if npc.CLS_SeatedActive() {
      return AIbehaviorUpdateOutcome.IN_PROGRESS;
    }
    let blockedDeath = npc.CLS_CrawlBlockedTooLong(context);
    if !blockedDeath && npc.CLS_TimeUntilWoundDeath(context) > 0.0 {
      // Only called while the chosen wound action is actively running.
      // The sampler itself accepts crawling NPCs only and throttles to 10 Hz.
      npc.CLS_UpdateCrawlBlood();
      return AIbehaviorUpdateOutcome.IN_PROGRESS;
    }
    npc.CLS_ArmGroundedDeath(context);
    AISubActionForceDeath_Record_Implementation.ForceDeath(context, record);
    return AIbehaviorUpdateOutcome.SUCCESS;
  }
  return wrappedMethod(context, record, duration);
}

@wrapMethod(AIDeathReactionsTask)
protected func TurnOnRagdoll(context: ScriptExecutionContext, activationReason: CName) -> Void {
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if IsDefined(npc) {
    npc.CLS_TraceCrawlTransition("ragdoll_dispatch_enter:" + NameToString(activationReason));
    if npc.CLS_IsDirectGroundedDeath() {
      // Forced-ragdoll stimuli can precede the actual native death event.
      // Defer this pending request to the confirmed-death callbacks; never
      // add native power-pose/impulse requests alongside the same handoff.
      if npc.IsDead() {
        npc.CLS_StartGroundedDeathRagdoll();
        npc.GetHitReactionComponent().UpdateDeathHasBeenPlayed();
        this.m_deathHasBeenPlayed = true;
        this.ChangeHighLevelState(context);
      }
      npc.CLS_TraceCrawlTransition("ragdoll_direct_grounded_handoff");
      return;
    }
  }
  if !IsDefined(npc) || (!npc.CLS_IsGroundedTimedDeath(context) && !npc.CLS_IsSeatedDamageDeath()) {
    wrappedMethod(context, activationReason);
    if IsDefined(npc) {
      npc.CLS_TraceCrawlTransition("ragdoll_native_exit");
    }
    return;
  }
  let now = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  if this.m_previousRagdollTimeStamp == now {
    return;
  }
  this.m_previousRagdollTimeStamp = now;
  if !npc.IsRagdolling() && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.ForceKillFromRagdoll") {
    // Settle from the current ground pose. Also prevent a native damage-death
    // request competing with our held-seat physics handoff and adding a
    // second hit impulse at +0.1s. Other damage deaths remain native.
    npc.QueueEvent(CreateRagdollActivationRequestEvent(entragdollActivationRequestType.Forced, n"", false, false, n"Cazanu timed wound death"));
  }
  npc.GetHitReactionComponent().UpdateDeathHasBeenPlayed();
  this.m_deathHasBeenPlayed = true;
  this.ChangeHighLevelState(context);
  npc.CLS_TraceCrawlTransition("ragdoll_grounded_exit");
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"GROUNDED_DEATH npc=\(EntityID.ToDebugString(npc.GetEntityID())) powerPose=false momentum=false addedImpulse=false");
  }
}
