// RelentlessLiveDismember by Cazanu - seated shooting and wounded poses.
// Mode 2 owns a pain workspot. Mode 3 owns a shooting workspot until death.
// A selected shooter never loads or transitions to the pain workspot.
module CazanuLimbSurvival

public class CLS_SeatedTickEvent extends Event {}
public class CLS_SeatedDeathRagdollEvent extends Event {
  public let attempts: Int32;
}

public class CLS_SeatedSupportReleaseEvent extends Event {
  public let target: ref<IKTargetAddEvent>;
  public let attempts: Int32;
}

@addField(NPCPuppet)
private let cls_seatedAttempted: Bool;
@addField(NPCPuppet)
private let cls_seatedStage: Int32;
@addField(NPCPuppet)
private let cls_seatedStageTime: Float;
@addField(NPCPuppet)
private let cls_seatedToken: ref<ResourceToken>;
@addField(NPCPuppet)
private let cls_seatedPendingPainToken: ref<ResourceToken>;
@addField(NPCPuppet)
private let cls_seatedRequestedTag: CName;
@addField(NPCPuppet)
private let cls_seatedOwnedTag: CName;
@addField(NPCPuppet)
private let cls_seatedRetiringTag: CName;
@addField(NPCPuppet)
private let cls_seatedPainTag: CName;
@addField(NPCPuppet)
private let cls_seatedForeignWorkspot: Bool;
@addField(NPCPuppet)
private let cls_seatedPainPath: ResRef;
@addField(NPCPuppet)
private let cls_seatedComponent: ref<WorkspotResourceComponent>;
@addField(NPCPuppet)
private let cls_seatedLookats: array<ref<LookAtAddEvent>>;
@addField(NPCPuppet)
private let cls_seatedSupportIK: ref<IKTargetAddEvent>;
@addField(NPCPuppet)
private let cls_seatedWeapon: wref<WeaponObject>;
@addField(NPCPuppet)
private let cls_seatedTarget: wref<GameObject>;
@addField(NPCPuppet)
private let cls_seatedFiring: Bool;
@addField(NPCPuppet)
private let cls_seatedHasFired: Bool;
@addField(NPCPuppet)
private let cls_seatedAmmoLogged: Bool;
@addField(NPCPuppet)
private let cls_seatedOwnsReload: Bool;
@addField(NPCPuppet)
private let cls_seatedReloadFinishing: Bool;
@addField(NPCPuppet)
private let cls_seatedReloadFailed: Bool;
@addField(NPCPuppet)
private let cls_seatedReloadEnd: Float;
@addField(NPCPuppet)
private let cls_seatedReloadVerifyBy: Float;
@addField(NPCPuppet)
private let cls_seatedReloadDuration: Float;
@addField(NPCPuppet)
private let cls_seatedReloadCount: Int32;
@addField(NPCPuppet)
private let cls_seatedOwnsWorkspot: Bool;
@addField(NPCPuppet)
private let cls_seatedSavedUpperBody: gamedataNPCUpperBodyState;
@addField(NPCPuppet)
private let cls_seatedOwnsUpperBody: Bool;
@addField(NPCPuppet)
private let cls_seatedDamageDeath: Bool;
@addField(NPCPuppet)
private let cls_seatedDeathPoseHeld: Bool;
@addField(NPCPuppet)
private let cls_seatedDeathFromSeat: Bool;
@addField(NPCPuppet)
private let cls_seatedDeathRagdollQueued: Bool;

public abstract class SeatedCombat {
  public static func Path() -> ResRef = r"cazanu\\limb_survival\\seated_shoot.workspot"
  public static func SeatTag() -> CName = n"CLS_LimbSurvivalSeat"

  // The verified seated clips keep the left wrist planted throughout their
  // loops. These owner-space points include the base rig's native IK endpoint
  // offset, which the final IK controller subtracts before solving the wrist.
  public static func SupportHandTarget(body: Int32) -> Vector3 {
    if body == 1 { return new Vector3(-0.175512, -0.462550, 0.015745); }
    return new Vector3(-0.345011, -0.450250, 0.017745);
  }

  public static func PainTag(body: Int32) -> CName {
    if body == 1 { return n"CLS_LimbSurvivalPainMale"; }
    if body == 2 { return n"CLS_LimbSurvivalPainFemale"; }
    return n"";
  }

  public static func EventTag(tags: array<CName>) -> CName {
    if ArrayContains(tags, SeatedCombat.SeatTag()) { return SeatedCombat.SeatTag(); }
    if ArrayContains(tags, SeatedCombat.PainTag(1)) { return SeatedCombat.PainTag(1); }
    if ArrayContains(tags, SeatedCombat.PainTag(2)) { return SeatedCombat.PainTag(2); }
    return n"";
  }

  // These private resources contain only the verified side-wounded idle,
  // with an infinite root sequence. Never substitute a different body rig.
  public static func PainPath(body: Int32) -> ResRef {
    if body == 1 { return r"cazanu\\limb_survival\\pain_male.workspot"; }
    if body == 2 { return r"cazanu\\limb_survival\\pain_female.workspot"; }
    return r"";
  }

  public static func IsTaggedGroundResource(token: ref<ResourceToken>, tag: CName) -> Bool {
    if !IsDefined(token) || !token.IsLoaded() { return false; }
    let resource = token.GetResource() as workWorkspotResource;
    if !IsDefined(resource) || !IsDefined(resource.workspotTree) { return false; }
    let root = resource.workspotTree.rootEntry as workSequence;
    return IsDefined(root) && root.loopInfinitely && !resource.workspotTree.frezeAtTheLastFrame_UseWithCaution
      && ArrayContains(resource.workspotTree.tags.tags, tag);
  }

  public static func IsSeatedGunType(kind: gamedataItemType) -> Bool {
    return Equals(kind, gamedataItemType.Wea_Handgun)
      || Equals(kind, gamedataItemType.Wea_Revolver)
      || Equals(kind, gamedataItemType.Wea_SubmachineGun);
  }

