module MuchBetterAI.Footwork

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Nerve.*

@addField(NPCPuppet)
let m_mbaiCoverReselectID: Uint64;

@addField(NPCPuppet)
let m_mbaiCoverReselectUntil: Float;

@addField(NPCPuppet)
let m_mbaiCoverBailReadyAt: Float;

public class MBAI_CoverSeekingSystem extends ScriptableSystem {
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("CoverSeek", "cover-seeking online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(4.0);
  }

  private func OnDetach() -> Void {
    GameInstance.GetDelaySystem(this.GetGameInstance()).CancelDelay(this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_CoverSeekCallback> = new MBAI_CoverSeekCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Evaluate(gi, player);
    };
    this.ScheduleTick(1.5);
  }

  private final func Evaluate(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let fireteam: ref<MBAI_FireteamSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_FireteamSystem") as MBAI_FireteamSystem;
    let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    let npcs: array<wref<NPCPuppet>> = MBAI_NearbyCombatActors(gi, player, 45.0, 1.40);
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i] as NPCPuppet;
      if IsDefined(npc) && MBAI_EnemyMovementEligible(npc) && !npc.IsMechanical() {
        if Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
          let id: EntityID = npc.GetEntityID();
          if (!IsDefined(fireteam) || !fireteam.HasActiveOrder(id)) && (!IsDefined(nerve) || !nerve.HasActiveAssignment(id)) && !MBAI_IntentBlocksCommand(npc, n"Footwork", now) {
            this.MaybeEject(npc, now);
          };
        };
      };
      i += 1;
    };
  }

  private final func MaybeEject(npc: ref<NPCPuppet>, now: Float) -> Void {
    let coverID: Uint64 = AICoverHelper.GetCurrentCoverId(npc);
    if npc.m_mbaiCoverReselectID != 0ul {
      if now - npc.m_mbaiCoverReselectUntil > 2.0 {
        npc.m_mbaiCoverReselectID = 0ul;
        npc.m_mbaiCoverReselectUntil = 0.0;
        return;
      };
      if coverID == 0ul || coverID != npc.m_mbaiCoverReselectID {
        npc.m_mbaiCoverReselectID = 0ul;
        npc.m_mbaiCoverReselectUntil = 0.0;
        npc.m_mbaiCoverBailReadyAt = now + 2.0;
        return;
      };
      if now >= npc.m_mbaiCoverReselectUntil {
        AICoverHelper.LeaveCoverImmediately(npc);
        npc.m_mbaiCoverReselectID = 0ul;
        npc.m_mbaiCoverReselectUntil = 0.0;
        npc.m_mbaiCoverBailReadyAt = now + 6.0;
        MBAI_SetIntent(npc, n"CoverBail", n"Footwork", 2.0, now);
        MBAInfo("CoverSeek", s"eject fallback npc=\(ToString(npc.GetEntityID())) rarity=\(npc.GetNPCRarity())");
      };
      return;
    };
    if now < npc.m_mbaiCoverBailReadyAt {
      return;
    };
    let hrc: ref<HitReactionComponent> = npc.GetHitReactionComponent();
    if !IsDefined(hrc) {
      return;
    };
    let lastHit: Float = hrc.GetLastHitTimeStamp();
    if lastHit <= 0.0 || (now - lastHit) > 3.5 {
      return;
    };
    if coverID == 0ul {
      return;
    };
    let healthPct: Float = AICoverHelper.GetCoverRemainingHealthPerc(npc, coverID);
    if healthPct >= 0.4 {
      return;
    };
    let chance: Float = MBAI_TierCoverAbandonChancePerSecond(npc.GetNPCRarity()) * 1.5;
    if RandF() < chance {
      npc.m_mbaiCoverReselectID = coverID;
      npc.m_mbaiCoverReselectUntil = now + 1.25;
      ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 1.0);
      MBAInfo("CoverSeek", s"reselection requested npc=\(ToString(npc.GetEntityID())) coverHP=\(healthPct) rarity=\(npc.GetNPCRarity())");
    };
  }
}

public class MBAI_CoverSeekCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_CoverSeekingSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Footwork.MBAI_CoverSeekingSystem") as MBAI_CoverSeekingSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
