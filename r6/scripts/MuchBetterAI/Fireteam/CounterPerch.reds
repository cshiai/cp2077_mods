module MuchBetterAI.Fireteam

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Stealth.*
import MuchBetterAI.Squad.*

public class MBAI_CounterPerchGroupState {
  public let squadName: CName;
  public let fallbackID: EntityID;
  public let perchPos: Vector4;
  public let stableSince: Float;
  public let lastSeen: Float;
  public let lastCheck: Float;
  public let activeUntil: Float;
  public let lastCoverSignal: Float;
  public let cordonCandidateID: EntityID;
  public let cordonPoint: Vector4;
  public let cordonID: EntityID;
  public let denialID: EntityID;
  public let nextDenialAttempt: Float;
  public let denialCursor: Int32;
}

public class MBAI_CounterPerchOrder {
  public let id: EntityID;
  public let squadName: CName;
  public let fallbackID: EntityID;
  public let kind: CName;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let destination: Vector4;
  public let startTime: Float;
  public let arrivedAt: Float;
  public let lastPos: Vector4;
  public let lastProgressTime: Float;
  public let arrived: Bool;
}

public class MBAI_CounterPerchSystem extends ScriptableSystem {
  private let m_groups: array<ref<MBAI_CounterPerchGroupState>>;
  private let m_orders: array<ref<MBAI_CounterPerchOrder>>;

  private func OnAttach() -> Void {
    MBAInfo("CounterPerch", "counter-perch coordinator online");
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    this.Reset(gi, EngineTime.ToFloat(GameInstance.GetSimTime(gi)));
  }