  // Also used before the first leg status exists, to classify the weapon
  // actually held at the wound rather than a later native replacement.
  public static func EquippedOneHandedGun(npc: wref<NPCPuppet>) -> wref<WeaponObject> {
    let empty: wref<WeaponObject>;
    if !IsDefined(npc) || !npc.IsAttached() || ArmCombat.MissingRight(npc) {
      return empty;
    }
    if GameInstance.GetStatsSystem(npc.GetGame()).GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.CanUseRightHand) <= 0.0 {
      return empty;
    }
    let gun = GameInstance.GetTransactionSystem(npc.GetGame()).GetItemInSlot(npc, t"AttachmentSlots.WeaponRight") as WeaponObject;
    if IsDefined(gun) && gun.IsAttached() && gun.IsRanged() {
      let kind = WeaponObject.GetWeaponType(gun.GetItemID());
      if SeatedCombat.IsSeatedGunType(kind) {
        return gun;
      }
    }
    return empty;
  }

  public static func Gun(npc: wref<NPCPuppet>) -> wref<WeaponObject> {
    let empty: wref<WeaponObject>;
    if !WoundTiming.Eligible(npc) { return empty; }
    return SeatedCombat.EquippedOneHandedGun(npc);
  }

  // Explain the existing gate only. Never equip a replacement or change a stat.
  public static func GunRejection(npc: wref<NPCPuppet>) -> CName {
    if !WoundTiming.Eligible(npc) { return n"shoot_unavailable_wound_ineligible"; }
    if ArmCombat.MissingRight(npc) { return n"shoot_unavailable_right_arm_missing"; }
    if GameInstance.GetStatsSystem(npc.GetGame()).GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.CanUseRightHand) <= 0.0 {
      return n"shoot_unavailable_right_hand_disabled";
    }
    let item = GameInstance.GetTransactionSystem(npc.GetGame()).GetItemInSlot(npc, t"AttachmentSlots.WeaponRight");
    if !IsDefined(item) { return n"shoot_unavailable_right_slot_empty"; }
    let gun = item as WeaponObject;
    if !IsDefined(gun) { return n"shoot_unavailable_right_item_not_weapon"; }
    if !gun.IsAttached() { return n"shoot_unavailable_right_weapon_detached"; }
    if !gun.IsRanged() { return n"shoot_unavailable_right_weapon_not_ranged"; }
    let kind = WeaponObject.GetWeaponType(gun.GetItemID());
    if !SeatedCombat.IsSeatedGunType(kind) {
      return n"shoot_unavailable_right_weapon_type_unsupported";
    }
    return n"shoot_unavailable_gun_gate_changed";
  }

  public static func SlotDiagnostic(item: wref<ItemObject>) -> String {
    if !IsDefined(item) { return "item=none weapon=false attached=false ranged=false"; }
    let gun = item as WeaponObject;
    let details = s"item=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(item.GetItemID()))) entity=\(EntityID.ToDebugString(item.GetEntityID())) attached=\(item.IsAttached()) weapon=\(IsDefined(gun))";
    if IsDefined(gun) {
      details += s" type=\(Diagnostics.Enum("gamedataItemType", EnumInt(WeaponObject.GetWeaponType(gun.GetItemID())))) ranged=\(gun.IsRanged())";
    }
    return details;
  }
}

// Read-only snapshots at two one-shot call sites: the first selected leg and
// the guarded shooting decision. No delayed/per-tick log or target mutation.
@addMethod(NPCPuppet)
public final func CLS_LogSeatedPreflight(eventName: CName) -> Void {
  if !Diagnostics.Enabled() { return; }
  let transaction = GameInstance.GetTransactionSystem(this.GetGame());
  let right = transaction.GetItemInSlot(this, t"AttachmentSlots.WeaponRight");
  let left = transaction.GetItemInSlot(this, t"AttachmentSlots.WeaponLeft");
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let id = Cast<StatsObjectID>(this.GetEntityID());
  let context: ScriptExecutionContext;
  let hasContext = AIHumanComponent.GetScriptContext(this, context);
  let target: wref<GameObject>;
  let argumentTarget: wref<GameObject>;
  let resolved = false;
  if hasContext {
    argumentTarget = ScriptExecutionContext.GetArgumentObject(context, n"CombatTarget");
    resolved = AIActionTarget.GetObject(context,
      TweakDBInterface.GetAIActionTargetRecord(t"AIActionTarget.CombatTarget"), target);
  }
  let targetID = "none";
  let argumentTargetID = "none";
  let targetAttached = false;
  let targetAlive = false;
  let targetPuppet = target as ScriptedPuppet;
  if IsDefined(target) {
    targetID = EntityID.ToDebugString(target.GetEntityID());
    targetAttached = target.IsAttached();
  }
  if IsDefined(targetPuppet) { targetAlive = ScriptedPuppet.IsAlive(targetPuppet); }
  if IsDefined(argumentTarget) { argumentTargetID = EntityID.ToDebugString(argumentTarget.GetEntityID()); }
  Diagnostics.Write(s"SEATED_PREFLIGHT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(eventName) highLevel=\(Diagnostics.Enum("gamedataNPCHighLevelState", EnumInt(this.GetHighLevelStateFromBlackboard()))) context=\(hasContext) missingRightArm=\(ArmCombat.MissingRight(this)) missingLeftArm=\(ArmCombat.MissingLeft(this)) canUseRightHand=\(stats.GetStatValue(id, gamedataStatType.CanUseRightHand)) canUseLeftHand=\(stats.GetStatValue(id, gamedataStatType.CanUseLeftHand)) right=[\(SeatedCombat.SlotDiagnostic(right))] left=[\(SeatedCombat.SlotDiagnostic(left))] targetResolved=\(resolved) targetDefined=\(IsDefined(target)) target=\(targetID) targetAttached=\(targetAttached) targetIsPuppet=\(IsDefined(targetPuppet)) targetAlive=\(targetAlive) combatArgument=\(argumentTargetID)");
}

@addMethod(NPCPuppet)
private final func CLS_GroundPainBody() -> Int32 {
  let root = this.FindComponentByName(n"root") as AnimatedComponent;
  if !IsDefined(root) { return 0; }
  let rig = ResourceRef.GetPath(root.rig);
  if Equals(rig, r"base\\characters\\base_entities\\man_base\\man_base.rig") { return 1; }
  if Equals(rig, r"base\\characters\\base_entities\\woman_base\\woman_base.rig") { return 2; }
  return 0;
}

@addMethod(NPCPuppet)
public final func CLS_SeatedActive() -> Bool {
  return this.cls_seatedStage > 0 && this.cls_seatedStage < 8;
}

@addMethod(NPCPuppet)
public final func CLS_WoundDeadlinePreempted() -> Bool {
  return this.cls_seatedForeignWorkspot || this.cls_seatedDamageDeath;
}

// Cazanu: keep either private ground pose until physics has actually spawned.
// Called for native fatal damage and immediately before our timed death.
@addMethod(NPCPuppet)
public final func CLS_HoldSeatedDeathPose() -> Void {
  if this.IsAttached() && this.cls_seatedOwnsWorkspot && !this.cls_seatedForeignWorkspot
    && (Equals(this.cls_seatedOwnedTag, SeatedCombat.SeatTag())
      || Equals(this.cls_seatedOwnedTag, SeatedCombat.PainTag(1))
      || Equals(this.cls_seatedOwnedTag, SeatedCombat.PainTag(2)))
    && ScriptedPuppet.CanRagdoll(this) {
    this.cls_seatedDeathPoseHeld = true;
    this.cls_seatedDeathFromSeat = true;
  }
}

@addMethod(NPCPuppet)
public final func CLS_IsSeatedDamageDeath() -> Bool {
  return this.cls_seatedDamageDeath && this.cls_seatedDeathFromSeat
    && !this.cls_seatedForeignWorkspot && this.IsDead();
}

