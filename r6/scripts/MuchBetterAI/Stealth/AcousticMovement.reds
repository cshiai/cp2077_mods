module MuchBetterAI.Stealth


@addField(PlayerPuppet)
public let m_mbaiAcousticJumpTakeoff: Bool;

public func MBAI_Acoustic_PlayerBaseRadius(gdStimType: gamedataStimType) -> Float {
  if Equals(gdStimType, gamedataStimType.FootStepRegular) {
    return TweakDBInterface.GetFloat(t"stims.FootStepRegularStimuli.radius", 0.0);
  };
  if Equals(gdStimType, gamedataStimType.FootStepSprint) {
    return TweakDBInterface.GetFloat(t"stims.FootStepSprintStimuli.radius", 0.0);
  };
  if Equals(gdStimType, gamedataStimType.LandingRegular) {
    return TweakDBInterface.GetFloat(t"stims.LandingRegularStimuli.radius", 0.0);
  };
  if Equals(gdStimType, gamedataStimType.LandingHard) {
    return TweakDBInterface.GetFloat(t"stims.LandingHardStimuli.radius", 0.0);
  };
  if Equals(gdStimType, gamedataStimType.LandingVeryHard) {
    return TweakDBInterface.GetFloat(t"stims.LandingVeryHardStimuli.radius", 0.0);
  };
  return 0.0;
}

public func MBAI_Acoustic_PlayerSourceEnabled(player: ref<PlayerPuppet>, gdStimType: gamedataStimType) -> Bool {
  if Equals(gdStimType, gamedataStimType.FootStepRegular) || Equals(gdStimType, gamedataStimType.FootStepSprint) {
    return player.m_mbaiAcousticJumpTakeoff ? true : true;
  };
  if Equals(gdStimType, gamedataStimType.LandingRegular) || Equals(gdStimType, gamedataStimType.LandingHard) || Equals(gdStimType, gamedataStimType.LandingVeryHard) {
    return true;
  };
  return false;
}

public func MBAI_Acoustic_PlayerSeverity(player: ref<PlayerPuppet>, gdStimType: gamedataStimType) -> MBAI_AcousticSeverity {
  if Equals(gdStimType, gamedataStimType.FootStepRegular) {
    if player.m_mbaiAcousticJumpTakeoff {
      return MBAI_AcousticSeverity.Suspicious;
    };
    return MBAI_AcousticSeverity.Incidental;
  };
  if Equals(gdStimType, gamedataStimType.FootStepSprint) {
    if player.m_mbaiAcousticJumpTakeoff {
      return MBAI_AcousticSeverity.Alarming;
    };
    return MBAI_AcousticSeverity.Suspicious;
  };
  if Equals(gdStimType, gamedataStimType.LandingRegular) {
    return MBAI_AcousticSeverity.Incidental;
  };
  if Equals(gdStimType, gamedataStimType.LandingHard) {
    return MBAI_AcousticSeverity.Suspicious;
  };
  if Equals(gdStimType, gamedataStimType.LandingVeryHard) {
    return MBAI_AcousticSeverity.Alarming;
  };
  return MBAI_AcousticSeverity.Suspicious;
}

@wrapMethod(StimBroadcasterComponent)
public final func TriggerSingleBroadcast(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool) -> Void {
  let player: ref<PlayerPuppet> = contextOwner as PlayerPuppet;
  if !IsDefined(player) || this.GetOwner() != player || !MBAI_Acoustic_PlayerSourceEnabled(player, gdStimType) {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  if MBAI_Acoustic_ATOOwnsMovement() {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let family: MBAI_AcousticFamily = MBAI_AcousticFamily.Movement;
  if !MBAI_Acoustic_Enabled(family) {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let baseRadius: Float = radius > 0.0 ? radius : MBAI_Acoustic_PlayerBaseRadius(gdStimType);
  if baseRadius <= 0.0 {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let scaledRadius: Float = baseRadius * MBAI_Acoustic_Scale(family);
  let severity: MBAI_AcousticSeverity = MBAI_Acoustic_PlayerSeverity(player, gdStimType);
  wrappedMethod(contextOwner, gdStimType, scaledRadius, investigateData, propagationChange);
  MBAI_Acoustic_Record(player, player.GetWorldPosition(), gdStimType, family, severity, scaledRadius);
}

public func MBAI_Acoustic_BroadcastJump(player: ref<PlayerPuppet>, gdStimType: gamedataStimType, radius: Float) -> Void {
  let broadcaster: ref<StimBroadcasterComponent> = player.GetStimBroadcasterComponent();
  if IsDefined(broadcaster) {
    player.m_mbaiAcousticJumpTakeoff = true;
    broadcaster.TriggerSingleBroadcast(player, gdStimType, radius);
    player.m_mbaiAcousticJumpTakeoff = false;
  };
}

@wrapMethod(JumpEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  let crouched: Bool = IsDefined(player) && player.GetPuppetPS().IsCrouch();
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(player) && !MBAI_Acoustic_ATOOwnsMovement() && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Movement) {
    let stats: ref<StatsSystem> = scriptInterface.GetStatsSystem();
    if stats.GetStatValue(Cast<StatsObjectID>(scriptInterface.ownerEntityID), gamedataStatType.CanWalkSilently) < 1.0 {
      let crouchFactor: Float = crouched ? 0.5 : 1.0;
      MBAI_Acoustic_BroadcastJump(player, gamedataStimType.FootStepRegular, MBAI_Acoustic_PlayerBaseRadius(gamedataStimType.FootStepRegular) * crouchFactor);
    };
  };
}

@wrapMethod(DoubleJumpEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && !MBAI_Acoustic_ATOOwnsMovement() && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Movement) {
    let stats: ref<StatsSystem> = scriptInterface.GetStatsSystem();
    if stats.GetStatValue(Cast<StatsObjectID>(scriptInterface.ownerEntityID), gamedataStatType.CanRunSilently) < 1.0 {
      MBAI_Acoustic_BroadcastJump(player, gamedataStimType.FootStepSprint, MBAI_Acoustic_PlayerBaseRadius(gamedataStimType.FootStepSprint));
    };
  };
}

@wrapMethod(ChargeJumpEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && !MBAI_Acoustic_ATOOwnsMovement() && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Movement) {
    let stats: ref<StatsSystem> = scriptInterface.GetStatsSystem();
    if stats.GetStatValue(Cast<StatsObjectID>(scriptInterface.ownerEntityID), gamedataStatType.CanRunSilently) < 1.0 {
      MBAI_Acoustic_BroadcastJump(player, gamedataStimType.FootStepSprint, MBAI_Acoustic_PlayerBaseRadius(gamedataStimType.FootStepSprint));
    };
  };
}
