module MuchBetterAI.Footwork

import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Nerve.*
import MuchBetterAI.Squad.*
import MuchBetterAI.Stealth.*

@addField(NPCPuppet)
let m_mbaiShotOpportunity: Float;

@addField(NPCPuppet)
let m_mbaiOpportunityPoorSince: Float;

@addField(NPCPuppet)
let m_mbaiOpportunityLastSample: Float;

@addField(NPCPuppet)
let m_mbaiOpportunityCooldownUntil: Float;

public func MBAI_RecordShotOpportunity(npc: ref<NPCPuppet>, score: Float, now: Float) -> Void {
  let sample: Float = ClampF(score, 0.0, 1.35);
  if npc.m_mbaiOpportunityLastSample <= 0.0 || now - npc.m_mbaiOpportunityLastSample > 4.0 {
    npc.m_mbaiShotOpportunity = sample;
    npc.m_mbaiOpportunityPoorSince = 0.0;
  } else {
    npc.m_mbaiShotOpportunity = LerpF(0.35, npc.m_mbaiShotOpportunity, sample);
  };
  npc.m_mbaiOpportunityLastSample = now;
  if npc.m_mbaiShotOpportunity <= 0.52 {
    if npc.m_mbaiOpportunityPoorSince <= 0.0 {
      npc.m_mbaiOpportunityPoorSince = now;
    };
  } else {
    if npc.m_mbaiShotOpportunity >= 0.68 {
      npc.m_mbaiOpportunityPoorSince = 0.0;
    };
  };
}

public class MBAI_OpportunityOrder {
  public let id: EntityID;
  public let squadName: CName;
  public let affiliation: gamedataAffiliation;
  public let fallbackID: EntityID;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let destination: Vector4;
  public let startTime: Float;
  public let nativeUntil: Float;
  public let reacquireUsed: Bool;
  public let lastPos: Vector4;
  public let lastProgressTime: Float;
}