// The native death task normally detects workspot deaths and ragdolls them.
// Our cleanup removes that workspot before the task may read it. Preserve
// the same animation choice only after native death is confirmed/pending;
// a defeat-only/nonlethal hit must not be promoted to death here.
@addMethod(NPCPuppet)
public final func CLS_PrepareGroundDamageDeath() -> Void {
  if this.cls_seatedDamageDeath || !this.CLS_IsTrackedSurvivor() || !this.IsAttached()
    || !this.cls_seatedOwnsWorkspot || this.cls_seatedForeignWorkspot
    || !IsNameValid(this.cls_seatedOwnedTag)
    || (!this.IsDead() && !this.IsAboutToDie()) { return; }
  this.cls_seatedDamageDeath = true;
  let canRagdoll = ScriptedPuppet.CanRagdoll(this);
  if canRagdoll { this.SetSkipDeathAnimation(true); }
  this.CLS_HoldSeatedDeathPose();
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"GROUND_DAMAGE_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) stage=\(this.cls_seatedStage) ownedTag=\(this.cls_seatedOwnedTag) dead=\(this.IsDead()) aboutToDie=\(this.IsAboutToDie()) skipDeathAnimation=\(canRagdoll) groundPoseHeld=\(this.cls_seatedDeathPoseHeld) nativeHealthAndKillUnchanged=true");
    this.CLS_QueueSurvivalSnapshot(0.25);
    this.CLS_QueueSurvivalSnapshot(1.0);
  }
}

// Native ProcessDefeated has already evaluated the hit before this method.
// Capture its death decision while our ground workspot still has ownership.
@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  wrappedMethod();
  if IsDefined(this.m_ownerNPC) { this.m_ownerNPC.CLS_PrepareGroundDamageDeath(); }
}

// Stages: 1 load seat, 2 request seat, 3 shoot, 4 load pain, 5 request pain,
// 6 hold pain, 7 deadline-only fallback, 8 finished. Crawlers do not enter.
@addMethod(NPCPuppet)
public final func CLS_TryStartSeated(context: ScriptExecutionContext) -> Bool {
  if this.cls_seatedAttempted {
    return this.CLS_SeatedActive();
  }
  this.cls_seatedAttempted = true;
  if (this.cls_legWoundMode != 2 && this.cls_legWoundMode != 3)
    || !TweakDBInterface.GetBool(t"CazanuLimbSurvival.SeatedCombatReady", false)
    || GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this) {
    return false;
  }
  this.cls_seatedComponent = this.FindComponentByName(n"CLS_SeatedWorkspot") as WorkspotResourceComponent;
  if !IsDefined(this.cls_seatedComponent) {
    this.CLS_KeepWoundDeadline(context, n"component_missing_native_fallback");
    this.CLS_QueueSeatedTick();
    return true;
  }
  let depot = GameInstance.GetResourceDepot();
  if this.cls_legWoundMode == 2 {
    let body = this.CLS_GroundPainBody();
    this.cls_seatedPainPath = SeatedCombat.PainPath(body);
    this.cls_seatedPainTag = SeatedCombat.PainTag(body);
    if ResRef.IsValid(this.cls_seatedPainPath) && depot.ResourceExists(this.cls_seatedPainPath) {
      this.cls_seatedPendingPainToken = depot.LoadResource(this.cls_seatedPainPath);
    }
    this.CLS_SeatedBeginPain(context, n"selected_pain_only");
    if this.CLS_SeatedActive() { this.CLS_QueueSeatedTick(); }
    return this.CLS_SeatedActive();
  }
  this.CLS_LogSeatedPreflight(n"shooting_decision");
  this.cls_seatedWeapon = SeatedCombat.Gun(this);
  if this.cls_seatedWeapon != this.cls_legWoundGun { this.cls_seatedWeapon = null; }
  let target: wref<GameObject>;
  let rejection: CName;
  // Missing gun/target prevents fire, but the selected shooter still sits.
  if !IsDefined(this.cls_seatedWeapon) {
    if Diagnostics.Enabled() { rejection = SeatedCombat.GunRejection(this); }
  } else if !AIActionTarget.GetObject(context,
    TweakDBInterface.GetAIActionTargetRecord(t"AIActionTarget.CombatTarget"), target) {
    rejection = n"shoot_unavailable_target_unresolved";
  } else if !IsDefined(target) {
    rejection = n"shoot_unavailable_target_undefined";
  } else if !target.IsAttached() {
    rejection = n"shoot_unavailable_target_detached";
  }
  if IsNameValid(rejection) {
    this.CLS_LogSeated(rejection);
  }
  if !depot.ResourceExists(SeatedCombat.Path()) {
    this.CLS_KeepWoundDeadline(context, n"seat_resource_missing_deadline");
    if this.CLS_SeatedActive() { this.CLS_QueueSeatedTick(); }
    return this.CLS_SeatedActive();
  }
  this.cls_seatedTarget = target;
  this.cls_seatedToken = depot.LoadResource(SeatedCombat.Path());
  if !IsDefined(this.cls_seatedToken) {
    this.CLS_KeepWoundDeadline(context, n"seat_load_unavailable_deadline");
    if this.CLS_SeatedActive() { this.CLS_QueueSeatedTick(); }
    return this.CLS_SeatedActive();
  }
  this.cls_seatedStage = 1;
  this.cls_seatedStageTime = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  this.CLS_LogSeated(n"loading_seat");
  this.CLS_QueueSeatedTick();
  return true;
}

@addMethod(NPCPuppet)
private final func CLS_QueueSeatedTick() -> Void {
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, new CLS_SeatedTickEvent(), 0.10, true);
}

@addMethod(NPCPuppet)
private final func CLS_LogSeated(eventName: CName) -> Void {
  if Diagnostics.Enabled() {
    let system = GameInstance.GetWorkspotSystem(this.GetGame());
    let instance = system.GetWorkspotInstance(this.GetEntityID());
    let info = system.GetExtendedInfo(this);
    let anim: CName;
    let idle: CName;
    let entryId: Uint32;
    let active: Bool;
    let entering: Bool;
    let exiting: Bool;
    let reaction: Bool;
    let motion: Bool;
    if IsDefined(instance) {
      anim = instance.animName;
      idle = instance.idleAnim;
      entryId = instance.entryId.id;
    }
    if IsDefined(info) {
      active = info.isActive;
      entering = info.entering;
      exiting = info.exiting;
      reaction = info.inReaction;
      motion = info.inMotion;
    }
    // Called only on stage transitions or failures, never on each delay tick.
    Diagnostics.Write(s"SEATED npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(eventName) stage=\(this.cls_seatedStage) requestedTag=\(this.cls_seatedRequestedTag) ownedTag=\(this.cls_seatedOwnedTag) owned=\(this.cls_seatedOwnsWorkspot) foreign=\(this.cls_seatedForeignWorkspot) instanceDefined=\(IsDefined(instance)) nativeInWorkspot=\(system.IsActorInWorkspot(this)) infoDefined=\(IsDefined(info)) active=\(active) entering=\(entering) exiting=\(exiting) reaction=\(reaction) motion=\(motion) anim=\(anim) idle=\(idle) entryId=\(entryId) aim=\(this.GetAIControllerComponent().GetShootingBlackboard().GetInt(GetAllBlackboardDefs().AIShooting.rightArmLookAtLimitReached))");
  }
}

