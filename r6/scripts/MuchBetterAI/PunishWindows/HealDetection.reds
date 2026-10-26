module MuchBetterAI.PunishWindows


@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if IsDefined(evt) && IsDefined(evt.staticData) && evt.staticData.GameplayTagsContains(n"UsedHealingItemOrCyberwareStatusEffect") {
    let sys: ref<MBAI_PunishWindowsSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"MuchBetterAI.PunishWindows.MBAI_PunishWindowsSystem") as MBAI_PunishWindowsSystem;
    if IsDefined(sys) {
      sys.MBAI_OnHealUsed();
    };
  };
  return result;
}
