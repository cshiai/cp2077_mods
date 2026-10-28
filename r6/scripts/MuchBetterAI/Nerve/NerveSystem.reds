module MuchBetterAI.Nerve

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Footwork.*
import MuchBetterAI.Squad.*
import MuchBetterAI.Stealth.*

public class MBAI_BreakOrder {
  public let id: EntityID;
  public let response: MBAI_NerveResponse;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let startTime: Float;
  public let nativeUntil: Float;
  public let until: Float;
  public let baselinePos: Vector4;
  public let baselinePlayerPos: Vector4;
  public let baselineDistance: Float;
  public let baselineCover: Uint64;
  public let baselineLOS: Bool;
  public let fallbackAttempted: Bool;
  public let reacquireUsed: Bool;
  public let lastPos: Vector4;
  public let lastProgressTime: Float;
}

public class MBAI_NerveGroupState {
  public let squadName: CName;
  public let fallbackID: EntityID;
  public let tracked: array<EntityID>;
  public let recentDeaths: Float;
  public let currentLeader: EntityID;
  public let firstDeathSeen: Bool;
  public let lastSeen: Float;
}

public class MBAI_NerveSystem extends ScriptableSystem {
  private let m_orders: array<ref<MBAI_BreakOrder>>;
  private let m_broken: array<EntityID>;
  private let m_groups: array<ref<MBAI_NerveGroupState>>;
  private let m_lastEval: Float;
  private let m_tickID: DelayID;

  public final func IsCurrentLeader(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      if Equals(this.m_groups[i].currentLeader, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private func OnAttach() -> Void {
    MBAInfo("Nerve", "morale online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(2.0);
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    MBAI_CancelDelay(gi, this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
    this.CancelAll(gi);
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_NerveTickCallback> = new MBAI_NerveTickCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Evaluate(gi, player);
    } else {
      this.CancelAll(gi);
    };
    this.ScheduleTick(1.0);
  }

  private final func Evaluate(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let dt: Float = this.m_lastEval > 0.0 ? now - this.m_lastEval : 0.0;
    this.m_lastEval = now;
    this.MonitorOrders(gi, player, now);
    this.PruneBroken(gi);
    let squad: array<wref<NPCPuppet>> = this.GatherEnemies(gi, player);
    this.SyncGroups(squad, now);
    let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(gi);
    if !IsDefined(statPools) {
      return;
    }
    let contagionAmount: Float = 0.2;
    let groupIndex: Int32 = ArraySize(this.m_groups) - 1;
    while groupIndex >= 0 {
      let state: ref<MBAI_NerveGroupState> = this.m_groups[groupIndex];
      let members: array<wref<NPCPuppet>> = this.GatherGroupMembers(squad, state);
      let count: Int32 = ArraySize(members);
      if count == 0 {
        state.recentDeaths = MaxF(0.0, state.recentDeaths - dt * 0.2);
        if now - state.lastSeen > 6.0 {
          ArrayErase(this.m_groups, groupIndex);
        };
      } else {
        this.DetectDeaths(gi, state, members);
        state.recentDeaths = MaxF(0.0, state.recentDeaths - dt * 0.2);
        this.ElectLeader(gi, state, members);
        let casualtyBonus: Float = ClampF(state.recentDeaths * 0.05, 0.0, 0.20);
        let i: Int32 = 0;
        while i < count {
          let npc: wref<NPCPuppet> = members[i];
          if !this.HasBroken(npc.GetEntityID()) {
            let rarity: gamedataNPCRarity = npc.GetNPCRarity();
            if NotEquals(rarity, gamedataNPCRarity.Boss) && NotEquals(rarity, gamedataNPCRarity.MaxTac) {
              let breakHP: Float = MBAI_FactionBreakHP(npc as NPCPuppet) * 0.85 * MBAI_TemperamentNerveThresholdMul(npc);
              if breakHP > 0.0 {
                let hp: Float = statPools.GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true) / 100.0;
                let incomingFireBonus: Float = MBAI_IncomingFireNerveBonus(npc as NPCPuppet, now);
                let totalBonus: Float = ClampF(casualtyBonus + MBAI_ShakenBonus(npc as NPCPuppet, now, contagionAmount) + incomingFireBonus, 0.0, 0.35);
                if hp <= breakHP + totalBonus && this.ActiveBreakCount() < 3 {
                  if this.IssueBreak(gi, player, npc, now) {
                    MBAInfo("Nerve", s"morale response assigned npc=\(ToString(npc.GetEntityID())) rarity=\(rarity) posture=\(MBAI_TemperamentName(MBAI_GetTemperamentScale(npc))) hp=\(hp) threshold=\(breakHP) bonus=\(totalBonus) contagion=\(contagionAmount) incomingFire=\(incomingFireBonus)");
                  };
                };
              };
            };
          };
          i += 1;
        };
      };
      groupIndex -= 1;
    };
  }

  private final func IssueBreak(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, now: Float) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) {
      return false;
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
      return false;
    };
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    let response: MBAI_NerveResponse = MBAI_FactionNerveResponse(npc as NPCPuppet);
    let g: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
    let retreatOnLoss: Bool = MBAI_DoctrineRetreatOnLoss(g);
    if !retreatOnLoss && Equals(response, MBAI_NerveResponse.Fallback) {
      response = MBAI_NerveResponse.Panic;
    };
    if retreatOnLoss && Equals(response, MBAI_NerveResponse.Panic) {
      response = MBAI_NerveResponse.Fallback;
    };
    let order: ref<MBAI_BreakOrder> = new MBAI_BreakOrder();
    order.id = npc.GetEntityID();
    order.response = response;
    order.startTime = now;
    order.nativeUntil = now + 1.5;
    order.until = now + 8.0;
    order.baselinePos = npc.GetWorldPosition();
    order.baselinePlayerPos = contactPosition;
    order.baselineDistance = Vector4.Distance(order.baselinePos, order.baselinePlayerPos);
    order.baselineCover = AICoverHelper.GetCurrentCoverId(npc);
    order.baselineLOS = MBAI_CorpseLOS.RayClearBetween(gi, order.baselinePos, order.baselinePlayerPos);
    order.lastPos = order.baselinePos;
    order.lastProgressTime = now;
    ArrayPush(this.m_orders, order);
    ScriptedPuppet.SendActionSignal(npc, n"GracefulCombatInterruption", 1.0);
    return true;
  }

