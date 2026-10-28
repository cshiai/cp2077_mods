module MuchBetterAI.Nerve

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Stealth.*
import MuchBetterAI.Squad.*
import SimpleDroneCompanion.*

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let gi: GameInstance = this.GetGame();
  let player: ref<PlayerPuppet> = GetPlayer(gi);
  let scan: Bool = !this.IsCharacterCivilian() && !this.IsMechanical() && this.IsEnemy() && !this.IsPlayerCompanion() && !SDC_IsCompanion(this) && !GameObject.IsFriendlyTowardsPlayer(this) && IsDefined(player);
  let now: Float;
  let victimPos: Vector4;
  let rarity: gamedataNPCRarity;
  let isLeader: Bool;
  let radius: Float;
  let duration: Float;
  let victimID: EntityID;
  let nearby: array<ref<NPCPuppet>>;
  if scan {
    now = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    victimPos = this.GetWorldPosition();
    rarity = this.GetNPCRarity();
    isLeader = Equals(rarity, gamedataNPCRarity.Officer) || Equals(rarity, gamedataNPCRarity.Elite) || Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac);
    radius = isLeader ? 40.0 : 25.0;
    duration = isLeader ? 15.0 : 12.0;
    victimID = this.GetEntityID();
    nearby = this.GetNPCsAroundObject(radius);
  };
  let result: Bool = wrappedMethod(evt);
  if !scan {
    return result;
  };
  let marked: Int32 = 0;
  let rejBasic: Int32 = 0;
  let rejState: Int32 = 0;
  let rejFactionFearless: Int32 = 0;
  let rejLos: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(nearby) {
    let witness: ref<NPCPuppet> = nearby[i];
    if MBAI_EnemyEligible(witness) && witness.GetEntityID() != victimID && !witness.IsMechanical() && MBAI_SameCombatGroup(this, witness) && NPCPuppet.IsInCombatWithTarget(witness, player) {
      if !Equals(witness.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
        rejState += 1;
      } else {
        if MBAI_FactionBreakHP(witness) <= 0.0 {
          rejFactionFearless += 1;
        } else {
          if !MBAI_CorpseLOS.HasAnyLOS(witness, victimPos) {
            rejLos += 1;
          } else {
            MBAI_MarkShaken(witness, now + duration);
            marked += 1;
          };
        };
      };
    } else {
      rejBasic += 1;
    };
    i += 1;
  };
  if marked > 0 {
    MBAInfo("Contagion", s"death rarity=\(rarity) leader=\(isLeader) shook \(marked) witness(es)");
  };
  MBADebug("Contagion", s"scan victimRarity=\(rarity) nearby=\(ArraySize(nearby)) shook=\(marked) rejBasic=\(rejBasic) rejState=\(rejState) rejFactionFearless=\(rejFactionFearless) rejLos=\(rejLos)");
  return result;
}
