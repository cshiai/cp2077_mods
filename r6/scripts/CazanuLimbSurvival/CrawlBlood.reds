// RelentlessLiveDismember by Cazanu - crawling blood trails and final decals.
module CazanuLimbSurvival

public abstract class CrawlBlood {
  // Five samples per second is visually indistinguishable at one-metre
  // spacing and avoids a physics/event burst for every animation frame.
  public static func SampleSeconds() -> Float = 0.20
  public static func Spacing() -> Float = 1.0
  public static func LegOffset() -> Float = 0.15
  public static func HipOffset() -> Float = 0.20
  public static func Lifetime() -> Float = 240.0
  public static func MaxMarks() -> Int32 = 128

  public static func Valid(v: Vector4) -> Bool {
    return v.X == v.X && v.Y == v.Y && v.Z == v.Z
      && AbsF(v.X) < 1000000.0 && AbsF(v.Y) < 1000000.0 && AbsF(v.Z) < 1000000.0;
  }

  public static func Fresh(game: GameInstance, time: Float) -> Bool {
    let age = EngineTime.ToFloat(GameInstance.GetTimeSystem(game).GetSimTime()) - time;
    return age >= 0.0 && age <= 0.5;
  }

  // Highest contact across the same groups as Shellrain's footprint system.
  // A shallow static projection prevents painting the NPC or nearby walls.
  public static func Ground(game: GameInstance, at: Vector4, out position: Vector4, out normal: Vector4) -> Bool {
    if !CrawlBlood.Valid(at) { return false; }
    let from = at;
    from.Z += 0.45;
    let to = at;
    to.Z -= 0.55;
    let groups: array<CName> = [n"Static", n"Terrain", n"World"];
    let result: TraceResult;
    let hitPosition: Vector4;
    let hitNormal: Vector4;
    let found = false;
    let queries = GameInstance.GetSpatialQueriesSystem(game);
    if !IsDefined(queries) { return false; }
    let i = 0;
    // Prefer the first usable surface.  The old implementation always ran
    // all three groups to select a theoretical higher hit, multiplying sync
    // raycasts for no visible gain on a shallow ground projection.
    while i < ArraySize(groups) && !found {
      if queries.SyncRaycastByCollisionGroup(from, to, groups[i], result, true, false) {
        hitPosition = new Vector4(result.position.X, result.position.Y, result.position.Z, 1.0);
        hitNormal = new Vector4(result.normal.X, result.normal.Y, result.normal.Z, 0.0);
        if CrawlBlood.Valid(hitPosition) && CrawlBlood.Valid(hitNormal)
          && hitPosition.Z <= from.Z + 0.001 && hitPosition.Z >= to.Z - 0.001
          && (!found || hitPosition.Z > position.Z) {
          found = true;
          position = hitPosition;
          normal = hitNormal;
        }
      }
      i += 1;
    }
    if !found || Vector4.Length(normal) < 0.001 { return false; }
    normal = Vector4.Normalize(normal);
    normal.W = 0.0;
    return normal.Z >= 0.65;
  }
}

public class CLS_CrawlBloodSpawn extends ScriptableSystemRequest {
  public let owner: wref<NPCPuppet>;
  public let position: Vector4;
  public let direction: Vector4;
  public let right: Vector4;
  public let forward: Vector4;
  public let left: Bool;
  public let rightLeg: Bool;
  public let time: Float;
}

public class CLS_CrawlBloodSweep extends ScriptableSystemRequest {}

// QueueEvent defers the query to entity event service, outside the physics
// flush phase in which ScriptableSystem requests run. Never raycast there.
public class CLS_CrawlBloodContactEvent extends Event {
  public let center: Vector4;
  public let heading: Vector4;
  public let side: Float;
  public let lateral: Float;
  public let variant: Int32;
  public let time: Float;
}

public class CLS_CrawlBloodPlace extends ScriptableSystemRequest {
  public let finalMark: Bool;
  public let owner: wref<NPCPuppet>;
  public let position: Vector4;
  public let normal: Vector4;
  public let along: Vector4;
  public let side: Float;
  public let anchor: CName;
  public let variant: Int32;
  public let time: Float;
}

public struct CLS_CrawlBloodMark {
  public let id: EntityID;
  public let expires: Float;
}

