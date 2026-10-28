module MuchBetterAI.Core

import MuchBetterAI.Logging.*

@addField(NPCPuppet)
let m_mbaiMoveToWatched: Bool;

@addField(NPCPuppet)
let m_mbaiMoveToLastPos: Vector4;

@addField(NPCPuppet)
let m_mbaiMoveToLastProgress: Float;

public class MBAI_MoveToWatchOrder {
  public let id: EntityID;
  public let owner: CName;
  public let leaseToken: Int32;
  public let cmd: ref<AICommand>;
  public let startTime: Float;
}

public class MBAI_MoveToWatchdogSystem extends ScriptableSystem {
  private let m_orders: array<ref<MBAI_MoveToWatchOrder>>;
  private let m_lastCancellation: Float;
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("Watchdog", "moveto watchdog online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(4.0);
  }

  private func OnDetach() -> Void {
    MBAI_CancelDelay(this.GetGameInstance(), this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_MoveToWatchdogCallback> = new MBAI_MoveToWatchdogCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Register(npc: ref<NPCPuppet>, cmd: ref<AICommand>, leaseToken: Int32, now: Float) -> Void {
    let id: EntityID = npc.GetEntityID();
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if this.m_orders[i].id == id {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) && MBAI_IsTrackedCommandRunning(ai, this.m_orders[i].cmd) {
          ai.CancelCommand(this.m_orders[i].cmd);
        };
        this.m_orders[i].owner = npc.m_mbaiOrderOwner;
        this.m_orders[i].leaseToken = leaseToken;
        this.m_orders[i].cmd = cmd;
        this.m_orders[i].startTime = now;
        npc.m_mbaiMoveToLastPos = npc.GetWorldPosition();
        npc.m_mbaiMoveToLastProgress = now;
        return;
      };
      i += 1;
    };
    let order: ref<MBAI_MoveToWatchOrder> = new MBAI_MoveToWatchOrder();
    order.id = id;
    order.owner = npc.m_mbaiOrderOwner;
    order.leaseToken = leaseToken;
    order.cmd = cmd;
    order.startTime = now;
    ArrayPush(this.m_orders, order);
    npc.m_mbaiMoveToWatched = true;
    npc.m_mbaiMoveToLastPos = npc.GetWorldPosition();
    npc.m_mbaiMoveToLastProgress = now;
  }

  public final func LastCancellation() -> Float {
    return this.m_lastCancellation;
  }

  public final func CancelOwner(owner: CName, now: Float) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_MoveToWatchOrder> = this.m_orders[i];
      if Equals(order.owner, owner) {
        let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
        if IsDefined(npc) {
          let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
          if IsDefined(ai) {
            ai.CancelCommand(order.cmd);
          };
          MBAI_ReleaseExecutionLease(npc as NPCPuppet, order.owner, order.leaseToken, now, 1.0);
          MBAI_ClearIntent(npc as NPCPuppet, order.owner);
          npc.m_mbaiMoveToWatched = false;
        };
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_MoveToWatchOrder> = this.m_orders[i];
      let remove: Bool = false;
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      let actorOwnershipLost: Bool = false;
      let deviceInvestigation: Bool = false;
      if !IsDefined(npc) || npc.IsDead() {
        remove = true;
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
        } else {
          let player: ref<PlayerPuppet> = GetPlayer(gi);
          actorOwnershipLost = !MBAI_PlayerAlertMovementEligible(npc, player);
          if !actorOwnershipLost {
            deviceInvestigation = MBAI_DeviceInvestigationOwnsMovement(npc as NPCPuppet);
          };
          if actorOwnershipLost || deviceInvestigation {
            ai.CancelCommand(order.cmd);
            if actorOwnershipLost {
              MBAInfo("Watchdog", s"actor ownership changed, movement cancelled npc=\(ToString(order.id))");
            } else {
              MBAInfo("Watchdog", s"device investigation took movement npc=\(ToString(order.id))");
            };
            remove = true;
          } else {
            let elapsed: Float = now - order.startTime;
            if elapsed > 25.0 {
              ai.CancelCommand(order.cmd);
              remove = true;
            } else {
              if elapsed > 1.0 && !MBAI_IsTrackedCommandRunning(ai, order.cmd) {
                remove = true;
              } else {
                let curPos: Vector4 = npc.GetWorldPosition();
                if Vector4.Distance(curPos, npc.m_mbaiMoveToLastPos) > 1.0 {
                  npc.m_mbaiMoveToLastPos = curPos;
                  npc.m_mbaiMoveToLastProgress = now;
                } else {
                  if now - npc.m_mbaiMoveToLastProgress > 5.0 {
                    ai.CancelCommand(order.cmd);
                    this.m_lastCancellation = now;
                    MBAInfo("Watchdog", s"stall cancel npc=\(ToString(order.id)) elapsed=\(elapsed) - path stuck, killing command before the engine's teleport fallback fires");
                    remove = true;
                  };
                };
              };
            };
          };
        };
      };
      if remove {
        if IsDefined(npc) {
          npc.m_mbaiMoveToWatched = false;
          if MBAI_ExecutionLeaseMatches(npc, order.owner, order.leaseToken) {
            MBAI_ClearIntent(npc as NPCPuppet, order.owner);
            MBAI_ReleaseExecutionLease(npc as NPCPuppet, order.owner, order.leaseToken, now, 1.0);
          };
        };
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
    this.ScheduleTick(1.5);
  }
}

public func MBAI_TrackMoveTo(gi: GameInstance, npc: ref<NPCPuppet>, cmd: ref<AICommand>, leaseToken: Int32, now: Float) -> Void {
  let sys: ref<MBAI_MoveToWatchdogSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_MoveToWatchdogSystem") as MBAI_MoveToWatchdogSystem;
  if IsDefined(sys) {
    sys.Register(npc, cmd, leaseToken, now);
  };
}

public func MBAI_CancelTrackedMoveToOwner(gi: GameInstance, owner: CName, now: Float) -> Void {
  let sys: ref<MBAI_MoveToWatchdogSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_MoveToWatchdogSystem") as MBAI_MoveToWatchdogSystem;
  if IsDefined(sys) {
    sys.CancelOwner(owner, now);
  };
}

public func MBAI_HasRecentMoveToCancellation(gi: GameInstance, withinSeconds: Float) -> Bool {
  let sys: ref<MBAI_MoveToWatchdogSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_MoveToWatchdogSystem") as MBAI_MoveToWatchdogSystem;
  if !IsDefined(sys) {
    return false;
  };
  let lastCancel: Float = sys.LastCancellation();
  if lastCancel <= 0.0 {
    return false;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  return (now - lastCancel) < withinSeconds;
}

public class MBAI_MoveToWatchdogCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_MoveToWatchdogSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Core.MBAI_MoveToWatchdogSystem") as MBAI_MoveToWatchdogSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