@addMethod(NPCPuppet)
private final func CLS_LogSeatedAmmo(eventName: CName) -> Void {
  if !Diagnostics.Enabled() || !IsDefined(this.cls_seatedWeapon) { return; }
  Diagnostics.Write(s"SEATED_AMMO npc=\(EntityID.ToDebugString(this.GetEntityID())) event=\(eventName) weapon=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(this.cls_seatedWeapon.GetItemID()))) magazine=\(WeaponObject.GetMagazineAmmoCount(this.cls_seatedWeapon))/\(WeaponObject.GetMagazineCapacity(this.cls_seatedWeapon)) reload=\(this.cls_seatedReloadCount)/12 duration=\(this.cls_seatedReloadDuration) owned=\(this.cls_seatedOwnsReload) awaitingFinish=\(this.cls_seatedReloadFinishing)");
}

@addMethod(NPCPuppet)
private final func CLS_InterruptSeatedReload() -> Void {
  if this.cls_seatedOwnsReload {
    if IsDefined(this.cls_seatedWeapon) {
      this.cls_seatedWeapon.StopReload(gameweaponReloadStatus.Interrupted);
    }
    this.cls_seatedOwnsReload = false;
    this.CLS_LogSeatedAmmo(n"reload_interrupted");
  }
  this.cls_seatedReloadFinishing = false;
}

// Returns true only when the magazine is ready for native firing. Reloads
// consume time inside the existing 25-second stage; they never reset it.
@addMethod(NPCPuppet)
private final func CLS_SeatedAmmoReady(context: ScriptExecutionContext, now: Float) -> Bool {
  if !IsDefined(this.cls_seatedWeapon) { return false; }
  if !this.cls_seatedAmmoLogged {
    this.cls_seatedAmmoLogged = true;
    this.CLS_LogSeatedAmmo(n"shooting_stage_start");
  }
  if this.cls_seatedOwnsReload {
    if now >= this.cls_seatedReloadEnd {
      this.cls_seatedWeapon.StopReload(gameweaponReloadStatus.Standard);
      this.cls_seatedOwnsReload = false;
      this.cls_seatedReloadFinishing = true;
      // StopReload queues ReloadFinishEvent. Check ammunition on later ticks
      // so the asynchronous native refill is not mistaken for a failure.
      this.cls_seatedReloadVerifyBy = now + 0.5;
      this.CLS_LogSeatedAmmo(n"reload_finish_queued");
    }
    return false;
  }
  let ammo = WeaponObject.GetMagazineAmmoCount(this.cls_seatedWeapon);
  if this.cls_seatedReloadFinishing {
    if ammo > 0u {
      this.cls_seatedReloadFinishing = false;
      this.CLS_LogSeatedAmmo(n"reload_complete");
      return true;
    }
    if now >= this.cls_seatedReloadVerifyBy {
      this.cls_seatedReloadFinishing = false;
      this.cls_seatedReloadFailed = true;
      this.CLS_LogSeatedAmmo(n"reload_failed_hold_until_25s");
    }
    return false;
  }
  if ammo > 0u { return true; }
  if this.cls_seatedReloadFailed { return false; }

  // Pause only shooting. The owned seated workspot, aiming look-at, and
  // original stage clock continue throughout the reload.
  if this.cls_seatedFiring {
    AISubActionShootWithWeapon_Record_Implementation.Deactivate(context,
      TweakDBInterface.GetAISubActionShootWithWeaponRecord(t"CazanuLimbSurvival.SeatedShootRight"),
      MaxF(0.0, now - this.cls_seatedStageTime), true);
    this.cls_seatedFiring = false;
  }
  // A fixed attempt bound supplements the 25-second deadline. Never refill
  // each tick or repeatedly retry a failed native reload.
  if this.cls_seatedReloadCount >= 12 {
    this.cls_seatedReloadFailed = true;
    this.CLS_LogSeatedAmmo(n"reload_limit_hold_until_25s");
    return false;
  }
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let weaponID = Cast<StatsObjectID>(this.cls_seatedWeapon.GetEntityID());
  let duration = stats.GetStatValue(weaponID, gamedataStatType.EmptyReloadTime);
  if !(duration >= 0.1 && duration <= 10.0) {
    duration = stats.GetStatValue(weaponID, gamedataStatType.ReloadTime);
  }
  if !(duration >= 0.1 && duration <= 10.0) {
    // Native handgun/revolver action phases total approximately 1.87/1.93s.
    // Use their midpoint only if this weapon has no usable reload stat.
    duration = 1.9;
  }
  this.cls_seatedReloadDuration = duration;
  this.cls_seatedReloadEnd = now + duration;
  this.cls_seatedReloadCount += 1;
  this.cls_seatedOwnsReload = true;
  // Native StartReload/StopReload manage ammo events and send their Reload
  // feature to the weapon, its owner and child items. Do not additionally
  // request a body Reload event or upper-body Reload state here.
  this.cls_seatedWeapon.StartReload(duration);
  this.CLS_LogSeatedAmmo(n"reload_started");
  return false;
}

@addMethod(NPCPuppet)
private final func CLS_CanUseSeatedSupportHand() -> Bool {
  return !ArmCombat.MissingLeft(this)
    && GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatType.CanUseLeftHand) > 0.0
    && !IsDefined(GameInstance.GetTransactionSystem(this.GetGame()).GetItemInSlot(this, t"AttachmentSlots.WeaponLeft"));
}

@addMethod(NPCPuppet)
private final func CLS_StartSeatedSupportHand() -> Void {
  if IsDefined(this.cls_seatedSupportIK) || this.cls_seatedStage != 3
    || !this.CLS_IsOwnedGroundIdle() || !this.CLS_CanUseSeatedSupportHand() { return; }
  let body = this.CLS_GroundPainBody();
  if body != 1 && body != 2 { return; }
  let target = SeatedCombat.SupportHandTarget(body);
  let support = new IKTargetAddEvent();
  support.bodyPart = n"ikLeftArm";
  support.targetPositionProvider = IPositionProvider.CreateEntityPositionProvider(this, target);
  // The provider makes endpoint compensation rotate with the seated owner.
  // A zero orientation weight preserves the animated palm/wrist rotation.
  let orientation: Quaternion;
  Quaternion.SetIdentity(orientation);
  support.SetEntityOrientationTarget(this, n"", orientation);
  support.request.weightPosition = 1.0;
  support.request.weightOrientation = 0.0;
  support.request.transitionIn = 0.20;
  support.request.transitionOut = 0.15;
  // Native explicit-request priority; leave higher-priority scene IK intact.
  support.request.priority = 0;
  this.cls_seatedSupportIK = support;
  this.QueueEvent(support);
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"SEATED_SUPPORT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=requested body=\(body) localTarget=(\(target.X),\(target.Y),\(target.Z)) positionWeight=1 orientationWeight=0");
  }
}

