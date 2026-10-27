// Immersive First Person 2.2.0 — pure REDscript rewrite.
//
// This is deliberately a source-only camera compositor: no CET, Lua, ASI,
// settings files, or native hooks are required.  The optional height archive
// remains an ordinary game asset; camera ownership and input stay in REDscript.
module ImmersiveFirstPerson

public struct IFP_CameraOffset {
  public let forward: Float;
  public let vertical: Float;
}

public struct IFP_BodyResult {
  public let progress: Float;
  public let lateral: Float;
  public let forward: Float;
  public let vertical: Float;
  public let pitch: Float;
}

public struct IFP_FreeLookResult {
  public let yaw: Float;
  public let pitch: Float;
  public let lateral: Float;
  public let forward: Float;
  public let vertical: Float;
  public let roll: Float;
}

public abstract class NativeCameraCurve {
  public static func MIN_CALIBRATED_FOV() -> Float { return 43.4072366; }
  public static func REFERENCE_FOV() -> Float { return 68.23; }
  public static func ClampPitch(pitch: Float) -> Float {
    return ClampF(pitch, -80.0, 80.0);
  }

  public static func EvaluateReference(pitch: Float) -> IFP_CameraOffset {
    let p: Float = NativeCameraCurve.ClampPitch(pitch);
    let normalized: Float = p / 80.0;
    let result: IFP_CameraOffset;
    if p <= 0.0 {
      result.forward = -0.00429768 * normalized + 0.00763932 * normalized * normalized - 0.17765878 * normalized * normalized * normalized;
      result.vertical = -0.01104677 * normalized - 0.01364154 * normalized * normalized;
    } else {
      result.forward = -0.35655461 * normalized;
      result.vertical = 0.16416325 * (1.0 - ExpF(-p / 17.05)) + 0.0001897246 * p;
    }
    return result;
  }

  public static func EvaluateLowFov(pitch: Float) -> IFP_CameraOffset {
    let p: Float = NativeCameraCurve.ClampPitch(pitch);
    if p >= 0.0 {
      return NativeCameraCurve.EvaluateReference(p);
    }
    let normalized: Float = p / 80.0;
    let result: IFP_CameraOffset;
    result.forward = -0.010391657 * normalized - 0.013748585 * normalized * normalized - 0.037616403 * normalized * normalized * normalized;
    result.vertical = 0.002250879 * normalized - 0.013009273 * normalized * normalized - 0.024464473 * normalized * normalized * normalized;
    return result;
  }

  public static func Evaluate(pitch: Float, fov: Float) -> IFP_CameraOffset {
    let reference = NativeCameraCurve.EvaluateReference(pitch);
    let lowFov = NativeCameraCurve.EvaluateLowFov(pitch);
    let fovBlend: Float = ClampF((fov - NativeCameraCurve.MIN_CALIBRATED_FOV())
      / (NativeCameraCurve.REFERENCE_FOV() - NativeCameraCurve.MIN_CALIBRATED_FOV()), 0.0, 1.0);
    if fovBlend >= 1.0 || pitch >= 0.0 {
      return reference;
    }
    let result: IFP_CameraOffset;
    result.forward = lowFov.forward + (reference.forward - lowFov.forward) * fovBlend;
    result.vertical = lowFov.vertical + (reference.vertical - lowFov.vertical) * fovBlend;
    return result;
  }

  public static func OffsetToReference(nativePitch: Float, effectivePitch: Float, fov: Float) -> IFP_CameraOffset {
    let actual = NativeCameraCurve.Evaluate(nativePitch, fov);
    let desired = NativeCameraCurve.EvaluateReference(effectivePitch);
    let result: IFP_CameraOffset;
    result.forward = desired.forward - actual.forward;
    result.vertical = desired.vertical - actual.vertical;
    return result;
  }
}

public func IFP_NormalizeBodyPitch(nativePitch: Float) -> Float {
  return ClampF((-nativePitch - 30.0) / (80.0 - 30.0), 0.0, 1.0);
}

