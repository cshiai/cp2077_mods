module MuchBetterAI.Core

@addField(NPCPuppet)
let m_mbaiSuppressUntil: Float;

@addField(NPCPuppet)
let m_mbaiShakenUntil: Float;

@addField(NPCPuppet)
let m_mbaiLastSawPlayer: Float;

@addField(NPCPuppet)
let m_mbaiLastOrderEnd: Float;

public static func MBAI_MarkSuppress(npc: ref<NPCPuppet>, until: Float) -> Void {
  npc.m_mbaiSuppressUntil = until;
}

public static func MBAI_IsSuppressing(npc: ref<NPCPuppet>, now: Float) -> Bool {
  return MBAI_OwnsSuppressionFire() && npc.m_mbaiSuppressUntil > now;
}

public static func MBAI_MarkShaken(npc: ref<NPCPuppet>, until: Float) -> Void {
  npc.m_mbaiShakenUntil = until;
}

public static func MBAI_ShakenBonus(npc: ref<NPCPuppet>, now: Float, amount: Float) -> Float {
  if npc.m_mbaiShakenUntil > now {
    return amount;
  };
  return 0.0;
}

public static func MBAI_MaxVerticalClimb(npc: ref<NPCPuppet>) -> Float {
  if !IsDefined(npc) {
    return 0.0;
  };
  let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
  if !IsDefined(stats) {
    return 0.0;
  };
  let id: StatsObjectID = Cast<StatsObjectID>(npc.GetEntityID());
  if stats.GetStatValue(id, gamedataStatType.HasChargeJump) >= 1.0 {
    return 8.0;
  };
  if stats.GetStatValue(id, gamedataStatType.HasDoubleJump) >= 1.0 {
    return 4.0;
  };
  return 1.5;
}

private static func MBAI_TierAffiliation(npc: ref<NPCPuppet>) -> gamedataAffiliation {
  if !IsDefined(npc) {
    return gamedataAffiliation.Unknown;
  };
  let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(npc.GetRecordID());
  if !IsDefined(record) || !IsDefined(record.Affiliation()) {
    return gamedataAffiliation.Unknown;
  };
  return record.Affiliation().Type();
}

public static func MBAI_TierCoverAbandonChancePerSecond(rarity: gamedataNPCRarity) -> Float {
  switch rarity {
    case gamedataNPCRarity.Trash: return 0.15;
    case gamedataNPCRarity.Weak: return 0.20;
    case gamedataNPCRarity.Normal: return 0.30;
    case gamedataNPCRarity.Rare: return 0.45;
    case gamedataNPCRarity.Officer: return 0.60;
    case gamedataNPCRarity.Elite: return 0.75;
    case gamedataNPCRarity.Boss: return 0.85;
    case gamedataNPCRarity.MaxTac: return 0.9;
    default: return 0.30;
  };
}

public static func MBAI_FactionSkillNudge(npc: ref<NPCPuppet>) -> Float {
  switch MBAI_TierAffiliation(npc) {
    case gamedataAffiliation.Arasaka:
    case gamedataAffiliation.Militech:
    case gamedataAffiliation.KangTao:
    case gamedataAffiliation.NCPD:
    case gamedataAffiliation.NetWatch:
    case gamedataAffiliation.SSI:
    case gamedataAffiliation.Zetatech:
    case gamedataAffiliation.Barghest:
    case gamedataAffiliation.NUSA:
    case gamedataAffiliation.TraumaTeam:
    case gamedataAffiliation.Biotechnica:
    case gamedataAffiliation.corpbud:
    case gamedataAffiliation.UnaffiliatedCorpo:
      return 0.25;
    case gamedataAffiliation.Scavengers:
    case gamedataAffiliation.ScavengersAndroid:
    case gamedataAffiliation.crimson_harvest:
    case gamedataAffiliation.Wraiths:
    case gamedataAffiliation.WraithsAndroid:
    case gamedataAffiliation.highriders:
    case gamedataAffiliation.Animals:
      return -0.25;
    default:
      return 0.0;
  };
}

public static func MBAI_FactionReactionMult(npc: ref<NPCPuppet>) -> Float {
  switch MBAI_TierAffiliation(npc) {
    case gamedataAffiliation.Arasaka:
    case gamedataAffiliation.Militech:
    case gamedataAffiliation.NUSA:
    case gamedataAffiliation.Barghest:
      return 0.4;
    case gamedataAffiliation.KangTao:
    case gamedataAffiliation.TraumaTeam:
      return 0.55;
    case gamedataAffiliation.TygerClaws:
    case gamedataAffiliation.NetWatch:
    case gamedataAffiliation.VoodooBoys:
      return 0.65;
    case gamedataAffiliation.NCPD:
    case gamedataAffiliation.SSI:
    case gamedataAffiliation.Zetatech:
    case gamedataAffiliation.Maelstrom:
    case gamedataAffiliation.MaelstromAndroid:
    case gamedataAffiliation.Biotechnica:
    case gamedataAffiliation.corpbud:
    case gamedataAffiliation.UnaffiliatedCorpo:
      return 0.85;
    case gamedataAffiliation.Valentinos:
    case gamedataAffiliation.TheMox:
    case gamedataAffiliation.SixthStreet:
    case gamedataAffiliation.SixthStreetAndroid:
      return 1.0;
    case gamedataAffiliation.Wraiths:
    case gamedataAffiliation.WraithsAndroid:
    case gamedataAffiliation.highriders:
    case gamedataAffiliation.Animals:
      return 1.0;
    case gamedataAffiliation.Scavengers:
    case gamedataAffiliation.ScavengersAndroid:
    case gamedataAffiliation.crimson_harvest:
      return 1.0;
    default:
      return 1.0;
  };
}

