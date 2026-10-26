module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

@wrapMethod(ShootEvents)
protected final func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  if !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Combat) {
    return;
  };
  if !IsDefined(scriptInterface.executionOwner as PlayerPuppet) {
    return;
  };
  let weapon: ref<WeaponObject> = this.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) {
    return;
  };
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if MBAI_IsWeaponSilenced(weapon, scriptInterface.GetGame()) {
    PlayerCoverHelper.BlockCoverVisibilityReduction(scriptInterface.executionOwner);
    MBATrace("Stealth", "exposure: silenced fire dropped cover-visibility");
    return;
  };
  let broadcaster: ref<StimBroadcasterComponent> = player.GetStimBroadcasterComponent();
  if !IsDefined(broadcaster) {
    return;
  };
  let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(40.0);
  let i: Int32 = 0;
  while i < ArraySize(npcs) {
    if MBAI_PlayerAlertMovementEligible(npcs[i], player) && NotEquals(npcs[i].GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Relaxed) {
      broadcaster.SendDrirectStimuliToTarget(player, gamedataStimType.SoundDistraction, npcs[i]);
    };
    i += 1;
  };
  MBATrace("Stealth", "shot-direction: loud fire -> " + ToString(ArraySize(npcs)) + " nearby orient to shooter");
}