public func IFP_FIXED_FOV_POSITION_COMPENSATION() -> Float { return 0.70; }
public func IFP_BODY_WEAPON_FADE_IN_DURATION() -> Float { return 0.15; }
public func IFP_BODY_WEAPON_FADE_OUT_DURATION() -> Float { return 0.0; }

// Faithful body correction constants from IFP 2.2.0:
// START_PITCH_DOWN=30.0, FULL_PITCH_DOWN=80.0, VERTICAL_OFFSET=-0.125,
// FORWARD_OFFSET=-0.100, PITCH_CORRECTION=-9.0, crouch multipliers 1.35/1.17/1.50,
// FIXED_FOV_POSITION_COMPENSATION=0.70, weapon fade-in=0.15s.
// The transition field is
// applied by the compositor so holster/draw never fights the weapon camera.
public func EvaluateBody(nativePitch: Float, crouching: Bool) -> IFP_BodyResult {
  let progress: Float = IFP_NormalizeBodyPitch(nativePitch);
  let verticalRamp: Float = MinF(1.0, progress * 4.0) * MinF(1.0, progress / 0.70);
  let forwardShape: Float = MaxF(-0.16, 5.0 * progress - MaxF(0.0, (progress - 0.55) * 8.5));
  let result: IFP_BodyResult;
  result.progress = progress;
  result.lateral = 0.0;
  result.vertical = verticalRamp * -0.125;
  result.forward = progress * -0.100 * forwardShape;
  result.pitch = progress * -9.0;
  if crouching {
    result.vertical *= 1.35;
    result.forward = progress * -0.100 * 1.17;
    result.pitch *= 1.50;
  }
  return result;
}

public func IFP_ConeRadius(yaw: Float, pitch: Float, power: Float) -> Float {
  return PowF(PowF(AbsF(yaw), power) + PowF(AbsF(pitch), power), 1.0 / power);
}

// MAX_YAW=145.0, MAX_PITCH_DOWN/UP=85.0, COMBAT_MAX_YAW=65.0,
// COMBAT_MAX_PITCH_DOWN=40.0, COMBAT_MAX_PITCH_UP=80.0,
// MAX_LATERAL_OFFSET=0.230, MAX_BACK_OFFSET=0.025, MAX_ROLL=8.0,
// REAR_PITCH_FLOOR=-30.0, DEFAULT_RETURN_DURATION=0.25.
// A bounded, allocation-free head-cone step.  Unarmed movement uses a rounded
// cone; armed movement uses the tighter combat ellipse and never offsets the
// weapon rig laterally.
public func stepHeadCone(yaw: Float, pitch: Float, yawDelta: Float, pitchDelta: Float, hasWeapon: Bool, basePitch: Float) -> IFP_FreeLookResult {
  let maxYaw: Float = hasWeapon ? 65.0 : 145.0;
  let maxDown: Float = hasWeapon ? 40.0 : 85.0;
  let maxUp: Float = hasWeapon ? 80.0 : 85.0;
  let power: Float = hasWeapon ? 2.0 : 4.0;
  let normalizedYaw: Float = ClampF((yaw + yawDelta) / maxYaw, -1.0, 1.0);
  let signedPitch: Float = pitch + pitchDelta;
  let normalizedPitch: Float = signedPitch < 0.0
    ? ClampF(signedPitch / maxDown, -1.0, 0.0)
    : ClampF(signedPitch / maxUp, 0.0, 1.0);
  let radius: Float = IFP_ConeRadius(normalizedYaw, normalizedPitch, power);
  let limitedYaw: Float = radius > 1.0 ? normalizedYaw / radius : normalizedYaw;
  let limitedPitch: Float = radius > 1.0 ? normalizedPitch / radius : normalizedPitch;
  let result: IFP_FreeLookResult;
  result.yaw = limitedYaw * maxYaw;
  result.pitch = limitedPitch * (limitedPitch < 0.0 ? maxDown : maxUp);
  // Rear pitch floor protects the neck when turning behind while unarmed.
  if !hasWeapon && AbsF(result.yaw) > 75.0 {
    result.pitch = MaxF(result.pitch, -30.0 - basePitch);
  }
  result.lateral = 0.0;
  result.forward = 0.0;
  result.vertical = 0.0;
  result.roll = 0.0;
  return result;
}

