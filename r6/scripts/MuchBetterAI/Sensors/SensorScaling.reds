module MuchBetterAI.Sensors

import MuchBetterAI.Logging.*

@wrapMethod(SensorDevice)
private final func SetSensePresetBasedOnSSState() -> Void {
  wrappedMethod();
  if !this.IsSurveillanceCamera() && !this.IsTurret() {
    return;
  };
  let ps: ref<SensorDeviceControllerPS> = this.GetDevicePS();
  if !IsDefined(ps) || !ps.IsConnectedToSecuritySystem() {
    return;
  };
  let secSys: ref<SecuritySystemControllerPS> = ps.GetSecuritySystem();
  if !IsDefined(secSys) {
    return;
  };
  let sense: ref<SenseComponent> = this.GetSensesComponent();
  if !IsDefined(sense) {
    return;
  };
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());
  if !IsDefined(player) {
    return;
  };
  let playerID: EntityID = player.GetEntityID();
  let current: Float = sense.GetDetectionMultiplier(playerID);
  if current >= 50.0 {
    return;
  };
  let state: ESecuritySystemState = secSys.GetSecurityState();
  let mult: Float = 1.0;
  if Equals(state, ESecuritySystemState.ALERTED) {
    mult = 2.5;
  } else {
    if Equals(state, ESecuritySystemState.SAFE) {
      mult = 1.5;
    };
  };
  let vanillaBase: Float = Equals(state, ESecuritySystemState.ALERTED) ? 2.0 : 1.0;
  let floor: Float = MaxF(vanillaBase, current);
  let ceiling: Float = MaxF(floor, vanillaBase * 5.0);
  let shaped: Float = ClampF(floor * mult, floor, ceiling);
  sense.SetDetectionMultiplier(playerID, shaped);
  MBATrace("Sensors", s"sensor \(ToString(this.GetEntityID())) state=\(EnumInt(state)) base=\(current) mult=\(mult) -> \(shaped)");
}
