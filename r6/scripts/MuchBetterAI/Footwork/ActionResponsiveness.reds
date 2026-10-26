module MuchBetterAI.Footwork

import MuchBetterAI.Core.*

@wrapMethod(AICondition)
public final static func ActivationCheck(const context: ScriptExecutionContext, actionRecord: ref<AIAction_Record>) -> Bool {
  if IsDefined(actionRecord) {
    let recordID: TweakDBID = actionRecord.GetID();
    let footworkAction: Bool = recordID == t"MBAI.ThreatHopKerenzikov"
      || recordID == t"MBAI.ThreatHopDisciplined"
      || recordID == t"MBAI.ThreatHopAggressive"
      || recordID == t"MBAI.NormalStrafeLeft"
      || recordID == t"MBAI.NormalStrafeRight"
      || recordID == t"MBAI.NormalStrafeLeftHit"
      || recordID == t"MBAI.NormalStrafeRightHit";
    if footworkAction {
      let npc: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
      if !MBAI_EnemyMovementEligible(npc) {
        return false;
      };
    };
  };
  return wrappedMethod(context, actionRecord);
}

@wrapMethod(AICondition)
public final static func CheckActionCondition(const context: ScriptExecutionContext, condition: wref<AIActionCondition_Record>) -> Bool {
  if IsDefined(condition) {
    let recordID: TweakDBID = condition.GetID();
    let footworkCondition: Bool = recordID == t"MBAI.ThreatHopKerenzikovGate"
      || recordID == t"MBAI.ThreatHopDisciplinedGate"
      || recordID == t"MBAI.ThreatHopAggressiveGate"
      || recordID == t"MBAI.NormalStrafeGateL"
      || recordID == t"MBAI.NormalStrafeGateR"
      || recordID == t"MBAI.NormalStrafeLeftHitGate"
      || recordID == t"MBAI.NormalStrafeRightHitGate";
    if footworkCondition {
      let npc: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
      if !MBAI_EnemyMovementEligible(npc) {
        return false;
      };
    };
  };
  return wrappedMethod(context, condition);
}
