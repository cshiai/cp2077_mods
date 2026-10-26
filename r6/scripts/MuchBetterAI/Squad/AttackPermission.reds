module MuchBetterAI.Squad

import MuchBetterAI.Core.*

public func MBAI_IndependentAttackActor(entity: wref<Entity>) -> Bool {
  let npc: wref<NPCPuppet> = entity as NPCPuppet;
  if !MBAI_EnemyCanReceiveMovement(npc) {
    return false;
  };
  let player: ref<PlayerPuppet> = GetPlayer(npc.GetGame());
  if !IsDefined(player) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
    return false;
  };
  let context: ScriptExecutionContext;
  return AIHumanComponent.GetScriptContext(npc, context) && AIBehaviorScriptBase.GetCombatTarget(context) == player;
}

public func MBAI_CloseAttackTicket(ticketName: CName) -> Bool {
  return Equals(ticketName, n"Melee")
    || Equals(ticketName, n"MeleeApproach")
    || Equals(ticketName, n"AndroidMelee")
    || Equals(ticketName, n"QuickMelee")
    || Equals(ticketName, n"MeleeSupport");
}

@wrapMethod(AITicketCondition)
public final static func CheckNumberOfTickets(entity: wref<Entity>, interface: wref<PuppetSquadInterface>, ticketRecord: wref<AITicket_Record>) -> Bool {
  if MBAI_IndependentAttackActor(entity) {
    let ticketName: CName = ticketRecord.TicketType().EnumName();
    if MBAI_CloseAttackTicket(ticketName) || Equals(ticketName, n"CloseRing") || Equals(ticketName, n"MeleeRing") {
      return true;
    };
  };
  return wrappedMethod(entity, interface, ticketRecord);
}

@wrapMethod(AITicketCondition)
public final static func CheckDistanceRelationToTarget(entity: wref<Entity>, interface: wref<PuppetSquadInterface>, condition: wref<AISquadDistanceRelationToTargetCheck_Record>, closest: Bool, squadMembers: script_ref<array<wref<Entity>>>) -> Bool {
  if closest && !condition.Invert() && condition.GetID() == t"Condition.SquadClosestToCombatTarget" && condition.Target().GetID() == t"AIActionTarget.CombatTarget" && condition.RingRadius() == 0.0 && MBAI_IndependentAttackActor(entity) {
    return ArrayContains(Deref(squadMembers), entity);
  };
  return wrappedMethod(entity, interface, condition, closest, squadMembers);
}

@wrapMethod(PuppetSquadInterface)
private final func CheckCooldown(entity: wref<Entity>, ticketRecord: wref<AITicket_Record>, ticketHistoryID: Int32) -> Bool {
  if MBAI_CloseAttackTicket(ticketRecord.TicketType().EnumName()) && MBAI_IndependentAttackActor(entity) {
    let cooldownsCount: Int32 = ticketRecord.GetCooldownsCount();
    let i: Int32 = 0;
    while i < cooldownsCount {
      let record: wref<AIActionCooldown_Record> = ticketRecord.GetCooldownsItem(i);
      if IsDefined(record) && GameObject.IsCooldownActive(entity as GameObject, record.Name()) {
        return false;
      };
      i += 1;
    };
    return true;
  };
  return wrappedMethod(entity, ticketRecord, ticketHistoryID);
}
