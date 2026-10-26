module MuchBetterAI.Footwork

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

@addField(NPCPuppet)
let m_mbaiIncomingFireWindowStart: Float;

@addField(NPCPuppet)
let m_mbaiIncomingFireLastReceipt: Float;

@addField(NPCPuppet)
let m_mbaiIncomingFireReadyAt: Float;

@addField(NPCPuppet)
let m_mbaiIncomingFireCount: Int32;

@addField(NPCPuppet)
let m_mbaiIncomingFireUntil: Float;

public static func MBAI_RegisterIncomingFire(npc: ref<NPCPuppet>, player: ref<PlayerPuppet>, sourcePos: Vector4, ignored: Bool) -> Void {
  if ignored || !IsDefined(player) || !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
    return;
  };
  if !MBAI_ActorAuthoredControlFree(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) {
    npc.m_mbaiIncomingFireWindowStart = 0.0;
    npc.m_mbaiIncomingFireCount = 0;
    return;
  };
  if Vector4.IsZero(sourcePos) || Vector4.Distance(npc.GetWorldPosition(), sourcePos) > 4.0 {
    return;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  let traceIncomingFire: Bool = false;
  if now < npc.m_mbaiIncomingFireReadyAt {
    return;
  };
  if now - npc.m_mbaiIncomingFireLastReceipt < 0.18 {
    if traceIncomingFire {
      MBATrace("IncomingFire", s"deduped npc=\(ToString(npc.GetEntityID()))");
    };
    return;
  };
  if npc.m_mbaiIncomingFireWindowStart <= 0.0 || now - npc.m_mbaiIncomingFireWindowStart > 1.50 {
    npc.m_mbaiIncomingFireWindowStart = now;
    npc.m_mbaiIncomingFireCount = 0;
  };
  npc.m_mbaiIncomingFireLastReceipt = now;
  npc.m_mbaiIncomingFireCount += 1;

  let rarity: gamedataNPCRarity = npc.GetNPCRarity();
  let rarityResistance: Int32;
  switch rarity {
    case gamedataNPCRarity.Rare:
    case gamedataNPCRarity.Officer:
      rarityResistance = 1;
      break;
    case gamedataNPCRarity.Elite:
      rarityResistance = 2;
      break;
    case gamedataNPCRarity.Boss:
      rarityResistance = 3;
      break;
    case gamedataNPCRarity.MaxTac:
      rarityResistance = 4;
      break;
    default:
      rarityResistance = 0;
  };
  let factionReaction: Float = MBAI_FactionReactionMult(npc);
  let disciplineResistance: Int32;
  if factionReaction <= 0.50 {
    disciplineResistance = 2;
  } else {
    if factionReaction <= 0.75 {
      disciplineResistance = 1;
    } else {
      disciplineResistance = 0;
    };
  };
  let requiredReceipts: Int32 = 3 + rarityResistance + disciplineResistance;
  if npc.m_mbaiIncomingFireCount < requiredReceipts {
    if traceIncomingFire {
      MBATrace("IncomingFire", s"pressure npc=\(ToString(npc.GetEntityID())) receipts=\(npc.m_mbaiIncomingFireCount)/\(requiredReceipts)");
    };
    return;
  };

  let cooldown: Float = ClampF(6.0 + (1.0 - factionReaction) * 4.0 + Cast<Float>(rarityResistance) * 0.5, 6.0, 10.0);
  npc.m_mbaiIncomingFireUntil = now + 2.0;
  npc.m_mbaiIncomingFireReadyAt = now + cooldown;
  npc.m_mbaiIncomingFireWindowStart = 0.0;
  npc.m_mbaiIncomingFireCount = 0;
  ScriptedPuppet.SendActionSignal(npc, n"GracefulCombatInterruption", 2.00);
  MBADebug("IncomingFire", s"under pressure npc=\(ToString(npc.GetEntityID())) rarity=\(rarity) factionReaction=\(factionReaction) cooldown=\(cooldown)");
}

public static func MBAI_IncomingFireNerveBonus(npc: ref<NPCPuppet>, now: Float) -> Float {
  if !IsDefined(npc) || npc.m_mbaiIncomingFireUntil <= now || MBAI_FactionBreakHP(npc) <= 0.0 {
    return 0.0;
  };
  let rarity: gamedataNPCRarity = npc.GetNPCRarity();
  if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
    return 0.0;
  };
  return 0.05 * MBAI_FactionReactionMult(npc);
}
