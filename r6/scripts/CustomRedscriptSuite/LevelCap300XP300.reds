// LevelCap150XP150: dependency-free Level Cap 150 & +50% XP multiplier (1.5x).
// Raises Player Level and Street Cred caps to 150, ensures XP thresholds and
// Perk/Attribute point rewards continue past level 60, raises the Attribute cap
// to 150 so additional points can be spent, and increases all XP gained by 50%.

module LevelCap150XP150

@wrapMethod(PlayerDevelopmentData)
public final const func GetProficiencyAbsoluteMaxLevel(type: gamedataProficiencyType) -> Int32 {
  let baseMax: Int32 = wrappedMethod(type);
  if Equals(type, gamedataProficiencyType.Level) || Equals(type, gamedataProficiencyType.StreetCred) {
    return Max(baseMax, 150);
  };
  return baseMax;
}

@wrapMethod(PlayerDevelopmentData)
private final const func GetProficiencyMaxLevel(type: gamedataProficiencyType) -> Int32 {
  let baseMax: Int32 = wrappedMethod(type);
  if Equals(type, gamedataProficiencyType.Level) || Equals(type, gamedataProficiencyType.StreetCred) {
    return Max(baseMax, 150);
  };
  return baseMax;
}

@wrapMethod(PlayerDevelopmentData)
private final const func GetExperienceForNextLevel(type: gamedataProficiencyType) -> Int32 {
  let exp: Int32 = wrappedMethod(type);
  if exp <= 0 && !this.IsProficiencyMaxLvl(type) {
    return 10000;
  };
  return exp;
}

@wrapMethod(PlayerDevelopmentData)
private final const func GetDevPointsForLevel(level: Int32, profType: gamedataProficiencyType, devPtsType: gamedataDevelopmentPointType) -> Int32 {
  let pts: Int32 = wrappedMethod(level, profType, devPtsType);
  if Equals(profType, gamedataProficiencyType.Level) && pts <= 0 {
    if Equals(devPtsType, gamedataDevelopmentPointType.Primary) || Equals(devPtsType, gamedataDevelopmentPointType.Attribute) {
      return 1;
    };
  };
  return pts;
}

@wrapMethod(PlayerDevelopmentData)
private final const func GetAttributeDevCap(type: gamedataStatType) -> Int32 {
  let cap: Int32 = wrappedMethod(type);
  return Max(cap, 150);
}

@wrapMethod(PlayerDevelopmentData)
public final const func AddExperience(amount: Int32, type: gamedataProficiencyType, telemetryGainReason: telemetryLevelGainReason, opt isDebug: Bool) -> Void {
  this.UpdateProficiencyMaxLevels();
  let boostedAmount: Int32 = amount;
  if amount > 0 {
    boostedAmount = Max(1, Cast<Int32>((Cast<Float>(amount) * 1.50) + 0.50));
  };
  wrappedMethod(boostedAmount, type, telemetryGainReason, isDebug);
}
