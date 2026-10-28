module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Fireteam.*

@addField(NPCPuppet)
let m_mbaiNextSweep: Float;

@addField(NPCPuppet)
let m_mbaiSweepDest: Vector4;

public class MBAI_SearchSweepSystem extends ScriptableSystem {
  private let m_tickID: DelayID;
  private let m_hunterID: EntityID;
  private let m_hunterDest: Vector4;
  private let m_hunterSince: Float;
  private let m_nextHunterAttempt: Float;

  private func OnAttach() -> Void {
    MBAInfo("Search", "search sweep online");
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
    let cb: ref<MBAI_SearchSweepCallback> = new MBAI_SearchSweepCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Sweep(gi, player);
    };
    this.ScheduleTick(0.5);
  }

  private final func Eligible(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, playerPos: Vector4) -> Bool {
    if !MBAI_PlayerAlertMovementEligible(npc, player) {
      return false;
    };
    if MBAI_DeviceInvestigationOwnsMovement(npc) {
      return false;
    };
    let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
    if Equals(state, gamedataNPCHighLevelState.Combat) {
      return false;
    };
    if !Equals(state, gamedataNPCHighLevelState.Alerted) {
      return false;
    };
    return !MBAI_CorpseLOS.HasAnyLOS(npc, playerPos);
  }

  private final func CanAssign(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, playerPos: Vector4) -> Bool {
    return this.Eligible(npc, player, playerPos) && MBAI_PlayerAlertCanReceiveMovement(npc, player);
  }

  private final func Sweep(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let playerPos: Vector4 = player.GetWorldPosition();
    let fanRadius: Float = 30.0;
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(60.0);

    let activeHunter: EntityID;
    let hunter: ref<NPCPuppet> = GameInstance.FindEntityByID(gi, this.m_hunterID) as NPCPuppet;
    if this.Eligible(hunter, player, playerPos) && !MBAI_CounterPerchActive(gi, hunter, player, now) && Vector4.Distance(hunter.GetWorldPosition(), this.m_hunterDest) > 2.5 && (now - this.m_hunterSince) < 15.0 {
      activeHunter = this.m_hunterID;
    } else {
      if now >= this.m_nextHunterAttempt {
        let best: ref<NPCPuppet>;
        let bestDist: Float = 61.0;
        let h: Int32 = 0;
        while h < ArraySize(npcs) {
          let cand: ref<NPCPuppet> = npcs[h];
          if this.CanAssign(cand, player, playerPos) {
            let searchTarget: Vector4 = MBAI_Search_GetIncidentAnchor(cand, playerPos, now);
            let d: Float = Vector4.Distance(cand.GetWorldPosition(), searchTarget);
            if d < bestDist {
              bestDist = d;
              best = cand;
            };
          };
          h += 1;
        };
        if IsDefined(best) {
          if MBAI_CounterPerchActive(gi, best, player, now) {
            this.m_nextHunterAttempt = now + 6.0;
          } else {
            let searchTarget: Vector4 = MBAI_Search_GetIncidentAnchor(best, playerPos, now);
            if this.CommandHunter(gi, best, searchTarget, now) {
              activeHunter = best.GetEntityID();
              MBAInfo("Search", s"hunter (re)assigned npc=\(ToString(best.GetEntityID())) dist=\(Vector4.Distance(best.GetWorldPosition(), playerPos))m");
            } else {
              this.m_nextHunterAttempt = now + 6.0;
            };
          };
        };
      };
    };

    let fanned: Int32 = 0;
    let eligible: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i];
      if this.CanAssign(npc, player, playerPos) && npc.GetEntityID() != activeHunter {
        eligible += 1;
        if !Vector4.IsZero(npc.m_mbaiSweepDest) && Vector4.Distance(npc.GetWorldPosition(), npc.m_mbaiSweepDest) <= 2.5 && npc.m_mbaiNextSweep > now + 1.0 {
          npc.m_mbaiNextSweep = now + 1.0;
        };
        if now >= npc.m_mbaiNextSweep {
          let dest: Vector4;
          if this.SearchAroundSelf(gi, npc, fanRadius, dest) {
            npc.m_mbaiSweepDest = dest;
            npc.m_mbaiNextSweep = now + 12.0;
            fanned += 1;
          } else {
            npc.m_mbaiSweepDest = new Vector4(0.0, 0.0, 0.0, 0.0);
            npc.m_mbaiNextSweep = now + 6.0;
          };
        };
      };
      i += 1;
    };
    if EntityID.IsDefined(activeHunter) || eligible > 0 {
      MBADebug("Search", s"sweep: eligible=\(eligible) hunter=\(EntityID.IsDefined(activeHunter)) fanned=\(fanned) fanR=\(fanRadius)");
    };
  }

  private final func CommandHunter(gi: GameInstance, best: ref<NPCPuppet>, searchTarget: Vector4, now: Float) -> Bool {
    let nav = GameInstance.GetAINavigationSystem(gi);
    let huntDist: Float = (1.0 - ClampF(0.55, 0.0, 1.0)) * 15.0;
    let navFail: Int32 = 0;
    let moveFail: Int32 = 0;
    let attempt: Int32 = 0;
    while attempt < 3 {
      let target: Vector4 = searchTarget;
      if huntDist > 0.5 {
        target.X += RandRangeF(-huntDist, huntDist);
        target.Y += RandRangeF(-huntDist, huntDist);
      };
      let snap: Float = 4.0 + Cast<Float>(attempt) * 8.0;
      let pr = nav.FindPointInSphereForCharacter(target, snap, best);
      if Equals(pr.status, worldNavigationRequestStatus.OK) {
        if MBAI_Search_MoveToWithContext(best, pr.point, "SearchHunter") {
          this.m_hunterID = best.GetEntityID();
          this.m_hunterDest = pr.point;
          this.m_hunterSince = now;
          MBADebug("Search", s"hunter npc=\(ToString(this.m_hunterID)) -> \(Vector4.Distance(pr.point, searchTarget))m from search target");
          return true;
        };
        moveFail += 1;
      } else {
        navFail += 1;
      };
      attempt += 1;
    };
    MBADebug("Search", s"hunter failed npc=\(ToString(best.GetEntityID())) navFail=\(navFail) moveFail=\(moveFail)");
    return false;
  }

  private final func SearchAroundSelf(gi: GameInstance, npc: ref<NPCPuppet>, fanRadius: Float, out dest: Vector4) -> Bool {
    let nav = GameInstance.GetAINavigationSystem(gi);
    let selfPos: Vector4 = npc.GetWorldPosition();
    let navFail: Int32 = 0;
    let moveFail: Int32 = 0;
    let attempt: Int32 = 0;
    while attempt < 5 {
      let reach: Float = attempt < 4 ? fanRadius : 6.0;
      let plot: Vector4 = selfPos;
      plot.X += RandRangeF(-reach, reach);
      plot.Y += RandRangeF(-reach, reach);
      let pr = nav.FindPointInSphereForCharacter(plot, 6.0, npc);
      if Equals(pr.status, worldNavigationRequestStatus.OK) {
        if MBAI_Search_MoveToWithContext(npc, pr.point, "SearchFan") {
          dest = pr.point;
          MBADebug("Search", s"fan npc=\(ToString(npc.GetEntityID())) -> \(Vector4.Distance(pr.point, selfPos))m (att \(attempt))");
          return true;
        };
        moveFail += 1;
      } else {
        navFail += 1;
      };
      attempt += 1;
    };
    MBADebug("Search", s"fan failed npc=\(ToString(npc.GetEntityID())) navFail=\(navFail) moveFail=\(moveFail)");
    return false;
  }
}

public class MBAI_SearchSweepCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_SearchSweepSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Stealth.MBAI_SearchSweepSystem") as MBAI_SearchSweepSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