@addMethod(NPCPuppet)
private final func CLS_StopSeatedSupportHand() -> Void {
  if !IsDefined(this.cls_seatedSupportIK) { return; }
  let release = new CLS_SeatedSupportReleaseEvent();
  release.target = this.cls_seatedSupportIK;
  this.cls_seatedSupportIK = null;
  if release.target.outIKTargetRef.id > 0 && Equals(release.target.outIKTargetRef.part, n"ikLeftArm") {
    IKTargetRemoveEvent.QueueRemoveIkTargetRemoveEvent(this, release.target);
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SEATED_SUPPORT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=release_queued ownedId=\(release.target.outIKTargetRef.id)");
    }
    return;
  }
  // Native Add assigns its reference when consumed. Never snapshot an
  // unassigned reference into Remove: retain the event until a later frame.
  if release.target.outIKTargetRef.id <= 0 {
    release.target.request.weightPosition = 0.0;
    release.target.request.weightOrientation = 0.0;
    // A late inert Add must also lose to the native default state.
    release.target.request.priority = 2147483647;
  }
  GameInstance.GetDelaySystem(this.GetGame()).DelayEventNextFrame(this, release);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_SeatedSupportReleaseEvent(evt: ref<CLS_SeatedSupportReleaseEvent>) -> Bool {
  if !IsDefined(evt.target) { return false; }
  if evt.target.outIKTargetRef.id > 0 && Equals(evt.target.outIKTargetRef.part, n"ikLeftArm") {
    IKTargetRemoveEvent.QueueRemoveIkTargetRemoveEvent(this, evt.target);
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SEATED_SUPPORT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=release_queued ownedId=\(evt.target.outIKTargetRef.id)");
    }
    return true;
  }
  if evt.attempts < 8 {
    evt.attempts += 1;
    GameInstance.GetDelaySystem(this.GetGame()).DelayEventNextFrame(this, evt);
  } else if Diagnostics.Enabled() {
    Diagnostics.Write(s"SEATED_SUPPORT npc=\(EntityID.ToDebugString(this.GetEntityID())) event=release_unassigned_inert nativeId=\(evt.target.outIKTargetRef.id)");
  }
  return false;
}

@addMethod(NPCPuppet)
private final func CLS_StopSeatedShooting(context: ScriptExecutionContext) -> Void {
  this.CLS_StopSeatedSupportHand();
  this.CLS_InterruptSeatedReload();
  if this.cls_seatedFiring {
    AISubActionShootWithWeapon_Record_Implementation.Deactivate(context,
      TweakDBInterface.GetAISubActionShootWithWeaponRecord(t"CazanuLimbSurvival.SeatedShootRight"),
      MaxF(0.0, EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context)) - this.cls_seatedStageTime), true);
    this.cls_seatedFiring = false;
  }
  AIActionLookat.Deactivate(this, this.cls_seatedLookats);
  this.CLS_RestoreSeatedUpperBody();
}

@addMethod(NPCPuppet)
private final func CLS_SetSeatedUpperBody(state: gamedataNPCUpperBodyState) -> Void {
  if !IsDefined(this.GetAIControllerComponent()) { return; }
  let signals = this.GetAIControllerComponent().GetSignals();
  let signal = new NPCStateChangeSignal();
  signal.m_upperBodyState = state;
  signal.m_upperBodyStateValid = true;
  let id = signals.GetOrCreateSignal(n"NPCStateChangeSignal");
  signals.Set(id, false);
  signals.SetWithData(id, signal);
}

@addMethod(NPCPuppet)
private final func CLS_RestoreSeatedUpperBody() -> Void {
  if this.cls_seatedOwnsUpperBody {
    if !this.IsAboutToDieOrDefeated() && ScriptedPuppet.IsAlive(this) && this.IsActive()
      && Equals(this.GetUpperBodyStateFromBlackboard(), gamedataNPCUpperBodyState.Shoot) {
      this.CLS_SetSeatedUpperBody(this.cls_seatedSavedUpperBody);
    }
    this.cls_seatedOwnsUpperBody = false;
  }
}

@addMethod(NPCPuppet)
public final func CLS_StopSeated(context: ScriptExecutionContext) -> Void {
  this.CLS_PrepareGroundDamageDeath();
  this.cls_seatedStage = 8;
  this.CLS_StopSeatedShooting(context);
  this.CLS_ClearSeated();
}

@addMethod(NPCPuppet)
private final func CLS_IsOwnedGroundIdle() -> Bool {
  if !this.cls_seatedOwnsWorkspot || this.cls_seatedForeignWorkspot
    || !IsNameValid(this.cls_seatedOwnedTag)
    || !Equals(this.cls_seatedOwnedTag, this.cls_seatedRequestedTag) { return false; }
  let system = GameInstance.GetWorkspotSystem(this.GetGame());
  if !system.IsActorInWorkspot(this) { return false; }
  let info = system.GetExtendedInfo(this);
  // Native start-event tags establish ownership; native record flags establish
  // playback. Raw Codeware instance offsets are diagnostic data only.
  return IsDefined(info) && info.isActive && !info.entering && !info.exiting
    && !info.inReaction && !info.inMotion;
}

@addMethod(NPCPuppet)
private final func CLS_StopOwnedSeatedWorkspot() -> Void {
  if this.cls_seatedOwnsWorkspot && IsNameValid(this.cls_seatedOwnedTag) && !this.cls_seatedForeignWorkspot {
    this.cls_seatedRetiringTag = this.cls_seatedOwnedTag;
    this.cls_seatedOwnsWorkspot = false;
    this.cls_seatedOwnedTag = n"";
    GameInstance.GetWorkspotSystem(this.GetGame()).StopNpcInWorkspot(this);
  }
}

