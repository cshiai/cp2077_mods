module MuchBetterAI.Stealth

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

@addField(ScriptedPuppet)
let m_mbaiIdentifiedAt: Float;

@wrapMethod(SenseComponent)
private final func PlayerExitedPercpetion(player: wref<PlayerPuppet>) -> Void {
  wrappedMethod(player);
  if !IsDefined(player) {
    return;
  };
  if this.GetDetection(player.GetEntityID()) < 50.0 {
    return;
  };
  let owner: ref<NPCPuppet> = this.GetOwnerPuppet() as NPCPuppet;
  if MBAI_PlayerAlertEligible(owner, player) {
    owner.m_mbaiIdentifiedAt = EngineTime.ToFloat(GameInstance.GetSimTime(owner.GetGame()));
    MBADebug("Stealth", s"identification stored npc=\(ToString(owner.GetEntityID())) det=\(this.GetDetection(player.GetEntityID()))");
  };
}