// Requests serialize shared bookkeeping. No world-wide NPC scans, no CET,
// and no persistent save fields. The engine effect owns opacity and fading.
public class CrawlBloodSystem extends ScriptableSystem {
  private let marks: array<CLS_CrawlBloodMark>;
  private let sweepPending: Bool;
  private let sweepID: DelayID;
  private let seed: Int32;
  private let finalSeed: Int32;

  private func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGameInstance()).GetSimTime());
  }

  private func RemoveFirst() -> Void {
    GameInstance.GetStaticEntitySystem().DespawnEntity(this.marks[0].id);
    ArrayErase(this.marks, 0);
  }

  private func Clear() -> Void {
    if this.sweepPending {
      GameInstance.GetDelaySystem(this.GetGameInstance()).CancelDelay(this.sweepID);
    }
    this.sweepPending = false;
    let entities = GameInstance.GetStaticEntitySystem();
    let i = 0;
    while i < ArraySize(this.marks) {
      entities.DespawnEntity(this.marks[i].id);
      i += 1;
    }
    ArrayClear(this.marks);
  }

  private func OnDetach() -> Void { this.Clear(); }

  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.Clear(); }

  private func Prune() -> Void {
    let now = this.Now();
    while ArraySize(this.marks) > 0 && this.marks[0].expires <= now { this.RemoveFirst(); }
  }

  private func ScheduleSweep() -> Void {
    if !this.sweepPending && ArraySize(this.marks) > 0 {
      this.sweepPending = true;
      this.sweepID = GameInstance.GetDelaySystem(this.GetGameInstance()).DelayScriptableSystemRequest(
        n"CazanuLimbSurvival.CrawlBloodSystem", new CLS_CrawlBloodSweep(), 1.0, true);
    }
  }

  private func OnSweep(request: ref<CLS_CrawlBloodSweep>) -> Void {
    this.sweepPending = false;
    this.Prune();
    this.ScheduleSweep();
  }

  private func NextRandom() -> Int32 {
    // Private bounded LCG does not consume the combat outcome RNG stream.
    this.seed = (this.seed * 25173 + 13849) % 65536;
    return this.seed;
  }

  private func RandomBetween(low: Float, high: Float) -> Float {
    return low + (high - low) * (Cast<Float>(this.NextRandom()) / 65535.0);
  }

  private func QueueContact(request: ref<CLS_CrawlBloodSpawn>, side: Float) -> Void {
    // Keep a body-relative fallback for actors without a usable leg slot.
    // The event resolves the current animated knee before the ground query.
    let center = request.position + request.right * (CrawlBlood.LegOffset() * side)
      - request.forward * CrawlBlood.HipOffset();
    if !CrawlBlood.Valid(center) { return; }
    let evt = new CLS_CrawlBloodContactEvent();
    evt.center = center;
    evt.heading = request.direction;
    evt.side = side;
    evt.lateral = this.RandomBetween(-0.04, 0.04);
    // Use the full range rather than the repeating low LCG bits.
    evt.variant = (this.NextRandom() * CrawlBloodAssets.Count()) / 65536;
    evt.time = request.time;
    request.owner.QueueEvent(evt);
  }

  private func OnPlace(request: ref<CLS_CrawlBloodPlace>) -> Void {
    if !this.CanPlace(request.owner, request.position, request.time, request.finalMark)
      || !CrawlBlood.Valid(request.normal) || !CrawlBlood.Valid(request.along)
      || Vector4.Length(request.normal) < 0.01 || Vector4.Length(request.along) < 0.01
      || request.variant < 0 || request.variant >= CrawlBloodAssets.Count() { return; }
    this.Prune();
    // Texture vertical axis is local +Y; projection axis is local +Z.
    let spec = new StaticEntitySpec();
    spec.templatePath = CrawlBloodAssets.Path(request.variant);
    let finalVariant = 0;
    if request.finalMark {
      // Separate RNG stream: choosing a final decal never changes the trail pool.
      this.finalSeed = (this.finalSeed * 25173 + 13849) % 65536;
      finalVariant = (this.finalSeed * CrawlBloodAssets.FinalCount()) / 65536;
      spec.templatePath = CrawlBloodAssets.FinalPath(finalVariant);
    }
    spec.position = request.position + request.normal * 0.004;
    spec.position.W = 1.0;
    spec.orientation = Quaternion.BuildFromDirectionVector(request.along, request.normal);
    spec.appearanceName = n"default";
    spec.attached = true;
    while ArraySize(this.marks) >= CrawlBlood.MaxMarks() { this.RemoveFirst(); }
    let id = GameInstance.GetStaticEntitySystem().SpawnEntity(spec);
    if !EntityID.IsDefined(id) { return; }
    let mark: CLS_CrawlBloodMark;
    mark.id = id;
    // Small cleanup margin lets the native fade finish before entity removal.
    mark.expires = this.Now() + CrawlBlood.Lifetime() + 1.0;
    ArrayPush(this.marks, mark);
    if request.finalMark {
      request.owner.CLS_FinalBloodPlaced(finalVariant);
    } else {
      request.owner.CLS_LogCrawlBlood(request.side, request.position, ArraySize(this.marks), request.anchor);
    }
    this.ScheduleSweep();
  }

  private func CanPlace(owner: wref<NPCPuppet>, position: Vector4, time: Float, opt finalMark: Bool) -> Bool {
    if !IsDefined(owner) || !CrawlBlood.Valid(position)
      || !CrawlBlood.Fresh(this.GetGameInstance(), time)
      || !GameInstance.GetStaticEntitySystem().IsReady() { return false; }
    if finalMark {
      if !owner.CLS_CanPlaceFinalBlood() { return false; }
    } else {
      if !owner.CLS_CanSmearCrawlBlood() { return false; }
    }
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    return IsDefined(player) && Vector4.DistanceSquared(player.GetWorldPosition(), position) <= 2500.0;
  }

  private func OnSpawn(request: ref<CLS_CrawlBloodSpawn>) -> Void {
    if !this.CanPlace(request.owner, request.position, request.time)
      || !CrawlBlood.Valid(request.direction) || !CrawlBlood.Valid(request.right) || !CrawlBlood.Valid(request.forward)
      || Vector4.Length(request.direction) < 0.01 || Vector4.Length(request.right) < 0.01
      || Vector4.Length(request.forward) < 0.01 { return; }
    if request.left { this.QueueContact(request, -1.0); }
    if request.rightLeg { this.QueueContact(request, 1.0); }
  }
}