@addMethod(NPCPuppet)
public final func CLS_OnGroundWorkspotStarted(tags: array<CName>) -> Void {
  let tag = SeatedCombat.EventTag(tags);
  // A private setup queued before the fatal hit may finish after cleanup.
  // Release only our tagged resource; never stop a foreign/quest workspot.
  if this.cls_seatedDamageDeath && IsNameValid(tag) {
    this.cls_seatedOwnedTag = tag;
    this.cls_seatedOwnsWorkspot = true;
    this.CLS_LogSeated(n"late_private_start_after_damage_death");
    // EventTag already restricts this branch to our seat or either pain pose.
    if !this.cls_seatedDeathPoseHeld {
      this.CLS_StopOwnedSeatedWorkspot();
    }
    return;
  }
  if !this.CLS_SeatedActive() && !this.cls_seatedOwnsWorkspot { return; }
  let seatStage = this.cls_seatedStage == 2 || this.cls_seatedStage == 3 || this.cls_seatedStage == 4;
  let painStage = this.cls_seatedStage == 5 || this.cls_seatedStage == 6;
  let requestedStage = this.cls_seatedStage == 7
    || (seatStage && Equals(tag, SeatedCombat.SeatTag()))
    || (painStage && Equals(tag, this.cls_seatedPainTag));
  if IsNameValid(tag) && Equals(tag, this.cls_seatedRequestedTag) && requestedStage {
    this.cls_seatedOwnedTag = tag;
    this.cls_seatedOwnsWorkspot = true;
    this.CLS_LogSeated(n"native_owned_workspot_started");
    // A delayed setup can arrive after its timeout. Release our own late
    // workspot while retaining the independent wound-death deadline.
    if this.cls_seatedStage == 7 && this.cls_legWoundMode != 3 { this.CLS_StopOwnedSeatedWorkspot(); }
  } else if this.cls_seatedStage == 5 && IsNameValid(tag) && Equals(tag, this.cls_seatedRetiringTag) {
    this.CLS_LogSeated(n"prior_seat_start_during_handoff");
  } else {
    // A foreign start supersedes our ownership before any cleanup can issue
    // StopNpc. It also cancels our deadline; a quest now owns this actor.
    this.cls_seatedOwnsWorkspot = false;
    this.cls_seatedOwnedTag = n"";
    this.cls_seatedForeignWorkspot = true;
    this.cls_seatedDeathPoseHeld = false;
    this.cls_seatedDeathFromSeat = false;
    this.CLS_LogSeated(n"foreign_workspot_started_release");
    this.CLS_ClearSeated();
  }
}

@addMethod(NPCPuppet)
public final func CLS_OnGroundWorkspotFinished(tags: array<CName>) -> Void {
  if !this.CLS_SeatedActive() && !this.cls_seatedOwnsWorkspot { return; }
  if this.cls_seatedOwnsWorkspot && IsNameValid(this.cls_seatedOwnedTag)
    && ArrayContains(tags, this.cls_seatedOwnedTag) {
    this.cls_seatedOwnsWorkspot = false;
    this.cls_seatedOwnedTag = n"";
    this.CLS_LogSeated(n"native_owned_workspot_finished");
  }
  // An old seat's finish event may arrive after the pain start event.
  if IsNameValid(this.cls_seatedRetiringTag) && ArrayContains(tags, this.cls_seatedRetiringTag) {
    this.cls_seatedRetiringTag = n"";
  }
}

// Detachment can invalidate ScriptExecutionContext before our next delay tick.
// Cleanup therefore also has an owner/weapon-only path.
@addMethod(NPCPuppet)
private final func CLS_ClearSeated() -> Void {
  this.CLS_PrepareGroundDamageDeath();
  // Close the controller before releasing anything that can queue callbacks.
  this.cls_seatedStage = 8;
  this.CLS_StopSeatedSupportHand();
  this.CLS_InterruptSeatedReload();
  if this.cls_seatedFiring && IsDefined(this.cls_seatedWeapon) {
    AIWeapon.OnStopShooting(this.cls_seatedWeapon, 0.0);
    WeaponObject.ChangeTriggerMode(this.cls_seatedWeapon, this.cls_seatedWeapon.GetWeaponRecord().PrimaryTriggerMode().Type());
  }
  this.cls_seatedFiring = false;
  AIActionLookat.Deactivate(this, this.cls_seatedLookats);
  this.CLS_RestoreSeatedUpperBody();
  if this.cls_seatedDeathPoseHeld && this.IsAttached() && !this.IsRagdolling() {
    return;
  }
  this.CLS_ReleaseSeatedResources();
}

@addMethod(NPCPuppet)
private final func CLS_ReleaseSeatedResources() -> Void {
  this.cls_seatedDeathPoseHeld = false;
  this.CLS_StopOwnedSeatedWorkspot();
  this.cls_seatedStage = 8;
  this.cls_seatedToken = null;
  this.cls_seatedPendingPainToken = null;
  this.cls_seatedRequestedTag = n"";
  this.cls_seatedOwnedTag = n"";
  this.cls_seatedRetiringTag = n"";
  this.cls_seatedOwnsWorkspot = false;
}

// OnIncapacitated enables the native ragdoll component. The skip-animation
// flag alone may choose DeathWithoutAnimation and never activate physics.
// Request physics only after native death, then release the seat on its
// actual enabled notification. Bounded retry covers asynchronous activation.
@addMethod(NPCPuppet)
private final func CLS_ActivateSeatedDeathRagdoll(attempts: Int32) -> Void {
  if !this.cls_seatedDeathPoseHeld { return; }
  if !this.IsAttached() || this.cls_seatedForeignWorkspot {
    this.CLS_ReleaseSeatedResources();
    return;
  }
  if !this.IsDead() { return; }
  if this.IsRagdolling() {
    this.CLS_ReleaseSeatedResources();
    return;
  }
  if attempts >= 10 || !ScriptedPuppet.CanRagdoll(this) {
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SEATED_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=ragdoll_unavailable_released attempts=\(attempts)");
    }
    this.CLS_ReleaseSeatedResources();
    return;
  }
  this.QueueEvent(CreateRagdollActivationRequestEvent(entragdollActivationRequestType.Forced,
    n"", false, false, n"Cazanu seated death"));
  if Diagnostics.Enabled() && attempts == 0 {
    Diagnostics.Write(s"SEATED_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=physics_requested_from_seated_pose timed=\(this.cls_groundedTimedDeath)");
  }
  let verify = new CLS_SeatedDeathRagdollEvent();
  verify.attempts = attempts + 1;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, verify, 0.10, true);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_SeatedDeathRagdollEvent(evt: ref<CLS_SeatedDeathRagdollEvent>) -> Bool {
  this.CLS_ActivateSeatedDeathRagdoll(evt.attempts);
  return true;
}

@wrapMethod(NPCPuppet)
protected cb func OnRagdollEnabledEvent(evt: ref<RagdollNotifyEnabledEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if this.cls_seatedDeathPoseHeld && this.IsDead() {
    if Diagnostics.Enabled() {
      Diagnostics.Write(s"SEATED_DEATH npc=\(EntityID.ToDebugString(this.GetEntityID())) event=physics_active_release_seat");
    }
    this.CLS_ReleaseSeatedResources();
  }
  return result;
}