public func EvaluateFreeLook(yaw: Float, pitch: Float, hasWeapon: Bool) -> IFP_FreeLookResult {
  let maxYaw: Float = hasWeapon ? 65.0 : 145.0;
  let normalized: Float = ClampF(AbsF(yaw) / maxYaw, 0.0, 1.0);
  let side: Float = yaw < 0.0 ? 1.0 : -1.0;
  let result: IFP_FreeLookResult;
  result.yaw = yaw;
  result.pitch = pitch;
  if hasWeapon {
    result.lateral = 0.0;
    result.forward = 0.0;
    result.vertical = 0.0;
    result.roll = 0.0;
    return result;
  }
  let lateralProgress: Float = ClampF((normalized - 0.25) / 0.40, 0.0, 1.0);
  let backProgress: Float = ClampF((normalized - 0.45) / 0.55, 0.0, 1.0);
  let turnProgress: Float = ClampF((normalized - 0.38) / 0.31, 0.0, 1.0);
  result.lateral = 0.230 * lateralProgress * side;
  result.forward = -0.025 * backProgress;
  result.vertical = 0.0;
  result.roll = -side * 8.0 * turnProgress;
  return result;
}

public class IFPCameraTickEvent extends TickableEvent {}

@addField(PlayerPuppet)
private let m_ifpBlackboard: ref<IBlackboard>;
@addField(PlayerPuppet)
private let m_ifpTickID: DelayID;
@addField(PlayerPuppet)
private let m_ifpAttached: Bool;
@addField(PlayerPuppet)
private let m_ifpFreeLook: Bool;
@addField(PlayerPuppet)
private let m_ifpReturning: Bool;
@addField(PlayerPuppet)
private let m_ifpFreeYaw: Float;
@addField(PlayerPuppet)
private let m_ifpFreePitch: Float;
@addField(PlayerPuppet)
private let m_ifpReturnYaw: Float;
@addField(PlayerPuppet)
private let m_ifpReturnPitch: Float;
@addField(PlayerPuppet)
private let m_ifpReturnElapsed: Float;
@addField(PlayerPuppet)
private let m_ifpInputMouseX: Float;
@addField(PlayerPuppet)
private let m_ifpInputMouseY: Float;
@addField(PlayerPuppet)
private let m_ifpInputStickX: Float;
@addField(PlayerPuppet)
private let m_ifpInputStickY: Float;
@addField(PlayerPuppet)
private let m_ifpBodyBlend: Float;
@addField(PlayerPuppet)
private let m_ifpBodyBlendTarget: Float;
@addField(PlayerPuppet)
private let m_ifpBodyFadeElapsed: Float;
@addField(PlayerPuppet)
private let m_ifpLastPositionDelta: Vector4;
@addField(PlayerPuppet)
private let m_ifpLastRotationDelta: EulerAngles;

public func IFP_BindBlackboard(player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(player) { return; }
  let system = GameInstance.GetBlackboardSystem(player.GetGame());
  if IsDefined(system) {
    player.m_ifpBlackboard = system.GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine);
  }
}

