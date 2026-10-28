module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

public class MBAI_CombatDropSystem extends ScriptableSystem {
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("Stealth", "combat drop online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(2.5);
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
    let cb: ref<MBAI_CombatDropTickCallback> = new MBAI_CombatDropTickCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) || player.IsDead() {
      this.ScheduleTick(3.0);
      return;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let playerPos: Vector4 = player.GetWorldPosition();
    let threshold: Float = 15.0;
    let latThreshold: Float = 25.0;
    let vertThreshold: Float = 3.0;
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(80.0);
    let combatCount: Int32 = 0;
    let alertedCount: Int32 = 0;
    let relaxedCount: Int32 = 0;
    let visibleCount: Int32 = 0;
    let candidateCount: Int32 = 0;
    let dropCount: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i];
      if MBAI_EnemyEligible(npc) && !npc.IsMechanical() {
        let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
        if Equals(state, gamedataNPCHighLevelState.Combat) {
          combatCount += 1;
          let tracked: TrackedLocation;
          let contactPosition: Vector4;
          if MBAI_GetCombatContact(npc, player, tracked, contactPosition) {
            if tracked.visible {
              npc.m_mbaiLastSawPlayer = now;
              visibleCount += 1;
            } else {
              if npc.m_mbaiLastSawPlayer <= 0.0 || now - npc.m_mbaiLastSawPlayer > threshold * 3.0 {
                npc.m_mbaiLastSawPlayer = now;
              } else {
                if now - npc.m_mbaiLastSawPlayer >= threshold && MBAI_EnemyCanReceiveMovement(npc) && tracked.sharedAccuracy < 0.33 && tracked.invalidExpectation {
                  candidateCount += 1;
                  let vertDelta: Float = AbsF(playerPos.Z - contactPosition.Z);
                  let dx: Float = playerPos.X - contactPosition.X;
                  let dy: Float = playerPos.Y - contactPosition.Y;
                  let latDist: Float = SqrtF(dx * dx + dy * dy);
                  if vertDelta >= vertThreshold || latDist >= latThreshold {
                    MBAI_RaiseAlert(npc, 90.0);
                    let tt: ref<TargetTrackerComponent> = npc.GetTargetTrackerComponent();
                    let searchIssued: Bool = false;
                    if IsDefined(tt) {
                      tt.RemoveThreat(tt.MapThreat(player));
                      searchIssued = MBAI_Search_MoveToWithCombatFlagAndContext(npc, contactPosition, true, "CombatDropLKP");
                      if searchIssued {
                        npc.m_mbaiInvestigateFired = true;
                        npc.m_mbaiSweepDest = contactPosition;
                        npc.m_mbaiNextSweep = now + 6.0;
                      };
                      dropCount += 1;
                      MBAInfo("Stealth", s"combat drop npc=\(ToString(npc.GetEntityID())) rarity=\(npc.GetNPCRarity()) vertDelta=\(vertDelta) latDist=\(latDist) search=\(searchIssued)");
                    };
                    npc.m_mbaiLastSawPlayer = 0.0;
                  };
                };
              };
            };
          };
        } else {
          if Equals(state, gamedataNPCHighLevelState.Alerted) {
            alertedCount += 1;
          } else {
            if Equals(state, gamedataNPCHighLevelState.Relaxed) {
              relaxedCount += 1;
            };
          };
          npc.m_mbaiLastSawPlayer = 0.0;
        };
      };
      i += 1;
    };
    if combatCount > 0 || alertedCount > 0 {
      MBADebug("Stealth", s"combat drop tick: combat=\(combatCount) alerted=\(alertedCount) relaxed=\(relaxedCount) visible=\(visibleCount) candidates=\(candidateCount) dropped=\(dropCount)");
    };
    this.ScheduleTick(2.5);
  }
}

public class MBAI_CombatDropTickCallback extends DelayCallback {
  public let game: GameInstance;
  public func Call() -> Void {
    let sys: ref<MBAI_CombatDropSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Stealth.MBAI_CombatDropSystem") as MBAI_CombatDropSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