@addMethod(NPCPuppet)
private final func CLS_KeepWoundDeadline(context: ScriptExecutionContext, reason: CName) -> Void {
  if this.cls_seatedDamageDeath || !WoundTiming.Eligible(this) {
    this.CLS_StopSeated(context);
    return;
  }
  this.CLS_StopSeatedShooting(context);
  // A shooter with no current target/ammunition keeps the seated pose until
  // its original deadline. Never substitute the pain animation.
  if this.cls_legWoundMode != 3 { this.CLS_StopOwnedSeatedWorkspot(); }
  this.cls_seatedPendingPainToken = null;
  // SetupWorkspot can deactivate the wounded AI action. Keep our delay event
  // alive after internal failures so its original deadline still resolves.
  this.cls_seatedStage = 7;
  this.cls_seatedStageTime = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  this.CLS_LogSeated(reason);
}

@addMethod(NPCPuppet)
private final func CLS_SeatedBeginPain(context: ScriptExecutionContext, reason: CName) -> Void {
  if this.cls_legWoundMode != 2 {
    this.CLS_KeepWoundDeadline(context, n"pain_blocked_for_shooter");
    return;
  }
  if this.cls_seatedDamageDeath || !WoundTiming.Eligible(this) {
    this.CLS_StopSeated(context);
    return;
  }
  this.CLS_StopSeatedShooting(context);
  if this.cls_seatedDamageDeath || !WoundTiming.Eligible(this) {
    this.CLS_ClearSeated();
    return;
  }
  if !ResRef.IsValid(this.cls_seatedPainPath) {
    this.CLS_KeepWoundDeadline(context, n"pain_rig_unsupported_deadline_fallback");
    return;
  }
  if !IsDefined(this.cls_seatedPendingPainToken) {
    this.CLS_KeepWoundDeadline(context, n"pain_resource_missing_deadline_fallback");
    return;
  }
  // Only the separately selected pain outcome loads this resource.
  this.cls_seatedStage = 4;
  this.cls_seatedStageTime = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  this.CLS_LogSeated(reason);
}

@addMethod(NPCPuppet)
private final func CLS_RequestGroundPain(now: Float) -> Void {
  if this.cls_legWoundMode != 2 { return; }
  if this.cls_seatedDamageDeath || !WoundTiming.Eligible(this) {
    this.CLS_ClearSeated();
    return;
  }
  let system = GameInstance.GetWorkspotSystem(this.GetGame());
  let priorTag = this.cls_seatedRequestedTag;
  this.CLS_StopOwnedSeatedWorkspot();
  if IsNameValid(priorTag) { this.cls_seatedRetiringTag = priorTag; }
  this.cls_seatedToken = this.cls_seatedPendingPainToken;
  this.cls_seatedPendingPainToken = null;
  ResourceAsyncRef.SetPath(this.cls_seatedComponent.workspotResource, this.cls_seatedPainPath);
  ResourceRef.LoadPath(this.cls_seatedComponent.npcWorkspotResourceSync, this.cls_seatedPainPath);
  // Private pain trees contain only an idle. There is no entry, exit, jump,
  // animation proxy, or periodic restart that can make the actor stand.
  this.cls_seatedRequestedTag = this.cls_seatedPainTag;
  this.cls_seatedStage = 5;
  this.cls_seatedStageTime = now;
  system.PlayNpcInWorkspot(this, null, this, n"CLS_SeatedWorkspot", n"", 0.0);
  this.CLS_LogSeated(n"ground_pain_requested");
}

