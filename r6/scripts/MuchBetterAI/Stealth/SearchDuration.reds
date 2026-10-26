module MuchBetterAI.Stealth

import MuchBetterAI.Core.*

@wrapMethod(ShouldNPCContinueInAlerted)
protected func Check(context: ScriptExecutionContext) -> AIbehaviorConditionOutcomes {
  let vanilla: AIbehaviorConditionOutcomes = wrappedMethod(context);
  let puppet: ref<ScriptedPuppet> = ScriptExecutionContext.GetOwner(context) as ScriptedPuppet;
  if !IsDefined(puppet) {
    return vanilla;
  };
  let npc: ref<NPCPuppet> = puppet as NPCPuppet;
  let player: ref<PlayerPuppet> = GetPlayer(puppet.GetGame());
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(puppet.GetGame()));
  let directReceipt: Bool = MBAI_ActorMovementEligible(npc) && npc.IsAggressive() && MBAI_AlertClockEnd(npc) > now;
  if !MBAI_PlayerAlertMovementEligible(npc, player) && !directReceipt {
    return vanilla;
  };
  let alertedWithCorpses: Bool = false;
  if puppet.IsConnectedToSecuritySystem() {
    if puppet.GetSecuritySystem().IsReprimandOngoing() {
      return AIbehaviorConditionOutcomes.True;
    };
    let reactionComponent: ref<ReactionManagerComponent> = puppet.GetStimReactionComponent();
    if reactionComponent.IsAlertedByDeadBody() || ArraySize(reactionComponent.GetIgnoreList()) > 0 {
      alertedWithCorpses = true;
    };
  };
  let searchStart: Float = ScriptExecutionContext.GetArgumentFloat(context, n"SearchingStarted");
  let dur: Float = alertedWithCorpses ? 60.0 : 20.0;
  if searchStart > 0.0 {
    MBAI_RecordAlertEnd(npc, searchStart + dur);
  };
  if Equals(vanilla, AIbehaviorConditionOutcomes.True) {
    return vanilla;
  };
  if MBAI_AlertClockEnd(npc) > now {
    return AIbehaviorConditionOutcomes.True;
  };
  return Cast<AIbehaviorConditionOutcomes>(searchStart + dur > now);
}
