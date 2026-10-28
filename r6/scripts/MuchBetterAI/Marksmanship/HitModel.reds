module MuchBetterAI.Marksmanship

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Footwork.*
import MuchBetterAI.Nerve.*

@addField(NPCPuppet)
let m_mbaiLastShotAtPlayerSim: Float;

@addField(NPCPuppet)
let m_mbaiAcquisitionStartSim: Float;

@addField(NPCPuppet)
let m_mbaiLastExposureSim: Float;

@addField(NPCPuppet)
let m_mbaiLastExposurePos: Vector4;

@addField(NPCPuppet)
let m_mbaiLastTrackingSampleSim: Float;

@addField(NPCPuppet)
let m_mbaiLastTrackedVelocity: Vector4;

@addField(NPCPuppet)
let m_mbaiDirectionBreakUntil: Float;

@addField(PlayerPuppet)
let m_mbaiShotBudgetWindowSim: Float;

@addField(PlayerPuppet)
let m_mbaiShotBudgetSpent: Int32;

@addMethod(TargetShootComponent)
private final func MBAI_TargetVelocity(player: ref<PlayerPuppet>, out vehicleFastHitCeiling: Float, out vehicleMounted: Bool, out vehicleSpeed: Float) -> Vector4 {
  vehicleFastHitCeiling = 1.0;
  vehicleMounted = false;
  vehicleSpeed = 0.0;
  let velocity: Vector4 = player.GetVelocity();
  let vehicle: ref<VehicleObject> = player.GetMountedVehicle();
  if !IsDefined(vehicle) {
    return velocity;
  };
  vehicleMounted = true;
  let vehicleVelocity: Vector4 = vehicle.GetLinearVelocity();
  vehicleSpeed = Vector4.Length2D(vehicleVelocity);
  if vehicleSpeed <= 6.0 {
    return velocity;
  };
  if IsDefined(vehicle as BikeObject) {
    vehicleFastHitCeiling = ClampF(40.0 / 100.0, 0.0, 1.0);
  } else {
    vehicleFastHitCeiling = ClampF(20.0 / 100.0, 0.0, 1.0);
  };
  return vehicleVelocity;
}

@addMethod(TargetShootComponent)
private final func MBAI_VehicleHitCeiling(speed: Float, vehicleFastHitCeiling: Float) -> Float {
  if vehicleFastHitCeiling >= 1.0 || speed <= 6.0 {
    return 1.0;
  };
  let progress: Float = ClampF((speed - 6.0) / (28.0 - 6.0), 0.0, 1.0);
  return LerpF(progress, 1.0, vehicleFastHitCeiling);
}

@addMethod(TargetShootComponent)
private final func MBAI_LateralSpeed(weaponOwner: ref<GameObject>, target: ref<GameObject>, targetVelocity: Vector4) -> Float {
  let toTarget: Vector4 = Vector4.Normalize(target.GetWorldPosition() - weaponOwner.GetWorldPosition());
  let lateral: Vector4 = targetVelocity - toTarget * Vector4.Dot(targetVelocity, toTarget);
  return Vector4.Length(lateral);
}

@addMethod(TargetShootComponent)
private final func MBAI_PlayerMotion(weaponOwner: ref<GameObject>, target: ref<GameObject>, skill: Float, targetVelocity: Vector4) -> Float {
  let speed: Float = this.MBAI_LateralSpeed(weaponOwner, target, targetVelocity);
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  let locomotion: gamePSMLocomotionStates = IsDefined(player) ? PlayerPuppet.GetCurrentLocomotionState(player) : gamePSMLocomotionStates.Default;
  if StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.PlayerJustDodged")
     || StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.PlayerJustDashed")
     || StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.PlayerJustAirDashed")
     || StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.PlayerJustDodgedLocomotionBuffer") {
    return skill >= 3.5 ? 0.62 : 0.42;
  };
  if Equals(locomotion, gamePSMLocomotionStates.Kereznikov) {
    return skill >= 3.5 ? 0.70 : 0.50;
  };
  if Equals(locomotion, gamePSMLocomotionStates.Dodge) || Equals(locomotion, gamePSMLocomotionStates.DodgeAir) || Equals(locomotion, gamePSMLocomotionStates.CrouchDodge) {
    return skill >= 3.5 ? 0.65 : 0.45;
  };
  if Equals(locomotion, gamePSMLocomotionStates.Jump) || Equals(locomotion, gamePSMLocomotionStates.Slide) || Equals(locomotion, gamePSMLocomotionStates.SlideFall) {
    return skill >= 3.0 ? 0.75 : 0.55;
  };
  if speed < 1.0 {
    return 1.05;
  };
  if speed < 3.5 {
    return skill >= 3.0 ? 0.92 : 0.76;
  };
  return skill >= 3.5 ? 0.78 : 0.55;
}