  private final func IssuePanicRush(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>, tracked: TrackedLocation, contactPosition: Vector4, now: Float) -> Bool {
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Nerve", now) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, contactPosition);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 5.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = true;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Nerve", 8.0, now);
      MBAI_SetIntent(npc as NPCPuppet, n"NervePanic", n"Nerve", 8.0, now);
      order.cmd = cmd;
      order.startTime = now;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      order.fallbackAttempted = true;
      MBATrace("Nerve", "panic-rush npc=" + ToString(order.id) + " rarity=" + ToString(npc.GetNPCRarity()));
      MBAI_TryBark(npc as NPCPuppet, n"battlecry_curse", n"MBAI:PanicRush", now, 4.0);
    };
    return ok;
  }

  private final func IssueRepositionForward(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>, tracked: TrackedLocation, contactPosition: Vector4, now: Float) -> Bool {
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let npcPos: Vector4 = npc.GetWorldPosition();
    let currentDist: Float = Vector4.Distance(npcPos, contactPosition);
    let toward: Vector4 = contactPosition - npcPos;
    let towardLen: Float = Vector4.Length(toward);
    if towardLen < 0.5 {
      return false;
    };
    let dir: Vector4 = toward / towardLen;
    let stepDist: Float = MinF(currentDist * 0.4, 10.0);
    let candidate: Vector4 = npcPos + dir * stepDist;
    let snapped: Vector4 = nav.GetNearestNavmeshPointBelow(npc, candidate, 2.5, 4);
    if Vector4.IsZero(snapped) {
      return false;
    };
    if Vector4.Distance(snapped, contactPosition) >= currentDist - 1.0 {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Nerve", now) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, snapped);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Sprint;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = true;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Nerve", 8.0, now);
      MBAI_SetIntent(npc as NPCPuppet, n"NerveReposition", n"Nerve", 8.0, now);
      order.cmd = cmd;
      order.startTime = now;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      order.fallbackAttempted = true;
      MBATrace("Nerve", "reposition-forward npc=" + ToString(order.id) + " rarity=" + ToString(npc.GetNPCRarity()) + " stepDist=" + ToString(stepDist));
    };
    return ok;
  }

  private final func IssueFallback(gi: GameInstance, npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>, contactPosition: Vector4, playerVisible: Bool, now: Float) -> Bool {
    let retreatPoint: Vector4;
    if !this.FindFallbackPoint(gi, npc, contactPosition, retreatPoint) {
      return playerVisible && this.IssuePanicFire(npc, order, now);
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Nerve", now) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, retreatPoint);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    cmd.movementType = moveMovementType.Sprint;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = false;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Nerve", 8.0, now);
      MBAI_SetIntent(npc as NPCPuppet, n"NerveFallback", n"Nerve", 8.0, now);
      order.cmd = cmd;
      order.startTime = now;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      order.fallbackAttempted = true;
      MBATrace("Nerve", "fallback npc=" + ToString(order.id) + " rarity=" + ToString(npc.GetNPCRarity()) + " fallbackDist=" + ToString(Vector4.Distance(contactPosition, retreatPoint)));
      MBAI_TryBark(npc as NPCPuppet, n"fear_run", n"MBAI:Fallback", now, 4.0);
    };
    return ok;
  }

  private final func FindFallbackPoint(gi: GameInstance, npc: wref<NPCPuppet>, contactPosition: Vector4, out result: Vector4) -> Bool {
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let npcPos: Vector4 = npc.GetWorldPosition();
    let currentDistance: Float = Vector4.Distance(npcPos, contactPosition);
    let zeroOffset: Vector4;
    let sphereCount: Int32 = 6;
    while sphereCount >= 2 {
      let candidate: Vector4;
      if nav.GetFurthestNavmeshPointBehind(npc, 2.5, sphereCount, candidate, zeroOffset, true) {
        let candidateDistance: Float = Vector4.Distance(candidate, contactPosition);
        if candidateDistance >= currentDistance + 2.0 && AbsF(candidate.Z - npcPos.Z) <= 1.5 && !MBAI_CorpseLOS.RayClearBetween(gi, candidate, contactPosition) {
          let path: ref<NavigationPath> = nav.CalculatePathForCharacter(npcPos, candidate, 0.5, npc);
          if IsDefined(path) && ArraySize(path.path) > 0 {
            result = candidate;
            return true;
          };
        };
      };
      sphereCount -= 1;
    };
    return false;
  }

  private final func IssuePanicFire(npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>, now: Float) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) || this.ActiveBreakCount() > 3 {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Nerve", now) {
      return false;
    };
    let cmd: ref<AIForceShootCommand> = new AIForceShootCommand();
    let noNames: array<CName>;
    cmd.targetOverridePuppetRef = CreateEntityReference("#player", noNames);
    cmd.duration = 2.0;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Nerve", 2.0, now);
      MBAI_SetIntent(npc as NPCPuppet, n"NervePanic", n"Nerve", 3.0, now);
      order.cmd = cmd;
      order.startTime = now;
      order.fallbackAttempted = true;
      MBAInfo("Nerve", "panic-fire npc=" + ToString(npc.GetEntityID()) + " rarity=" + ToString(npc.GetNPCRarity()));
      MBAI_TryBark(npc as NPCPuppet, n"battlecry_curse", n"MBAI:PanicFire", now, 4.0);
    };
    return ok;
  }

  private final func ActiveBreakCount() -> Int32 {
    return ArraySize(this.m_orders);
  }

  private final func MonitorOrders(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_BreakOrder> = this.m_orders[i];
      let remove: Bool = false;
      let completed: Bool = false;
      let reason: String = "";
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || !MBAI_EnemyMovementEligible(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
        remove = true;
        reason = IsDefined(npc) ? "ownership-changed" : "dead";
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
          reason = "no-ai-component";
        } else {
          if StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
            remove = true;
            reason = "netrunner-hacking";
          } else {
            if this.NerveReceipt(gi, npc, order) {
              remove = true;
              completed = true;
              reason = order.fallbackAttempted ? "fallback-response-receipt" : "native-response-receipt";
            } else {
              if now >= order.until {
                remove = true;
                reason = "window-closed";
              } else {
                if !IsDefined(order.cmd) {
                  if now >= order.nativeUntil {
                    if !order.fallbackAttempted || order.reacquireUsed {
                      if !this.DispatchBreakFallback(gi, player, npc, order, now) {
                        remove = true;
                        reason = "fallback-unavailable";
                      };
                    };
                  };
                } else {
                  let state: AICommandState = ai.GetCommandState(order.cmd);
                  if Equals(state, AICommandState.Interrupted) {
                    if order.reacquireUsed {
                      remove = true;
                      reason = "reacquire-interrupted";
                    } else {
                      MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Nerve", order.leaseToken, now, 1.0);
                      MBAI_ClearIntent(npc as NPCPuppet, n"Nerve");
                      order.cmd = null;
                      order.nativeUntil = now + 1.0;
                      order.reacquireUsed = true;
                    };
                  } else {
                    if Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) || Equals(state, AICommandState.Success) {
                      remove = true;
                      reason = "fallback-ended-without-receipt";
                    } else {
                      let curPos: Vector4 = npc.GetWorldPosition();
                      if Vector4.Distance(curPos, order.lastPos) > 1.0 {
                        order.lastPos = curPos;
                        order.lastProgressTime = now;
                      } else {
                        if now - order.lastProgressTime > 3.0 {
                          remove = true;
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
        MBAInfo("Nerve", "break end npc=" + ToString(order.id) + " elapsed=" + ToString(now - order.startTime) + " reason=" + reason);
        if IsDefined(npc) {
          let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
          if IsDefined(ai) && IsDefined(order.cmd) {
            ai.CancelCommand(order.cmd);
          };
          MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Nerve", order.leaseToken, now, 0.5);
          MBAI_ClearIntent(npc, n"Nerve");
        };
        if completed && !ArrayContains(this.m_broken, order.id) {
          ArrayPush(this.m_broken, order.id);
        };
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
  }

  private final func NerveReceipt(gi: GameInstance, npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>) -> Bool {
    let currentDistance: Float = Vector4.Distance(npc.GetWorldPosition(), order.baselinePlayerPos);
    if Equals(order.response, MBAI_NerveResponse.Fallback) {
      let currentCover: Uint64 = AICoverHelper.GetCurrentCoverId(npc);
      return currentDistance >= order.baselineDistance + 1.5
        || (currentCover != 0ul && currentCover != order.baselineCover)
        || (order.baselineLOS && !MBAI_CorpseLOS.RayClearBetween(gi, npc.GetWorldPosition(), order.baselinePlayerPos));
    };
    return order.baselineDistance - currentDistance >= 1.5 || npc.m_mbaiLastShotAtPlayerSim >= order.startTime;
  }

  private final func DispatchBreakFallback(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, order: ref<MBAI_BreakOrder>, now: Float) -> Bool {
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    switch order.response {
      case MBAI_NerveResponse.Panic:
        return this.IssuePanicRush(gi, player, npc, order, tracked, contactPosition, now);
      case MBAI_NerveResponse.Reposition:
        return this.IssueRepositionForward(gi, player, npc, order, tracked, contactPosition, now);
      case MBAI_NerveResponse.Fallback:
        return this.IssueFallback(gi, npc, order, contactPosition, tracked.visible, now);
      default:
        return false;
    };
  }

  private final func CancelAll(gi: GameInstance) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_BreakOrder> = this.m_orders[i];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if IsDefined(npc) {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) && IsDefined(order.cmd) {
          ai.CancelCommand(order.cmd);
        };
        MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Nerve", order.leaseToken, EngineTime.ToFloat(GameInstance.GetSimTime(gi)), 0.5);
        MBAI_ClearIntent(npc, n"Nerve");
      };
      i -= 1;
    };
    ArrayClear(this.m_orders);
    ArrayClear(this.m_broken);
    ArrayClear(this.m_groups);
    this.m_lastEval = 0.0;
  }

  private final func SyncGroups(squad: array<wref<NPCPuppet>>, now: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let groupIndex: Int32 = this.FindGroupIndex(squad[i]);
      if groupIndex < 0 {
        let state: ref<MBAI_NerveGroupState> = new MBAI_NerveGroupState();
        state.squadName = MBAI_CombatGroupSquadName(squad[i]);
        state.fallbackID = squad[i].GetEntityID();
        state.lastSeen = now;
        ArrayPush(this.m_groups, state);
      } else {
        this.m_groups[groupIndex].lastSeen = now;
      };
      i += 1;
    };
  }

  private final func FindGroupIndex(npc: wref<NPCPuppet>) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_NerveGroupState> = this.m_groups[i];
      if MBAI_CombatGroupMatches(state.squadName, state.fallbackID, npc) {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  private final func GatherGroupMembers(squad: array<wref<NPCPuppet>>, state: ref<MBAI_NerveGroupState>) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      if MBAI_CombatGroupMatches(state.squadName, state.fallbackID, squad[i]) {
        ArrayPush(result, squad[i]);
      };
      i += 1;
    };
    return result;
  }

  private final func DetectDeaths(gi: GameInstance, state: ref<MBAI_NerveGroupState>, squad: array<wref<NPCPuppet>>) -> Void {
    let current: array<EntityID>;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      ArrayPush(current, squad[i].GetEntityID());
      i += 1;
    };
    i = 0;
    while i < ArraySize(state.tracked) {
      let id: EntityID = state.tracked[i];
      if !ArrayContains(current, id) {
        let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, id) as NPCPuppet;
        if IsDefined(npc) && (npc.IsDead() || ScriptedPuppet.IsDefeated(npc)) {
          let weight: Float = 1.0;
          let r: gamedataNPCRarity = npc.GetNPCRarity();
          if Equals(r, gamedataNPCRarity.Officer) || Equals(r, gamedataNPCRarity.Elite) {
            weight = 2.5;
          };
          let derivedRole: MBAI_Role = MBAI_GetRole(MBAI_GetArchetype(npc), MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), r));
          if Equals(derivedRole, MBAI_Role.Anchor) {
            weight = MaxF(weight, 1.5);
          };
          if Equals(id, state.currentLeader) {
            weight *= 2.0;
            state.currentLeader = EMPTY_ENTITY_ID();
            MBAInfo("Nerve", "leader down id=" + ToString(id) + " rarity=" + ToString(r));
            let k: Int32 = 0;
            while k < ArraySize(squad) {
              let mate: wref<NPCPuppet> = squad[k];
              if IsDefined(mate) && Vector4.Distance(mate.GetWorldPosition(), npc.GetWorldPosition()) < 40.0 {
                MBAI_TryBark(mate as NPCPuppet, n"danger", n"MBAI:LeaderDown", EngineTime.ToFloat(GameInstance.GetSimTime(gi)), 10.0);
              };
              k += 1;
            };
          };
          if !state.firstDeathSeen {
            weight += 0.5;
            state.firstDeathSeen = true;
          };
          state.recentDeaths = MinF(state.recentDeaths + weight, 6.0);
        };
      };
      i += 1;
    };
    state.tracked = current;
  }

  private final func ElectLeader(gi: GameInstance, state: ref<MBAI_NerveGroupState>, squad: array<wref<NPCPuppet>>) -> Void {
    let curLeaderAlive: Bool = false;
    if !EntityID.IsDefined(state.currentLeader) {
      curLeaderAlive = false;
    } else {
      let cur: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, state.currentLeader) as NPCPuppet;
      if IsDefined(cur) && !cur.IsDead() && !ScriptedPuppet.IsDefeated(cur) {
        let memberIndex: Int32 = 0;
        while memberIndex < ArraySize(squad) {
          if Equals(squad[memberIndex].GetEntityID(), state.currentLeader) {
            curLeaderAlive = true;
          };
          memberIndex += 1;
        };
      };
    };
    if curLeaderAlive {
      return;
    };
    let bestSkill: Float = -1.0;
    let bestId: EntityID;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let npc: wref<NPCPuppet> = squad[i];
      if IsDefined(npc) && !npc.IsDead() && !ScriptedPuppet.IsDefeated(npc) {
        let skill: Float = MBAI_TierSkillLevel(npc);
        if skill > bestSkill {
          bestSkill = skill;
          bestId = npc.GetEntityID();
        };
      };
      i += 1;
    };
    if bestSkill >= 0.0 && !Equals(bestId, state.currentLeader) {
      state.currentLeader = bestId;
      let newLeader: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, bestId) as NPCPuppet;
      if IsDefined(newLeader) {
        MBAInfo("Nerve", "leader elected id=" + ToString(bestId) + " rarity=" + ToString(newLeader.GetNPCRarity()));
        MBAI_TryBark(newLeader as NPCPuppet, n"danger", n"MBAI:LeaderElected", EngineTime.ToFloat(GameInstance.GetSimTime(gi)), 8.0);
      };
    };
  }

  private final func PruneBroken(gi: GameInstance) -> Void {
    let i: Int32 = ArraySize(this.m_broken) - 1;
    while i >= 0 {
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, this.m_broken[i]) as NPCPuppet;
      if !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || !Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
        ArrayErase(this.m_broken, i);
      };
      i -= 1;
    };
  }

  public final func HasBroken(id: EntityID) -> Bool {
    if ArrayContains(this.m_broken, id) {
      return true;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if Equals(this.m_orders[i].id, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public final func HasActiveAssignment(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if Equals(this.m_orders[i].id, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func GatherEnemies(gi: GameInstance, player: ref<PlayerPuppet>) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let candidates: array<wref<NPCPuppet>> = MBAI_EnemyCombatActors(gi, player, 60.0, 0.90);
    let i: Int32 = 0;
    while i < ArraySize(candidates) {
      let npc: wref<NPCPuppet> = candidates[i];
      if IsDefined(npc) && this.IsEligible(npc, player) {
        ArrayPush(result, npc);
      };
      i += 1;
    };
    return result;
  }

  private final func IsEligible(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>) -> Bool {
    if !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    if !Equals(ai.GetHighLevelState(), gamedataNPCHighLevelState.Combat) {
      return false;
    };
    return NPCPuppet.IsInCombatWithTarget(npc, player);
  }
}

public class MBAI_NerveTickCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
