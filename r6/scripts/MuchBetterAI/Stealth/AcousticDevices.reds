module MuchBetterAI.Stealth


@addField(Door)
public let m_mbaiAcousticPlayerClose: Bool;

@addField(Door)
public let m_mbaiAcousticPlayerOpen: Bool;

@addField(Door)
public let m_mbaiAcousticCloseEmission: Bool;

public func MBAI_Acoustic_DoorBaseRadius(radius: Float) -> Float {
  return radius > 0.0 ? radius : TweakDBInterface.GetFloat(t"stims.OpeningDoorStimuli.radius", 0.0);
}

public func MBAI_Acoustic_DoorPlayerAction(executor: wref<GameObject>) -> Bool {
  let player: ref<PlayerPuppet> = executor as PlayerPuppet;
  return IsDefined(player) && !MBAI_Acoustic_ATOOwnsInteraction() && MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Interaction);
}

public func MBAI_Acoustic_ClearDoorMarkers(door: ref<Door>) -> Void {
  door.m_mbaiAcousticPlayerOpen = false;
  door.m_mbaiAcousticPlayerClose = false;
  door.m_mbaiAcousticCloseEmission = false;
}

@wrapMethod(StimBroadcasterComponent)
public final func TriggerSingleBroadcast(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool) -> Void {
  if !Equals(gdStimType, gamedataStimType.OpeningDoor) {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let door: ref<Door> = contextOwner as Door;
  if !IsDefined(door) || (!door.m_mbaiAcousticPlayerOpen && !door.m_mbaiAcousticCloseEmission) || MBAI_Acoustic_ATOOwnsInteraction() || !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Interaction) {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let source: ref<GameObject> = this.GetOwner();
  if source != contextOwner {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let baseRadius: Float = MBAI_Acoustic_DoorBaseRadius(radius);
  if baseRadius <= 0.0 {
    wrappedMethod(contextOwner, gdStimType, radius, investigateData, propagationChange);
    return;
  };
  let scaledRadius: Float = baseRadius * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Interaction);
  let severity: MBAI_AcousticSeverity = MBAI_AcousticSeverity.Incidental;
  if radius > 0.0 && !door.m_mbaiAcousticCloseEmission {
    severity = MBAI_AcousticSeverity.Suspicious;
  };
  wrappedMethod(contextOwner, gdStimType, scaledRadius, investigateData, propagationChange);
  MBAI_Acoustic_Record(source, source.GetWorldPosition(), gdStimType, MBAI_AcousticFamily.Interaction, severity, scaledRadius);
}

@wrapMethod(StimBroadcasterComponent)
public final func AddActiveStimuli(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt lifetime: Float, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool, opt shouldOverride: Bool) -> Void {
  if !Equals(gdStimType, gamedataStimType.OpeningDoor) {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  let door: ref<Door> = contextOwner as Door;
  if !IsDefined(door) || (!door.m_mbaiAcousticPlayerOpen && !door.m_mbaiAcousticCloseEmission) || MBAI_Acoustic_ATOOwnsInteraction() || !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Interaction) {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  let source: ref<GameObject> = this.GetOwner();
  if source != contextOwner {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  let baseRadius: Float = MBAI_Acoustic_DoorBaseRadius(radius);
  if baseRadius <= 0.0 {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange, shouldOverride);
    return;
  };
  wrappedMethod(contextOwner, gdStimType, lifetime, baseRadius * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Interaction), investigateData, propagationChange, shouldOverride);
}

@wrapMethod(StimBroadcasterComponent)
public final func SetSingleActiveStimuli(contextOwner: wref<GameObject>, gdStimType: gamedataStimType, opt lifetime: Float, opt radius: Float, opt investigateData: stimInvestigateData, opt propagationChange: Bool) -> Void {
  let radio: ref<Radio> = contextOwner as Radio;
  let player: ref<PlayerPuppet> = investigateData.attackInstigator as PlayerPuppet;
  if !IsDefined(radio) || !IsDefined(player) || radius <= 0.0 || MBAI_Acoustic_ATOOwnsInteraction() || !MBAI_Acoustic_Enabled(MBAI_AcousticFamily.Interaction) {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange);
    return;
  };
  let source: ref<GameObject> = this.GetOwner();
  if source != contextOwner {
    wrappedMethod(contextOwner, gdStimType, lifetime, radius, investigateData, propagationChange);
    return;
  };
  let scaledRadius: Float = radius * MBAI_Acoustic_Scale(MBAI_AcousticFamily.Interaction);
  propagationChange = true;
  wrappedMethod(contextOwner, gdStimType, lifetime, scaledRadius, investigateData, propagationChange);
  MBAI_Acoustic_Record(source, source.GetWorldPosition(), gdStimType, MBAI_AcousticFamily.Interaction, MBAI_AcousticSeverity.Suspicious, scaledRadius);
}