@addMethod(NPCPuppet)
protected cb func OnCLS_CrawlBloodContactEvent(evt: ref<CLS_CrawlBloodContactEvent>) -> Bool {
  if !IsDefined(evt) || !this.CLS_CanSmearCrawlBlood() || !CrawlBlood.Fresh(this.GetGame(), evt.time)
    || !CrawlBlood.Valid(evt.center) || !CrawlBlood.Valid(evt.heading)
    || Vector4.Length(evt.heading) < 0.01 { return false; }
  let contact = evt.center;
  let anchor = n"body_fallback";
  let transform: WorldTransform;
  let slot = evt.side < 0.0 ? n"LeftLeg" : n"RightLeg";
  // Native helper prefers the actual hit-representation knee bone, then
  // ordinary slots. This tracks the animated limb rather than the capsule.
  if AIActionHelper.GetTargetSlotTransform(this, slot, transform) {
    let knee = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(transform));
    if CrawlBlood.Valid(knee) && Vector4.DistanceSquared(knee, this.GetWorldPosition()) < 4.0 {
      contact = knee;
      anchor = n"knee_slot";
    }
  }
  let heading = evt.heading;
  let hasPrevious = evt.side < 0.0 ? this.cls_bloodHasLeftContact : this.cls_bloodHasRightContact;
  let previous = evt.side < 0.0 ? this.cls_bloodLeftContact : this.cls_bloodRightContact;
  if hasPrevious {
    let trail = contact - previous;
    trail.Z = 0.0;
    trail.W = 0.0;
    let length = Vector4.Length(trail);
    if CrawlBlood.Valid(trail) && length > 0.12 && length < 2.5 {
      trail = trail / length;
      // Follow the actual contact-to-contact stroke. On a sharp reversal,
      // use current motion so a long chord cannot point the new mark back.
      if Vector4.Dot(trail, heading) > 0.25 { heading = trail; }
    }
  }
  let sideways = new Vector4(heading.Y, -heading.X, 0.0, 0.0);
  let center = contact + sideways * evt.lateral;
  let position: Vector4;
  let normal: Vector4;
  // Ground queries only run in NPC contact events. The engine
  // fences entity event service from PhysicsFlushBufferedState.
  if !CrawlBlood.Ground(this.GetGame(), center, position, normal) { return false; }
  let along = heading - normal * Vector4.Dot(heading, normal);
  if !CrawlBlood.Valid(along) || Vector4.Length(along) < 0.01 { return false; }
  let system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"CazanuLimbSurvival.CrawlBloodSystem");
  if !IsDefined(system) { return false; }
  let request = new CLS_CrawlBloodPlace();
  request.owner = this;
  request.position = position;
  request.normal = normal;
  request.along = Vector4.Normalize(along);
  request.side = evt.side;
  request.anchor = anchor;
  request.variant = evt.variant;
  request.time = evt.time;
  system.QueueRequest(request);
  if evt.side < 0.0 {
    this.cls_bloodLeftContact = contact;
    this.cls_bloodHasLeftContact = true;
  } else {
    this.cls_bloodRightContact = contact;
    this.cls_bloodHasRightContact = true;
  }
  return true;
}

