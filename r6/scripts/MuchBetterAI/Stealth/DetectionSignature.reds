module MuchBetterAI.Stealth

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

public static func MBAI_TimeOfDayLightFactor(gi: GameInstance, player: ref<PlayerPuppet>) -> Float {
  if IsEntityInInteriorArea(player) {
    return 1.0;
  };
  let gt: GameTime = GameInstance.GetGameTime(gi);
  let hour: Float = Cast<Float>(GameTime.Hours(gt)) + Cast<Float>(GameTime.Minutes(gt)) / 60.0;
  let nightF: Float = 0.6;
  if hour >= 21.0 || hour < 5.0 {
    return nightF;
  };
  if hour >= 9.0 && hour < 17.0 {
    return 1.0;
  };
  if hour >= 5.0 && hour < 9.0 {
    return nightF + (hour - 5.0) / 4.0 * (1.0 - nightF);
  };
  return 1.0 - (hour - 17.0) / 4.0 * (1.0 - nightF);
}

public static func MBAI_VanillaDetectionMultiplier(owner: ref<ScriptedPuppet>, target: ref<ScriptedPuppet>, out multiplier: Float) -> Bool {
  let cssi: ref<CombatSquadScriptInterface>;
  let tl: TrackedLocation;
  let tte: ref<TargetTrackingExtension> = owner.GetTargetTrackerComponent() as TargetTrackingExtension;
  AISquadHelper.GetCombatSquadInterface(target, cssi);
  if !IsDefined(cssi) || !IsDefined(tte) {
    return false;
  };
  if tte.IsSquadTracked(cssi) {
    multiplier = 100.0;
    return true;
  };
  if tte.ThreatFromEntity(target, tl) && tl.sharedAccuracy > 0.0 {
    multiplier = 10.0;
    return true;
  };
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  if IsDefined(player) && player.IsInCombat() {
    multiplier = 2.0;
    return true;
  };
  multiplier = 1.0;
  return true;
}

@wrapMethod(SenseComponent)
public final func RefreshCombatDetectionMultiplier(target: ref<ScriptedPuppet>) -> Void {
  wrappedMethod(target);
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  if !IsDefined(player) {
    return;
  };
  let owner: ref<ScriptedPuppet> = this.GetOwnerPuppet();
  if !IsDefined(owner) {
    return;
  };
  let npc: ref<NPCPuppet> = owner as NPCPuppet;
  if !MBAI_PlayerAlertEligible(npc, player) {
    return;
  };
  let state: gamedataNPCHighLevelState = owner.GetHighLevelStateFromBlackboard();
  let vanillaBase: Float;
  if !MBAI_VanillaDetectionMultiplier(owner, target, vanillaBase) {
    return;
  };
  let inherited: Float = this.GetDetectionMultiplier(player.GetEntityID());
  let floor: Float = MaxF(vanillaBase, inherited);
  if Equals(state, gamedataNPCHighLevelState.Combat) || vanillaBase >= 10.0 {
    this.SetDetectionMultiplier(player.GetEntityID(), floor);
    return;
  };
  let dist: Float = Vector4.Distance(owner.GetWorldPosition(), player.GetWorldPosition());
  let distF: Float = ClampF(1.6 - dist / 40.0, 0.6, 1.5);
  let speed: Float = Vector4.Length(player.GetVelocity());
  let speedF: Float = ClampF(0.7 + speed / 6.0 * 0.6, 0.7, 1.35);
  let alertF: Float = 1.0;
  if Equals(state, gamedataNPCHighLevelState.Alerted) {
    alertF = 2.5;
  } else {
    if owner.IsInvestigating() {
      alertF = 1.5;
    };
  };
  if alertF == 1.0 {
    let now2: Float = EngineTime.ToFloat(GameInstance.GetSimTime(owner.GetGame()));
    let combatExitTs: Float = AIAutonomousConditions.IsPlayerRecentlyDroppedThreat(owner) ? player.GetCombatExitTimestamp() : 0.0;
    let alertEnd: Float = MBAI_AlertClockEnd(npc);
    let heightenedStart: Float = combatExitTs;
    if alertEnd > 0.0 && alertEnd < now2 && alertEnd > heightenedStart {
      heightenedStart = alertEnd;
    };
    let window: Float = 60.0;
    if heightenedStart > 0.0 && (now2 - heightenedStart) < window {
      let age: Float = (now2 - heightenedStart) / window;
      let peak: Float = 2.0;
      alertF = peak + (1.0 - peak) * age;
    };
  };
  let tierF: Float = 1.0;
  tierF = ClampF(0.8 + (MBAI_TierSkillLevel(npc) - 1.0) / 3.5 * 0.7, 0.8, 1.5);
  let idF: Float = 1.0;
  if owner.m_mbaiIdentifiedAt > 0.0 && (EngineTime.ToFloat(GameInstance.GetSimTime(owner.GetGame())) - owner.m_mbaiIdentifiedAt) < 5.0 {
    idF = 2.5;
  };
  let gi: GameInstance = owner.GetGame();
  let lightF: Float = MBAI_TimeOfDayLightFactor(gi, player);
  let coverF: Float = 1.0;
  let blackboard = GameInstance.GetBlackboardSystem(gi);
  let psmBB: ref<IBlackboard> = IsDefined(blackboard)
    ? blackboard.GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine)
    : null;
  if IsDefined(psmBB) && psmBB.GetBool(GetAllBlackboardDefs().PlayerStateMachine.UsingCover) {
    coverF = 0.7;
  };
  let ceiling: Float = MaxF(floor, vanillaBase * 10.0);
  let shaped: Float = ClampF(floor * distF * speedF * alertF * tierF * idF * lightF * coverF * 3.0, floor, ceiling);
  this.SetDetectionMultiplier(player.GetEntityID(), shaped);
  MBATrace("Stealth", s"detect mult vanilla=\(vanillaBase) inherited=\(inherited) dist=\(dist) speed=\(speed) alert=\(alertF) tier=\(tierF) id=\(idF) light=\(lightF) cover=\(coverF) -> \(shaped)");
}
