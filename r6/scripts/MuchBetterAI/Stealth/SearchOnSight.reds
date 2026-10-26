module MuchBetterAI.Stealth

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

@addField(NPCPuppet)
let m_mbaiInvestigateFired: Bool;

@addField(SensorDevice)
let m_mbaiCamFired: Bool;

public class MBAI_SearchSpikeSystem extends ScriptableSystem {
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("Search", "on-sight investigate online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(3.0);
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    MBAI_CancelTrackedMoveToOwner(gi, n"Search", now);
    GameInstance.GetDelaySystem(this.GetGameInstance()).CancelDelay(this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_SearchSpikeCallback> = new MBAI_SearchSpikeCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Evaluate(gi, player);
      this.PollCameras(player);
    } else {
      let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
      MBAI_CancelTrackedMoveToOwner(gi, n"Search", now);
    };
    this.ScheduleTick(1.0);
  }

  private final func Evaluate(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let broadcaster: ref<StimBroadcasterComponent> = player.GetStimBroadcasterComponent();
    if !IsDefined(broadcaster) {
      return;
    };
    let threshold: Float = MBAI_Search_GetAreaThreshold(player);
    if threshold < 0.0 {
      return;
    };
    let rearm: Float = threshold - 0.02;
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(30.0);
    let count: Int32 = ArraySize(npcs);
    MBADebug("Search", s"hostile area thr=\(threshold) npcs=\(count)");
    let i: Int32 = 0;
    while i < count {
      let npc: ref<NPCPuppet> = npcs[i];
      if MBAI_PlayerAlertMovementEligible(npc, player) && !MBAI_DeviceInvestigationOwnsMovement(npc) {
        let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
        let det: Float = MBAI_Search_GetDetection(npc);
        MBATrace("Search", s"scan npc=\(ToString(npc.GetEntityID())) state=\(EnumInt(state)) det=\(det)");
        if Equals(state, gamedataNPCHighLevelState.Combat) || det < rearm {
          npc.m_mbaiInvestigateFired = false;
        } else {
          MBATrace("Search", s"npc=\(ToString(npc.GetEntityID())) det=\(det) fired=\(npc.m_mbaiInvestigateFired)");
          if !npc.m_mbaiInvestigateFired && det >= threshold {
            npc.m_mbaiInvestigateFired = true;
            let inv: stimInvestigateData;
            inv.distrationPoint = player.GetWorldPosition();
            broadcaster.SendDrirectStimuliToTarget(player, gamedataStimType.VisualDistract, npc, inv);
            MBAInfo("Search", s"investigate fired npc=\(ToString(npc.GetEntityID())) det=\(det) thr=\(threshold)");
          };
        };
      };
      i += 1;
    };
  }

