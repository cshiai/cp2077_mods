module MuchBetterAI.Fireteam

import MuchBetterAI.Core.*
import MuchBetterAI.Footwork.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Squad.*

@addField(NPCPuppet)
let m_mbaiCombatPropagationRecruitUntil: Float;

@addField(NPCPuppet)
let m_mbaiCombatPropagationRetryAt: Float;

@wrapMethod(ReactionManagerComponent)
public final func ShouldIgnoreCombatStim(stimType: gamedataStimType, instigator: wref<ScriptedPuppet>, source: wref<ScriptedPuppet>, sourcePos: Vector4, canDelay: Bool, out canIgnoreOnlyDueToDelay: Bool, out canIgnorePlayerCombatStim: Bool, log: Bool) -> Bool {
  let ignored: Bool = wrappedMethod(stimType, instigator, source, sourcePos, canDelay, canIgnoreOnlyDueToDelay, canIgnorePlayerCombatStim, log);
  let npc: ref<NPCPuppet> = this.GetOwnerPuppet() as NPCPuppet;
  let player: ref<PlayerPuppet> = source as PlayerPuppet;
  if !IsDefined(player) {
    player = instigator as PlayerPuppet;
  };
  if canDelay && Equals(stimType, gamedataStimType.Bullet) && IsDefined(player) {
    MBAI_RegisterIncomingFire(npc, player, sourcePos, ignored);
  };
  let now: Float;
  if IsDefined(npc) && npc.m_mbaiCombatPropagationRecruitUntil > 0.0 {
    now = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
    if now >= npc.m_mbaiCombatPropagationRecruitUntil && NotEquals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
      npc.m_mbaiCombatPropagationRecruitUntil = 0.0;
    };
  };
  if !ignored || canIgnoreOnlyDueToDelay {
    return ignored;
  };
  if !StimFilters.IsGunshot(stimType) && NotEquals(stimType, gamedataStimType.Explosion) {
    return ignored;
  };
  if !IsDefined(player) {
    return ignored;
  };
  if !MBAI_EnemyEligible(npc) || npc.IsMechanical() || npc.IsPrevention() || npc.IsQuest() {
    return ignored;
  };
  if Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
    return ignored;
  };
  if now <= 0.0 {
    now = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  };
  let range: Float = ClampF(30.0, 15.0, 40.0);
  let incidentPos: Vector4 = Vector4.IsZero(sourcePos) ? player.GetWorldPosition() : sourcePos;
  if Vector4.Distance(npc.GetWorldPosition(), incidentPos) > range {
    return ignored;
  };
  let affiliation: gamedataAffiliation = MBAI_GetAffiliation(npc);
  if Equals(affiliation, gamedataAffiliation.Unknown) {
    return ignored;
  };
  let doctrine: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(affiliation, npc.GetNPCRarity());
  let budget: Int32 = 1 + MBAI_DoctrineCoordinationTier(doctrine);
  if now < npc.m_mbaiCombatPropagationRetryAt {
    return ignored;
  };
  npc.m_mbaiCombatPropagationRetryAt = now + 0.35;
  let budgets: ref<MBAI_SquadAbilityBudgetSystem> = GameInstance.GetScriptableSystemsContainer(npc.GetGame()).Get(n"MuchBetterAI.Squad.MBAI_SquadAbilityBudgetSystem") as MBAI_SquadAbilityBudgetSystem;
  if !IsDefined(budgets) {
    return ignored;
  };
  let allies: array<ref<NPCPuppet>> = npc.GetNPCsAroundObject(range);
  let i: Int32 = 0;
  while i < ArraySize(allies) {
    let ally: ref<NPCPuppet> = allies[i];
    if MBAI_EnemyEligible(ally) && ally != npc && !ally.IsMechanical() && !ally.IsPrevention() && !ally.IsQuest() && ally.m_mbaiCombatPropagationRecruitUntil <= 0.0 && Equals(MBAI_GetAffiliation(ally), affiliation) && MBAI_SameCombatGroup(npc, ally) && NPCPuppet.IsInCombatWithTarget(ally, player) && budgets.CombatPropagationReady(ally, budget, now) {
      npc.m_mbaiCombatPropagationRecruitUntil = now + 60.0;
      let spent: Int32 = budgets.SpendCombatPropagation(ally, now);
      canIgnorePlayerCombatStim = false;
      MBAInfo("Propagation", s"combat joined npc=\(ToString(npc.GetEntityID())) ally=\(ToString(ally.GetEntityID())) doctrine=\(ToString(EnumInt(doctrine))) spent=\(spent)/\(budget)");
      return false;
    };
    i += 1;
  };
  return ignored;
}