  public final func Reset(gi: GameInstance, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      this.EndOrder(gi, i, now, "reset", true);
      i -= 1;
    };
    ArrayClear(this.m_groups);
  }

  public final func EvaluateCounterPerch(gi: GameInstance, player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Void {
    this.RefreshOrderedGroups(gi, player, now);
    this.SyncGroups(squad, player, now);
    this.EvaluateGroups(gi, player, squad, now, fireteam);
    this.MonitorOrders(gi, player, now);
    this.IssueResponses(gi, player, squad, now, fireteam);
  }

  public final func IsActiveFor(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, now: Float) -> Bool {
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      if state.activeUntil > now && Vector4.Distance(state.perchPos, contactPosition) <= 3.0 && MBAI_CombatGroupMatches(state.squadName, state.fallbackID, npc) {
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

  private final func RefreshOrderedGroups(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let orderIndex: Int32 = 0;
    while orderIndex < ArraySize(this.m_orders) {
      let order: ref<MBAI_CounterPerchOrder> = this.m_orders[orderIndex];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if MBAI_EnemyMovementEligible(npc) && NPCPuppet.IsInCombatWithTarget(npc, player) {
        let tracked: TrackedLocation;
        let contactPosition: Vector4;
        if MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
          let groupIndex: Int32 = 0;
          while groupIndex < ArraySize(this.m_groups) {
            let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[groupIndex];
            if this.OrderMatchesGroup(order, state) && Vector4.Distance(state.perchPos, contactPosition) <= 3.0 {
              state.lastSeen = now;
              state.activeUntil = MaxF(state.activeUntil, now + 4.5);
            };
            groupIndex += 1;
          };
        };
      };
      orderIndex += 1;
    };
  }

  private final func SyncGroups(squad: array<wref<NPCPuppet>>, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let npc: wref<NPCPuppet> = squad[i];
      if IsDefined(npc) {
        let tracked: TrackedLocation;
        let contactPosition: Vector4;
        if MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
          let state: ref<MBAI_CounterPerchGroupState> = this.GetOrCreateGroup(npc, contactPosition, now);
          state.lastSeen = now;
        };
      };
      i += 1;
    };
    let groupIndex: Int32 = ArraySize(this.m_groups) - 1;
    while groupIndex >= 0 {
      if now - this.m_groups[groupIndex].lastSeen > 6.0 {
        if this.m_groups[groupIndex].activeUntil > now {
          MBAInfo("CounterPerch", "state ended reason=group-lost");
        };
        this.CancelGroupOrders(this.m_groups[groupIndex], now);
        ArrayErase(this.m_groups, groupIndex);
      };
      groupIndex -= 1;
    };
  }

  private final func GetOrCreateGroup(npc: wref<NPCPuppet>, playerPos: Vector4, now: Float) -> ref<MBAI_CounterPerchGroupState> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let current: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      if MBAI_CombatGroupMatches(current.squadName, current.fallbackID, npc) {
        return current;
      };
      i += 1;
    };
    let state: ref<MBAI_CounterPerchGroupState> = new MBAI_CounterPerchGroupState();
    state.squadName = MBAI_CombatGroupSquadName(npc);
    state.fallbackID = npc.GetEntityID();
    state.perchPos = playerPos;
    state.stableSince = now;
    state.lastSeen = now;
    ArrayPush(this.m_groups, state);
    return state;
  }

  private final func GatherGroupMembers(squad: array<wref<NPCPuppet>>, state: ref<MBAI_CounterPerchGroupState>) -> array<wref<NPCPuppet>> {
    let members: array<wref<NPCPuppet>>;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let npc: wref<NPCPuppet> = squad[i];
      if MBAI_CombatGroupMatches(state.squadName, state.fallbackID, npc) {
        ArrayPush(members, npc);
      };
      i += 1;
    };
    return members;
  }

  private final func EvaluateGroups(gi: GameInstance, player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      let members: array<wref<NPCPuppet>> = this.GatherGroupMembers(squad, state);
      if ArraySize(members) > 0 {
        let tracked: TrackedLocation;
        let contactPosition: Vector4;
        if MBAI_GetCombatGroupContact(members, player, members[0], tracked, contactPosition) {
          let resetDistance: Float = state.activeUntil > now ? 3.0 : 2.5;
          if Vector4.Distance(state.perchPos, contactPosition) > resetDistance {
            this.EndState(state, now, "contact-moved");
            state.perchPos = contactPosition;
            state.stableSince = now;
            state.lastCheck = 0.0;
          } else {
            if now - state.stableSince >= 5.0 && now - state.lastCheck >= 3.0 {
              this.EvaluateReachability(gi, state, members, contactPosition, now);
            };
            if state.activeUntil > now {
              this.YieldManeuvers(fireteam, members, now);
            };
          };
        };
      };
      i += 1;
    };
  }

  private final func EvaluateReachability(gi: GameInstance, state: ref<MBAI_CounterPerchGroupState>, members: array<wref<NPCPuppet>>, playerPos: Vector4, now: Float) -> Void {
    state.lastCheck = now;
    state.cordonCandidateID = EMPTY_ENTITY_ID();
    state.cordonPoint = new Vector4(0.0, 0.0, 0.0, 0.0);
    let memberCount: Int32 = ArraySize(members);
    let highCount: Int32 = 0;
    let checkedCount: Int32 = 0;
    let unreachableCount: Int32 = 0;
    let cordonScore: Float = 9999.0;
    let i: Int32 = 0;
    while i < memberCount {
      let npc: wref<NPCPuppet> = members[i];
      if playerPos.Z - npc.GetWorldPosition().Z >= 4.0 {
        highCount += 1;
      };
      let navResult: AINavigationSystemResult;
      if this.QueryReachability(gi, npc, playerPos, navResult) {
        checkedCount += 1;
        let reachable: Bool = navResult.hasPath;
        let hasClosest: Bool = navResult.hasClosestReachablePoint;
        let closest: Vector4;
        if !reachable && hasClosest {
          closest = WorldPosition.ToVector4(navResult.closestReachablePoint);
          let remaining: Vector4 = playerPos - closest;
          let horizontalSq: Float = remaining.X * remaining.X + remaining.Y * remaining.Y;
          reachable = AbsF(remaining.Z) <= 1.5 && horizontalSq <= 9.0;
        };
        if !reachable {
          unreachableCount += 1;
          if hasClosest && MBAI_ArchetypeIsCloseRange(MBAI_GetArchetype(npc)) {
            let score: Float = Vector4.Distance(npc.GetWorldPosition(), closest);
            if score > 2.0 && score < cordonScore {
              cordonScore = score;
              state.cordonCandidateID = npc.GetEntityID();
              state.cordonPoint = closest;
            };
          };
        };
      };
      i += 1;
    };
    let wasActive: Bool = state.activeUntil > now;
    let active: Bool = checkedCount > 0 && highCount * 2 > memberCount && unreachableCount * 2 > checkedCount;
    if active {
      state.activeUntil = now + 4.5;
      if !wasActive {
        MBAInfo("CounterPerch", s"state active members=\(memberCount) high=\(highCount) checked=\(checkedCount) unreachable=\(unreachableCount)");
      } else {
        MBADebug("CounterPerch", s"state confirmed members=\(memberCount) high=\(highCount) checked=\(checkedCount) unreachable=\(unreachableCount)");
      };
    } else {
      this.EndState(state, now, "reachability-restored");
      MBADebug("CounterPerch", s"state rejected members=\(memberCount) high=\(highCount) checked=\(checkedCount) unreachable=\(unreachableCount)");
    };
  }

  private final func QueryReachability(gi: GameInstance, npc: wref<NPCPuppet>, playerPos: Vector4, out result: AINavigationSystemResult) -> Bool {
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let query: AINavigationSystemQuery;
    let target: WorldPosition;
    AIPositionSpec.SetEntity(query.source, npc);
    WorldPosition.SetVector4(target, playerPos);
    AIPositionSpec.SetWorldPosition(query.target, target);
    let queryID: Uint32 = nav.StartPathfinding(query);
    let received: Bool = nav.GetResult(queryID, result);
    nav.StopPathfinding(queryID);
    return received && !result.hasFailed;
  }

  private final func EndState(state: ref<MBAI_CounterPerchGroupState>, now: Float, reason: String) -> Void {
    if state.activeUntil > now {
      MBAInfo("CounterPerch", "state ended reason=" + reason);
    };
    state.activeUntil = 0.0;
    state.cordonCandidateID = EMPTY_ENTITY_ID();
    state.cordonPoint = new Vector4(0.0, 0.0, 0.0, 0.0);
  }

  private final func YieldManeuvers(fireteam: ref<MBAI_FireteamSystem>, members: array<wref<NPCPuppet>>, now: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(members) {
      fireteam.YieldManeuverToCounterPerch(members[i], now);
      i += 1;
    };
  }

  private final func IssueResponses(gi: GameInstance, player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      if state.activeUntil > now {
        let members: array<wref<NPCPuppet>> = this.GatherGroupMembers(squad, state);
        if ArraySize(members) > 0 {
          let tracked: TrackedLocation;
          let contactPosition: Vector4;
          if MBAI_GetCombatGroupContact(members, player, members[0], tracked, contactPosition) && Vector4.Distance(state.perchPos, contactPosition) <= 3.0 {
            this.SignalCover(state, members, contactPosition, now);
            if !EntityID.IsDefined(state.cordonID) {
              this.TryCordon(gi, player, state, contactPosition, now, fireteam);
            };
            if !EntityID.IsDefined(state.denialID) && now >= state.nextDenialAttempt {
              state.nextDenialAttempt = now + 3.0;
              this.TryDenial(player, state, members, contactPosition, now, fireteam);
            };
          };
        };
      };
      i += 1;
    };
  }

  private final func SignalCover(state: ref<MBAI_CounterPerchGroupState>, members: array<wref<NPCPuppet>>, playerPos: Vector4, now: Float) -> Void {
    if now - state.lastCoverSignal < 3.0 {
      return;
    };
    state.lastCoverSignal = now;
    let coverAbility: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseCovers");
    let i: Int32 = 0;
    while i < ArraySize(members) {
      let npc: wref<NPCPuppet> = members[i];
      if MBAI_CorpseLOS.HasAnyLOS(npc as NPCPuppet, playerPos) && AIActionHelper.CheckAbility(npc, coverAbility) {
        ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 1.0);
      };
      i += 1;
    };
  }

  private final func TryCordon(gi: GameInstance, player: ref<PlayerPuppet>, state: ref<MBAI_CounterPerchGroupState>, playerPos: Vector4, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Void {
    if !EntityID.IsDefined(state.cordonCandidateID) || Vector4.IsZero(state.cordonPoint) {
      return;
    };
    let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, state.cordonCandidateID) as NPCPuppet;
    if !this.CanIssue(npc, now, fireteam) {
      return;
    };
    let npcDistance: Float = Vector4.Distance(npc.GetWorldPosition(), state.cordonPoint);
    let playerOffset: Vector4 = playerPos - state.cordonPoint;
    let horizontalSq: Float = playerOffset.X * playerOffset.X + playerOffset.Y * playerOffset.Y;
    if npcDistance < 2.0 || (AbsF(playerOffset.Z) <= 1.5 && horizontalSq <= 9.0) {
      return;
    };
    if this.IssueMove(npc, player, state, state.cordonPoint, n"Cordon", now) {
      state.cordonID = npc.GetEntityID();
      MBAInfo("CounterPerch", "cordon issued npc=" + ToString(state.cordonID) + " dist=" + ToString(npcDistance));
      MBAI_TryBark(npc as NPCPuppet, n"enemy_warning", n"MBAI:CounterPerchCordon", now, 8.0);
    };
  }

  private final func TryDenial(player: ref<PlayerPuppet>, state: ref<MBAI_CounterPerchGroupState>, members: array<wref<NPCPuppet>>, playerPos: Vector4, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let picked: wref<NPCPuppet>;
    let pickedPoint: Vector4;
    let bestScore: Float = 9999.0;
    let considered: Int32 = 0;
    let memberCount: Int32 = ArraySize(members);
    let visited: Int32 = 0;
    let i: Int32 = state.denialCursor;
    if i >= memberCount {
      i = 0;
    };
    while visited < memberCount && considered < 3 {
      let npc: wref<NPCPuppet> = members[i];
      if !Equals(npc.GetEntityID(), state.cordonID) && MBAI_CorpseLOS.HasAnyLOS(npc as NPCPuppet, playerPos) && this.CanIssue(npc, now, fireteam) {
        considered += 1;
        let point: Vector4;
        if this.FindDenialPoint(gi, npc, playerPos, point) {
          let score: Float = Vector4.Distance(npc.GetWorldPosition(), point);
          if score < bestScore {
            bestScore = score;
            picked = npc;
            pickedPoint = point;
          };
        };
      };
      i += 1;
      if i >= memberCount {
        i = 0;
      };
      visited += 1;
    };
    state.denialCursor = i;
    if IsDefined(picked) && this.IssueMove(picked, player, state, pickedPoint, n"Deny", now) {
      state.denialID = picked.GetEntityID();
      MBAInfo("CounterPerch", "denial issued npc=" + ToString(state.denialID) + " dist=" + ToString(bestScore));
    };
  }

  private final func CanIssue(npc: wref<NPCPuppet>, now: Float, fireteam: ref<MBAI_FireteamSystem>) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) || npc.IsMechanical() || now - (npc as NPCPuppet).m_mbaiLastOrderEnd <= 3.0 {
      return false;
    };
    if fireteam.HasActiveOrder(npc.GetEntityID()) || this.HasOrder(npc.GetEntityID()) || !MBAI_IsOrderAvailable(npc as NPCPuppet, n"CounterPerch", now) || MBAI_IntentBlocksCommand(npc as NPCPuppet, n"CounterPerch", now) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    return !ai.IsCommandActive(n"AIMoveToCommand") && !ai.IsCommandActive(n"AIHoldPositionCommand") && !ai.IsCommandActive(n"AIThrowGrenadeCommand");
  }

  private final func FindDenialPoint(gi: GameInstance, npc: wref<NPCPuppet>, playerPos: Vector4, out result: Vector4) -> Bool {
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let npcPos: Vector4 = npc.GetWorldPosition();
    let bestScore: Float = 9999.0;
    let found: Bool = false;
    let ring: Int32 = 1;
    while ring <= 3 {
      let radius: Float = 3.0 + Cast<Float>(ring) * 2.5;
      let angleIndex: Int32 = 0;
      while angleIndex < 8 {
        let angle: Float = Cast<Float>(angleIndex) * 0.7853981633974483;
        let candidate: Vector4 = npcPos;
        candidate.X += CosF(angle) * radius;
        candidate.Y += SinF(angle) * radius;
        let pointResult = nav.FindPointInSphereForCharacter(candidate, 1.5, npc);
        if Equals(pointResult.status, worldNavigationRequestStatus.OK) {
          let snapped: Vector4 = pointResult.point;
          let distance: Float = Vector4.Distance(npcPos, snapped);
          if distance >= 2.0 && AbsF(snapped.Z - npcPos.Z) <= 1.5 && !MBAI_CorpseLOS.RayClearBetween(gi, snapped, playerPos) {
            let path: ref<NavigationPath> = nav.CalculatePathForCharacter(npcPos, snapped, 0.5, npc);
            if IsDefined(path) && ArraySize(path.path) > 0 && distance < bestScore {
              bestScore = distance;
              result = snapped;
              found = true;
            };
          };
        };
        angleIndex += 1;
      };
      ring += 1;
    };
    return found;
  }

  private final func IssueMove(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, state: ref<MBAI_CounterPerchGroupState>, destination: Vector4, kind: CName, now: Float) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) || !MBAI_CanClaimExecutionLease(npc, n"CounterPerch", now) {
      return false;
    };
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destinationWp: WorldPosition;
    WorldPosition.SetVector4(destinationWp, destination);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destinationWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 1.5;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = false;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      let intent: CName = Equals(kind, n"Cordon") ? n"CounterPerchCordon" : n"CounterPerchDeny";
      let leaseToken: Int32 = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"CounterPerch", 20.0, now);
      MBAI_SetIntent(npc as NPCPuppet, intent, n"CounterPerch", 20.0, now);
      let order: ref<MBAI_CounterPerchOrder> = new MBAI_CounterPerchOrder();
      order.id = npc.GetEntityID();
      order.squadName = state.squadName;
      order.fallbackID = state.fallbackID;
      order.kind = kind;
      order.cmd = cmd;
      order.leaseToken = leaseToken;
      order.destination = destination;
      order.startTime = now;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      ArrayPush(this.m_orders, order);
    };
    return ok;
  }

  private final func MonitorOrders(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_CounterPerchOrder> = this.m_orders[i];
      let remove: Bool = false;
      let cancel: Bool = false;
      let reason: String = "";
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || !MBAI_EnemyMovementEligible(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
        remove = true;
        cancel = IsDefined(npc) && !npc.IsDead() && !ScriptedPuppet.IsDefeated(npc);
        reason = cancel ? "ownership-changed" : "invalid";
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
          reason = "no-ai";
        } else {
          if StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
            remove = true;
            cancel = true;
            reason = "netrunner-hacking";
          } else {
          if !this.OrderStateActive(order, now) {
            remove = true;
            cancel = true;
            reason = "state-ended";
          } else {
            if order.arrived {
              if now - order.arrivedAt >= 2.0 && Vector4.Distance(npc.GetWorldPosition(), order.destination) > 6.0 {
                remove = true;
                reason = "slot-abandoned";
              };
            } else {
              let elapsed: Float = now - order.startTime;
              let moveState: AICommandState = ai.GetCommandState(order.cmd);
              let moveAborted: Bool = Equals(moveState, AICommandState.Failure) || Equals(moveState, AICommandState.Cancelled) || Equals(moveState, AICommandState.Interrupted);
              if moveAborted {
                remove = true;
                if Equals(moveState, AICommandState.Failure) {
                  reason = "move-failure";
                } else {
                  if Equals(moveState, AICommandState.Cancelled) {
                    reason = "move-cancelled";
                  } else {
                    reason = "move-interrupted";
                  };
                };
              } else {
                if Vector4.Distance(npc.GetWorldPosition(), order.destination) <= 2.0 || Equals(moveState, AICommandState.Success) {
                  this.MarkArrived(npc, order, now);
                } else {
                  if elapsed > 20.0 {
                    remove = true;
                    cancel = true;
                    reason = "timeout";
                  } else {
                    let currentPos: Vector4 = npc.GetWorldPosition();
                    if Vector4.Distance(currentPos, order.lastPos) > 1.0 {
                      order.lastPos = currentPos;
                      order.lastProgressTime = now;
                    } else {
                      if now - order.lastProgressTime > 4.0 {
                        remove = true;
                        cancel = true;
                        reason = "stalled";
                      };
                    };
                  };
                };
              };
            };
          };
          };
        };
      };
      if remove {
        this.EndOrder(gi, i, now, reason, cancel);
      };
      i -= 1;
    };
  }

  private final func MarkArrived(npc: wref<NPCPuppet>, order: ref<MBAI_CounterPerchOrder>, now: Float) -> Void {
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    let moveState: AICommandState = ai.GetCommandState(order.cmd);
    if Equals(moveState, AICommandState.Enqueued) || Equals(moveState, AICommandState.Executing) {
      ai.CancelCommand(order.cmd);
    };
    MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"CounterPerch", order.leaseToken, now, 0.5);
    MBAI_ClearIntent(npc as NPCPuppet, n"CounterPerch");
    ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 1.0);
    order.cmd = null;
    order.arrived = true;
    order.arrivedAt = now;
    MBAInfo("CounterPerch", s"arrival receipt npc=\(ToString(order.id)) kind=\(ToString(order.kind))");
  }

  private final func OrderStateActive(order: ref<MBAI_CounterPerchOrder>, now: Float) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      if state.activeUntil > now && this.OrderMatchesGroup(order, state) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func OrderMatchesGroup(order: ref<MBAI_CounterPerchOrder>, state: ref<MBAI_CounterPerchGroupState>) -> Bool {
    if IsNameValid(order.squadName) || IsNameValid(state.squadName) {
      return IsNameValid(order.squadName) && IsNameValid(state.squadName) && Equals(order.squadName, state.squadName);
    };
    return Equals(order.fallbackID, state.fallbackID);
  }

  private final func CancelGroupOrders(state: ref<MBAI_CounterPerchGroupState>, now: Float) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      if this.OrderMatchesGroup(this.m_orders[i], state) {
        this.EndOrder(gi, i, now, "group-lost", true);
      };
      i -= 1;
    };
  }

  private final func EndOrder(gi: GameInstance, index: Int32, now: Float, reason: String, cancel: Bool) -> Void {
    let order: ref<MBAI_CounterPerchOrder> = this.m_orders[index];
    let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
    if IsDefined(npc) {
      let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
      if cancel && IsDefined(ai) && IsDefined(order.cmd) {
        ai.CancelCommand(order.cmd);
      };
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      npcSharp.m_mbaiLastOrderEnd = now;
      MBAI_ReleaseExecutionLease(npcSharp, n"CounterPerch", order.leaseToken, now, 0.5);
      MBAI_ClearIntent(npcSharp, n"CounterPerch");
    };
    this.ClearGroupOrderID(order);
    if Equals(reason, "timeout") || Equals(reason, "stalled") || Equals(reason, "move-failure") || Equals(reason, "move-cancelled") || Equals(reason, "move-interrupted") || Equals(reason, "slot-abandoned") {
      MBAInfo("CounterPerch", "order ended npc=" + ToString(order.id) + " kind=" + NameToString(order.kind) + " reason=" + reason);
    } else {
      MBADebug("CounterPerch", "order ended npc=" + ToString(order.id) + " kind=" + NameToString(order.kind) + " reason=" + reason);
    };
    ArrayErase(this.m_orders, index);
  }

  private final func ClearGroupOrderID(order: ref<MBAI_CounterPerchOrder>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_CounterPerchGroupState> = this.m_groups[i];
      if this.OrderMatchesGroup(order, state) {
        if Equals(state.cordonID, order.id) {
          state.cordonID = EMPTY_ENTITY_ID();
        };
        if Equals(state.denialID, order.id) {
          state.denialID = EMPTY_ENTITY_ID();
        };
        return;
      };
      i += 1;
    };
  }

  private final func HasOrder(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if Equals(this.m_orders[i].id, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }
}

public static func MBAI_CounterPerchActive(gi: GameInstance, npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, now: Float) -> Bool {
  let system: ref<MBAI_CounterPerchSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_CounterPerchSystem") as MBAI_CounterPerchSystem;
  return IsDefined(system) && system.IsActiveFor(npc, player, now);
}
