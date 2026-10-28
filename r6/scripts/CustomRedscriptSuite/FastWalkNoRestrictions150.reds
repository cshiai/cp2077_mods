// FastWalkNoRestrictions250: dependency-free 2.5x walk/movement speed and
// removal of story/quest forced slow-walk restrictions (ForceWalk and SceneTierII).
// Multiplier 2.5 scales PlayerPuppet MaxSpeed across locomotion states without
// modifying save data.  This reaches the game's approximately 15 m/s on-foot
// ceiling for sprinting, making sprint travel vehicle-like without touching
// vehicle physics or save data.

module FastWalkNoRestrictions150

// The player is attached before every subsystem has finished restoring the
// save.  A short, one-shot reapply closes that race without introducing a
// per-frame poll or a persistent timer.
public class FastWalk150ReapplyEvent extends Event {}

@addField(PlayerPuppet)
private let fastWalk150MaxSpeedModifier: ref<gameStatModifierData>;

@addField(PlayerPuppet)
private let fastWalk150ReapplyScheduled: Bool;

@addMethod(PlayerPuppet)
public final func ApplyFastWalk150() -> Void {
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());
  if !IsDefined(stats) || !EntityID.IsDefined(this.GetEntityID()) {
    return;
  };

  if !IsDefined(this.fastWalk150MaxSpeedModifier) {
    this.fastWalk150MaxSpeedModifier = RPGManager.CreateStatModifier(gamedataStatType.MaxSpeed, gameStatModifierType.Multiplier, 2.5);
  };
  if !IsDefined(this.fastWalk150MaxSpeedModifier) {
    return;
  };

  // Re-adding the same transient modifier is intentional.  Save loading and
  // equipment refreshes can rebuild the player's stat container and silently
  // drop transient entries; remove-first keeps this idempotent and prevents
  // stacking a second 2.5x multiplier.
  stats.RemoveModifier(id, this.fastWalk150MaxSpeedModifier);
  stats.AddModifier(id, this.fastWalk150MaxSpeedModifier);
}

@addMethod(PlayerPuppet)
private final func ScheduleFastWalk150Reapply() -> Void {
  if this.fastWalk150ReapplyScheduled {
    return;
  };
  let delaySystem = GameInstance.GetDelaySystem(this.GetGame());
  if !IsDefined(delaySystem) {
    return;
  };
  this.fastWalk150ReapplyScheduled = true;
  delaySystem.DelayEvent(this, new FastWalk150ReapplyEvent(), 0.25, true);
}

@addMethod(PlayerPuppet)
protected cb func OnFastWalk150ReapplyEvent(evt: ref<FastWalk150ReapplyEvent>) -> Bool {
  this.fastWalk150ReapplyScheduled = false;
  if this.IsAttached() {
    this.ApplyFastWalk150();
  };
  return true;
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  this.ApplyFastWalk150();
  this.ScheduleFastWalk150Reapply();
  return result;
}

@wrapMethod(PlayerPuppet)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) -> Void {
  wrappedMethod(playerPuppet);
  this.ApplyFastWalk150();
  this.ScheduleFastWalk150Reapply();
}

@wrapMethod(PlayerPuppet)
protected func OnResurrected() -> Void {
  wrappedMethod();
  this.ApplyFastWalk150();
  this.ScheduleFastWalk150Reapply();
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
