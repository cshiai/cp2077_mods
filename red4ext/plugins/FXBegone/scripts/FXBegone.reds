module FXBegone

// FXBegoneSettings.reds holds the menu; it's generated from data/effects.json
public native func SetToggles(values: array<Bool>) -> Void;
public native func SetSliders(values: array<Float>) -> Void;
public native func TakeStoppedNames() -> array<CName>;
public native func LowHealthThreshold() -> Float;
public native func TraceEnabled() -> Bool;
public native func SetSceneTier(tier: Int32) -> Void;

// The DLL only stops new spawns, so loops already running on V end here
public func StopDisabled(game: GameInstance) -> Void {
  let names = TakeStoppedNames();
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return;
  }
  for name in names {
    GameObjectEffectHelper.BreakEffectLoopEvent(player, name);
    GameObjectEffectHelper.StopEffectEvent(player, name);
  }
}

// Feeds V's PSM HighLevel to the trace log, which tells gameplay (0-2, 6) from cinematics (3-5)
public class FXBegoneSceneTier extends ScriptableSystem {
  private let blackboard: wref<IBlackboard>;
  private let listener: ref<CallbackHandle>;

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if !IsDefined(request) {
      return;
    }
    let player = request.owner as PlayerPuppet;
    if !TraceEnabled() || !IsDefined(player) {
      return;
    }
    this.Unlisten();
    this.blackboard = GameInstance.GetBlackboardSystem(this.GetGameInstance())
      .GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine);
    if IsDefined(this.blackboard) {
      this.listener = this.blackboard.RegisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel,
        this, n"OnHighLevel", true);
    }
  }

  private final func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.Unlisten();
  }

  private final func Unlisten() -> Void {
    if IsDefined(this.blackboard) && IsDefined(this.listener) {
      this.blackboard.UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel, this.listener);
    }
    this.blackboard = null;
    this.listener = null;
  }

  protected cb func OnHighLevel(value: Int32) -> Bool {
    SetSceneTier(value);
    return false;
  }
}

// Scales the health it sees. The TweakDB threshold also drives the low health sound cues, so it stays put
@wrapMethod(PlayerPuppet)
private final func UpdateHealthStateVFX(healthValue: Float) -> Void {
  let threshold = LowHealthThreshold();
  let vanilla = PlayerPuppet.GetLowHealthThreshold();
  if threshold < 0.0 || vanilla <= 0.0 || threshold == vanilla {
    wrappedMethod(healthValue);
  } else {
    if threshold <= 0.0 {
      // At or above the threshold, so a running overlay stops and no new one starts
      wrappedMethod(MaxF(healthValue, vanilla));
    } else {
      wrappedMethod(healthValue * vanilla / threshold);
    }
  }
}
