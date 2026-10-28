module MuchBetterAI.Netrunner

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Nerve.*
import MuchBetterAI.Stealth.*

public class MBAI_RepoOrder {
  public let id: EntityID;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let startTime: Float;
  public let nativeUntil: Float;
  public let until: Float;
  public let baselinePlayerPos: Vector4;
  public let baselineDistance: Float;
  public let baselineCover: Uint64;
  public let baselineLOS: Bool;
  public let fallbackAttempted: Bool;
  public let reacquireUsed: Bool;
  public let lastPos: Vector4;
  public let lastProgressTime: Float;
}

public class MBAI_NetrunnerRepositionSystem extends ScriptableSystem {
  private let m_orders: array<ref<MBAI_RepoOrder>>;
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("NetrunnerRepo", "netrunner reposition online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(3.0);
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
    let cb: ref<MBAI_NetrunnerRepoCallback> = new MBAI_NetrunnerRepoCallback();
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
    this.ScheduleTick(2.0);
  }

  public final func HasActiveOrder(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if this.m_orders[i].id == id {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func Evaluate(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    this.MonitorOrders(gi, player, now);
    let fireteam: ref<MBAI_FireteamSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_FireteamSystem") as MBAI_FireteamSystem;
    let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    let range: Float = 15.0;
    let netrunners: array<wref<NPCPuppet>> = MBAI_NearbyCombatActors(gi, player, 45.0, 1.90);
    let i: Int32 = 0;
    while i < ArraySize(netrunners) {
      let npc: ref<NPCPuppet> = netrunners[i] as NPCPuppet;
      if IsDefined(npc) && MBAI_EnemyCanReceiveMovement(npc) && NPCPuppet.IsInCombatWithTarget(npc, player) && !npc.IsMechanical() {
        if MBAI_ArchetypeIsHangBack(MBAI_GetArchetype(npc)) && Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
          let rarity: gamedataNPCRarity = npc.GetNPCRarity();
          if NotEquals(rarity, gamedataNPCRarity.Boss) {
            let id: EntityID = npc.GetEntityID();
            if !this.HasActiveOrder(id) && MBAI_IsOrderAvailable(npc, n"NetrunnerRepo", now) && !MBAI_IntentBlocksCommand(npc, n"NetrunnerRepo", now) && (!IsDefined(fireteam) || !fireteam.HasActiveOrder(id)) && (!IsDefined(nerve) || !nerve.HasActiveAssignment(id)) {
              let tracked: TrackedLocation;
              let contactPosition: Vector4;
              if MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
                let dist: Float = Vector4.Distance(npc.GetWorldPosition(), contactPosition);
                if dist < range * MBAI_TemperamentNetrunnerRepositionMul(npc) && (now - npc.m_mbaiLastHack) > 3.0 && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") && !Equals(MBAI_GetIntent(npc, now), n"NetrunnerCast") {
                  this.IssueReposition(gi, player, npc, contactPosition, now);
                };
              };
            };
          };
        };
      };
      i += 1;
    };
  }

  private final func IssueReposition(gi: GameInstance, player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, contactPosition: Vector4, now: Float) -> Bool {
    if !MBAI_EnemyCanReceiveMovement(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
      return false;
    };
    let order: ref<MBAI_RepoOrder> = new MBAI_RepoOrder();
    order.id = npc.GetEntityID();
    order.startTime = now;
    order.nativeUntil = now + 1.5;
    order.until = now + 8.0;
    order.baselinePlayerPos = contactPosition;
    order.baselineDistance = Vector4.Distance(npc.GetWorldPosition(), order.baselinePlayerPos);
    order.baselineCover = AICoverHelper.GetCurrentCoverId(npc);
    order.baselineLOS = MBAI_CorpseLOS.RayClearBetween(gi, npc.GetWorldPosition(), order.baselinePlayerPos);
    order.lastPos = npc.GetWorldPosition();
    order.lastProgressTime = now;
    ArrayPush(this.m_orders, order);
    ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 1.0);
    MBAInfo("NetrunnerRepo", s"reposition assigned npc=\(ToString(order.id)) posture=\(MBAI_TemperamentName(MBAI_GetTemperamentScale(npc))) dist=\(order.baselineDistance)");
    return true;
  }

  private final func DispatchReposition(gi: GameInstance, player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, order: ref<MBAI_RepoOrder>, now: Float) -> Bool {
    if !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"NetrunnerRepo", now) || StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") || Equals(MBAI_GetIntent(npc, now), n"NetrunnerCast") {
      return false;
    };
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
      return false;
    };
    let retreatPoint: Vector4;
    let zeroOffset: Vector4;
    if !nav.GetFurthestNavmeshPointBehind(npc, 2.5, 5, retreatPoint, zeroOffset, true) {
      return false;
    };
    if Vector4.Distance(retreatPoint, contactPosition) <= Vector4.Distance(npc.GetWorldPosition(), contactPosition) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, retreatPoint);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Sprint;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = false;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.leaseToken = MBAI_ClaimExecutionLease(npc, n"NetrunnerRepo", 5.0, now);
      MBAI_SetIntent(npc, n"NetrunnerReposition", n"NetrunnerRepo", 5.0, now);
      order.cmd = cmd;
      order.startTime = now;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      order.fallbackAttempted = true;
      MBAInfo("NetrunnerRepo", s"reposition fallback npc=\(ToString(order.id)) posture=\(MBAI_TemperamentName(MBAI_GetTemperamentScale(npc))) dist=\(Vector4.Distance(npc.GetWorldPosition(), contactPosition))");
    };
    return ok;
  }

  private final func MonitorOrders(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_RepoOrder> = this.m_orders[i];
      let remove: Bool = false;
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if !IsDefined(npc) || npc.IsDead() {
        remove = true;
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
        } else {
          if !MBAI_EnemyMovementEligible(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
            remove = true;
          } else {
            let currentCover: Uint64 = AICoverHelper.GetCurrentCoverId(npc);
            let currentDistance: Float = Vector4.Distance(npc.GetWorldPosition(), order.baselinePlayerPos);
            let currentLOS: Bool = MBAI_CorpseLOS.RayClearBetween(gi, npc.GetWorldPosition(), order.baselinePlayerPos);
            let nativeReceipt: Bool = currentDistance >= order.baselineDistance + 2.0
              || (currentCover != 0ul && currentCover != order.baselineCover)
              || (order.baselineLOS && !currentLOS);
            if nativeReceipt || npc.m_mbaiLastHack > order.startTime {
              MBAInfo("NetrunnerRepo", s"reposition receipt npc=\(ToString(order.id)) source=\(order.fallbackAttempted ? "fallback" : "native")");
              remove = true;
            } else {
              if now >= order.until {
                remove = true;
              } else {
                if !IsDefined(order.cmd) {
                  if now >= order.nativeUntil {
                    if !order.fallbackAttempted || order.reacquireUsed {
                      if !this.DispatchReposition(gi, player, npc as NPCPuppet, order, now) {
                        remove = true;
                      };
                    };
                  };
                } else {
                  let state: AICommandState = ai.GetCommandState(order.cmd);
                  if Equals(state, AICommandState.Interrupted) {
                    if order.reacquireUsed {
                      remove = true;
                    } else {
                      MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"NetrunnerRepo", order.leaseToken, now, 1.0);
                      MBAI_ClearIntent(npc as NPCPuppet, n"NetrunnerRepo");
                      order.cmd = null;
                      order.nativeUntil = now + 1.0;
                      order.reacquireUsed = true;
                    };
                  } else {
                    if Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) {
                      remove = true;
                    } else {
                      let curPos: Vector4 = npc.GetWorldPosition();
                      if Vector4.Distance(curPos, order.lastPos) > 1.0 {
                        order.lastPos = curPos;
                        order.lastProgressTime = now;
                      } else {
                        if now - order.lastProgressTime > 3.0 {
                          remove = true;
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
        if IsDefined(npc) {
          let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
          if IsDefined(ai) && IsDefined(order.cmd) {
            ai.CancelCommand(order.cmd);
          };
          MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"NetrunnerRepo", order.leaseToken, now, 0.5);
          MBAI_ClearIntent(npc, n"NetrunnerRepo");
        };
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
  }

  private final func CancelAll(gi: GameInstance) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_RepoOrder> = this.m_orders[i];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      if IsDefined(npc) {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) && IsDefined(order.cmd) {
          ai.CancelCommand(order.cmd);
        };
        MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"NetrunnerRepo", order.leaseToken, EngineTime.ToFloat(GameInstance.GetSimTime(gi)), 0.5);
        MBAI_ClearIntent(npc, n"NetrunnerRepo");
      };
      ArrayErase(this.m_orders, i);
      i -= 1;
    };
  }
}

public class MBAI_NetrunnerRepoCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_NetrunnerRepositionSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Netrunner.MBAI_NetrunnerRepositionSystem") as MBAI_NetrunnerRepositionSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
