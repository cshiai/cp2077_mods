module MuchBetterAI.Stealth

import MuchBetterAI.Core.*

@addField(NPCPuppet)
let m_mbaiAlertEnd: Float;

public func MBAI_RecordAlertEnd(npc: ref<NPCPuppet>, expiresAt: Float) -> Void {
  if IsDefined(npc) {
    npc.m_mbaiAlertEnd = MaxF(npc.m_mbaiAlertEnd, expiresAt);
  };
}

public func MBAI_RaiseAlert(npc: ref<NPCPuppet>, dur: Float) -> Void {
  if !MBAI_ActorEligible(npc) || !npc.IsAggressive() {
    return;
  };
  MBAI_RecordAlertEnd(npc, EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame())) + dur);
}

public func MBAI_AlertClockEnd(npc: wref<NPCPuppet>) -> Float {
  return IsDefined(npc) ? npc.m_mbaiAlertEnd : 0.0;
}

@wrapMethod(ReactionManagerComponent)
protected final func ReactToSecuritySystemOutputByTask(evt: ref<SecuritySystemOutput>) -> Void {
  wrappedMethod(evt);
  if !IsDefined(evt) || !this.IsEnabled() {
    return;
  };
  let input: ref<SecuritySystemInput> = evt.GetOriginalInputEvent();
  if !IsDefined(input) || !Equals(input.GetNotificationType(), ESecurityNotificationType.ALARM) {
    return;
  };
  let breached: ref<NPCPuppet> = input.GetObjectOfInterest() as NPCPuppet;
  if !IsDefined(breached) || !breached.IsDead() && !ScriptedPuppet.IsDefeated(breached) && !ScriptedPuppet.IsUnconscious(breached) {
    return;
  };
  let state: ESecuritySystemState = evt.GetCachedSecurityState();
  if !Equals(state, ESecuritySystemState.ALERTED) && !Equals(state, ESecuritySystemState.COMBAT) {
    return;
  };
  let npc: ref<NPCPuppet> = this.GetOwnerPuppet() as NPCPuppet;
  let player: ref<PlayerPuppet> = IsDefined(npc) ? GetPlayer(npc.GetGame()) : null;
  if !MBAI_PlayerAlertEligible(npc, player) {
    return;
  };
  MBAI_BodyAlert_Register(npc, breached.GetWorldPosition());
  MBAI_RaiseAlert(npc, 60.0);
}