@addField(NPCPuppet)
private let cls_bloodPrevious: Vector4;
@addField(NPCPuppet)
private let cls_bloodAt: Float;
@addField(NPCPuppet)
private let cls_bloodCarry: Float;
@addField(NPCPuppet)
private let cls_bloodInitialized: Bool;
@addField(NPCPuppet)
private let cls_bloodLogCount: Int32;
@addField(NPCPuppet)
private let cls_bloodLeftContact: Vector4;
@addField(NPCPuppet)
private let cls_bloodRightContact: Vector4;
@addField(NPCPuppet)
private let cls_bloodHasLeftContact: Bool;
@addField(NPCPuppet)
private let cls_bloodHasRightContact: Bool;
@addField(NPCPuppet)
private let cls_bloodHeading: Vector4;
@addField(NPCPuppet)
private let cls_bloodFinalQueued: Bool;
@addField(NPCPuppet)
private let cls_bloodFinalPlaced: Bool;
@addField(NPCPuppet)
private let cls_bloodFinalDelayStarted: Bool;

@addMethod(NPCPuppet)
public final func CLS_CanSmearCrawlBlood() -> Bool {
  return this.cls_legWoundMode == 1 && WoundTiming.Eligible(this)
    && this.cls_extendedWoundStarted && !this.cls_groundedTimedDeath && !this.IsRagdolling()
    && !this.CLS_WoundDeadlinePreempted()
    && !GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this);
}

@addMethod(NPCPuppet)
public final func CLS_LogCrawlBlood(side: Float, position: Vector4, total: Int32, anchor: CName) -> Void {
  if Diagnostics.Enabled() && this.cls_bloodLogCount < 4 {
    this.cls_bloodLogCount += 1;
    Diagnostics.Write(s"CRAWL_BLOOD npc=\(EntityID.ToDebugString(this.GetEntityID())) mark=\(this.cls_bloodLogCount)/4 side=\(side) (-1=left,1=right) groundZ=\(position.Z) live=\(total) anchor=\(NameToString(anchor)) nativeFadeIn=0.25s spacing=1.0m scale=3x scatter=4cm direction=contact_travel headTowardTravel=true queryPhase=entity_event");
  }
}

