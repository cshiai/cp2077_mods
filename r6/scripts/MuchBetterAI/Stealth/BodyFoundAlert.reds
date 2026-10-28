module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Squad.*

public class MBAI_BodyAlertAnchor {
  public let pos: Vector4;
  public let squadName: CName;
  public let affiliation: gamedataAffiliation;
  public let fallbackID: EntityID;
  public let expiresAt: Float;
}

public class MBAI_BodyAlertSystem extends ScriptableSystem {
  private let m_anchors: array<ref<MBAI_BodyAlertAnchor>>;
  private let m_tickID: DelayID;
  private let m_ticking: Bool;

  private func OnAttach() -> Void {
    this.m_tickID = GetInvalidDelayID();
    this.m_ticking = false;
  }

  private func OnDetach() -> Void {
    MBAI_CancelDelay(this.GetGameInstance(), this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
    this.m_ticking = false;
    ArrayClear(this.m_anchors);
  }

  public final func RegisterBodyFound(observer: ref<NPCPuppet>, pos: Vector4) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    if !MBAI_ActorMovementEligible(observer) || !observer.IsAggressive() {
      return;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let duration: Float = 60.0;
    let expiresAt: Float = now + duration;
    MBAI_RecordAlertEnd(observer, expiresAt);
    let i: Int32 = 0;
    while i < ArraySize(this.m_anchors) {
      if Vector4.Distance(this.m_anchors[i].pos, pos) < 15.0 && MBAI_CombatGroupMatches(this.m_anchors[i].squadName, this.m_anchors[i].fallbackID, observer) {
        this.m_anchors[i].expiresAt = MaxF(this.m_anchors[i].expiresAt, expiresAt);
        if !this.m_ticking {
          this.m_ticking = true;
          this.ScheduleTick(1.0);
        };
        MBAInfo("BodyAlert", s"body found -> compound alert anchor extended (\(ArraySize(this.m_anchors)) active)");
        return;
      };
      i += 1;
    };
    let anchor: ref<MBAI_BodyAlertAnchor> = new MBAI_BodyAlertAnchor();
    anchor.pos = pos;
    anchor.squadName = MBAI_CombatGroupSquadName(observer);
    anchor.fallbackID = observer.GetEntityID();
    anchor.expiresAt = expiresAt;
    ArrayPush(this.m_anchors, anchor);
    MBAInfo("BodyAlert", s"body found -> compound alert anchor added (\(ArraySize(this.m_anchors)) active)");
    if !this.m_ticking {
      this.m_ticking = true;
      this.ScheduleTick(1.0);
    };
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_BodyAlertCallback> = new MBAI_BodyAlertCallback();
    cb.system = this;
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  private final func FindAnchor(npc: ref<NPCPuppet>, range: Float) -> ref<MBAI_BodyAlertAnchor> {
    let best: ref<MBAI_BodyAlertAnchor>;
    let bestDistance: Float = 999999.0;
    let i: Int32 = 0;
    while i < ArraySize(this.m_anchors) {
      let anchor: ref<MBAI_BodyAlertAnchor> = this.m_anchors[i];
      let distance: Float = Vector4.Distance(anchor.pos, npc.GetWorldPosition());
      if distance <= range && MBAI_CombatGroupMatches(anchor.squadName, anchor.fallbackID, npc) {
        if !IsDefined(best) || anchor.expiresAt > best.expiresAt || anchor.expiresAt == best.expiresAt && distance < bestDistance {
          best = anchor;
          bestDistance = distance;
        };
      };
      i += 1;
    };
    return best;
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    if ArraySize(this.m_anchors) == 0 {
      this.m_ticking = false;
      return;
    };
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) {
      this.ScheduleTick(2.0);
      return;
    };
    let playerPos: Vector4 = player.GetWorldPosition();
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let kept: array<ref<MBAI_BodyAlertAnchor>>;
    let a: Int32 = 0;
    while a < ArraySize(this.m_anchors) {
      let anchor: ref<MBAI_BodyAlertAnchor> = this.m_anchors[a];
      if IsDefined(anchor) && anchor.expiresAt > now && Vector4.Distance(anchor.pos, playerPos) <= 100.0 {
        ArrayPush(kept, anchor);
      };
      a += 1;
    };
    this.m_anchors = kept;
    if ArraySize(this.m_anchors) == 0 {
      MBAInfo("BodyAlert", "body alert anchors expired or left range");
      this.m_ticking = false;
      return;
    };
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(60.0);
    let held: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i];
      if MBAI_ActorMovementEligible(npc) && npc.IsAggressive() {
        let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
        let anchor: ref<MBAI_BodyAlertAnchor> = this.FindAnchor(npc, 50.0);
        if NotEquals(state, gamedataNPCHighLevelState.Combat) && IsDefined(anchor) {
          MBAI_RecordAlertEnd(npc, anchor.expiresAt);
          MBAI_Search_SetIncidentAnchor(npc, anchor.pos, anchor.expiresAt, false);
          if NotEquals(state, gamedataNPCHighLevelState.Alerted) {
            NPCPuppet.ChangeHighLevelState(npc, gamedataNPCHighLevelState.Alerted);
          };
          held += 1;
        };
      };
      i += 1;
    };
    MBATrace("BodyAlert", s"re-assert holding \(held) enemies alerted across \(ArraySize(this.m_anchors)) anchor(s)");
    this.ScheduleTick(2.0);
  }
}

public func MBAI_BodyAlert_Register(observer: ref<NPCPuppet>, pos: Vector4) -> Void {
  if !IsDefined(observer) {
    return;
  };
  let sys: ref<MBAI_BodyAlertSystem> = GameInstance.GetScriptableSystemsContainer(observer.GetGame()).Get(n"MuchBetterAI.Stealth.MBAI_BodyAlertSystem") as MBAI_BodyAlertSystem;
  if IsDefined(sys) {
    sys.RegisterBodyFound(observer, pos);
  };
}

public class MBAI_BodyAlertCallback extends DelayCallback {
  public let system: wref<MBAI_BodyAlertSystem>;

  public func Call() -> Void {
    let system: ref<MBAI_BodyAlertSystem> = this.system;
    if IsDefined(system) {
      system.Tick();
    };
  }
}