public class MBAI_OpportunityRepositionSystem extends ScriptableSystem {
  private let m_orders: array<ref<MBAI_OpportunityOrder>>;
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("Opportunity", "firing-angle reposition online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(3.0);
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    MBAI_CancelDelay(gi, this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
    this.CancelAll(gi, EngineTime.ToFloat(GameInstance.GetSimTime(gi)));
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_OpportunityRepositionCallback> = new MBAI_OpportunityRepositionCallback();
    cb.system = this;
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    this.MonitorOrders(gi, player, now);
    if 2 > 0 {
      if IsDefined(player) {
        this.TryReposition(gi, player, now);
      };
    } else {
      this.CancelAll(gi, now);
    };
    this.ScheduleTick(ArraySize(this.m_orders) > 0 ? 0.5 : 1.5);
  }

  private final func TryReposition(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    if !player.IsInCombat() {
      return;
    };
    let fireteam: ref<MBAI_FireteamSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_FireteamSystem") as MBAI_FireteamSystem;
    let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    let npcs: array<wref<NPCPuppet>> = MBAI_NearbyCombatActors(gi, player, 45.0, 0.40);
    let picked: ref<NPCPuppet>;
    let pickedScore: Float = 2.0;
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i] as NPCPuppet;
      if IsDefined(npc) && this.IsEligible(npc, player, fireteam, nerve, now) && !this.GroupHasOrder(npc) && npc.m_mbaiShotOpportunity < pickedScore {
        picked = npc;
        pickedScore = npc.m_mbaiShotOpportunity;
      };
      i += 1;
    };
    if IsDefined(picked) {
      let destination: Vector4;
      let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(picked);
      if this.FindFiringPoint(gi, picked, player, weapon, destination) {
        this.IssueMove(picked, player, destination, now);
      } else {
        picked.m_mbaiOpportunityCooldownUntil = now + 5.0;
      };
    };
  }

  private final func IsEligible(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, fireteam: ref<MBAI_FireteamSystem>, nerve: ref<MBAI_NerveSystem>, now: Float) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) || npc.IsMechanical() || ScriptedPuppet.IsBlinded(npc) {
      return false;
    };
    if !MBAI_ActorHasLegMobility(npc) {
      return false;
    };
    if !Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
      return false;
    };
    let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(npc);
    if !IsDefined(weapon) || !weapon.IsRanged() {
      return false;
    };
    let poorDuration: Float = MaxF(2.5, (5.0 - MBAI_TierSkillLevel(npc) * 0.5) * 0.70);
    if npc.m_mbaiOpportunityPoorSince <= 0.0 || now - npc.m_mbaiOpportunityPoorSince < poorDuration || now - npc.m_mbaiOpportunityLastSample > 4.0 || now < npc.m_mbaiOpportunityCooldownUntil {
      return false;
    };
    if now - npc.m_mbaiLastShotAtPlayerSim < 0.6 || !MBAI_CanClaimExecutionLease(npc, n"Opportunity", now) {
      return false;
    };
    if MBAI_IntentBlocksCommand(npc, n"Opportunity", now) || (IsDefined(fireteam) && fireteam.HasActiveOrder(npc.GetEntityID())) || (IsDefined(nerve) && nerve.HasActiveAssignment(npc.GetEntityID())) {
      return false;
    };
    if MBAI_CounterPerchActive(npc.GetGame(), npc, player, now) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    return !ai.IsCommandActive(n"AIMoveToCommand") && !ai.IsCommandActive(n"AIHoldPositionCommand") && !ai.IsCommandActive(n"AIThrowGrenadeCommand") && !ai.IsCommandActive(n"AIBaseUseWorkspotCommand");
  }

  private final func FindFiringPoint(gi: GameInstance, npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, weapon: ref<WeaponObject>, out result: Vector4) -> Bool {
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let npcPos: Vector4 = npc.GetWorldPosition();
    let tracked: TrackedLocation;
    let playerPos: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, playerPos) {
      return false;
    };
    let weaponType: gamedataItemType = RPGManager.GetItemType(weapon.GetItemID());
    let currentDistance: Float = Vector4.Distance(npcPos, playerPos);
    let currentBand: Float = MBAI_WeaponBand(currentDistance, weaponType);
    let currentClear: Bool = MBAI_CorpseLOS.RayClearBetween(gi, npcPos, playerPos);
    let currentDir: Vector4 = Vector4.Normalize(npcPos - playerPos);
    let bestScore: Float = -1.0;
    let ring: Int32 = 0;
    while ring < 2 {
      let radius: Float = ring == 0 ? 5.0 : 8.0;
      let angleIndex: Int32 = 0;
      while angleIndex < 8 {
        let angle: Float = Cast<Float>(angleIndex) * 0.7853981633974483;
        let candidate: Vector4 = npcPos;
        candidate.X += CosF(angle) * radius;
        candidate.Y += SinF(angle) * radius;
        let pointResult = nav.FindPointInSphereForCharacter(candidate, 1.25, npc);
        if Equals(pointResult.status, worldNavigationRequestStatus.OK) {
          let snapped: Vector4 = pointResult.point;
          let moveDistance: Float = Vector4.Distance(npcPos, snapped);
          if moveDistance >= 3.0 && moveDistance <= 10.0 && AbsF(snapped.Z - npcPos.Z) <= 1.5 && MBAI_CorpseLOS.RayClearBetween(gi, snapped, playerPos) {
            let path: ref<NavigationPath> = nav.CalculatePathForCharacter(npcPos, snapped, 0.5, npc);
            if IsDefined(path) && ArraySize(path.path) > 0 {
              let candidateDistance: Float = Vector4.Distance(snapped, playerPos);
              let candidateBand: Float = MBAI_WeaponBand(candidateDistance, weaponType);
              if candidateBand >= currentBand + 0.08 || (!currentClear && candidateBand >= currentBand - 0.05) {
                let candidateDir: Vector4 = Vector4.Normalize(snapped - playerPos);
                let lateralGain: Float = 1.0 - AbsF(Vector4.Dot(currentDir, candidateDir));
                let score: Float = candidateBand * 4.0 + lateralGain * 1.5 - moveDistance * 0.05;
                if score > bestScore {
                  bestScore = score;
                  result = snapped;
                };
              };
            };
          };
        };
        angleIndex += 1;
      };
      ring += 1;
    };
    return bestScore >= 0.0;
  }

  private final func IssueMove(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, destination: Vector4, now: Float) -> Bool {
    let cmd: ref<AICommand>;
    let leaseToken: Int32;
    let ok: Bool = this.SendMoveCommand(npc, player, destination, now, cmd, leaseToken);
    if ok {
      let order: ref<MBAI_OpportunityOrder> = new MBAI_OpportunityOrder();
      order.id = npc.GetEntityID();
      order.squadName = MBAI_CombatGroupSquadName(npc);
      order.fallbackID = npc.GetEntityID();
      order.cmd = cmd;
      order.leaseToken = leaseToken;
      order.destination = destination;
      order.startTime = now;
      order.nativeUntil = 0.0;
      order.reacquireUsed = false;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      ArrayPush(this.m_orders, order);
      MBAI_SetIntent(npc, n"FootworkReposition", n"Opportunity", 7.0, now);
      npc.m_mbaiOpportunityPoorSince = 0.0;
      npc.m_mbaiOpportunityCooldownUntil = now + 7.0;
      MBAInfo("Opportunity", s"reposition npc=\(ToString(order.id)) quality=\(npc.m_mbaiShotOpportunity)");
    };
    return ok;
  }

  private final func SendMoveCommand(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, destination: Vector4, now: Float, out sentCommand: ref<AICommand>, out leaseToken: Int32) -> Bool {
    if !MBAI_ActorHasLegMobility(npc) || !MBAI_EnemyCanReceiveMovement(npc) || !MBAI_CanClaimExecutionLease(npc, n"Opportunity", now) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destinationWp: WorldPosition;
    WorldPosition.SetVector4(destinationWp, destination);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destinationWp);
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = false;
    if !ai.SendCommand(cmd) {
      return false;
    };
    sentCommand = cmd;
    leaseToken = MBAI_ClaimExecutionLease(npc, n"Opportunity", 7.0, now);
    return true;
  }

  private final func GroupHasOrder(npc: ref<NPCPuppet>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let order: ref<MBAI_OpportunityOrder> = this.m_orders[i];
      if MBAI_CombatGroupMatches(order.squadName, order.fallbackID, npc) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public final func HasActiveOrder(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if Equals(this.m_orders[i].id, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func MonitorOrders(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_OpportunityOrder> = this.m_orders[i];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      let remove: Bool = false;
      let cancel: Bool = false;
      if !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || !MBAI_ActorHasLegMobility(npc) || !MBAI_EnemyMovementEligible(npc) || !IsDefined(player) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
        remove = true;
        if IsDefined(npc) && !npc.IsDead() && !ScriptedPuppet.IsDefeated(npc) {
          let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
          if IsDefined(ai) && IsDefined(order.cmd) {
            ai.CancelCommand(order.cmd);
          };
        };
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
        } else {
          if StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
            remove = true;
            cancel = true;
          } else {
            if !IsDefined(order.cmd) {
              if now >= order.nativeUntil {
                if order.reacquireUsed {
                  remove = true;
                } else {
                  let destination: Vector4;
                  let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(npc);
                  let reacquired: ref<AICommand>;
                  let reacquiredToken: Int32;
                  if IsDefined(weapon) && weapon.IsRanged() && this.FindFiringPoint(gi, npc as NPCPuppet, player, weapon, destination) && this.SendMoveCommand(npc as NPCPuppet, player, destination, now, reacquired, reacquiredToken) {
                    order.cmd = reacquired;
                    order.leaseToken = reacquiredToken;
                    order.destination = destination;
                    order.startTime = now;
                    order.lastPos = npc.GetWorldPosition();
                    order.lastProgressTime = now;
                    order.reacquireUsed = true;
                    MBAI_SetIntent(npc as NPCPuppet, n"FootworkReposition", n"Opportunity", 7.0, now);
                  } else {
                    remove = true;
                  };
                };
              };
            } else {
              let state: AICommandState = ai.GetCommandState(order.cmd);
              if Equals(state, AICommandState.Interrupted) {
                MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Opportunity", order.leaseToken, now, 1.5);
                MBAI_ClearIntent(npc as NPCPuppet, n"Opportunity");
                order.cmd = null;
                order.nativeUntil = now + 1.5;
                MBATrace("Opportunity", s"interruption assignment npc=\(ToString(order.id)) reacquireAt=\(order.nativeUntil)");
              } else {
                if Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) || Vector4.Distance(npc.GetWorldPosition(), order.destination) <= 1.5 {
                  remove = true;
                } else {
                  if now - order.startTime > 8.0 {
                    remove = true;
                    cancel = true;
                  } else {
                    let currentPos: Vector4 = npc.GetWorldPosition();
                    if Vector4.Distance(currentPos, order.lastPos) > 1.0 {
                      order.lastPos = currentPos;
                      order.lastProgressTime = now;
                    } else {
                      if now - order.lastProgressTime > 3.0 {
                        remove = true;
                        cancel = true;
                      };
                    };
                  };
                };
              };
            };
          };
          if remove && cancel && IsDefined(order.cmd) {
            ai.CancelCommand(order.cmd);
          };
        };
      };
      if remove {
        this.EndOrder(npc, now);
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
  }

  private final func EndOrder(npc: wref<NPCPuppet>, now: Float) -> Void {
    if IsDefined(npc) {
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      MBAI_ReleaseExecutionLease(npcSharp, n"Opportunity", this.FindLeaseToken(npcSharp.GetEntityID()), now, 0.5);
      MBAI_ClearIntent(npcSharp, n"Opportunity");
      npcSharp.m_mbaiOpportunityCooldownUntil = MaxF(npcSharp.m_mbaiOpportunityCooldownUntil, now + 7.0);
    };
  }

  private final func FindLeaseToken(id: EntityID) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if Equals(this.m_orders[i].id, id) {
        return this.m_orders[i].leaseToken;
      };
      i += 1;
    };
    return 0;
  }

  private final func CancelAll(gi: GameInstance, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_OpportunityOrder> = this.m_orders[i];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if IsDefined(npc) {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) && IsDefined(order.cmd) {
          ai.CancelCommand(order.cmd);
        };
      };
      this.EndOrder(npc, now);
      ArrayErase(this.m_orders, i);
      i -= 1;
    };
  }
}

public class MBAI_OpportunityRepositionCallback extends DelayCallback {
  public let system: wref<MBAI_OpportunityRepositionSystem>;

  public func Call() -> Void {
    let system: ref<MBAI_OpportunityRepositionSystem> = this.system;
    if IsDefined(system) {
      system.Tick();
    };
  }
}
