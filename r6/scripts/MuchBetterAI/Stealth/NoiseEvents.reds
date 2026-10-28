module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

public func MBAI_Noise_Recruit(player: ref<PlayerPuppet>, noisePos: Vector4, range: Float, tag: String) -> Void {
  if MBAI_Search_GetAreaThreshold(player) < 0.0 {
    return;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
  let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(40.0);
  let best: ref<NPCPuppet>;
  let bestDist: Float = range + 1.0;
  let i: Int32 = 0;
  while i < ArraySize(npcs) {
    let npc: ref<NPCPuppet> = npcs[i];
    if MBAI_PlayerAlertCanReceiveMovement(npc, player) && !MBAI_DeviceInvestigationOwnsMovement(npc) && (!npc.m_mbaiInvestigateFired) && NotEquals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) && MBAI_IsOrderAvailable(npc, n"Acoustics", now) && !MBAI_IntentBlocksCommand(npc, n"Acoustics", now) {
      let d: Float = Vector4.Distance(npc.GetWorldPosition(), noisePos);
      if d < bestDist {
        bestDist = d;
        best = npc;
      };
    };
    i += 1;
  };
  if IsDefined(best) {
    best.m_mbaiInvestigateFired = true;
    TargetTrackingExtension.InjectThreat(best, noisePos, 15.0);
    MBAI_Search_MoveToForOwner(best, noisePos, false, tag, n"Acoustics");
    MBAInfo(tag, s"noise -> npc=\(ToString(best.GetEntityID())) walking to investigate dist=\(bestDist)");
  }
}

@wrapMethod(ThrowableKnifeNPC)
protected cb func OnCollision(eventData: ref<gameprojectileHitEvent>) -> Bool {
  let result: Bool = wrappedMethod(eventData);
  if IsDefined(eventData) && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Combat) && ArraySize(eventData.hitInstances) > 0 {
    let playerSystem = GameInstance.GetPlayerSystem(this.GetGame());
    let player: ref<PlayerPuppet> = IsDefined(playerSystem)
      ? playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet
      : null;
    if IsDefined(player) {
      let hit: gameprojectileHitInstance = eventData.hitInstances[0];
      let obj: wref<GameObject> = this.GetObject(hit);
      if !IsDefined(obj) || (!obj.IsNPC() && !obj.IsDrone() && !obj.IsPlayer()) {
        MBAI_Noise_Recruit(player, this.GetWorldPosition(), 5.0, "KnifeNoise");
      };
    };
  };
  return result;
}

@wrapMethod(CarriedObjectEvents)
protected final func CleanUpCarryStateMachine(state: ECarryState, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(state, stateContext, scriptInterface);
  if !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Body) {
    return;
  };
  if this.GetIsFriendlyCarryParameter(stateContext) {
    return;
  };
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    MBAI_Noise_Recruit(player, scriptInterface.owner.GetWorldPosition(), 15.0, "BodyDrop");
  }
}

@wrapMethod(DisposalDevice)
protected cb func OnDisposeBody(evt: ref<DisposeBody>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !MBAI_Acoustic_ATOOwnsDisposal() && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Body) {
    let playerSystem = GameInstance.GetPlayerSystem(this.GetGame());
    let player: ref<PlayerPuppet> = IsDefined(playerSystem)
      ? playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet
      : null;
    if IsDefined(player) {
      MBAI_Noise_Recruit(player, this.GetWorldPosition(), 5.0, "BodyStash");
    };
  };
  return result;
}
