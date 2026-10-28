module MuchBetterAI.Stealth

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

@addField(NPCPuppet)
let m_mbaiGrappleWitnessUntil: Float;

public class MBAI_GrappleWitnessSystem extends ScriptableSystem {
  private let m_tickID: DelayID;

  private func OnAttach() -> Void {
    MBAInfo("Takedown", "grapple witness monitor online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(2.0);
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
    let cb: ref<MBAI_GrappleWitnessCallback> = new MBAI_GrappleWitnessCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let delay: Float = 0.75;
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) && !player.IsDead() {
      let active: Bool = this.React(gi, player);
      if active {
        delay = 0.35;
      };
    };
    this.ScheduleTick(delay);
  }

  private final func React(gi: GameInstance, player: ref<PlayerPuppet>) -> Bool {
    let victimID: EntityID;
    if !this.FindGrappledVictim(player, victimID) {
      return false;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(60.0);
    let seen: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(npcs) {
      let npc: ref<NPCPuppet> = npcs[i];
      if npc.m_mbaiGrappleWitnessUntil <= now && MBAI_Takedown_CanWitness(npc, player, victimID) {
        npc.m_mbaiGrappleWitnessUntil = now + 2.0;
        if AIActionHelper.TryStartCombatWithTarget(npc, player) {
          seen += 1;
        };
      };
      i += 1;
    };
    if seen > 0 {
      MBAInfo("Takedown", s"grapple seen by \(seen) enemy(ies) -> combat");
    };
    return true;
  }

  private final func FindGrappledVictim(player: ref<PlayerPuppet>, out victimID: EntityID) -> Bool {
    victimID = player.GetPlayerStateMachineBlackboard().GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.TakedownTargetID);
    if !EntityID.IsDefined(victimID) {
      return false;
    };
    let victim: ref<NPCPuppet> = GameInstance.FindEntityByID(player.GetGame(), victimID) as NPCPuppet;
    return IsDefined(victim) && !victim.IsDead() && StatusEffectSystem.ObjectHasStatusEffect(victim, t"BaseStatusEffect.Grappled");
  }
}

public class MBAI_GrappleWitnessCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_GrappleWitnessSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Stealth.MBAI_GrappleWitnessSystem") as MBAI_GrappleWitnessSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