@addMethod(TargetShootComponent)
private final func MBAI_TargetPosture(target: ref<GameObject>, hasSecondaryLOS: Bool) -> Float {
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  if !IsDefined(player) {
    return 1.0;
  };
  let bb: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
  if !IsDefined(bb) {
    return 1.0;
  };
  let usingCover: Bool = bb.GetBool(GetAllBlackboardDefs().PlayerStateMachine.UsingCover);
  let locomotion: gamePSMLocomotionStates = PlayerPuppet.GetCurrentLocomotionState(player);
  let crouching: Bool = Equals(locomotion, gamePSMLocomotionStates.Crouch) || Equals(locomotion, gamePSMLocomotionStates.CrouchSprint) || Equals(locomotion, gamePSMLocomotionStates.CrouchDodge);
  if usingCover && crouching && !hasSecondaryLOS {
    return 0.45;
  };
  if usingCover && !hasSecondaryLOS {
    return 0.58;
  };
  if usingCover {
    return crouching ? 0.75 : 0.85;
  };
  if crouching {
    return 0.92;
  };
  return 1.0;
}

@addMethod(TargetShootComponent)
private final func MBAI_ShooterStability(npc: ref<NPCPuppet>, skill: Float) -> Float {
  let speed: Float = Vector4.Length2D(npc.GetVelocity());
  let stable: Float = 1.0;
  if speed > 5.5 {
    stable = skill >= 3.5 ? 0.68 : 0.48;
  } else {
    if speed > 2.5 {
      stable = skill >= 3.0 ? 0.82 : 0.65;
    };
  };
  if AIActionHelper.IsCurrentlyInCoverAttackAction(npc) {
    stable += 0.14;
  };
  if AIActionHelper.IsCurrentlyCrouching(npc) {
    stable += 0.08;
  };
  return ClampF(stable, 0.35, 1.15);
}

@addMethod(TargetShootComponent)
private final func MBAI_CamoPressure(weaponOwner: ref<GameObject>, target: ref<GameObject>) -> Float {
  if !StatusEffectSystem.ObjectHasStatusEffectWithTag(target, n"ActiveCamo") {
    return 1.0;
  };
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(weaponOwner.GetGame());
  if statsSystem.GetStatValue(Cast<StatsObjectID>(weaponOwner.GetEntityID()), gamedataStatType.HasThermovision) >= 1.0 {
    return 1.0;
  };
  return 0.45;
}

@addMethod(TargetShootComponent)
private final func MBAI_DoctrinePrecision(npc: ref<NPCPuppet>, weaponType: gamedataItemType) -> Float {
  let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
  let scalar: Float;
  switch group {
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.LockAndHold:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.WallAroundRunner:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      scalar = 1.12;
      break;
    case MBAI_DoctrineGroup.MeasuredExecution:
      scalar = 1.16;
      break;
    case MBAI_DoctrineGroup.RelentlessAdvance:
      scalar = 1.05;
      break;
    case MBAI_DoctrineGroup.WeekendWarriors:
    case MBAI_DoctrineGroup.RaiderStrike:
      scalar = 1.02;
      break;
    case MBAI_DoctrineGroup.ChromeRush:
    case MBAI_DoctrineGroup.BullCharge:
    case MBAI_DoctrineGroup.CowardsSwarm:
      scalar = 0.90;
      break;
    case MBAI_DoctrineGroup.BladeWave:
    case MBAI_DoctrineGroup.BrotherhoodPush:
      scalar = 0.92;
      break;
    case MBAI_DoctrineGroup.Overwhelm:
      scalar = 1.05;
      break;
    default:
      scalar = 1.0;
  };
  if Equals(weaponType, gamedataItemType.Wea_LightMachineGun) || Equals(weaponType, gamedataItemType.Wea_HeavyMachineGun) {
    return ClampF(scalar - 0.10, 0.70, 1.18);
  };
  return ClampF(scalar, 0.70, 1.18);
}