public func IFP_IsBlocked(player: ref<PlayerPuppet>) -> Bool {
  let bb = player.m_ifpBlackboard;
  if !IsDefined(bb) { return true; }
  let inspection = player.GetInspectionComponent();
  if IsDefined(inspection) && inspection.GetIsPlayerInspecting() {
    return true;
  }
  let defs = GetAllBlackboardDefs().PlayerStateMachine;
  if bb.GetInt(defs.SceneTier) != 0 || bb.GetInt(defs.Vitals) != 0 {
    return true;
  }
  if bb.GetInt(defs.Vehicle) != 0
    || EntityID.IsDefined(bb.GetEntityID(defs.EntityIDVehicleRemoteControlled))
    || bb.GetBool(defs.IsControllingDevice)
    || bb.GetBool(defs.IsControllingCamera)
    || bb.GetBool(defs.IsUIZoomDevice)
    || bb.GetBool(defs.IsInMinigame)
    || bb.GetBool(defs.IsForceOpeningDoor)
    || bb.GetInt(defs.Swimming) != 0
    || bb.GetInt(defs.Takedown) != 0
    || bb.GetInt(defs.BodyCarrying) != 0
    || bb.GetBool(defs.Carrying)
    || bb.GetBool(defs.Felled)
    || bb.GetInt(defs.LadderCameraParams) != 0
    || bb.GetInt(defs.Consumable) != 0
    || bb.GetInt(defs.IsInWorkspot) != 0
    || StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Knockdown)
    || StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.VehicleKnockdown) {
    return true;
  }
  let upperBody: Int32 = bb.GetInt(defs.UpperBody);
  if upperBody == 1
    || upperBody == 2
    || upperBody == 3
    || upperBody == 4
    || upperBody == 5 {
    return true;
  }
  return false;
}

public func IFP_IsCrouching(player: ref<PlayerPuppet>) -> Bool {
  let bb = player.m_ifpBlackboard;
  if !IsDefined(bb) { return false; }
  let locomotion: Int32 = bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion);
  return locomotion == 1
    || locomotion == 11
    || locomotion == 12
    || locomotion == 8;
}

public func IFP_ReadNativePitch(camera: ref<FPPCameraComponent>) -> Float {
  if !IsDefined(camera) { return 0.0; }
  let orientation: EulerAngles = Quaternion.ToEulerAngles(camera.GetLocalOrientation());
  return orientation.Pitch;
}

public func IFP_IsArmed(player: ref<PlayerPuppet>) -> Bool {
  let bb = player.m_ifpBlackboard;
  if !IsDefined(bb) { return false; }
  let defs = GetAllBlackboardDefs().PlayerStateMachine;
  return bb.GetInt(defs.RightWeapon) != 0 || bb.GetInt(defs.LeftWeapon) != 0
    || bb.GetInt(defs.UpperBody) == 6;
}

public func IFP_UpdateBodyFade(player: ref<PlayerPuppet>, hasWeapon: Bool, delta: Float) -> Float {
  let target: Float = hasWeapon ? 0.0 : 1.0;
  if player.m_ifpBodyBlendTarget != target {
    player.m_ifpBodyBlendTarget = target;
    player.m_ifpBodyFadeElapsed = 0.0;
  }
  let duration: Float = target > player.m_ifpBodyBlend
    ? IFP_BODY_WEAPON_FADE_IN_DURATION()
    : IFP_BODY_WEAPON_FADE_OUT_DURATION();
  if duration <= 0.0 {
    player.m_ifpBodyBlend = target;
    return target;
  }
  player.m_ifpBodyFadeElapsed = MinF(duration, player.m_ifpBodyFadeElapsed + MaxF(delta, 0.0));
  let progress: Float = ClampF(player.m_ifpBodyFadeElapsed / duration, 0.0, 1.0);
  player.m_ifpBodyBlend = LerpF(progress, player.m_ifpBodyBlend, target);
  return player.m_ifpBodyBlend;
}

