module MuchBetterAI.Squad

import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*

public static func MBAI_CombatGroupSquadName(npc: wref<NPCPuppet>) -> CName {
  if !IsDefined(npc) {
    return n"";
  };
  return AISquadHelper.GetSquadName(npc);
}

public static func MBAI_CombatGroupMatches(squadName: CName, fallbackID: EntityID, npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) {
    return false;
  };
  let npcSquad: CName = MBAI_CombatGroupSquadName(npc);
  if IsNameValid(squadName) || IsNameValid(npcSquad) {
    return IsNameValid(squadName) && IsNameValid(npcSquad) && Equals(squadName, npcSquad);
  };
  return EntityID.IsDefined(fallbackID) && Equals(fallbackID, npc.GetEntityID());
}

public static func MBAI_SameCombatGroup(left: wref<NPCPuppet>, right: wref<NPCPuppet>) -> Bool {
  if !IsDefined(left) || !IsDefined(right) {
    return false;
  };
  return MBAI_CombatGroupMatches(MBAI_CombatGroupSquadName(left), left.GetEntityID(), right);
}

public static func MBAI_GetCombatGroupContact(members: array<wref<NPCPuppet>>, player: ref<PlayerPuppet>, groupMember: wref<NPCPuppet>, out tracked: TrackedLocation, out position: Vector4) -> Bool {
  if !IsDefined(groupMember) {
    return false;
  };
  let found: Bool = false;
  let bestAccuracy: Float = -1.0;
  let i: Int32 = 0;
  while i < ArraySize(members) {
    let npc: wref<NPCPuppet> = members[i];
    if MBAI_CombatGroupMatches(MBAI_CombatGroupSquadName(groupMember), groupMember.GetEntityID(), npc) {
      let candidate: TrackedLocation;
      let candidatePosition: Vector4;
      if MBAI_GetCombatContact(npc, player, candidate, candidatePosition) {
        if candidate.visible {
          tracked = candidate;
          position = candidatePosition;
          return true;
        };
        if candidate.sharedAccuracy > bestAccuracy {
          bestAccuracy = candidate.sharedAccuracy;
          tracked = candidate;
          position = candidatePosition;
          found = true;
        };
      };
    };
    i += 1;
  };
  return found;
}
