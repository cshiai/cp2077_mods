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

public func IFP_RotatePitchVector(pitch: Float, motion: Vector4) -> Vector4 {
  let radians: Float = Deg2Rad(pitch);
  let cosine: Float = CosF(radians);
  let sine: Float = SinF(radians);
  let result: Vector4 = new Vector4(motion.X, 0.0, 0.0, motion.W);
  result.Y = cosine * motion.Y - sine * motion.Z;
  result.Z = sine * motion.Y + cosine * motion.Z;
  return result;
}

public func IFP_QuatMul(a: Quaternion, b: Quaternion) -> Quaternion {
  return a * b;
}

public func IFP_AxisAngle(axis: Vector4, angle: Float) -> Quaternion {
  let result: Quaternion;
  Quaternion.SetAxisAngle(result, axis, angle);
  return result;
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
  let verticalRamp: Float = MinF(1.0, progress * 4.0) * MinF(1.0, progress / 0.80);
  let forwardShape: Float = MaxF(-0.16, 5.0 * progress - MaxF(0.0, (progress - 0.37) * 8.5));
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
private let m_ifpOwnsCamera: Bool;
@addField(PlayerPuppet)
private let m_ifpBaselinePos: Vector4;
@addField(PlayerPuppet)
private let m_ifpBaselineRot: Quaternion;
@addField(PlayerPuppet)
private let m_ifpBaselineFov: Float;
@addField(PlayerPuppet)
private let m_ifpLastTickTime: Float;

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

public func IFP_ReadNativePitch(camera: ref<FPPCameraComponent>, actualLocalOrientation: Quaternion) -> Float {
  let worldOrientation: Quaternion = Matrix.ToQuat(camera.GetLocalToWorld());
  let nativeOrientation: Quaternion = Quaternion.MulInverse(worldOrientation, actualLocalOrientation);
  let forward: Vector4 = Quaternion.GetForward(nativeOrientation);
  let fromForward: Float = Rad2Deg(AsinF(ClampF(forward.Z, -1.0, 1.0)));
  let eulerPitch: Float = Quaternion.ToEulerAngles(nativeOrientation).Pitch;
  if AbsF(-fromForward - eulerPitch) < AbsF(fromForward - eulerPitch) {
    return -fromForward;
  }
  return fromForward;
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

public func IFP_CaptureBaseline(player: ref<PlayerPuppet>, camera: ref<FPPCameraComponent>) -> Bool {
  if !IsDefined(player) || !IsDefined(camera) { return false; }
  if player.m_ifpOwnsCamera { return true; }
  player.m_ifpBaselinePos = camera.GetLocalPosition();
  player.m_ifpBaselineRot = camera.GetLocalOrientation();
  player.m_ifpBaselineFov = camera.GetFOV();
  player.m_ifpOwnsCamera = true;
  return true;
}

public func IFP_ReleaseCamera(player: ref<PlayerPuppet>, camera: ref<FPPCameraComponent>) -> Void {
  if !IsDefined(player) { return; }
  if player.m_ifpOwnsCamera && IsDefined(camera) {
    camera.SetLocalTransform(player.m_ifpBaselinePos, player.m_ifpBaselineRot);
  }
  player.m_ifpOwnsCamera = false;
  player.m_ifpBaselinePos = new Vector4(0.0, 0.0, 0.0, 0.0);
  Quaternion.SetIdentity(player.m_ifpBaselineRot);
  player.m_ifpBaselineFov = 0.0;
}

public func IFP_ApplyCamera(player: ref<PlayerPuppet>, delta: Float) -> Void {
  if !IsDefined(player) { return; }
  let camera = player.GetFPPCameraComponent();
  if !IsDefined(camera) {
    IFP_ReleaseCamera(player, camera);
    return;
  }
  if IFP_IsBlocked(player) {
    IFP_ReleaseCamera(player, camera);
    return;
  }

  let actualLocalOrientation: Quaternion = camera.GetLocalOrientation();
  let nativePitch: Float = IFP_ReadNativePitch(camera, actualLocalOrientation);
  let hasWeapon: Bool = IFP_IsArmed(player);
  let bodyBlend: Float = IFP_UpdateBodyFade(player, hasWeapon, delta);
  let bodyFadeActive: Bool = AbsF(bodyBlend - player.m_ifpBodyBlendTarget) > 0.001;
  if !player.m_ifpFreeLook && !player.m_ifpReturning && !bodyFadeActive && nativePitch > -30.0 {
    IFP_ReleaseCamera(player, camera);
    return;
  }
  if !IFP_CaptureBaseline(player, camera) { return; }

  let free = EvaluateFreeLook(player.m_ifpFreeYaw, player.m_ifpFreePitch, hasWeapon);
  let effectiveNativePitch: Float = nativePitch
    + ((player.m_ifpFreeLook || player.m_ifpReturning) ? free.pitch : 0.0);
  let body = EvaluateBody(effectiveNativePitch, IFP_IsCrouching(player));
  body.forward *= bodyBlend;
  body.vertical *= bodyBlend;
  body.pitch *= bodyBlend;
  let curve = NativeCameraCurve.OffsetToReference(nativePitch, effectiveNativePitch, player.m_ifpBaselineFov);
  let positionCompensation: Float = IFP_FIXED_FOV_POSITION_COMPENSATION();
  let bodySpaceMotion: Vector4 = IFP_RotatePitchVector(
    -nativePitch,
    new Vector4(
      0.0,
      curve.forward * positionCompensation,
      curve.vertical * positionCompensation,
      0.0
    )
  );
  let freeMotion: Vector4 = IFP_RotatePitchVector(
    -nativePitch,
    new Vector4(0.0, free.forward, free.vertical, 0.0)
  );
  let bodyPosition: Vector4 = new Vector4(
    body.lateral,
    body.forward,
    body.vertical,
    0.0
  );
  if player.m_ifpFreeLook || player.m_ifpReturning {
    bodyPosition = IFP_RotatePitchVector(effectiveNativePitch - nativePitch, bodyPosition);
  }
  let position: Vector4 = player.m_ifpBaselinePos;
  position.X += bodyPosition.X + free.lateral;
  position.Y += bodyPosition.Y + freeMotion.Y + bodySpaceMotion.Y;
  position.Z += bodyPosition.Z + freeMotion.Z + bodySpaceMotion.Z;

  let orientationNativePitch: Float = nativePitch;
  let cancelNativePitch: Quaternion = IFP_AxisAngle(
    new Vector4(1.0, 0.0, 0.0, 0.0),
    Deg2Rad(-orientationNativePitch)
  );
  let yaw: Quaternion = IFP_AxisAngle(
    new Vector4(0.0, 0.0, 1.0, 0.0),
    Deg2Rad(free.yaw)
  );
  let pitch: Quaternion = IFP_AxisAngle(
    new Vector4(1.0, 0.0, 0.0, 0.0),
    Deg2Rad(orientationNativePitch + body.pitch + free.pitch)
  );
  let roll: Quaternion = IFP_AxisAngle(
    new Vector4(0.0, 1.0, 0.0, 0.0),
    Deg2Rad(free.roll)
  );
  let orientation: Quaternion = IFP_QuatMul(
    IFP_QuatMul(
      IFP_QuatMul(
        IFP_QuatMul(cancelNativePitch, yaw),
        pitch
      ),
      roll
    ),
    player.m_ifpBaselineRot
  );
  camera.SetLocalTransform(position, orientation);

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
  let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGame()));
  let delta: Float = ClampF(now - this.m_ifpLastTickTime, 0.001, 0.10);
  this.m_ifpLastTickTime = now;
  IFP_ApplyCamera(this, delta);
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
  this.m_ifpOwnsCamera = false;
  this.m_ifpBaselinePos = new Vector4(0.0, 0.0, 0.0, 0.0);
  Quaternion.SetIdentity(this.m_ifpBaselineRot);
  this.m_ifpBaselineFov = 0.0;
  this.m_ifpLastTickTime = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGame()));
  IFP_BindBlackboard(this);
  let delay = GameInstance.GetDelaySystem(this.GetGame());
  if IsDefined(delay) {
    // OnTakeControl can fire again during a save/load handoff.  Retire the
    // previous TickOnEvent before installing the new one so camera work never
    // doubles up for a single frame.
    delay.CancelTick(this.m_ifpTickID);
    this.m_ifpTickID = GetInvalidDelayID();
  }
  if this.m_ifpAttached && IsDefined(delay) {
    let tick = new IFPCameraTickEvent();
    // -1.0 keeps one event alive for the attached lifetime; OnDetach cancels
    // it explicitly, so no per-frame global scan or orphaned callback exists.
    this.m_ifpTickID = delay.TickOnEvent(this, tick, -1.0);
  }
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  this.RegisterInputListener(this, n"FreeLook");
  this.RegisterInputListener(this, n"Vision_Hold_Button");
  this.RegisterInputListener(this, n"CameraMouseX");
  this.RegisterInputListener(this, n"CameraMouseY");
  this.RegisterInputListener(this, n"CameraX");
  this.RegisterInputListener(this, n"CameraY");
  this.RegisterInputListener(this, n"right_stick_x");
  this.RegisterInputListener(this, n"right_stick_y");
  this.RegisterInputListener(this, n"mouse_left");
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let name: CName = ListenerAction.GetName(action);
  if Equals(name, n"FreeLook") || Equals(name, n"Vision_Hold_Button") || Equals(name, n"CameraFreeLook") {
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
  IFP_ReleaseCamera(this, this.GetFPPCameraComponent());
  this.m_ifpAttached = false;
  this.m_ifpFreeLook = false;
  this.m_ifpReturning = false;
  let delay = GameInstance.GetDelaySystem(this.GetGame());
  if IsDefined(delay) {
    delay.CancelTick(this.m_ifpTickID);
  }
  this.m_ifpTickID = GetInvalidDelayID();
  this.m_ifpBlackboard = null;
  this.m_ifpLastTickTime = 0.0;
  return wrappedMethod();
}
