module MuchBetterAI.Stealth


public func MBAI_Acoustic_CombatBaseRadius(gdStimType: gamedataStimType, radius: Float) -> Float {
  if radius > 0.0 {
    return radius;
  };
  if Equals(gdStimType, gamedataStimType.MeleeAttack) {
    return TweakDBInterface.GetFloat(t"stims.MeleeAttackStimuli.radius", 0.0);
  };
  if Equals(gdStimType, gamedataStimType.SilencedGunshot) {
    return TweakDBInterface.GetFloat(t"stims.SilencedGunshotStimuli.radius", 0.0);
  };
  return 0.0;
}

@wrapMethod(StimBroadcasterComponent)
public final func TriggerSingleBroadcast(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool) -> Void {
  let melee: Bool = Equals(gdStimType, gamedataStimType.MeleeAttack);
  let silencedGunshot: Bool = Equals(gdStimType, gamedataStimType.SilencedGunshot);
  if !melee && !silencedGunshot {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let player: ref<PlayerPuppet> = contextOwner as PlayerPuppet;
  if !IsDefined(player) || this.GetOwner() != player || !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Combat) || (silencedGunshot && !player.m_mbaiAcousticSuppressedShot) {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let baseRadius: Float = MBAI_Acoustic_CombatBaseRadius(gdStimType, radius);
  if baseRadius <= 0.0 {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let scaledRadius: Float = baseRadius * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Combat);
  wrappedMethod(contextOwner, gdStimType, scaledRadius, investigateData, propagationChange);
  if melee {
    MBAI_Acoustic_Record(player, player.GetWorldPosition(), gdStimType, MBAI_AcousticFamily.Combat, MBAI_AcousticSeverity.Suspicious, scaledRadius);
  };
}

@wrapMethod(StimBroadcasterComponent)
public final func AddActiveStimuli(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt lifetime: Float, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool, opt shouldOverride: Bool) -> Void {
  let player: ref<PlayerPuppet> = contextOwner as PlayerPuppet;
  if !Equals(gdStimType, gamedataStimType.CarryBody) || !IsDefined(player) || this.GetOwner() != player || !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Body) {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  let baseRadius: Float = radius > 0.0 ? radius : TweakDBInterface.GetFloat(t"stims.CarryBodyStimuli.radius", 0.0);
  if baseRadius <= 0.0 {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  let scaledRadius: Float = baseRadius * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Body);
  wrappedMethod(contextOwner, gdStimType, lifetime, scaledRadius, investigateData, propagationChange, shouldOverride);
  MBAI_Acoustic_Record(player, player.GetWorldPosition(), gdStimType, MBAI_AcousticFamily.Body, MBAI_AcousticSeverity.Suspicious, scaledRadius);
}