@addMethod(NPCPuppet)
protected cb func OnCLS_SeatedTickEvent(evt: ref<CLS_SeatedTickEvent>) -> Bool {
  if !this.CLS_SeatedActive() { return false; }
  let context: ScriptExecutionContext;
  if !AIHumanComponent.GetScriptContext(this, context) {
    this.CLS_ClearSeated();
    return false;
  }
  if this.cls_seatedDamageDeath || !WoundTiming.Eligible(this) {
    this.CLS_LogSeated(n"ended_by_damage_or_detach");
    this.CLS_StopSeated(context);
    return false;
  }
  let now = EngineTime.ToFloat(ScriptExecutionContext.GetAITime(context));
  let elapsed = now - this.cls_seatedStageTime;
  if this.cls_seatedForeignWorkspot {
    this.CLS_StopSeated(context);
    return false;
  }
  if this.CLS_TimeUntilWoundDeath(context) <= 0.0 {
    this.CLS_LogSeated(n"grounded_death");
    this.CLS_ArmGroundedDeath(context);
    // Stop only our workspot and dispatch death in the same tick, retaining
    // its last sampled ground pose for the ragdoll handoff.
    this.CLS_StopSeated(context);
    AISubActionForceDeath_Record_Implementation.ForceDeath(context,
      TweakDBInterface.GetAISubActionForceDeathRecord(t"CazanuLimbSurvival.LegFinalDeath"));
    return true;
  }
  if this.cls_seatedStage == 1 {
    let system = GameInstance.GetWorkspotSystem(this.GetGame());
    if system.IsActorInWorkspot(this) {
      this.cls_seatedForeignWorkspot = true;
      this.CLS_LogSeated(n"external_workspot_during_load");
      this.CLS_StopSeated(context);
      return false;
    }
    if this.cls_seatedToken.IsFailed() || elapsed > 2.0 {
      this.CLS_KeepWoundDeadline(context, n"seat_load_failed_deadline");
    } else if this.cls_seatedToken.IsLoaded() {
      if !SeatedCombat.IsTaggedGroundResource(this.cls_seatedToken, SeatedCombat.SeatTag()) {
        this.CLS_KeepWoundDeadline(context, n"seat_private_resource_invalid_deadline");
      } else {
        ResourceAsyncRef.SetPath(this.cls_seatedComponent.workspotResource, SeatedCombat.Path());
        ResourceRef.LoadPath(this.cls_seatedComponent.npcWorkspotResourceSync, SeatedCombat.Path());
        // The private tree starts directly in the seated idle. Native start
        // tags confirm ownership; no cached jump or entry clip is needed.
        this.cls_seatedRequestedTag = SeatedCombat.SeatTag();
        this.cls_seatedStage = 2;
        this.cls_seatedStageTime = now;
        system.PlayNpcInWorkspot(this, null, this, n"CLS_SeatedWorkspot", n"", 0.0);
        this.CLS_LogSeated(n"requested");
      }
    }
  } else if this.cls_seatedStage == 2 {
    if this.CLS_IsOwnedGroundIdle() {
      this.CLS_AlignSeatedWoundClock(context);
      if !IsDefined(this.cls_seatedWeapon) || !IsDefined(this.cls_seatedTarget)
        || !this.cls_seatedTarget.IsAttached() || SeatedCombat.Gun(this) != this.cls_seatedWeapon {
        this.CLS_KeepWoundDeadline(context, n"seated_no_combat_hold_until_death");
        this.CLS_QueueSeatedTick();
        return true;
      }
      let look: ref<LookAtAddEvent>;
      AIActionLookat.Activate(context, TweakDBInterface.GetAIActionLookAtDataRecord(t"CazanuLimbSurvival.SeatedLookBody"), look);
      if IsDefined(look) { ArrayPush(this.cls_seatedLookats, look); }
      look = null;
      AIActionLookat.Activate(context, TweakDBInterface.GetAIActionLookAtDataRecord(t"CazanuLimbSurvival.SeatedLookRight"), look);
      if !IsDefined(look) {
        this.CLS_KeepWoundDeadline(context, n"no_aim_hold_until_death");
      } else {
        ArrayPush(this.cls_seatedLookats, look);
        this.GetAIControllerComponent().GetShootingBlackboard().SetInt(GetAllBlackboardDefs().AIShooting.rightArmLookAtLimitReached, 1);
        // Do not force ShootAction here. It enables an unmasked upper-body
        // recoil clip after WORKSPOT, disturbing both arms of the seated pose.
        // Native right-hand look-at and weapon fire do not need that feature.
        this.cls_seatedSavedUpperBody = this.GetUpperBodyStateFromBlackboard();
        this.cls_seatedOwnsUpperBody = true;
        this.CLS_SetSeatedUpperBody(gamedataNPCUpperBodyState.Shoot);
        this.cls_seatedStage = 3;
        this.cls_seatedStageTime = now;
        this.CLS_StartSeatedSupportHand();
        this.CLS_LogSeated(n"seated_aiming");
      }
    } else if elapsed > 2.0 {
      this.CLS_KeepWoundDeadline(context, n"seat_setup_timeout_deadline");
    }
  } else if this.cls_seatedStage == 3 {
    // A later off-hand loss releases only this support target. A usable
    // right-hand gun can continue firing for the rest of the seated stage.
    if IsDefined(this.cls_seatedSupportIK) && !this.CLS_CanUseSeatedSupportHand() {
      this.CLS_StopSeatedSupportHand();
    }
    let target: wref<GameObject>;
    let validTarget = AIActionTarget.GetObject(context,
      TweakDBInterface.GetAIActionTargetRecord(t"AIActionTarget.CombatTarget"), target);
    let targetPuppet = target as ScriptedPuppet;
    if IsDefined(targetPuppet) && !ScriptedPuppet.IsAlive(targetPuppet) { validTarget = false; }
    if !validTarget || !IsDefined(target) || !target.IsAttached() || target != this.cls_seatedTarget
      || SeatedCombat.Gun(this) != this.cls_seatedWeapon || !this.CLS_IsOwnedGroundIdle() {
      this.CLS_KeepWoundDeadline(context, n"combat_lost_hold_until_death");
    } else {
      let aiming = this.GetAIControllerComponent().GetShootingBlackboard().GetInt(GetAllBlackboardDefs().AIShooting.rightArmLookAtLimitReached) == 2;
      let ammoReady = this.CLS_SeatedAmmoReady(context, now);
      if ammoReady && aiming {
        let record = TweakDBInterface.GetAISubActionShootWithWeaponRecord(t"CazanuLimbSurvival.SeatedShootRight");
        if !this.cls_seatedFiring {
          AISubActionShootWithWeapon_Record_Implementation.Activate(context, record);
          this.cls_seatedFiring = true;
          this.cls_seatedHasFired = true;
          this.CLS_StartFinalBloodDelay();
          this.CLS_LogSeated(n"aim_verified_native_fire");
        }
        if Equals(AISubActionShootWithWeapon_Record_Implementation.Update(context, record, elapsed), AIbehaviorUpdateOutcome.FAILURE) {
          this.CLS_KeepWoundDeadline(context, n"native_shoot_failed_hold_until_death");
        }
      } else if ammoReady && elapsed >= 3.0 && !this.cls_seatedHasFired {
        this.CLS_KeepWoundDeadline(context, n"aim_timeout_hold_until_death");
      }
    }
  } else if this.cls_seatedStage == 4 {
    if this.cls_seatedPendingPainToken.IsFailed() || elapsed > 2.0 {
      this.CLS_KeepWoundDeadline(context, n"pain_load_failed_deadline_fallback");
    } else if this.cls_seatedPendingPainToken.IsLoaded() {
      if !SeatedCombat.IsTaggedGroundResource(this.cls_seatedPendingPainToken, this.cls_seatedPainTag) {
        this.CLS_KeepWoundDeadline(context, n"pain_private_resource_invalid_deadline_fallback");
      } else {
        this.CLS_RequestGroundPain(now);
      }
    }
  } else if this.cls_seatedStage == 5 {
    if this.CLS_IsOwnedGroundIdle() {
      this.cls_seatedStage = 6;
      this.cls_seatedStageTime = now;
      this.CLS_LogSeated(n"ground_pain_active_infinite_idle");
      this.CLS_StartFinalBloodDelay();
    } else if elapsed > 2.0 {
      this.CLS_KeepWoundDeadline(context, n"pain_setup_timeout_deadline_fallback");
    }
  } else if this.cls_seatedStage == 6 {
    if !this.CLS_IsOwnedGroundIdle() {
      this.CLS_KeepWoundDeadline(context, n"ground_pain_ended_deadline_fallback");
    }
  }
  if this.CLS_SeatedActive() { this.CLS_QueueSeatedTick(); }
  return true;
}

@wrapMethod(ScriptedPuppet)
protected cb func OnWorkspotStartedEvent(evt: ref<WorkspotStartedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let npc = this as NPCPuppet;
  if IsDefined(npc) { npc.CLS_OnGroundWorkspotStarted(evt.tags); }
  return result;
}

@wrapMethod(ScriptedPuppet)
protected cb func OnWorkspotFinishedEvent(evt: ref<WorkspotFinishedEvent>) -> Bool {
  let result = wrappedMethod(evt);
  let npc = this as NPCPuppet;
  if IsDefined(npc) { npc.CLS_OnGroundWorkspotFinished(evt.tags); }
  return result;
}

@wrapMethod(NPCPuppet)
protected cb func OnDetach() -> Bool {
  this.cls_seatedDeathPoseHeld = false;
  this.cls_seatedDeathFromSeat = false;
  if this.CLS_SeatedActive() || this.cls_seatedOwnsWorkspot || this.cls_seatedFiring || IsDefined(this.cls_seatedSupportIK) { this.CLS_ClearSeated(); }
  this.CLS_ReleaseSeatedResources();
  return wrappedMethod();
}

@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  if this.CLS_SeatedActive() || this.cls_seatedOwnsWorkspot || this.cls_seatedFiring || IsDefined(this.cls_seatedSupportIK) { this.CLS_ClearSeated(); }
  wrappedMethod();
  if this.cls_seatedDeathPoseHeld && this.IsDead() && !this.cls_seatedDeathRagdollQueued {
    this.cls_seatedDeathRagdollQueued = true;
    this.CLS_ActivateSeatedDeathRagdoll(0);
  }
}