@addMethod(TargetShootComponent)
private final func MBAI_Acquisition(npc: ref<NPCPuppet>, target: ref<GameObject>, skill: Float, now: Float, out retained: Bool) -> Float {
  retained = false;
  let graceScale: Float = ClampF(1.0, 0.0, 2.0);
  if graceScale <= 0.0 {
    return 1.0;
  };
  let reaction: Float = MBAI_FactionReactionMult(npc);
  let baseDuration: Float = ClampF((2.8 - skill * 0.45) * reaction, 0.15, 3.0);
  let duration: Float = baseDuration * graceScale;
  let floor: Float = ClampF(0.35 + skill * 0.12, 0.40, 0.92);
  let visibleDuration: Float = 0.0;
  let visible: Bool = npc.GetSourceShootComponent().GetContinuousLineOfSightToTarget(target, visibleDuration);
  let targetPos: Vector4 = target.GetWorldPosition();
  let exposureAge: Float = npc.m_mbaiLastExposureSim > 0.0 ? now - npc.m_mbaiLastExposureSim : 99.0;
  let samePosition: Bool = npc.m_mbaiLastExposureSim > 0.0 && Vector4.Distance(npc.m_mbaiLastExposurePos, targetPos) < 2.75;
  let recentPosition: Bool = samePosition && exposureAge < 4.0;
  let newlyVisible: Bool = !visible || (exposureAge > 0.35 && visibleDuration + 0.10 < exposureAge);
  if npc.m_mbaiAcquisitionStartSim <= 0.0 || !recentPosition || (newlyVisible && exposureAge > 0.35) {
    let retainedProgress: Float = recentPosition ? ClampF(0.18 + skill * 0.08, 0.20, 0.50) : 0.0;
    retained = retainedProgress > 0.0;
    npc.m_mbaiAcquisitionStartSim = now - duration * retainedProgress;
    MBADebug("HitModel", s"acquisition npc=\(ToString(npc.GetEntityID())) rarity=\(npc.GetNPCRarity()) skill=\(skill) retained=\(retainedProgress)");
  };
  let progress: Float = MaxF(ClampF((now - npc.m_mbaiAcquisitionStartSim) / duration, 0.0, 1.0), ClampF(visibleDuration / duration, 0.0, 1.0));
  if visible {
    npc.m_mbaiLastExposurePos = targetPos;
    npc.m_mbaiLastExposureSim = now;
  };
  return LerpF(progress, floor, 1.0);
}

@addMethod(TargetShootComponent)
private final func MBAI_PredictionConfidence(npc: ref<NPCPuppet>, target: ref<GameObject>, skill: Float, now: Float, targetVelocity: Vector4, movingVehicleTarget: Bool) -> Float {
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  if !IsDefined(player) {
    return 1.0;
  };
  let velocity: Vector4 = targetVelocity;
  let tracked: TrackedLocation;
  if !movingVehicleTarget && TargetTrackingExtension.GetTrackedLocation(npc, target, tracked) && tracked.visible {
    velocity = tracked.speed;
  };
  let speed: Float = Vector4.Length2D(velocity);
  let dt: Float = npc.m_mbaiLastTrackingSampleSim > 0.0 ? now - npc.m_mbaiLastTrackingSampleSim : 99.0;
  if dt > 0.05 && dt < 1.5 {
    let prevSpeed: Float = Vector4.Length2D(npc.m_mbaiLastTrackedVelocity);
    if speed > 1.0 && prevSpeed > 1.0 {
      let curDir: Vector4 = velocity / MaxF(Vector4.Length(velocity), 0.1);
      let prevDir: Vector4 = npc.m_mbaiLastTrackedVelocity / MaxF(Vector4.Length(npc.m_mbaiLastTrackedVelocity), 0.1);
      let dot: Float = Vector4.Dot(curDir, prevDir);
      if dot < 0.30 {
        npc.m_mbaiDirectionBreakUntil = now + 0.80;
      } else {
        if dot < 0.65 {
          npc.m_mbaiDirectionBreakUntil = MaxF(npc.m_mbaiDirectionBreakUntil, now + 0.45);
        };
      };
    };
  };
  npc.m_mbaiLastTrackedVelocity = velocity;
  npc.m_mbaiLastTrackingSampleSim = now;
  if npc.m_mbaiDirectionBreakUntil > now {
    return skill >= 3.5 ? 0.82 : 0.70;
  };
  if speed < 1.0 {
    return 1.06;
  };
  if speed > 4.0 {
    let toTarget: Vector4 = Vector4.Normalize(target.GetWorldPosition() - npc.GetWorldPosition());
    let lateralVelocity: Vector4 = velocity - toTarget * Vector4.Dot(velocity, toTarget);
    let lateral: Float = Vector4.Length(lateralVelocity);
    if lateral < speed * 0.35 {
      return skill >= 3.0 ? 1.04 : 0.96;
    };
  };
  return 1.0;
}

