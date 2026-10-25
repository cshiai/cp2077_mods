// F1: Cyber-Ninja Parkour (Infinite Mid-Air Jumps + Infinite Mid-Air Dashes + Zero Fall Damage)
// Pure Redscript (0 dependencies) for Cyberpunk 2077 v2.5:
// 1. Infinite Mid-Air Jumps: Jump as many times as you want in mid-air from any airborne
//    state (Jump, Fall, ChargeJump, HoverJump, DodgeAir, or while still rising in DoubleJump),
//    regardless of equipped leg cyberware or fall speed.
// 2. Infinite Mid-Air Dashes: Air-dash infinitely in mid-air without touching the ground.
// 3. Zero Fall Damage: Replaces Hard, VeryHard, and Death landings with smooth Regular landings.

// --- 1. Infinite Mid-Air Jumps ---
@wrapMethod(DoubleJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let jumpPressedFlag: Bool = stateContext.GetConditionBool(n"JumpPressed");
  if !jumpPressedFlag && !this.m_jumpPressed {
    this.EnableOnEnterCondition(false);
  };
  if scriptInterface.localBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsPlayerInsideMovingElevator) {
    return false;
  };
  if jumpPressedFlag || scriptInterface.IsActionJustPressed(n"Jump") {
    return true;
  };
  return false;
}

@wrapMethod(DoubleJumpEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  stateContext.SetPermanentIntParameter(n"currentNumberOfJumps", 0, true);
}

// Allow chaining another mid-air jump or air-dash immediately while still inside DoubleJump / DodgeAir
@wrapMethod(LocomotionAirEvents)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let doubleJump: ref<DoubleJumpEvents> = this as DoubleJumpEvents;
  if IsDefined(doubleJump) && scriptInterface.IsActionJustPressed(n"Jump") {
    doubleJump.OnEnter(stateContext, scriptInterface);
    return;
  };
  let dodgeAir: ref<DodgeAirEvents> = this as DodgeAirEvents;
  if IsDefined(dodgeAir) && scriptInterface.IsActionJustPressed(n"Jump") {
    stateContext.SetConditionBoolParameter(n"JumpPressed", true, true);
  };
}

// --- 2. Infinite Mid-Air Dashes ---
@replaceMethod(DodgeAirDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  this.EnableOnEnterCondition(true);
  if StatusEffectSystem.ObjectHasStatusEffect(scriptInterface.executionOwner, t"BaseStatusEffect.NetwatcherGeneral") {
    return false;
  };
  return this.WantsToDodge(stateContext, scriptInterface);
}

@wrapMethod(DodgeAirEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  stateContext.SetPermanentIntParameter(n"currentNumberOfAirDodges", 0, true);
}

// --- 3. Zero Fall Damage (Always Smooth Regular Landing) ---
@replaceMethod(LocomotionAirDecisions)
protected const func ToRegularLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if !this.IsTouchingGround(scriptInterface) || this.GetVerticalSpeed(scriptInterface) > 0.0 {
    return false;
  };
  return true;
}

@replaceMethod(LocomotionAirDecisions)
protected final const func ToHardLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  return false;
}

@replaceMethod(LocomotionAirDecisions)
protected final const func ToVeryHardLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  return false;
}

@replaceMethod(LocomotionAirDecisions)
protected const func ToDeathLand(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  return false;
}