  private final func PollCameras(player: ref<PlayerPuppet>) -> Void {
    if MBAI_Search_GetAreaThreshold(player) < 0.0 {
      return;
    };
    let playerID: EntityID = player.GetEntityID();
    let camRange: Float = 40.0;
    let entities: array<ref<Entity>> = player.GetEntitiesAroundObject(camRange, TSF_Quickhackable());
    let i: Int32 = 0;
    while i < ArraySize(entities) {
      let sensor: ref<SensorDevice> = entities[i] as SensorDevice;
      if IsDefined(sensor) && sensor.GetDevicePS().IsON() && (sensor.IsSurveillanceCamera() || sensor.IsTurret()) && NotEquals(sensor.GetAttitudeTowards(player), EAIAttitude.AIA_Friendly) {
        let sense: ref<SenseComponent> = sensor.GetSensesComponent();
        if IsDefined(sense) {
          let camDet: Float = sense.GetDetection(playerID) / 100.0;
          MBATrace("Camera", s"cam=\(ToString(sensor.GetEntityID())) det=\(camDet) fired=\(sensor.m_mbaiCamFired)");
          if camDet < 0.08 {
            sensor.m_mbaiCamFired = false;
          } else {
            if !sensor.m_mbaiCamFired && camDet >= 0.10 && camDet < 1.0 {
              sensor.m_mbaiCamFired = true;
              let npc: ref<NPCPuppet> = MBAI_Search_ClosestNPCTo(sensor, player, camRange);
              if IsDefined(npc) {
                npc.m_mbaiInvestigateFired = true;
                TargetTrackingExtension.InjectThreat(npc, player.GetWorldPosition(), 20.0);
                MBAI_Search_MoveToWithContext(npc, player.GetWorldPosition(), "CameraInvestigate");
                let dist: Float = Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition());
                MBAInfo("Camera", s"camera alert cam=\(ToString(sensor.GetEntityID())) -> npc=\(ToString(npc.GetEntityID())) dist=\(dist) state=\(ToString(EnumInt(npc.GetHighLevelStateFromBlackboard()))) det=\(camDet)");
              } else {
                MBAInfo("Camera", s"camera cam=\(ToString(sensor.GetEntityID())) det=\(camDet) but NO eligible npc near you (all already investigating / in combat)");
              };
            };
          };
        };
        let corpses: array<ref<NPCPuppet>> = sensor.GetNPCsAroundObject(30.0);
        let c: Int32 = 0;
        while c < ArraySize(corpses) {
          let corpse: ref<NPCPuppet> = corpses[c];
          if IsDefined(corpse) && corpse.IsDead() && MBAI_CorpseLOS.HasAnyLOS(sensor, corpse.GetWorldPosition()) {
            let cameraDeadBodyData: ref<CameraDeadBodyData> = new CameraDeadBodyData();
            cameraDeadBodyData.ownerID = sensor.GetEntityID();
            cameraDeadBodyData.bodyID = corpse.GetEntityID();
            let bodyPos: Vector4 = corpse.GetWorldPosition();
            let ps: ref<SensorDeviceControllerPS> = sensor.GetDevicePS();
            if IsDefined(ps) && !GameSessionDataSystem.CheckDataRequest(sensor.GetGame(), EGameSessionDataType.CameraDeadBody, ToVariant(cameraDeadBodyData)) {
              GameSessionDataSystem.AddDataEntryRequest(sensor.GetGame(), EGameSessionDataType.CameraDeadBody, ToVariant(cameraDeadBodyData));
              ps.TriggerSecuritySystemNotification(corpse, bodyPos, ESecurityNotificationType.ALARM);
              MBAInfo("Camera", s"cam=\(ToString(sensor.GetEntityID())) spotted body \(ToString(corpse.GetEntityID())) -> ALARM + alert duration");
            };
          };
          c += 1;
        };
      };
      i += 1;
    };
  }
}

public func MBAI_Search_ClosestNPCTo(source: ref<GameObject>, player: ref<PlayerPuppet>, range: Float) -> ref<NPCPuppet> {
  let npcs: array<ref<NPCPuppet>> = source.GetNPCsAroundObject(range);
  let spos: Vector4 = source.GetWorldPosition();
  let best: ref<NPCPuppet>;
  let bestDist: Float = range + 1.0;
  let i: Int32 = 0;
  while i < ArraySize(npcs) {
    let npc: ref<NPCPuppet> = npcs[i];
    if MBAI_PlayerAlertCanReceiveMovement(npc, player) && !npc.m_mbaiInvestigateFired && !MBAI_DeviceInvestigationOwnsMovement(npc) && NotEquals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
      let d: Float = Vector4.Distance(npc.GetWorldPosition(), spos);
      if d < bestDist {
        bestDist = d;
        best = npc;
      };
    };
    i += 1;
  };
  return best;
}

public func MBAI_Search_MoveTo(npc: ref<NPCPuppet>, pos: Vector4) -> Bool {
  return MBAI_Search_MoveToWithContext(npc, pos, "SearchMove");
}

public func MBAI_Search_MoveToWithContext(npc: ref<NPCPuppet>, pos: Vector4, context: String) -> Bool {
  return MBAI_Search_MoveToWithCombatFlagAndContext(npc, pos, false, context);
}

public func MBAI_Search_MoveToWithCombatFlag(npc: ref<NPCPuppet>, pos: Vector4, ignoreCombat: Bool) -> Bool {
  return MBAI_Search_MoveToWithCombatFlagAndContext(npc, pos, ignoreCombat, "SearchMove");
}

public func MBAI_Search_MoveToWithCombatFlagAndContext(npc: ref<NPCPuppet>, pos: Vector4, ignoreCombat: Bool, context: String) -> Bool {
  return MBAI_Search_MoveToForOwner(npc, pos, ignoreCombat, context, n"Search");
}