@addMethod(TargetShootComponent)
private final func MBAI_StressConfidence(npc: ref<NPCPuppet>, target: ref<GameObject>, weaponType: gamedataItemType, skill: Float, now: Float) -> Float {
  let result: Float = 1.0;
  let distance: Float = Vector4.Distance(npc.GetWorldPosition(), target.GetWorldPosition());
  let rarity: gamedataNPCRarity = npc.GetNPCRarity();
  if MBAI_ShakenBonus(npc, now, 1.0) > 0.0 {
    result *= skill >= 3.0 ? 0.88 : 0.76;
  };
  let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(npc.GetGame()).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
  if IsDefined(nerve) {
    if nerve.HasBroken(npc.GetEntityID()) {
      result *= 0.62;
    } else {
      if nerve.IsCurrentLeader(npc.GetEntityID()) {
        result *= 1.07;
      };
    };
  };
  if Equals(rarity, gamedataNPCRarity.Officer) || Equals(rarity, gamedataNPCRarity.Elite) || Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
    result *= 1.05;
  };
  if distance < 7.0 {
    if Equals(weaponType, gamedataItemType.Wea_Shotgun) || Equals(weaponType, gamedataItemType.Wea_ShotgunDual) {
      result *= 1.08;
    } else {
      if Equals(weaponType, gamedataItemType.Wea_SubmachineGun) || Equals(weaponType, gamedataItemType.Wea_Handgun) || Equals(weaponType, gamedataItemType.Wea_Revolver) {
        result *= 1.00;
      } else {
        result *= skill >= 3.0 ? 0.92 : 0.78;
      };
    };
  };
  return ClampF(result, 0.45, 1.15);
}

@addMethod(TargetShootComponent)
private final func MBAI_SquadPressure(player: ref<PlayerPuppet>, now: Float) -> Float {
  let pressure: Float = 1.0;
  if player.m_mbaiShotBudgetSpent > 0 && now - player.m_mbaiShotBudgetWindowSim > 0.85 {
    player.m_mbaiShotBudgetSpent = 0;
  };
  if player.m_mbaiShotBudgetSpent >= 2 {
    let statsData = GameInstance.GetStatsDataSystem(player.GetGame());
    if !IsDefined(statsData) {
      return 1.0;
    };
    let difficulty: gameDifficulty = statsData.GetDifficulty();
    if player.m_mbaiShotBudgetSpent == 2 {
      switch difficulty {
        case gameDifficulty.Story: pressure = 0.38; break;
        case gameDifficulty.Easy: pressure = 0.55; break;
        case gameDifficulty.VeryHard: pressure = 0.90; break;
        default: pressure = 0.78;
      };
    } else {
      switch difficulty {
        case gameDifficulty.Story: pressure = 0.16; break;
        case gameDifficulty.Easy: pressure = 0.28; break;
        case gameDifficulty.VeryHard: pressure = 0.72; break;
        default: pressure = 0.52;
      };
    };
  };
  return LerpF(ClampF(1.0, 0.0, 1.0), 1.0, pressure);
}

@addMethod(TargetShootComponent)
private final func MBAI_StampSquadPressure(player: ref<PlayerPuppet>, now: Float) -> Void {
  if player.m_mbaiShotBudgetSpent == 0 || now - player.m_mbaiShotBudgetWindowSim > 0.85 {
    player.m_mbaiShotBudgetWindowSim = now;
    player.m_mbaiShotBudgetSpent = 0;
  };
  player.m_mbaiShotBudgetSpent += 1;
}

