module MuchBetterAI.Core

public func MBAI_DeviceInvestigationOwnsMovement(npc: ref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) {
    return false;
  };
  let reaction: ref<ReactionManagerComponent> = npc.GetStimReactionComponent();
  if !IsDefined(reaction) {
    return false;
  };
  let active: ref<AIReactionData> = reaction.GetActiveReactionData();
  if IsDefined(active) && Equals(active.reactionBehaviorName, gamedataOutput.DeviceInvestigate) {
    return true;
  };
  let desired: ref<AIReactionData> = reaction.GetDesiredReactionData();
  if IsDefined(desired) && Equals(desired.reactionBehaviorName, gamedataOutput.DeviceInvestigate) {
    return true;
  };
  return Equals(reaction.GetPendingReactionName(), gamedataOutput.DeviceInvestigate);
}