public enum MBAI_NerveResponse {
  Panic = 0,
  Reposition = 1,
  Fallback = 2,
  None = 3
}

public static func MBAI_FactionNerveResponse(npc: ref<NPCPuppet>) -> MBAI_NerveResponse {
  switch MBAI_TierAffiliation(npc) {
    case gamedataAffiliation.Scavengers:
    case gamedataAffiliation.ScavengersAndroid:
    case gamedataAffiliation.crimson_harvest:
      return MBAI_NerveResponse.Panic;
    case gamedataAffiliation.Wraiths:
    case gamedataAffiliation.WraithsAndroid:
    case gamedataAffiliation.highriders:
    case gamedataAffiliation.SixthStreet:
    case gamedataAffiliation.SixthStreetAndroid:
    case gamedataAffiliation.Valentinos:
    case gamedataAffiliation.TheMox:
      return MBAI_NerveResponse.Reposition;
    case gamedataAffiliation.Arasaka:
    case gamedataAffiliation.Militech:
    case gamedataAffiliation.Barghest:
    case gamedataAffiliation.NUSA:
    case gamedataAffiliation.TraumaTeam:
    case gamedataAffiliation.KangTao:
    case gamedataAffiliation.NetWatch:
    case gamedataAffiliation.NCPD:
    case gamedataAffiliation.SSI:
    case gamedataAffiliation.Zetatech:
    case gamedataAffiliation.TygerClaws:
    case gamedataAffiliation.Biotechnica:
    case gamedataAffiliation.corpbud:
    case gamedataAffiliation.UnaffiliatedCorpo:
      return MBAI_NerveResponse.Fallback;
    case gamedataAffiliation.Maelstrom:
    case gamedataAffiliation.MaelstromAndroid:
    case gamedataAffiliation.VoodooBoys:
    case gamedataAffiliation.Animals:
      return MBAI_NerveResponse.None;
    default:
      return MBAI_NerveResponse.Reposition;
  };
}

public static func MBAI_FactionBreakHP(npc: ref<NPCPuppet>) -> Float {
  switch TweakDBInterface.GetCharacterRecord(npc.GetRecordID()).Affiliation().Type() {
    case gamedataAffiliation.Scavengers:
    case gamedataAffiliation.ScavengersAndroid:
    case gamedataAffiliation.crimson_harvest:
      return 0.40;
    case gamedataAffiliation.Wraiths:
    case gamedataAffiliation.WraithsAndroid:
    case gamedataAffiliation.highriders:
    case gamedataAffiliation.SixthStreet:
    case gamedataAffiliation.SixthStreetAndroid:
    case gamedataAffiliation.Valentinos:
    case gamedataAffiliation.TheMox:
      return 0.25;
    case gamedataAffiliation.Arasaka:
    case gamedataAffiliation.Militech:
    case gamedataAffiliation.Barghest:
    case gamedataAffiliation.NUSA:
    case gamedataAffiliation.TraumaTeam:
    case gamedataAffiliation.KangTao:
    case gamedataAffiliation.NetWatch:
    case gamedataAffiliation.NCPD:
    case gamedataAffiliation.SSI:
    case gamedataAffiliation.Zetatech:
    case gamedataAffiliation.TygerClaws:
    case gamedataAffiliation.Biotechnica:
    case gamedataAffiliation.corpbud:
    case gamedataAffiliation.UnaffiliatedCorpo:
      return 0.12;
    case gamedataAffiliation.Maelstrom:
    case gamedataAffiliation.MaelstromAndroid:
    case gamedataAffiliation.VoodooBoys:
    case gamedataAffiliation.Animals:
      return 0.0;
    default:
      return 0.22;
  };
}

public static func MBAI_TierSkillLevel(npc: ref<NPCPuppet>) -> Float {
  let skill: Float;
  switch npc.GetNPCRarity() {
    case gamedataNPCRarity.Trash: skill = 1.0; break;
    case gamedataNPCRarity.Weak: skill = 1.25; break;
    case gamedataNPCRarity.Normal: skill = 2.0; break;
    case gamedataNPCRarity.Rare: skill = 2.5; break;
    case gamedataNPCRarity.Officer: skill = 3.0; break;
    case gamedataNPCRarity.Elite: skill = 3.25; break;
    case gamedataNPCRarity.Boss: skill = 3.75; break;
    case gamedataNPCRarity.MaxTac: skill = 4.0; break;
    default: skill = 2.0;
  };
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
  if statsSystem.GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.HasKerenzikov) >= 1.0 {
    skill += 0.5;
  };
  skill += MBAI_FactionSkillNudge(npc);
  return ClampF(skill, 1.0, 4.5);
}