@addMethod(TargetShootComponent)
private final func MBAI_SensoryPenalty(npc: ref<NPCPuppet>, weaponOwner: ref<GameObject>, visibilityThresholdCoefficient: Float, visibility: Float, visionBlockers: Float) -> Float {
  if StatusEffectSystem.ObjectHasStatusEffectWithTag(npc, n"Blind") {
    return 0.0;
  };
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(weaponOwner.GetGame());
  if !IsDefined(statsSystem) {
    return 0.0;
  };
  let accuracy: Float = statsSystem.GetStatValue(Cast<StatsObjectID>(weaponOwner.GetEntityID()), gamedataStatType.Accuracy);
  if accuracy <= 0.0 {
    return 0.0;
  };
  let visibilityPenalty: Float = visibilityThresholdCoefficient > 0.0 ? 1.0 / MaxF(visibility, 1.0) : 1.0;
  let visionBlockerPenalty: Float = 1.0 / MaxF(visionBlockers, 1.0);
  let accuracyPenalty: Float = ClampF(accuracy, 0.0, 1.0);
  return visibilityPenalty * visionBlockerPenalty * accuracyPenalty;
}

@addMethod(TargetShootComponent)
private final func MBAI_ShotQuality(npc: ref<NPCPuppet>, weaponOwner: ref<GameObject>, target: ref<GameObject>, weaponRecord: ref<WeaponItem_Record>, weaponType: gamedataItemType, skill: Float, grace: Float, hasSecondaryLOS: Bool, visibilityThresholdCoefficient: Float, visibility: Float, visionBlockers: Float, rangeBand: Float, targetVelocity: Vector4, fullMode: Bool) -> Float {
  let quality: Float = rangeBand
    * this.MBAI_PlayerMotion(weaponOwner, target, skill, targetVelocity)
    * this.MBAI_TargetPosture(target, hasSecondaryLOS)
    * this.MBAI_ShooterStability(npc, skill)
    * this.MBAI_CamoPressure(weaponOwner, target)
    * this.MBAI_DoctrinePrecision(npc, weaponType)
    * MBAI_TemperamentShotDiscipline(npc)
    * grace;
  if visibilityThresholdCoefficient > 0.0 && visibility <= 0.0 {
    return 0.0;
  };
  let visionPenalty: Float = fullMode ? 1.0 : ClampF(visionBlockers, 1.0, 4.0);
  return ClampF(quality / ClampF(this.GetCoverCoefficient(weaponOwner, weaponRecord, target), 0.50, 2.50) / visionPenalty, 0.0, 1.35);
}

@addMethod(TargetShootComponent)
private final func MBAI_StructuralShotAllowed(weaponOwner: ref<GameObject>, weapon: wref<WeaponObject>, target: ref<GameObject>) -> Bool {
  let gameInstance: GameInstance = target.GetGame();
  if target.IsPlayer() && RPGManager.IsTechPierceEnabled(weaponOwner.GetGame(), weaponOwner, weapon.GetItemID()) {
    let scripted: ref<ScriptedPuppet> = weaponOwner as ScriptedPuppet;
    if IsDefined(scripted) {
      let visibilityCollisionToTargetDist: Float = scripted.GetSenses().GetVisibilityTraceEndToAgentDist(target);
      if visibilityCollisionToTargetDist > 0.0 && visibilityCollisionToTargetDist < 1000000000.0 {
        return false;
      };
    };
  };
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(gameInstance);
  if !IsDefined(statsSystem) {
    return false;
  };
  let accuracy: Float = statsSystem.GetStatValue(Cast<StatsObjectID>(weaponOwner.GetEntityID()), gamedataStatType.Accuracy);
  if accuracy == 0.0 {
    return false;
  };
  if this.GetDistanceCoefficient(weapon, target.GetWorldPosition()) == 0.0 {
    return false;
  };
  return true;
}

@addMethod(TargetShootComponent)
private final func MBAI_WeaponHitScale(weaponType: gamedataItemType) -> Float {
  let weaponScale: Float = 1.0;
  switch weaponType {
    case gamedataItemType.Wea_LightMachineGun:
    case gamedataItemType.Wea_HeavyMachineGun:
      weaponScale = 0.78;
      break;
    case gamedataItemType.Wea_SubmachineGun:
      weaponScale = 0.82;
      break;
    case gamedataItemType.Wea_AssaultRifle:
      weaponScale = 0.92;
      break;
    case gamedataItemType.Wea_Shotgun:
    case gamedataItemType.Wea_ShotgunDual:
      weaponScale = 1.10;
      break;
    case gamedataItemType.Wea_SniperRifle:
    case gamedataItemType.Wea_PrecisionRifle:
      weaponScale = 1.05;
      break;
    default:
      break;
  };
  return weaponScale;
}