@wrapMethod(Door)
protected cb func OnToggleOpen(evt: ref<ToggleOpen>) -> Bool {
  MBAI_Acoustic_ClearDoorMarkers(this);
  let playerAction: Bool = IsDefined(evt) && MBAI_Acoustic_DoorPlayerAction(evt.GetExecutor());
  this.m_mbaiAcousticPlayerOpen = playerAction && this.GetDevicePS().IsOpen();
  this.m_mbaiAcousticPlayerClose = playerAction && !this.GetDevicePS().IsOpen();
  let result: Bool = wrappedMethod(evt);
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}

@wrapMethod(Door)
protected cb func OnActionDemolition(evt: ref<ActionDemolition>) -> Bool {
  MBAI_Acoustic_ClearDoorMarkers(this);
  this.m_mbaiAcousticPlayerOpen = IsDefined(evt) && MBAI_Acoustic_DoorPlayerAction(evt.GetExecutor());
  let result: Bool = wrappedMethod(evt);
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}

@wrapMethod(Door)
protected cb func OnActionEngineering(evt: ref<ActionEngineering>) -> Bool {
  MBAI_Acoustic_ClearDoorMarkers(this);
  this.m_mbaiAcousticPlayerOpen = IsDefined(evt) && MBAI_Acoustic_DoorPlayerAction(evt.GetExecutor());
  let result: Bool = wrappedMethod(evt);
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}

@wrapMethod(Door)
protected cb func OnForceOpen(evt: ref<ForceOpen>) -> Bool {
  MBAI_Acoustic_ClearDoorMarkers(this);
  this.m_mbaiAcousticPlayerOpen = IsDefined(evt) && MBAI_Acoustic_DoorPlayerAction(evt.GetExecutor());
  let result: Bool = wrappedMethod(evt);
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}

@wrapMethod(BunkerDoor)
protected cb func OnMalfunctionHalfOpen(evt: ref<MalfunctionHalfOpen>) -> Bool {
  MBAI_Acoustic_ClearDoorMarkers(this);
  this.m_mbaiAcousticPlayerOpen = IsDefined(evt) && MBAI_Acoustic_DoorPlayerAction(evt.GetExecutor());
  let result: Bool = wrappedMethod(evt);
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}

@wrapMethod(Door)
private final func MoveDoor(shouldBeOpened: Bool, immediate: Bool, opt movingSpeedMultiplier: Float) -> Bool {
  let playerClose: Bool = this.m_mbaiAcousticPlayerClose && !immediate && !shouldBeOpened;
  this.m_mbaiAcousticPlayerClose = false;
  let result: Bool = wrappedMethod(shouldBeOpened, immediate, movingSpeedMultiplier);
  if playerClose {
    let baseRadius: Float = TweakDBInterface.GetFloat(t"stims.OpeningDoorStimuli.radius", 0.0);
    let broadcaster: ref<StimBroadcasterComponent> = this.GetStimBroadcasterComponent();
    if baseRadius > 0.0 && IsDefined(broadcaster) {
      this.m_mbaiAcousticCloseEmission = true;
      broadcaster.TriggerSingleBroadcast(this, gamedataStimType.OpeningDoor, baseRadius);
      this.m_mbaiAcousticCloseEmission = false;
    };
  };
  MBAI_Acoustic_ClearDoorMarkers(this);
  return result;
}
