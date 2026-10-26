module MuchBetterAI.Fireteam

import MuchBetterAI.Logging.*

public enum MBAI_DoctrineGroup {
  FixAndFlank = 0,
  LockAndHold = 1,
  WallAroundRunner = 2,
  CallAndCoordinate = 3,
  Overwhelm = 4,
  ChromeRush = 5,
  BullCharge = 6,
  BladeWave = 7,
  WeekendWarriors = 8,
  BrotherhoodPush = 9,
  CowardsSwarm = 10,
  RaiderStrike = 11,
  Baseline = 12,
  MeasuredExecution = 13,
  RelentlessAdvance = 14,
  DefensivePerimeter = 15
}

public enum MBAI_Role {
  None = 0,
  HangBack = 1,
  Flanker = 2,
  Anchor = 3,
  Rescue = 4,
  BoundHold = 5,
  BoundAdvance = 6
}

public enum MBAI_FlankerKind {
  None = 0,
  MeleeOnly = 1,
  RangedAngle = 2,
  Any = 3
}

public static func MBAI_GetArchetype(npc: wref<NPCPuppet>) -> gamedataArchetypeType {
  if !IsDefined(npc) {
    return gamedataArchetypeType.Invalid;
  };
  let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(npc.GetRecordID());
  if !IsDefined(record) {
    return gamedataArchetypeType.Invalid;
  }
  let data: wref<ArchetypeData_Record> = record.ArchetypeData();
  if !IsDefined(data) {
    return gamedataArchetypeType.Invalid;
  }
  let typeRecord: wref<ArchetypeType_Record> = data.Type();
  if !IsDefined(typeRecord) {
    return gamedataArchetypeType.Invalid;
  }
  return typeRecord.Type();
}

public static func MBAI_GetAffiliation(npc: wref<NPCPuppet>) -> gamedataAffiliation {
  if !IsDefined(npc) {
    return gamedataAffiliation.Unknown;
  };
  let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(npc.GetRecordID());
  if !IsDefined(record) {
    return gamedataAffiliation.Unknown;
  }
  let aff: wref<Affiliation_Record> = record.Affiliation();
  if !IsDefined(aff) {
    return gamedataAffiliation.Unknown;
  }
  return aff.Type();
}

public static func MBAI_GetDoctrineGroup(aff: gamedataAffiliation, rarity: gamedataNPCRarity) -> MBAI_DoctrineGroup {
  if Equals(rarity, gamedataNPCRarity.MaxTac) {
    return MBAI_DoctrineGroup.Overwhelm;
  }
  switch aff {
    case gamedataAffiliation.Militech:
    case gamedataAffiliation.NUSA:
      return MBAI_DoctrineGroup.FixAndFlank;
    case gamedataAffiliation.Arasaka:
      return MBAI_DoctrineGroup.MeasuredExecution;
    case gamedataAffiliation.Barghest:
      return MBAI_DoctrineGroup.RelentlessAdvance;
    case gamedataAffiliation.TraumaTeam:
      return MBAI_DoctrineGroup.DefensivePerimeter;
    case gamedataAffiliation.KangTao:
      return MBAI_DoctrineGroup.LockAndHold;
    case gamedataAffiliation.NetWatch:
    case gamedataAffiliation.VoodooBoys:
      return MBAI_DoctrineGroup.WallAroundRunner;
    case gamedataAffiliation.NCPD:
    case gamedataAffiliation.SSI:
    case gamedataAffiliation.Zetatech:
    case gamedataAffiliation.Biotechnica:
    case gamedataAffiliation.CityCouncil:
    case gamedataAffiliation.corpbud:
    case gamedataAffiliation.UnaffiliatedCorpo:
      return MBAI_DoctrineGroup.CallAndCoordinate;
    case gamedataAffiliation.Maelstrom:
    case gamedataAffiliation.MaelstromAndroid:
      return MBAI_DoctrineGroup.ChromeRush;
    case gamedataAffiliation.Animals:
      return MBAI_DoctrineGroup.BullCharge;
    case gamedataAffiliation.TygerClaws:
      return MBAI_DoctrineGroup.BladeWave;
    case gamedataAffiliation.SixthStreet:
    case gamedataAffiliation.SixthStreetAndroid:
      return MBAI_DoctrineGroup.WeekendWarriors;
    case gamedataAffiliation.Valentinos:
    case gamedataAffiliation.TheMox:
      return MBAI_DoctrineGroup.BrotherhoodPush;
    case gamedataAffiliation.Scavengers:
    case gamedataAffiliation.ScavengersAndroid:
    case gamedataAffiliation.crimson_harvest:
      return MBAI_DoctrineGroup.CowardsSwarm;
    case gamedataAffiliation.Wraiths:
    case gamedataAffiliation.WraithsAndroid:
    case gamedataAffiliation.highriders:
      return MBAI_DoctrineGroup.RaiderStrike;
    default:
      break;
  };
  return MBAI_DoctrineGroup.Baseline;
}