@addMethod(TargetShootComponent)
private final func MBAI_DifficultyHitScale(target: ref<GameObject>) -> Float {
  let difficultyScale: Float = 1.0;
  let statsData = GameInstance.GetStatsDataSystem(target.GetGame());
  if !IsDefined(statsData) {
    return difficultyScale;
  };
  switch statsData.GetDifficulty() {
    case gameDifficulty.Story: difficultyScale = 0.70; break;
    case gameDifficulty.Easy: difficultyScale = 0.85; break;
    case gameDifficulty.VeryHard: difficultyScale = 1.12; break;
    default: break;
  };
  return difficultyScale;
}

@addMethod(TargetShootComponent)
private final func MBAI_BaselineHitChance(target: ref<GameObject>, distance: Float, skill: Float, weaponType: gamedataItemType, rangeBand: Float) -> Float {
  let skillNorm: Float = ClampF((skill - 1.0) / 3.5, 0.0, 1.0);
  let closeBonus: Float = distance < 7.0 && rangeBand >= 0.70 ? (1.0 - ClampF(distance / 7.0, 0.0, 1.0)) * 0.08 : 0.0;
  let baseline: Float = (0.18 + rangeBand * 0.34 + skillNorm * 0.08 + closeBonus)
    * this.MBAI_WeaponHitScale(weaponType)
    * this.MBAI_DifficultyHitScale(target)
    * ClampF(1.6, 0.5, 5.0);
  return ClampF(baseline, 0.0, 0.90);
}

@addMethod(TargetShootComponent)
private final func MBAI_BoundedMitigation(quality: Float, rangeBand: Float, skill: Float, sensoryPenalty: Float) -> Float {
  let skillNorm: Float = ClampF((skill - 1.0) / 3.5, 0.0, 1.0);
  let floor: Float = LerpF(skillNorm, 0.35, 0.62);
  return ClampF(quality / MaxF(rangeBand, 0.20), MinF(floor, sensoryPenalty), 1.20);
}

@addMethod(TargetShootComponent)
private final func MBAI_RangeHitFloor(rangeBand: Float) -> Float {
  if rangeBand >= 0.45 { return 0.15; };
  if rangeBand >= 0.25 { return 0.10; };
  return 0.08;
}

@addMethod(TargetShootComponent)
private final func MBAI_RangeHitCeiling(rangeBand: Float) -> Float {
  if rangeBand >= 0.95 { return 0.90; };
  if rangeBand >= 0.80 { return 0.84; };
  if rangeBand >= 0.75 { return 0.80; };
  if rangeBand >= 0.70 { return 0.74; };
  if rangeBand >= 0.55 { return 0.62; };
  if rangeBand >= 0.45 { return 0.55; };
  if rangeBand >= 0.35 { return 0.42; };
  if rangeBand >= 0.25 { return 0.32; };
  return 0.22;
}

@addMethod(TargetShootComponent)
private final func MBAI_DirectHitChance(baseChance: Float, mitigation: Float, rangeBand: Float, sensoryPenalty: Float) -> Float {
  let floor: Float = this.MBAI_RangeHitFloor(rangeBand) * sensoryPenalty;
  let ceiling: Float = this.MBAI_RangeHitCeiling(rangeBand);
  return MinF(ClampF(baseChance * mitigation, floor, ceiling), sensoryPenalty);
}