@addMethod(NPCPuppet)
public final func CLS_UpdateCrawlBlood() -> Void {
  if !this.CLS_CanSmearCrawlBlood() { this.cls_bloodInitialized = false; return; }
  let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
  let position = this.GetWorldPosition();
  if !CrawlBlood.Valid(position) { this.cls_bloodInitialized = false; return; }
  if !this.cls_bloodInitialized {
    this.cls_bloodInitialized = true;
    this.cls_bloodPrevious = position;
    this.cls_bloodAt = now;
    // Let the crawler travel one metre before laying the first full-length
    // smear, so its trailing half does not paint behind the crawl's origin.
    this.cls_bloodCarry = 0.0;
    this.cls_bloodHasLeftContact = false;
    this.cls_bloodHasRightContact = false;
    return;
  }
  let elapsed = now - this.cls_bloodAt;
  if elapsed >= 0.0 && elapsed < CrawlBlood.SampleSeconds() { return; }
  let previous = this.cls_bloodPrevious;
  this.cls_bloodPrevious = position;
  this.cls_bloodAt = now;
  let delta = position - previous;
  let dz = delta.Z;
  delta.Z = 0.0;
  delta.W = 0.0;
  let distance = Vector4.Length(delta);
  // No catch-up trails across hitches, teleports, falls or action interruptions.
  if elapsed <= 0.0 || elapsed > 0.5 || distance > 0.72
    || distance / elapsed > 3.0 || AbsF(dz) > 0.35 {
    this.cls_bloodCarry = 0.0;
    this.cls_bloodHasLeftContact = false;
    this.cls_bloodHasRightContact = false;
    return;
  }
  if distance < 0.005 { return; }
  let direction = delta / distance;
  this.cls_bloodHeading = direction;
  let right = this.GetWorldRight();
  right.Z = 0.0;
  right.W = 0.0;
  if !CrawlBlood.Valid(right) || Vector4.Length(right) < 0.01 { this.cls_bloodCarry = 0.0; return; }
  right = Vector4.Normalize(right);
  let forward = this.GetWorldForward();
  forward.Z = 0.0;
  forward.W = 0.0;
  if !CrawlBlood.Valid(forward) || Vector4.Length(forward) < 0.01 { this.cls_bloodCarry = 0.0; return; }
  forward = Vector4.Normalize(forward);
  let left = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegLeft");
  let rightLeg = StatusEffectSystem.ObjectHasStatusEffect(this, t"BaseStatusEffect.DismemberedLegRight");
  let system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"CazanuLimbSurvival.CrawlBloodSystem");
  if !IsDefined(system) { return; }
  let consumed = 0.0;
  let needed = CrawlBlood.Spacing() - this.cls_bloodCarry;
  let steps = 0;
  while distance - consumed + 0.0001 >= needed && steps < 2 {
    consumed += needed;
    let request = new CLS_CrawlBloodSpawn();
    request.owner = this;
    request.position = previous + (position - previous) * MinF(1.0, consumed / distance);
    request.direction = direction;
    request.right = right;
    request.forward = forward;
    request.left = left;
    request.rightLeg = rightLeg;
    request.time = now;
    system.QueueRequest(request);
    this.cls_bloodCarry = 0.0;
    needed = CrawlBlood.Spacing();
    steps += 1;
  }
  // Only an established trail may add a newly missing leg immediately.
  // Otherwise this shortcut would bypass the first smear's travel delay.
  if steps == 0 && (this.cls_bloodHasLeftContact || this.cls_bloodHasRightContact)
    && ((left && !this.cls_bloodHasLeftContact) || (rightLeg && !this.cls_bloodHasRightContact)) {
    let first = new CLS_CrawlBloodSpawn();
    first.owner = this;
    first.position = position;
    first.direction = direction;
    first.right = right;
    first.forward = forward;
    first.left = left && !this.cls_bloodHasLeftContact;
    first.rightLeg = rightLeg && !this.cls_bloodHasRightContact;
    first.time = now;
    system.QueueRequest(first);
  }
  this.cls_bloodCarry = MinF(CrawlBlood.Spacing(), this.cls_bloodCarry + MaxF(0.0, distance - consumed));
}

// Final decals have their own two-variant pool and one body-centred placement.
// Crawlers trigger on death; shooting/pain trigger after their animation starts.
public class CLS_FinalBloodContactEvent extends Event {
  public let center: Vector4;
  public let heading: Vector4;
  public let time: Float;
}

@addMethod(NPCPuppet)
public final func CLS_CanPlaceFinalBlood() -> Bool {
  return this.cls_bloodFinalQueued && !this.cls_bloodFinalPlaced && this.CLS_FinalBloodStateValid();
}

@addMethod(NPCPuppet)
public final func CLS_FinalBloodStateValid() -> Bool {
  if !this.cls_extendedWoundStarted || !this.IsAttached() || this.CLS_IsMechanical() { return false; }
  if this.cls_legWoundMode == 1 { return this.IsDead(); }
  return (this.cls_legWoundMode == 2 || this.cls_legWoundMode == 3)
    && WoundTiming.Eligible(this) && !this.cls_groundedTimedDeath
    && !this.cls_seatedDamageDeath && !this.cls_seatedForeignWorkspot
    && this.CLS_SeatedActive() && this.CLS_IsOwnedGroundIdle();
}

