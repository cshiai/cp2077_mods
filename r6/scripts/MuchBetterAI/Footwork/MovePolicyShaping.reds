module MuchBetterAI.Footwork

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

private static func MBAI_SpacingDiscipline(skillLevel: Float) -> Float {
  return ClampF(1.55 - 0.25 * skillLevel, 0.6, 1.3);
}

private static func MBAI_TrackingSharpness(skillLevel: Float, npc: ref<NPCPuppet>) -> Float {
  let mult: Float = ClampF(0.6 + 0.18 * skillLevel, 0.7, 1.4);
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
  if statsSystem.GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.HasKerenzikov) >= 1.0 {
    mult += 0.3;
  };
  return mult;
}

@wrapMethod(AIActionMovePolicy)
public final static func Add(const context: ScriptExecutionContext, record: wref<MovementPolicy_Record>, out policy: ref<MovePolicies>) -> Void {
  wrappedMethod(context, record, policy);
  if !IsDefined(record) || !IsDefined(policy) {
    return;
  };
  let npc: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
    return;
  };
  let rarity: gamedataNPCRarity = npc.GetNPCRarity();
  if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
    return;
  };
  let skillLevel: Float = MBAI_TierSkillLevel(npc);
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  let ring: wref<AIRingType_Record> = record.Ring();
  if IsDefined(ring) && NotEquals(ring.Type(), gamedataAIRingType.Undefined) && NotEquals(ring.Type(), gamedataAIRingType.LatestActive) {
    let distance: Float;
    let tolerance: Float;
    if AIActionHelper.GetDistanceAndToleranceFromRingType(record, distance, tolerance) && tolerance > 0.0 {
      policy.SetDistancePolicy(distance, MaxF(tolerance * MBAI_SpacingDiscipline(skillLevel) * MBAI_IntentSpacingMul(npc, now), 0.25));
    };
  };
  let basePrediction: Float = record.StrafingPredictionTime();
  if basePrediction > 0.0 {
    policy.SetStrafingPredictionTime(basePrediction * MBAI_TrackingSharpness(skillLevel, npc) * MBAI_IntentTrackingMul(npc, now), record.StrafingPredictionVelocityMax());
  };
  MBATrace("Footwork", s"rarity=\(rarity) policy shaped");
}
