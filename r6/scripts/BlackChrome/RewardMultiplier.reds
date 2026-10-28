module Phoenicia.BlackChrome

// The upstream package used a CET TweakDB enumeration to append
// BlackChrome.RewardMultiplier to every currency reward.  Apply the same
// player-stat multiplier at the single vanilla reward boundary instead.  This
// keeps Sponsored Covering functional without CET or a runtime TweakDB scan.
public static func BlackChrome_RewardMoneyFactor(game: GameInstance) -> Float {
  let player: ref<PlayerPuppet> = GetPlayer(game);
  if !IsDefined(player) {
    return 1.0;
  };
  let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
  if !IsDefined(stats) {
    return 1.0;
  };
  let rewardStat: gamedataStatType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"RewardBaseStatMultiplier"));
  let bonus: Float = MaxF(stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), rewardStat), 0.0);
  return 1.0 + bonus;
}

@wrapMethod(RPGManager)
public static func GiveReward(gi: GameInstance, rewardID: TweakDBID, amount: Int32, opt target: StatsObjectID, opt moneyMultiplier: Float) -> Void {
  let factor: Float = BlackChrome_RewardMoneyFactor(gi);
  let adjustedMultiplier: Float = moneyMultiplier > 0.0 ? moneyMultiplier * factor : factor;
  wrappedMethod(gi, rewardID, amount, target, adjustedMultiplier);
}