@wrapMethod(TargetShootComponent)
private final func ShouldBeHit(weaponOwner: ref<GameObject>, weapon: wref<WeaponObject>, weaponRecord: ref<WeaponItem_Record>, visibilityThresholdCoefficient: Float) -> Bool {
  let hitModelMode: Int32 = 2;
  let fullMode: Bool = hitModelMode >= 2;
  let target: ref<GameObject> = this.GetGameObject();
  let player: ref<PlayerPuppet> = target as PlayerPuppet;
  if !IsDefined(player) {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  let npc: ref<NPCPuppet> = weaponOwner as NPCPuppet;
  if !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(target.GetGame()));
  npc.m_mbaiLastShotAtPlayerSim = now;
  if hitModelMode <= 0 {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  let weaponEvolution: gamedataWeaponEvolution = weaponRecord.Evolution().Type();
  if Equals(weaponEvolution, gamedataWeaponEvolution.Smart) {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  if !IsDefined(weaponOwner.GetSourceShootComponent()) {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  if MBAI_ISAIInstalled() {
    return wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  let vehicleFastHitCeiling: Float = 1.0;
  let vehicleMounted: Bool = false;
  let vehicleSpeed: Float = 0.0;
  let targetVelocity: Vector4 = this.MBAI_TargetVelocity(player, vehicleFastHitCeiling, vehicleMounted, vehicleSpeed);
  let movingVehicleTarget: Bool = vehicleMounted && vehicleSpeed > 6.0;
  let vehicleHitCeiling: Float = this.MBAI_VehicleHitCeiling(vehicleSpeed, vehicleFastHitCeiling);
  let skill: Float = MBAI_TierSkillLevel(npc);
  let weaponType: gamedataItemType = RPGManager.GetItemType(weapon.GetItemID());
  let distance: Float = Vector4.Distance(weapon.GetWorldPosition(), target.GetWorldPosition());
  let rangeBand: Float = MBAI_WeaponBand(distance, weaponType);
  let hasSecondaryLOS: Bool = weaponOwner.GetSourceShootComponent().CanSeeSecondaryPointOfTarget(target);
  let retainedAcquisition: Bool = false;
  let grace: Float = this.MBAI_Acquisition(npc, target, skill, now, retainedAcquisition);
  let vanillaHit: Bool = false;
  if hitModelMode < 2 {
    vanillaHit = wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  };
  let visibility: Float = this.GetVisibilityCoefficient(weaponOwner, weapon, target, visibilityThresholdCoefficient);
  let visionBlockers: Float = this.GetVisionBlockersCoefficient(weaponOwner, target);
  let sensoryPenalty: Float = 1.0;
  let quality: Float = this.MBAI_ShotQuality(npc, weaponOwner, target, weaponRecord, weaponType, skill, grace, hasSecondaryLOS, visibilityThresholdCoefficient, visibility, visionBlockers, rangeBand, targetVelocity, fullMode);
  let prediction: Float = this.MBAI_PredictionConfidence(npc, target, skill, now, targetVelocity, movingVehicleTarget);
  let stress: Float = this.MBAI_StressConfidence(npc, target, weaponType, skill, now);
  if fullMode {
    sensoryPenalty = this.MBAI_SensoryPenalty(npc, weaponOwner, visibilityThresholdCoefficient, visibility, visionBlockers);
    quality *= sensoryPenalty;
  };
  MBAI_RecordShotOpportunity(npc, ClampF(quality / MaxF(grace, 0.35) * prediction * stress, 0.0, 1.35), now);
  let intentMul: Float = MBAI_IntentShotQuality(npc, now);
  quality *= prediction * stress * intentMul;
  if MBAI_IsSuppressing(npc, now) {
    quality *= 0.3;
  };
  let pressure: Float = hitModelMode >= 2 ? this.MBAI_SquadPressure(player, now) : 1.0;
  quality *= pressure;
  let traceShot: Bool = false;
  if traceShot {
    MBATrace("HitModel", s"roll npc=\(ToString(npc.GetEntityID())) weaponID=\(ToString(weapon.GetEntityID())) sim=\(now) rarity=\(npc.GetNPCRarity()) weapon=\(weaponType) filter=\(hitModelMode < 2) vanilla=\(vanillaHit) q=\(quality) sensory=\(sensoryPenalty) pred=\(prediction) stress=\(stress) intent=\(ToString(MBAI_GetIntent(npc, now))) intentMul=\(intentMul) budget=\(pressure) spent=\(player.m_mbaiShotBudgetSpent) retained=\(retainedAcquisition) los=\(hasSecondaryLOS) vehicleMounted=\(vehicleMounted) vehicleActive=\(movingVehicleTarget) vehicleSpeed=\(vehicleSpeed) vehicleCap=\(vehicleHitCeiling)");
  };
  if quality <= 0.0 {
    if traceShot {
      MBATrace("HitModel", "blocked quality-zero npc=" + ToString(npc.GetEntityID()));
    };
    return false;
  };
  if hitModelMode < 2 {
    if !vanillaHit {
      return false;
    };
    let filterChance: Float = ClampF(quality * ClampF(1.6, 0.5, 5.0), 0.0, 1.0);
    let filterChanceBeforeVehicle: Float = filterChance;
    filterChance = MinF(filterChance, vehicleHitCeiling);
    if RandF() <= filterChance {
      if traceShot {
        MBATrace("HitModel", s"filter accepted rarity=\(npc.GetNPCRarity()) skill=\(skill) quality=\(quality) beforeVehicle=\(filterChanceBeforeVehicle) chance=\(filterChance)");
      };
      return true;
    };
    if traceShot {
      MBATrace("HitModel", s"quality miss rarity=\(npc.GetNPCRarity()) skill=\(skill) quality=\(quality) beforeVehicle=\(filterChanceBeforeVehicle) chance=\(filterChance)");
    };
    return false;
  };
  if !this.MBAI_StructuralShotAllowed(weaponOwner, weapon, target) {
    return false;
  };
  let baseChance: Float = this.MBAI_BaselineHitChance(target, distance, skill, weaponType, rangeBand);
  let mitigation: Float = this.MBAI_BoundedMitigation(quality, rangeBand, skill, sensoryPenalty);
  let chance: Float = this.MBAI_DirectHitChance(baseChance, mitigation, rangeBand, sensoryPenalty);
  let chanceBeforeVehicle: Float = chance;
  chance = MinF(chance, vehicleHitCeiling);
  if traceShot {
    MBATrace("HitModel", s"direct rarity=\(npc.GetNPCRarity()) skill=\(skill) dist=\(distance) band=\(rangeBand) quality=\(quality) base=\(baseChance) mitigation=\(mitigation) rangeCap=\(this.MBAI_RangeHitCeiling(rangeBand)) beforeVehicle=\(chanceBeforeVehicle) vehicleCap=\(vehicleHitCeiling) chance=\(chance)");
  };
  if RandF() <= chance {
    this.MBAI_StampSquadPressure(player, now);
    return true;
  };
  return false;
}

@wrapMethod(AIWeapon)
public final static func Fire(weaponOwner: wref<GameObject>, weapon: wref<WeaponObject>, const timeStamp: Float, tbhCoefficient: Float, requestedTriggerMode: gamedataTriggerMode, opt targetPosition: Vector4, opt target: ref<GameObject>, opt rangedAttack: TweakDBID, opt maxSpreadOverride: Float, opt aimingDelay: Float, opt offset: Vector4, opt shouldTrackTarget: Bool, opt predictionTime: Float, opt posProviderOverride: ref<IPositionProvider>, opt muzzleOffset: Vector4, opt weaponCustomEvent: CName) -> Void {
  let forwardedAimingDelay: Float = aimingDelay;
  let forwardedProvider: ref<IPositionProvider> = posProviderOverride;
  if aimingDelay > 0.0
    && 2 > 0
    && IsDefined(weapon)
    && weapon.IsAttached() {
    let player: ref<PlayerPuppet> = target as PlayerPuppet;
    let npc: ref<NPCPuppet> = weaponOwner as NPCPuppet;
    if IsDefined(player) && IsDefined(npc) {
      let bridgeSim: Float = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
      let eligible: Bool = MBAI_EnemyEligible(npc);
      let mechanical: Bool = npc.IsMechanical();
      let sourceShoot: Bool = IsDefined(weaponOwner.GetSourceShootComponent());
      let isai: Bool = MBAI_ISAIInstalled();
      let weaponRecord: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
      let smart: Bool = Equals(weaponRecord.Evolution().Type(), gamedataWeaponEvolution.Smart);
      let vehicle: ref<VehicleObject> = player.GetMountedVehicle();
      let vehicleMounted: Bool = IsDefined(vehicle);
      let vehicleSpeed: Float = vehicleMounted ? Vector4.Length2D(vehicle.GetLinearVelocity()) : 0.0;
      let bridged: Bool = false;
      if eligible && !mechanical && sourceShoot && !smart && !isai && vehicleSpeed > 6.0 {
        forwardedProvider = IPositionProvider.CreateEntityHistoryPositionProvider(player.GetTransformHistoryComponent(), aimingDelay);
        forwardedAimingDelay = 0.0;
        bridged = true;
      };
    };
  };
  wrappedMethod(weaponOwner, weapon, timeStamp, tbhCoefficient, requestedTriggerMode, targetPosition, target, rangedAttack, maxSpreadOverride, forwardedAimingDelay, offset, shouldTrackTarget, predictionTime, forwardedProvider, muzzleOffset, weaponCustomEvent);
}
