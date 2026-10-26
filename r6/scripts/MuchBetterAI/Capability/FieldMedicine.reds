module MuchBetterAI.Capability

import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Nerve.*

public static func MBAI_FieldMedicineCanStart(npc: wref<NPCPuppet>) -> Bool {
  if !MBAI_EnemyEligible(npc) || !MBAI_PhysicalCapabilityEligible(npc) {
    return false;
  };
  if !MBAI_ActorAuthoredControlFree(npc) || !MBAI_ActorHasNoActiveAICommand(npc) {
    return false;
  };
  let gi: GameInstance = npc.GetGame();
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  let fireteam: ref<MBAI_FireteamSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_FireteamSystem") as MBAI_FireteamSystem;
  if IsDefined(fireteam) && fireteam.HasActiveOrder(npc.GetEntityID()) {
    return false;
  };
  let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
  if IsDefined(nerve) && nerve.HasActiveAssignment(npc.GetEntityID()) {
    return false;
  };
  return Equals(MBAI_GetIntent(npc, now), n"") && !MBAI_IntentBlocksCommand(npc, n"FieldMedicine", now);
}

@wrapMethod(AICondition)
public final static func ActivationCheck(const context: ScriptExecutionContext, actionRecord: ref<AIAction_Record>) -> Bool {
  let vanillaAllowed: Bool = wrappedMethod(context, actionRecord);
  if !vanillaAllowed {
    return false;
  };
  if IsDefined(actionRecord) && actionRecord.GetID() == t"MBAI.FieldMedicineAction" {
    let npc: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if !MBAI_FieldMedicineCanStart(npc) {
      return false;
    };
  };
  return true;
}

@wrapMethod(AISubActionStatusEffect_Record_Implementation)
public final static func ApplyRemoveStatusEffect(context: ScriptExecutionContext, record: wref<AISubActionStatusEffect_Record>) -> Void {
  wrappedMethod(context, record);
  if IsDefined(record) && record.GetID() == t"MBAI.FieldMedicineStatusEffect" {
    let npc: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
    if IsDefined(npc) {
      MBAInfo("FieldMedicine", s"combat-stim apply branch npc=\(ToString(npc.GetEntityID())) record=\(TDBID.ToStringDEBUG(npc.GetRecordID()))");
    };
  };
}
