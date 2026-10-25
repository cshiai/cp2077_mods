// Cazanu - candidate priority fix for simultaneous arm and leg loss.
module CazanuLimbSurvival

// Native wounded conditions independently match each missing limb. Suppress
// an arm match while an actual dismembered-leg status is present on a tracked
// survivor, so the graph can select its native leg branch. This candidate
// still needs current-game behavior-graph verification; it does not select
// an animation, alter statuses, or change the native leg death sequence.
@wrapMethod(CheckCurrentWoundedState)
protected func Check(context: ScriptExecutionContext) -> AIbehaviorConditionOutcomes {
  let nativeResult = wrappedMethod(context);
  // Native false/failure outcomes are never changed by this override.
  if NotEquals(nativeResult, AIbehaviorConditionOutcomes.True) { return nativeResult; }
  let npc = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !Settings.Enabled() || !IsDefined(npc) || !npc.CLS_IsTrackedSurvivor()
    || !npc.IsAttached() || !ScriptedPuppet.IsAlive(npc) || !npc.IsActive()
    || npc.IsAboutToDieOrDefeated() || ScriptedPuppet.IsDefeated(npc) {
    return nativeResult;
  }

  let legLeft = StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft");
  let legRight = StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
  let effectiveResult = nativeResult;
  if legLeft || legRight {
    switch this.m_woundedTypeToCompare {
      case EWoundedBodyPart.WoundedLeftArm:
      case EWoundedBodyPart.WoundedRightArm:
      case EWoundedBodyPart.DismemberedLeftArm:
      case EWoundedBodyPart.DismemberedRightArm:
        effectiveResult = AIbehaviorConditionOutcomes.False;
        break;
    }
  }
  npc.CLS_LogWoundedPriority(this.m_woundedTypeToCompare, nativeResult, effectiveResult, legLeft, legRight);
  return effectiveResult;
}

@addField(NPCPuppet)
private let cls_woundedPriorityLogCount: Int32;

// Logging is bounded independently of the gameplay override. Turning off
// Diagnostics keeps the candidate priority behavior enabled.
@addMethod(NPCPuppet)
public final func CLS_LogWoundedPriority(phase: EWoundedBodyPart, nativeResult: AIbehaviorConditionOutcomes, effectiveResult: AIbehaviorConditionOutcomes, legLeft: Bool, legRight: Bool) -> Void {
  if !Diagnostics.Enabled() || this.cls_woundedPriorityLogCount >= 16 {
    return;
  }
  this.cls_woundedPriorityLogCount += 1;
  Diagnostics.Write(s"WOUNDED_PRIORITY npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(this.cls_woundedPriorityLogCount)/16 phase=\(Diagnostics.Enum("EWoundedBodyPart", EnumInt(phase))) native=\(Diagnostics.Enum("AIbehaviorConditionOutcomes", EnumInt(nativeResult))) effective=\(Diagnostics.Enum("AIbehaviorConditionOutcomes", EnumInt(effectiveResult))) redirected=\(NotEquals(nativeResult, effectiveResult)) legLeft=\(legLeft) legRight=\(legRight)");
  if this.cls_woundedPriorityLogCount == 16 {
    Diagnostics.Write(s"WOUNDED_PRIORITY_LIMIT npc=\(EntityID.ToDebugString(this.GetEntityID())); further positive wounded-condition traces suppressed; priority behavior remains enabled.");
  }
}