public static func MBAI_DoctrineUsesAnchors(g: MBAI_DoctrineGroup) -> Bool {
  switch g {
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.Overwhelm:
    case MBAI_DoctrineGroup.LockAndHold:
    case MBAI_DoctrineGroup.WeekendWarriors:
    case MBAI_DoctrineGroup.ChromeRush:
    case MBAI_DoctrineGroup.RaiderStrike:
    case MBAI_DoctrineGroup.BrotherhoodPush:
    case MBAI_DoctrineGroup.Baseline:
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.RelentlessAdvance:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_DoctrineFlankerKind(g: MBAI_DoctrineGroup) -> MBAI_FlankerKind {
  switch g {
    case MBAI_DoctrineGroup.LockAndHold:
    case MBAI_DoctrineGroup.WallAroundRunner:
      return MBAI_FlankerKind.None;
    case MBAI_DoctrineGroup.BullCharge:
    case MBAI_DoctrineGroup.BladeWave:
      return MBAI_FlankerKind.MeleeOnly;
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.WeekendWarriors:
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return MBAI_FlankerKind.RangedAngle;
    case MBAI_DoctrineGroup.RelentlessAdvance:
      return MBAI_FlankerKind.Any;
    default:
      break;
  };
  return MBAI_FlankerKind.Any;
}

public static func MBAI_DoctrineNumbersGated(g: MBAI_DoctrineGroup) -> Bool {
  return Equals(g, MBAI_DoctrineGroup.CowardsSwarm);
}

public static func MBAI_DoctrineLowNumbersChanceMul(g: MBAI_DoctrineGroup) -> Float {
  if Equals(g, MBAI_DoctrineGroup.CowardsSwarm) {
    return 0.25;
  };
  return 1.0;
}

public static func MBAI_DoctrineReactive(g: MBAI_DoctrineGroup) -> Bool {
  switch g {
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.Overwhelm:
    case MBAI_DoctrineGroup.ChromeRush:
    case MBAI_DoctrineGroup.RaiderStrike:
    case MBAI_DoctrineGroup.BrotherhoodPush:
    case MBAI_DoctrineGroup.WeekendWarriors:
    case MBAI_DoctrineGroup.CowardsSwarm:
    case MBAI_DoctrineGroup.Baseline:
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.RelentlessAdvance:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_DoctrineBounds(g: MBAI_DoctrineGroup) -> Bool {
  switch g {
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.Overwhelm:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.RaiderStrike:
    case MBAI_DoctrineGroup.WeekendWarriors:
    case MBAI_DoctrineGroup.RelentlessAdvance:
      return true;
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return false;
    default:
      break;
  };
  return false;
}

public static func MBAI_DoctrineChanceMul(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm: return 1.40;
    case MBAI_DoctrineGroup.BullCharge: return 1.35;
    case MBAI_DoctrineGroup.CowardsSwarm: return 1.35;
    case MBAI_DoctrineGroup.ChromeRush: return 1.30;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 1.20;
    case MBAI_DoctrineGroup.RaiderStrike: return 1.15;
    case MBAI_DoctrineGroup.BladeWave: return 1.10;
    case MBAI_DoctrineGroup.FixAndFlank: return 1.05;
    case MBAI_DoctrineGroup.BrotherhoodPush: return 1.05;
    case MBAI_DoctrineGroup.WeekendWarriors: return 0.90;
    case MBAI_DoctrineGroup.MeasuredExecution: return 0.85;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 0.75;
    case MBAI_DoctrineGroup.Baseline: return 0.50;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 0.45;
    case MBAI_DoctrineGroup.WallAroundRunner: return 0.35;
    case MBAI_DoctrineGroup.LockAndHold: return 0.20;
    default: break;
  };
  return 0.50;
}

public static func MBAI_DoctrineBudget(g: MBAI_DoctrineGroup) -> Int32 {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm: return 4;
    case MBAI_DoctrineGroup.BullCharge: return 3;
    case MBAI_DoctrineGroup.ChromeRush: return 3;
    case MBAI_DoctrineGroup.CowardsSwarm: return 3;
    case MBAI_DoctrineGroup.FixAndFlank: return 2;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 3;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 2;
    case MBAI_DoctrineGroup.WeekendWarriors: return 2;
    case MBAI_DoctrineGroup.BladeWave: return 2;
    case MBAI_DoctrineGroup.BrotherhoodPush: return 2;
    case MBAI_DoctrineGroup.RaiderStrike: return 2;
    case MBAI_DoctrineGroup.MeasuredExecution: return 2;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 1;
    default: break;
  };
  return 1;
}

public static func MBAI_ArchetypeIsAnchor(a: gamedataArchetypeType) -> Bool {
  switch a {
    case gamedataArchetypeType.HeavyRangedT2:
    case gamedataArchetypeType.HeavyRangedT3:
    case gamedataArchetypeType.SniperT2:
    case gamedataArchetypeType.FastSniperT3:
    case gamedataArchetypeType.GenericRangedT1:
    case gamedataArchetypeType.GenericRangedT2:
    case gamedataArchetypeType.GenericRangedT3:
    case gamedataArchetypeType.AndroidRangedT2:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_ArchetypeIsMelee(a: gamedataArchetypeType) -> Bool {
  switch a {
    case gamedataArchetypeType.FastMeleeT2:
    case gamedataArchetypeType.FastMeleeT3:
    case gamedataArchetypeType.GenericMeleeT1:
    case gamedataArchetypeType.GenericMeleeT2:
    case gamedataArchetypeType.HeavyMeleeT2:
    case gamedataArchetypeType.HeavyMeleeT3:
    case gamedataArchetypeType.AndroidMeleeT1:
    case gamedataArchetypeType.AndroidMeleeT2:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_ArchetypeIsHangBack(a: gamedataArchetypeType) -> Bool {
  switch a {
    case gamedataArchetypeType.NetrunnerT1:
    case gamedataArchetypeType.NetrunnerT2:
    case gamedataArchetypeType.NetrunnerT3:
    case gamedataArchetypeType.TechieT2:
    case gamedataArchetypeType.TechieT3:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_ArchetypeIsSniper(a: gamedataArchetypeType) -> Bool {
  switch a {
    case gamedataArchetypeType.SniperT2:
    case gamedataArchetypeType.FastSniperT3:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_ArchetypeIsShotgunner(a: gamedataArchetypeType) -> Bool {
  switch a {
    case gamedataArchetypeType.ShotgunnerT2:
    case gamedataArchetypeType.ShotgunnerT3:
    case gamedataArchetypeType.FastShotgunnerT2:
    case gamedataArchetypeType.FastShotgunnerT3:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_ArchetypeIsCloseRange(a: gamedataArchetypeType) -> Bool {
  if MBAI_ArchetypeIsMelee(a) || MBAI_ArchetypeIsShotgunner(a) {
    return true;
  };
  switch a {
    case gamedataArchetypeType.FastRangedT2:
    case gamedataArchetypeType.FastRangedT3:
    case gamedataArchetypeType.AndroidRangedT2:
      return true;
    default:
      break;
  };
  return false;
}

public static func MBAI_GetRole(a: gamedataArchetypeType, g: MBAI_DoctrineGroup) -> MBAI_Role {
  if MBAI_ArchetypeIsHangBack(a) {
    return MBAI_Role.HangBack;
  }
  let kind: MBAI_FlankerKind = MBAI_DoctrineFlankerKind(g);
  if MBAI_ArchetypeIsAnchor(a) {
    if MBAI_DoctrineUsesAnchors(g) {
      return MBAI_Role.Anchor;
    }
    if Equals(kind, MBAI_FlankerKind.None) {
      return MBAI_Role.HangBack;
    }
    return MBAI_Role.Flanker;
  }
  if MBAI_ArchetypeIsMelee(a) {
    if Equals(kind, MBAI_FlankerKind.None) {
      return MBAI_Role.HangBack;
    }
    return MBAI_Role.Flanker;
  }
  switch kind {
    case MBAI_FlankerKind.RangedAngle:
    case MBAI_FlankerKind.Any:
      return MBAI_Role.Flanker;
    case MBAI_FlankerKind.MeleeOnly:
      return MBAI_DoctrineUsesAnchors(g) ? MBAI_Role.Anchor : MBAI_Role.HangBack;
    default:
      break;
  };
  return MBAI_Role.HangBack;
}

public static func MBAI_RoleToTag(r: MBAI_Role) -> CName {
  switch r {
    case MBAI_Role.HangBack:     return n"HangBack";
    case MBAI_Role.Flanker:      return n"Flanker";
    case MBAI_Role.Anchor:       return n"Anchor";
    case MBAI_Role.Rescue:       return n"Rescue";
    case MBAI_Role.BoundHold:    return n"BoundHold";
    case MBAI_Role.BoundAdvance: return n"BoundAdvance";
    default: break;
  };
  return n"None";
}

public static func MBAI_TagToRole(t: CName) -> MBAI_Role {
  if Equals(t, n"HangBack")     { return MBAI_Role.HangBack; };
  if Equals(t, n"Flanker")      { return MBAI_Role.Flanker; };
  if Equals(t, n"Anchor")       { return MBAI_Role.Anchor; };
  if Equals(t, n"Rescue")       { return MBAI_Role.Rescue; };
  if Equals(t, n"BoundHold")    { return MBAI_Role.BoundHold; };
  if Equals(t, n"BoundAdvance") { return MBAI_Role.BoundAdvance; };
  return MBAI_Role.None;
}

public static func MBAI_GetOrStampRole(npc: ref<NPCPuppet>) -> MBAI_Role {
  if !IsDefined(npc) {
    return MBAI_Role.None;
  };
  if !Equals(npc.m_mbaiRoleTag, n"") {
    return MBAI_TagToRole(npc.m_mbaiRoleTag);
  };
  let a: gamedataArchetypeType = MBAI_GetArchetype(npc);
  let g: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
  let role: MBAI_Role = MBAI_GetRole(a, g);
  npc.m_mbaiRoleTag = MBAI_RoleToTag(role);
  MBAInfo("Doctrine", s"role stamp npc=\(ToString(npc.GetEntityID())) aff=\(ToString(MBAI_GetAffiliation(npc))) rarity=\(npc.GetNPCRarity()) arch=\(ToString(a)) group=\(ToString(EnumInt(g))) role=\(ToString(EnumInt(role)))");
  return role;
}

public static func MBAI_DoctrineCommitDepth(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.BullCharge:       return 11.0;
    case MBAI_DoctrineGroup.ChromeRush:       return 9.0;
    case MBAI_DoctrineGroup.Overwhelm:        return 8.5;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 8.0;
    case MBAI_DoctrineGroup.BrotherhoodPush:  return 7.0;
    case MBAI_DoctrineGroup.BladeWave:        return 6.5;
    case MBAI_DoctrineGroup.FixAndFlank:      return 5.5;
    case MBAI_DoctrineGroup.WeekendWarriors:  return 5.0;
    case MBAI_DoctrineGroup.RaiderStrike:     return 5.0;
    case MBAI_DoctrineGroup.MeasuredExecution: return 4.5;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 4.0;
    case MBAI_DoctrineGroup.CowardsSwarm:     return 3.0;
    case MBAI_DoctrineGroup.WallAroundRunner: return 3.0;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 2.5;
    case MBAI_DoctrineGroup.LockAndHold:      return 2.0;
    default: break;
  };
  return 5.0;
}

public static func MBAI_DoctrinePeelThreshold(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm:        return 0.0;
    case MBAI_DoctrineGroup.BullCharge:       return 0.0;
    case MBAI_DoctrineGroup.ChromeRush:       return 0.0;
    case MBAI_DoctrineGroup.BrotherhoodPush:  return 0.0;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 0.0;
    case MBAI_DoctrineGroup.BladeWave:        return 0.20;
    case MBAI_DoctrineGroup.WallAroundRunner: return 0.25;
    case MBAI_DoctrineGroup.FixAndFlank:      return 0.35;
    case MBAI_DoctrineGroup.RaiderStrike:     return 0.40;
    case MBAI_DoctrineGroup.WeekendWarriors:  return 0.35;
    case MBAI_DoctrineGroup.LockAndHold:      return 0.45;
    case MBAI_DoctrineGroup.MeasuredExecution: return 0.45;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 0.50;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 0.55;
    case MBAI_DoctrineGroup.CowardsSwarm:     return 0.70;
    default: break;
  };
  return 0.30;
}

public static func MBAI_DoctrineCoordinationTier(g: MBAI_DoctrineGroup) -> Int32 {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm:        return 2;
    case MBAI_DoctrineGroup.FixAndFlank:      return 2;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 2;
    case MBAI_DoctrineGroup.LockAndHold:      return 2;
    case MBAI_DoctrineGroup.WallAroundRunner: return 2;
    case MBAI_DoctrineGroup.MeasuredExecution: return 2;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 2;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 2;
    case MBAI_DoctrineGroup.BladeWave:        return 1;
    case MBAI_DoctrineGroup.RaiderStrike:     return 1;
    case MBAI_DoctrineGroup.BrotherhoodPush:  return 1;
    case MBAI_DoctrineGroup.WeekendWarriors:  return 1;
    case MBAI_DoctrineGroup.BullCharge:       return 0;
    case MBAI_DoctrineGroup.ChromeRush:       return 0;
    case MBAI_DoctrineGroup.CowardsSwarm:     return 0;
    default: break;
  };
  return 0;
}

public static func MBAI_DoctrineRetreatOnLoss(g: MBAI_DoctrineGroup) -> Bool {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm:        return false;
    case MBAI_DoctrineGroup.BullCharge:       return false;
    case MBAI_DoctrineGroup.ChromeRush:       return false;
    case MBAI_DoctrineGroup.BrotherhoodPush:  return false;
    case MBAI_DoctrineGroup.RelentlessAdvance: return false;
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return true;
    default: break;
  };
  return true;
}

public static func MBAI_RollPersonality(g: MBAI_DoctrineGroup) -> CName {
  let idx: Int32 = RandRange(0, 4);
  switch g {
    case MBAI_DoctrineGroup.ChromeRush:
      if idx == 0 { return n"Bloodthirsty"; };
      if idx == 1 { return n"Aggressive"; };
      if idx == 2 { return n"Aggressive"; };
      return n"Bloodthirsty";
    case MBAI_DoctrineGroup.BullCharge:
      if idx == 0 { return n"Bloodthirsty"; };
      if idx == 1 { return n"Aggressive"; };
      if idx == 2 { return n"Aggressive"; };
      return n"Bloodthirsty";
    case MBAI_DoctrineGroup.BladeWave:
      if idx == 0 { return n"Patient"; };
      if idx == 1 { return n"Veteran"; };
      if idx == 2 { return n"Aggressive"; };
      return n"Aggressive";
    case MBAI_DoctrineGroup.BrotherhoodPush:
      if idx == 0 { return n"Aggressive"; };
      if idx == 1 { return n"Veteran"; };
      if idx == 2 { return n"Bloodthirsty"; };
      return n"Aggressive";
    case MBAI_DoctrineGroup.FixAndFlank:
      if idx == 0 { return n"Veteran"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Cautious"; };
      return n"Aggressive";
    case MBAI_DoctrineGroup.MeasuredExecution:
      if idx == 0 { return n"Veteran"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Veteran"; };
      return n"Cautious";
    case MBAI_DoctrineGroup.RelentlessAdvance:
      if idx == 0 { return n"Veteran"; };
      if idx == 1 { return n"Aggressive"; };
      if idx == 2 { return n"Aggressive"; };
      return n"Bloodthirsty";
    case MBAI_DoctrineGroup.DefensivePerimeter:
      if idx == 0 { return n"Cautious"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Veteran"; };
      return n"Cautious";
    case MBAI_DoctrineGroup.CallAndCoordinate:
      if idx == 0 { return n"Cautious"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Green"; };
      return n"Veteran";
    case MBAI_DoctrineGroup.WeekendWarriors:
      if idx == 0 { return n"Veteran"; };
      if idx == 1 { return n"Aggressive"; };
      if idx == 2 { return n"Patient"; };
      return n"Green";
    case MBAI_DoctrineGroup.Overwhelm:
      if idx == 0 { return n"Veteran"; };
      if idx == 1 { return n"Veteran"; };
      if idx == 2 { return n"Veteran"; };
      return n"Aggressive";
    case MBAI_DoctrineGroup.RaiderStrike:
      if idx == 0 { return n"Aggressive"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Aggressive"; };
      return n"Bloodthirsty";
    case MBAI_DoctrineGroup.LockAndHold:
      if idx == 0 { return n"Cautious"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Cautious"; };
      return n"Veteran";
    case MBAI_DoctrineGroup.WallAroundRunner:
      if idx == 0 { return n"Patient"; };
      if idx == 1 { return n"Patient"; };
      if idx == 2 { return n"Cautious"; };
      return n"Aggressive";
    case MBAI_DoctrineGroup.CowardsSwarm:
      if idx == 0 { return n"Green"; };
      if idx == 1 { return n"Cautious"; };
      if idx == 2 { return n"Green"; };
      return n"Bloodthirsty";
    default: break;
  };
  if idx == 0 { return n"Patient"; };
  if idx == 1 { return n"Aggressive"; };
  if idx == 2 { return n"Cautious"; };
  return n"Veteran";
}

public static func MBAI_PersonalityShift(tag: CName) -> Int32 {
  if Equals(tag, n"Aggressive")   { return 1; };
  if Equals(tag, n"Bloodthirsty") { return 2; };
  if Equals(tag, n"Cautious")     { return -1; };
  if Equals(tag, n"Green")        { return -1; };
  return 0;
}

public static func MBAI_DoctrinePlayerAwarenessMul(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.CowardsSwarm:      return 0.70;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 0.65;
    case MBAI_DoctrineGroup.WallAroundRunner:  return 0.55;
    case MBAI_DoctrineGroup.LockAndHold:       return 0.55;
    case MBAI_DoctrineGroup.MeasuredExecution: return 0.55;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 0.45;
    case MBAI_DoctrineGroup.WeekendWarriors:   return 0.40;
    case MBAI_DoctrineGroup.FixAndFlank:       return 0.35;
    case MBAI_DoctrineGroup.BrotherhoodPush:   return 0.25;
    case MBAI_DoctrineGroup.RaiderStrike:      return 0.25;
    case MBAI_DoctrineGroup.BladeWave:         return 0.15;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 0.15;
    case MBAI_DoctrineGroup.ChromeRush:        return 0.08;
    case MBAI_DoctrineGroup.BullCharge:        return 0.05;
    case MBAI_DoctrineGroup.Overwhelm:         return 0.05;
    default: break;
  };
  return 0.25;
}

public static func MBAI_DoctrinePushCadence(g: MBAI_DoctrineGroup) -> Int32 {
  switch g {
    case MBAI_DoctrineGroup.RaiderStrike:     return 2;
    case MBAI_DoctrineGroup.WallAroundRunner: return 2;
    case MBAI_DoctrineGroup.CowardsSwarm:     return 2;
    case MBAI_DoctrineGroup.MeasuredExecution: return 2;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 2;
    case MBAI_DoctrineGroup.BladeWave:        return 1;
    case MBAI_DoctrineGroup.FixAndFlank:      return 1;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 1;
    case MBAI_DoctrineGroup.WeekendWarriors:  return 1;
    case MBAI_DoctrineGroup.LockAndHold:      return 1;
    case MBAI_DoctrineGroup.Overwhelm:        return 0;
    case MBAI_DoctrineGroup.BullCharge:       return 0;
    case MBAI_DoctrineGroup.ChromeRush:       return 0;
    case MBAI_DoctrineGroup.BrotherhoodPush:  return 0;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 0;
    default: break;
  };
  return 1;
}

public static func MBAI_TierFlankChance(rarity: gamedataNPCRarity) -> Float {
  switch rarity {
    case gamedataNPCRarity.Trash: return 0.08;
    case gamedataNPCRarity.Weak: return 0.10;
    case gamedataNPCRarity.Normal: return 0.15;
    case gamedataNPCRarity.Rare: return 0.22;
    case gamedataNPCRarity.Officer: return 0.30;
    case gamedataNPCRarity.Elite: return 0.38;
    case gamedataNPCRarity.Boss: return 0.45;
    case gamedataNPCRarity.MaxTac: return 0.50;
    default: break;
  };
  return 0.15;
}

public static func MBAI_IsPushThrough(g: MBAI_DoctrineGroup, a: gamedataArchetypeType) -> Bool {
  if MBAI_ArchetypeIsMelee(a) {
    return true;
  }
  switch g {
    case MBAI_DoctrineGroup.ChromeRush:
    case MBAI_DoctrineGroup.BullCharge:
    case MBAI_DoctrineGroup.BladeWave:
    case MBAI_DoctrineGroup.RelentlessAdvance:
      return true;
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return false;
    default:
      break;
  };
  return false;
}

public static func MBAI_DoctrineAnchorChance(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm: return 0.90;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 0.85;
    case MBAI_DoctrineGroup.MeasuredExecution: return 0.80;
    case MBAI_DoctrineGroup.FixAndFlank: return 0.75;
    case MBAI_DoctrineGroup.LockAndHold: return 0.75;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 0.65;
    case MBAI_DoctrineGroup.CallAndCoordinate: return 0.65;
    case MBAI_DoctrineGroup.WeekendWarriors: return 0.55;
    case MBAI_DoctrineGroup.RaiderStrike: return 0.50;
    case MBAI_DoctrineGroup.BrotherhoodPush: return 0.45;
    case MBAI_DoctrineGroup.ChromeRush: return 0.35;
    case MBAI_DoctrineGroup.BladeWave: return 0.25;
    case MBAI_DoctrineGroup.CowardsSwarm: return 0.20;
    case MBAI_DoctrineGroup.BullCharge: return 0.0;
    case MBAI_DoctrineGroup.WallAroundRunner: return 0.0;
    case MBAI_DoctrineGroup.Baseline: return 0.50;
  };
  return 0.50;
}

public static func MBAI_DoctrineSuppressorLimit(g: MBAI_DoctrineGroup, groupCount: Int32) -> Int32 {
  switch g {
    case MBAI_DoctrineGroup.Overwhelm:
      return groupCount >= 3 ? 2 : 1;
    case MBAI_DoctrineGroup.FixAndFlank:
      return groupCount >= 4 ? 2 : 1;
    case MBAI_DoctrineGroup.RelentlessAdvance:
      return groupCount >= 5 ? 2 : 1;
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return 1;
  };
  return groupCount >= 5 ? 2 : 1;
}

public static func MBAI_DoctrineSuppressDuration(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.FixAndFlank: return 7.0;
    case MBAI_DoctrineGroup.RelentlessAdvance: return 6.5;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 5.5;
    case MBAI_DoctrineGroup.MeasuredExecution: return 5.0;
  };
  return 6.0;
}

public static func MBAI_DoctrineGrenadeWillingness(g: MBAI_DoctrineGroup) -> Float {
  switch g {
    case MBAI_DoctrineGroup.RelentlessAdvance: return 1.25;
    case MBAI_DoctrineGroup.FixAndFlank: return 1.10;
    case MBAI_DoctrineGroup.MeasuredExecution: return 0.90;
    case MBAI_DoctrineGroup.DefensivePerimeter: return 0.80;
  };
  return 1.0;
}

public static func MBAI_DoctrineOpposesActiveFlank(g: MBAI_DoctrineGroup) -> Bool {
  switch g {
    case MBAI_DoctrineGroup.FixAndFlank:
      return true;
    case MBAI_DoctrineGroup.MeasuredExecution:
    case MBAI_DoctrineGroup.RelentlessAdvance:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return false;
  };
  return false;
}