public func IFP_ApplyCamera(player: ref<PlayerPuppet>, delta: Float) -> Void {
  if !IsDefined(player) || IFP_IsBlocked(player) { return; }
  let camera = player.GetFPPCameraComponent();
  if !IsDefined(camera) { return; }

  // Remove only our previous additive transform; this preserves native camera
  // writers and avoids per-frame drift or matrix allocations.
  let position = camera.GetLocalPosition();
  position.X -= player.m_ifpLastPositionDelta.X;
  position.Y -= player.m_ifpLastPositionDelta.Y;
  position.Z -= player.m_ifpLastPositionDelta.Z;
  let orientation = Quaternion.ToEulerAngles(camera.GetLocalOrientation());
  orientation.Pitch -= player.m_ifpLastRotationDelta.Pitch;
  orientation.Yaw -= player.m_ifpLastRotationDelta.Yaw;
  orientation.Roll -= player.m_ifpLastRotationDelta.Roll;
  let nativePitch: Float = orientation.Pitch;
  if !player.m_ifpFreeLook && !player.m_ifpReturning && nativePitch > -30.0 {
    player.m_ifpLastPositionDelta = new Vector4(0.0, 0.0, 0.0, 0.0);
    player.m_ifpLastRotationDelta = new EulerAngles();
    return;
  }

  let hasWeapon: Bool = IFP_IsArmed(player);
  let bodyBlend: Float = IFP_UpdateBodyFade(player, hasWeapon, delta);
  let body = EvaluateBody(nativePitch, IFP_IsCrouching(player));
  body.forward *= bodyBlend;
  body.vertical *= bodyBlend;
  body.pitch *= bodyBlend;
  let effectivePitch: Float = nativePitch + body.pitch;
  let curve = NativeCameraCurve.OffsetToReference(nativePitch, effectivePitch, camera.GetFOV());
  let free = EvaluateFreeLook(player.m_ifpFreeYaw, player.m_ifpFreePitch, hasWeapon);
  let positionCompensation: Float = IFP_FIXED_FOV_POSITION_COMPENSATION();
  let newDelta: Vector4 = new Vector4(0.0, 0.0, 0.0, 0.0);
  newDelta.X = body.lateral + free.lateral;
  newDelta.Y = body.forward + free.forward + curve.forward * positionCompensation;
  newDelta.Z = body.vertical + free.vertical + curve.vertical * positionCompensation;
  let newRotation: EulerAngles = new EulerAngles();
  newRotation.Pitch = body.pitch + free.pitch;
  newRotation.Yaw = free.yaw;
  newRotation.Roll = free.roll;
  position.X += newDelta.X;
  position.Y += newDelta.Y;
  position.Z += newDelta.Z;
  orientation.Pitch += newRotation.Pitch;
  orientation.Yaw += newRotation.Yaw;
  orientation.Roll += newRotation.Roll;
  camera.SetLocalTransform(position, EulerAngles.ToQuat(orientation));
  player.m_ifpLastPositionDelta = newDelta;
  player.m_ifpLastRotationDelta = newRotation;

  if player.m_ifpReturning {
    player.m_ifpReturnElapsed += delta;
    let t: Float = ClampF(player.m_ifpReturnElapsed / 0.25, 0.0, 1.0);
    let ease: Float = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
    player.m_ifpFreeYaw = LerpF(ease, player.m_ifpReturnYaw, 0.0);
    player.m_ifpFreePitch = LerpF(ease, player.m_ifpReturnPitch, 0.0);
    if t >= 1.0 {
      player.m_ifpReturning = false;
      player.m_ifpFreeYaw = 0.0;
      player.m_ifpFreePitch = 0.0;
    }
  } else if player.m_ifpFreeLook {
    let head = stepHeadCone(player.m_ifpFreeYaw, player.m_ifpFreePitch,
      player.m_ifpInputMouseX * -0.07 + player.m_ifpInputStickX * -1.92,
      player.m_ifpInputMouseY * 0.07 + player.m_ifpInputStickY * 1.92,
      IFP_IsArmed(player), nativePitch);
    player.m_ifpFreeYaw = head.yaw;
    player.m_ifpFreePitch = head.pitch;
  }
  player.m_ifpInputMouseX = 0.0;
  player.m_ifpInputMouseY = 0.0;
  player.m_ifpInputStickX = 0.0;
  player.m_ifpInputStickY = 0.0;
}

public func IFP_BeginFreeLook(player: ref<PlayerPuppet>) -> Void {
  if IsDefined(player) && !IFP_IsBlocked(player) {
    player.m_ifpFreeLook = true;
    player.m_ifpReturning = false;
  }
}

