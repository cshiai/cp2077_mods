module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

public func MBAI_Takedown_IsCompletionNoise(takedownActionType: ETakedownActionType) -> Bool {
  return Equals(takedownActionType, ETakedownActionType.Takedown)
    || Equals(takedownActionType, ETakedownActionType.TakedownNonLethal)
    || Equals(takedownActionType, ETakedownActionType.TakedownNetrunner)
    || Equals(takedownActionType, ETakedownActionType.TakedownMassiveTarget)
    || Equals(takedownActionType, ETakedownActionType.AerialTakedown)
    || Equals(takedownActionType, ETakedownActionType.KillTarget)
    || Equals(takedownActionType, ETakedownActionType.SpareTarget)
    || Equals(takedownActionType, ETakedownActionType.BossTakedown)
    || Equals(takedownActionType, ETakedownActionType.DisposalTakedown)
    || Equals(takedownActionType, ETakedownActionType.DisposalTakedownNonLethal);
}

public func MBAI_Takedown_CanWitness(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, victimID: EntityID) -> Bool {
  if !MBAI_ActorMovementEligible(npc) || npc.GetEntityID() == victimID {
    return false;
  };
  if Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
    return false;
  };
  let reaction: ref<ReactionManagerComponent> = npc.GetStimReactionComponent();
  return IsDefined(reaction) && reaction.IsTargetVisible(player) && MBAI_Search_GetDetection(npc) >= 0.10;
}

@wrapMethod(StimBroadcasterComponent)
public final func TriggerNoiseStim(owner: wref<GameObject>, takedownActionType: ETakedownActionType) -> Void {
  if Equals(takedownActionType, ETakedownActionType.Grapple) {
    this.TriggerSingleBroadcast(owner, gamedataStimType.SoundDistraction, 6.0);
    return;
  };
  if MBAI_Takedown_IsCompletionNoise(takedownActionType) {
    this.TriggerSingleBroadcast(owner, gamedataStimType.SoundDistraction, 8.0);
    return;
  };
  wrappedMethod(owner, takedownActionType);
}

public func MBAI_Takedown_React(scriptInterface: ref<StateGameScriptInterface>, victim: wref<GameObject>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(player) {
    return;
  };
  if scriptInterface.HasStatFlag(gamedataStatType.CanTakedownSilently) {
    let broadcaster: ref<StimBroadcasterComponent> = player.GetStimBroadcasterComponent();
    if IsDefined(broadcaster) {
      broadcaster.TriggerSingleBroadcast(player, gamedataStimType.SoundDistraction, 8.0);
    };
  };
  let victimID: EntityID;
  if IsDefined(victim) {
    victimID = victim.GetEntityID();
  };
  let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(60.0);
  let seen: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(npcs) {
    let npc: ref<NPCPuppet> = npcs[i];
    if MBAI_Takedown_CanWitness(npc, player, victimID) && AIActionHelper.TryStartCombatWithTarget(npc, player) {
      seen += 1;
    };
    i += 1;
  };
  if seen > 0 {
    MBAInfo("Takedown", s"takedown seen by \(seen) enemy(ies) -> combat");
  };
}

@wrapMethod(TakedownExecuteTakedownEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  MBAI_Takedown_React(scriptInterface, this.stateMachineInitData.target);
}

@wrapMethod(TakedownExecuteTakedownAndDisposeEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  MBAI_Takedown_React(scriptInterface, this.stateMachineInitData.target);
}