@addMethod(NPCPuppet)
public final func CLS_FinalBloodPlaced(variant: Int32) -> Void {
  this.cls_bloodFinalPlaced = true;
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"FINAL_BLOOD npc=\(EntityID.ToDebugString(this.GetEntityID())) mode=\(this.cls_legWoundMode) (1=crawl_death,2=pain_after3s,3=shoot_after3s) count=1 variant=\(variant + 1)/2 fadeIn=0.25s queryPhase=entity_event");
  }
}

public class CLS_FinalBloodDelayEvent extends Event {}

@addMethod(NPCPuppet)
public final func CLS_StartFinalBloodDelay() -> Void {
  if this.cls_bloodFinalDelayStarted || this.cls_bloodFinalQueued
    || this.cls_legWoundMode == 1 || !this.CLS_FinalBloodStateValid() { return; }
  this.cls_bloodFinalDelayStarted = true;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, new CLS_FinalBloodDelayEvent(), 3.0, true);
  if Diagnostics.Enabled() {
    Diagnostics.Write(s"FINAL_BLOOD_TIMER npc=\(EntityID.ToDebugString(this.GetEntityID())) mode=\(this.cls_legWoundMode) delay=3.0s");
  }
}

@addMethod(NPCPuppet)
protected cb func OnCLS_FinalBloodDelayEvent(evt: ref<CLS_FinalBloodDelayEvent>) -> Bool {
  if !this.cls_bloodFinalDelayStarted || this.cls_legWoundMode == 1
    || !this.CLS_FinalBloodStateValid() { return false; }
  this.CLS_QueueFinalBloodContact();
  return true;
}

@addMethod(NPCPuppet)
private final func CLS_QueueFinalBloodContact() -> Void {
  if this.cls_bloodFinalQueued || this.CLS_IsMechanical() { return; }
  this.cls_bloodFinalQueued = true;
  let contact = new CLS_FinalBloodContactEvent();
  contact.center = this.GetWorldPosition();
  contact.heading = this.cls_legWoundMode == 1 ? this.cls_bloodHeading : this.GetWorldForward();
  if !CrawlBlood.Valid(contact.heading) || Vector4.Length(contact.heading) < 0.01 {
    contact.heading = this.GetWorldForward();
  }
  contact.heading.Z = 0.0;
  contact.heading.W = 0.0;
  contact.time = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
  this.QueueEvent(contact);
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  if this.cls_legWoundMode == 1 && this.cls_extendedWoundStarted && this.IsAttached() {
    // Capture before native ragdoll moves the crawler. The contact handler
    // requires confirmed death; the living pose timer cannot enter this path.
    this.CLS_QueueFinalBloodContact();
  }
  return wrappedMethod(evt);
}

@addMethod(NPCPuppet)
protected cb func OnCLS_FinalBloodContactEvent(evt: ref<CLS_FinalBloodContactEvent>) -> Bool {
  if !this.CLS_CanPlaceFinalBlood() || !CrawlBlood.Fresh(this.GetGame(), evt.time)
    || !CrawlBlood.Valid(evt.heading) || Vector4.Length(evt.heading) < 0.01 { return false; }
  let position: Vector4;
  let normal: Vector4;
  // The same fenced entity-event query phase as ordinary crawl contacts.
  if !CrawlBlood.Ground(this.GetGame(), evt.center, position, normal) { return false; }
  let along = evt.heading - normal * Vector4.Dot(evt.heading, normal);
  if !CrawlBlood.Valid(along) || Vector4.Length(along) < 0.01 { return false; }
  let system = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"CazanuLimbSurvival.CrawlBloodSystem");
  if !IsDefined(system) { return false; }
  let request = new CLS_CrawlBloodPlace();
  request.owner = this;
  request.position = position;
  request.normal = normal;
  request.along = Vector4.Normalize(along);
  request.time = evt.time;
  request.finalMark = true;
  system.QueueRequest(request);
  return true;
}