public func MBAI_Search_MoveToForOwner(npc: ref<NPCPuppet>, pos: Vector4, ignoreCombat: Bool, context: String, owner: CName) -> Bool {
  let player: ref<PlayerPuppet> = IsDefined(npc) ? GetPlayer(npc.GetGame()) : null;
  if !MBAI_PlayerAlertCanReceiveMovement(npc, player) {
    if IsDefined(npc) {
      MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) record=\(TDBID.ToStringDEBUG(npc.GetRecordID())) reason=actor-ownership");
    };
    return false;
  };
  if MBAI_DeviceInvestigationOwnsMovement(npc) {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=device-investigation");
    return false;
  };
  let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
  if !IsDefined(ai) {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=no-ai");
    return false;
  };
  let gi: GameInstance = npc.GetGame();
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  if MBAI_IntentBlocksCommand(npc, owner, now) {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=intent-block intent=\(ToString(MBAI_GetIntent(npc, now)))");
    return false;
  };
  if !MBAI_CanClaimExecutionLease(npc, owner, now) {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=lease-guard");
    return false;
  };
  let zDiff: Float = pos.Z - npc.GetWorldPosition().Z;
  let maxClimb: Float = MBAI_MaxVerticalClimb(npc);
  if zDiff > maxClimb {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=vertical zDiff=\(zDiff) max=\(maxClimb)");
    return false;
  };
  let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
  let path: ref<NavigationPath> = nav.CalculatePathForCharacter(npc.GetWorldPosition(), pos, 0.5, npc);
  if !IsDefined(path) || ArraySize(path.path) <= 0 {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=no-path dist=\(Vector4.Distance(npc.GetWorldPosition(), pos))");
    return false;
  };
  let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
  let destWp: WorldPosition;
  WorldPosition.SetVector4(destWp, pos);
  AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
  cmd.movementType = moveMovementType.Run;
  cmd.ignoreNavigation = false;
  cmd.desiredDistanceFromTarget = 2.0;
  cmd.finishWhenDestinationReached = true;
  cmd.ignoreInCombat = ignoreCombat;
  let sent: Bool = ai.SendCommand(cmd);
  if sent {
    let duration: Float = ignoreCombat ? 8.0 : 6.0;
    let intent: CName = n"Search";
    if StrContains(context, "Hunter") {
      intent = n"SearchHunter";
    } else {
      if StrContains(context, "Fan") {
        intent = n"SearchFan";
      } else {
        if StrContains(context, "LKP") {
          intent = n"SearchLKP";
        } else {
          if StrContains(context, "TakedownHeard") {
            intent = n"TakedownHeard";
          };
        };
      };
    };
    let leaseToken: Int32 = MBAI_ClaimExecutionLease(npc, owner, duration, now);
    MBAI_SetIntent(npc, intent, owner, duration, now);
    MBAI_TrackMoveTo(gi, npc, cmd, leaseToken, now);
    MBATrace("MoveTo", s"sent context=\(context) npc=\(ToString(npc.GetEntityID())) record=\(TDBID.ToStringDEBUG(npc.GetRecordID())) dist=\(Vector4.Distance(npc.GetWorldPosition(), pos)) ignoreCombat=\(ignoreCombat)");
  } else {
    MBADebug("MoveTo", s"fail context=\(context) npc=\(ToString(npc.GetEntityID())) reason=send-rejected dist=\(Vector4.Distance(npc.GetWorldPosition(), pos)) ignoreCombat=\(ignoreCombat)");
  };
  return sent;
}

public func MBAI_Search_GetAreaThreshold(player: ref<PlayerPuppet>) -> Float {
  let areaType: ESecurityAreaType = MBAI_Search_GetPlayerAreaType(player);
  if Equals(areaType, ESecurityAreaType.DANGEROUS) {
    return 0.05;
  };
  if Equals(areaType, ESecurityAreaType.RESTRICTED) {
    return 0.25;
  };
  return -1.0;
}

public func MBAI_Search_GetPlayerAreaType(player: ref<PlayerPuppet>) -> ESecurityAreaType {
  let psmBB: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
  if !IsDefined(psmBB) {
    return ESecurityAreaType.DISABLED;
  };
  let variantData: Variant = psmBB.GetVariant(GetAllBlackboardDefs().PlayerStateMachine.SecurityZoneData);
  if !IsDefined(variantData) {
    return ESecurityAreaType.DISABLED;
  };
  let securityData: SecurityAreaData = FromVariant<SecurityAreaData>(variantData);
  return securityData.securityAreaType;
}

public func MBAI_Search_GetDetection(npc: ref<NPCPuppet>) -> Float {
  return npc.GetDetectionPercentage() / 100.0;
}

public class MBAI_SearchSpikeCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_SearchSpikeSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Stealth.MBAI_SearchSpikeSystem") as MBAI_SearchSpikeSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