public func IFP_EndFreeLook(player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(player) { return; }
  player.m_ifpFreeLook = false;
  player.m_ifpReturning = true;
  player.m_ifpReturnYaw = player.m_ifpFreeYaw;
  player.m_ifpReturnPitch = player.m_ifpFreePitch;
  player.m_ifpReturnElapsed = 0.0;
}

public func IFP_AbortFreeLook(player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(player) { return; }
  player.m_ifpFreeLook = false;
  player.m_ifpReturning = false;
  player.m_ifpFreeYaw = 0.0;
  player.m_ifpFreePitch = 0.0;
}

@addMethod(PlayerPuppet)
protected cb func OnIFPCameraTickEvent(evt: ref<IFPCameraTickEvent>) -> Bool {
  if !this.m_ifpAttached { return true; }
  IFP_ApplyCamera(this, 0.016);
  return true;
}

@wrapMethod(PlayerPuppet)
protected cb func OnTakeControl(ri: EntityResolveComponentsInterface) -> Bool {
  let result: Bool = wrappedMethod(ri);
  this.m_ifpAttached = !this.IsReplacer();
  this.m_ifpFreeLook = false;
  this.m_ifpReturning = false;
  this.m_ifpBodyBlend = 1.0;
  this.m_ifpBodyBlendTarget = 1.0;
  this.m_ifpBodyFadeElapsed = 0.0;
  this.m_ifpLastPositionDelta = new Vector4(0.0, 0.0, 0.0, 0.0);
  this.m_ifpLastRotationDelta = new EulerAngles();
  IFP_BindBlackboard(this);
  let delay = GameInstance.GetDelaySystem(this.GetGame());
  if this.m_ifpAttached && IsDefined(delay) {
    let tick = new IFPCameraTickEvent();
    // -1.0 keeps one event alive for the attached lifetime; OnDetach cancels
    // it explicitly, so no per-frame global scan or orphaned callback exists.
    this.m_ifpTickID = delay.TickOnEvent(this, tick, -1.0);
  }
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let name: CName = ListenerAction.GetName(action);
  if Equals(name, n"FreeLook") || Equals(name, n"CameraFreeLook") {
    if ListenerAction.IsButtonJustPressed(action) { IFP_BeginFreeLook(this); }
    if ListenerAction.IsButtonJustReleased(action) { IFP_EndFreeLook(this); }
  }
  if this.m_ifpFreeLook {
    if Equals(name, n"mouse_left") || Equals(name, n"RangedAttack") {
      IFP_AbortFreeLook(this);
    } else if Equals(name, n"CameraMouseX") {
      this.m_ifpInputMouseX += ListenerAction.GetValue(action);
      ListenerActionConsumer.ConsumeSingleAction(consumer);
    } else if Equals(name, n"CameraMouseY") {
      this.m_ifpInputMouseY += ListenerAction.GetValue(action);
      ListenerActionConsumer.ConsumeSingleAction(consumer);
    } else if Equals(name, n"CameraX") || Equals(name, n"right_stick_x") {
      this.m_ifpInputStickX += ListenerAction.GetValue(action);
      ListenerActionConsumer.ConsumeSingleAction(consumer);
    } else if Equals(name, n"CameraY") || Equals(name, n"right_stick_y") {
      this.m_ifpInputStickY += ListenerAction.GetValue(action);
      ListenerActionConsumer.ConsumeSingleAction(consumer);
    }
  }
  return wrappedMethod(action, consumer);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  this.m_ifpAttached = false;
  this.m_ifpFreeLook = false;
  this.m_ifpReturning = false;
  let delay = GameInstance.GetDelaySystem(this.GetGame());
  if IsDefined(delay) {
    delay.CancelTick(this.m_ifpTickID);
  }
  this.m_ifpTickID = GetInvalidDelayID();
  this.m_ifpBlackboard = null;
  return wrappedMethod();
}
