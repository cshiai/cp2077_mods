module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

@addField(PlayerPuppet)
let m_mbaiLastSilencedScan: Float;

@addField(PlayerPuppet)
let m_mbaiAcousticSuppressedShot: Bool;

public func MBAI_IsWeaponSilenced(weapon: ref<WeaponObject>, gi: GameInstance) -> Bool {
  if !IsDefined(weapon) {
    return false;
  };
  return GameInstance.GetStatsSystem(gi).GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.CanSilentKill) > 0.0;
}

public func MBAI_Silenced_HeardRange(wt: gamedataItemType) -> Float {
  if Equals(wt, gamedataItemType.Wea_SniperRifle) || Equals(wt, gamedataItemType.Wea_PrecisionRifle) {
    return 25.0;
  };
  if Equals(wt, gamedataItemType.Wea_LightMachineGun) || Equals(wt, gamedataItemType.Wea_HeavyMachineGun) {
    return 22.0;
  };
  if Equals(wt, gamedataItemType.Wea_Shotgun) || Equals(wt, gamedataItemType.Wea_ShotgunDual) {
    return 20.0;
  };
  if Equals(wt, gamedataItemType.Wea_AssaultRifle) || Equals(wt, gamedataItemType.Wea_Rifle) {
    return 16.0;
  };
  if Equals(wt, gamedataItemType.Wea_SubmachineGun) {
    return 12.0;
  };
  return 10.0;
}

@wrapMethod(ShootEvents)
protected final func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    player.m_mbaiAcousticSuppressedShot = true;
  };
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(player) {
    player.m_mbaiAcousticSuppressedShot = false;
  };
  if !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Combat) {
    return;
  };
  if !IsDefined(player) {
    return;
  };
  let weapon: ref<WeaponObject> = this.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) {
    return;
  };
  let gi: GameInstance = scriptInterface.GetGame();
  if !MBAI_IsWeaponSilenced(weapon, gi) {
    return;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  if now - player.m_mbaiLastSilencedScan < 0.4 {
    return;
  };
  player.m_mbaiLastSilencedScan = now;
  let range: Float = MBAI_Silenced_HeardRange(WeaponObject.GetWeaponType(weapon.GetItemID())) * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Combat);
  let playerPos: Vector4 = player.GetWorldPosition();
  let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(range);
  let alerted: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(npcs) {
    let npc: ref<NPCPuppet> = npcs[i];
    if MBAI_PlayerAlertMovementEligible(npc, player) {
      let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
      if NotEquals(state, gamedataNPCHighLevelState.Combat) && Vector4.Distance(npc.GetWorldPosition(), playerPos) <= range {
        if NotEquals(state, gamedataNPCHighLevelState.Alerted) {
          NPCPuppet.ChangeHighLevelState(npc, gamedataNPCHighLevelState.Alerted);
          alerted += 1;
        };
        let anchorDuration: Float = 30.0;
        MBAI_Search_SetIncidentAnchor(npc, playerPos, now + anchorDuration, true);
        MBAI_RaiseAlert(npc, 30.0);
      };
    };
    i += 1;
  };
  if alerted > 0 {
    MBAInfo("Silenced", s"silenced shot alerted \(alerted) enemies within \(range)m");
  }
}
