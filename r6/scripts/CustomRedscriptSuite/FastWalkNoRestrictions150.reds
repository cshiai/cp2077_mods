// FastWalkNoRestrictions150: dependency-free 1.5x walk/movement speed and
// removal of story/quest forced slow-walk restrictions (ForceWalk and SceneTierII).
// Multiplier 1.5 scales PlayerPuppet MaxSpeed across locomotion states without
// modifying save data.

module FastWalkNoRestrictions150

@addField(PlayerPuppet)
private let fastWalk150MaxSpeedModifier: ref<gameStatModifierData>;

@addMethod(PlayerPuppet)
public final func ApplyFastWalk150() -> Void {
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());

  if !IsDefined(this.fastWalk150MaxSpeedModifier) {
    this.fastWalk150MaxSpeedModifier = RPGManager.CreateStatModifier(gamedataStatType.MaxSpeed, gameStatModifierType.Multiplier, 1.5);
    stats.AddModifier(id, this.fastWalk150MaxSpeedModifier);
  };
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.ApplyFastWalk150();
  return result;
}

@wrapMethod(PlayerPuppet)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
  wrappedMethod(playerPuppet);
  this.ApplyFastWalk150();
}

@wrapMethod(PlayerPuppet)
protected func OnResurrected() -> Void {
  wrappedMethod();
  this.ApplyFastWalk150();
}

@wrapMethod(LocomotionTransition)
protected final const func IsWalkForced(const stateContext: ref<StateContext>) -> Bool {
  return false;
}

@wrapMethod(HighLevelTransition)
public final func SetTier2LocomotionSlow(scriptInterface: ref<StateGameScriptInterface>) -> Void {
  this.SetTier2LocomotionFast(scriptInterface);
}

@wrapMethod(SceneTierIIEvents)
protected final func UpdateSpeedValue(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Float {
  let speed: Float = wrappedMethod(stateContext, scriptInterface);
  if speed < 0.0 {
    return 0.0;
  };
  return speed;
}
