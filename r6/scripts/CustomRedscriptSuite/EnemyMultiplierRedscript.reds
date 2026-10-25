// ============================================================================
// EnemyMultiplierRedscript.reds
// Replication of EnemyMultiplierRS 1.2.6 (Nexus #35088) using Codeware's
// native DynamicEntitySystem (Codeware 1.21.0+ / Cyberpunk 2077 Patch 2.50).
// No CET or ModSettings dependency.
//
// Stability architecture:
// - Uses Codeware's DynamicEntitySystem (GameInstance.GetDynamicEntitySystem())
//   for native PopulationSystem / EntityStubSystem lifecycle management.
// - Never hooks PreventionSpawnSystem.SpawnRequestFinished / DespawnCallback
//   and never calls EntityGameInterface.Destroy directly, preventing dangling
//   EntityStubSystem mappin pointers (0xC0000005 at +0x2fb6a8).
// - Caps active clones at 24 (upstream default) and cleans up distant dead
//   clones and ownerless clones via DynamicEntitySystem.DeleteEntity.
// ============================================================================

public class EMRS_Settings extends ScriptableSystem {

  // Clone hostile NPCs as they spawn. Turning this off also removes every clone alive.
  public let enabled: Bool = true;

  // Enemies per spawn, original included. 2 doubles every eligible enemy. Default 2 (range 1..5).
  public let multiplier: Int32 = 2;

  // Hard cap on clones in the world at once. New spawns are skipped past it. Default 24 (range 4..80).
  public let maxClones: Int32 = 24;

  // Only enemies that spawn within this distance (metres) of V are cloned. Default 60 (range 10..200).
  public let cloneRange: Int32 = 60;

  // How far from the original each clone is placed, in tenths of a metre (15 = 1.5m).
  // Snapped to the nearest walkable point on the human navmesh.
  public let cloneSpacing: Int32 = 15;

  // Include Elite and Rare rarity enemies. Bosses, MaxTac, Officers, and police are never cloned.
  public let cloneElites: Bool = true;

  // Also clone gang members who are not yet hostile to V.
  public let cloneNeutralGangers: Bool = true;

  // Also clone corporate, military, and security NPCs who are not yet hostile to V.
  public let cloneNeutralCorpos: Bool = false;

  // Clones roll their own outfit from the character's appearance list instead of copying the original's.
  public let randomizeAppearance: Bool = true;

  // Clones may spawn as a different character of the same faction and rarity seen this session.
  public let cloneSiblingRecords: Bool = false;

  // Log every clone decision to the game log.
  public let verboseLogging: Bool = false;

  public final static func Get(gi: GameInstance) -> ref<EMRS_Settings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"EMRS_Settings") as EMRS_Settings;
  }
}

public func EMRS_CloneTag() -> CName {
  return n"EMRS_Clone";
}

public func EMRS_TickSeconds() -> Float {
  return 0.5;
}

public func EMRS_QueuePerTick() -> Int32 {
  return 4;
}

public func EMRS_BacklogThreshold() -> Int32 {
  return 16;
}

public func EMRS_BacklogPerTick() -> Int32 {
  return 32;
}

public func EMRS_MaxInactiveQueue() -> Int32 {
  return 2048;
}

public func EMRS_MaxQueue() -> Int32 {
  return 512;
}

public func EMRS_WarmupSeconds() -> Float {
  return 8.0;
}

public func EMRS_SweepEveryTicks() -> Int32 {
  return 4;
}

public func EMRS_RecheckEveryTicks() -> Int32 {
  return 2;
}

public func EMRS_MaxPending() -> Int32 {
  return 128;
}

public func EMRS_MaxPool() -> Int32 {
  return 256;
}

public func EMRS_IsCorpoOrSecurity(affiliation: gamedataAffiliation) -> Bool {
  return Equals(affiliation, gamedataAffiliation.Arasaka)
    || Equals(affiliation, gamedataAffiliation.Militech)
    || Equals(affiliation, gamedataAffiliation.KangTao)
    || Equals(affiliation, gamedataAffiliation.NetWatch)
    || Equals(affiliation, gamedataAffiliation.Biotechnica)
    || Equals(affiliation, gamedataAffiliation.Zetatech)
    || Equals(affiliation, gamedataAffiliation.SSI)
    || Equals(affiliation, gamedataAffiliation.NUSA)
    || Equals(affiliation, gamedataAffiliation.Barghest)
    || Equals(affiliation, gamedataAffiliation.UnaffiliatedCorpo);
}

public func EMRS_MinDeferredMetres() -> Float {
  return 20.0;
}

public func EMRS_FirstDeferredCode() -> Int32 {
  return 20;
}

public func EMRS_LastDeferredCode() -> Int32 {
  return 22;
}

public func EMRS_ReasonText(code: Int32) -> String {
  if code == 1 {
    return "our clone";
  };
  if code == 2 {
    return "dead or defeated";
  };
  if code == 3 {
    return "crowd";
  };
  if code == 4 {
    return "civilian";
  };
  if code == 5 {
    return "police";
  };
  if code == 6 {
    return "child";
  };
  if code == 8 {
    return "companion";
  };
  if code == 9 {
    return "boss, MaxTac or officer";
  };
  if code == 10 {
    return "elite or rare, setting off";
  };
  if code == 11 {
    return "named quest character";
  };
  if code == 20 {
    return "in a vehicle, pending";
  };
  if code == 21 {
    return "not hostile, pending";
  };
  if code == 22 {
    return "out of range, pending";
  };
  if code == 23 {
    return "clone cap reached";
  };
  if code == 24 {
    return "already in combat, no late clone";
  };
  if code == 25 {
    return "too close to spawn unseen";
  };
  return "unclassified";
}

public func EMRS_OutcomeSettled() -> Int32 {
  return 0;
}

public func EMRS_OutcomePending() -> Int32 {
  return 1;
}

public func EMRS_OutcomeGone() -> Int32 {
  return 2;
}

public func EMRS_Log(msg: String) -> Void {
  let line: String = "[EnemyMultiplierRS] " + msg;
  FTLog(line);
}

public class EMRS_EnqueueRequest extends ScriptableSystemRequest {
  public let entityID: EntityID;
}

public class EMRS_System extends ScriptableSystem {
  private let m_active: Bool;
  private let m_tickRunning: Bool;
  private let m_tickGen: Int32;
  private let m_tickCount: Int32;
  private let m_queue: array<EntityID>;
  private let m_pending: array<EntityID>;
  private let m_pendingDist: array<Float>;
  private let m_seen: array<EntityID>;
  private let m_clones: array<EntityID>;
  private let m_cloneOwner: array<EntityID>;
  private let m_poolRecords: array<TweakDBID>;
  private let m_poolAffiliation: array<gamedataAffiliation>;
  private let m_poolRarity: array<gamedataNPCRarity>;

  public final static func Get(gi: GameInstance) -> ref<EMRS_System> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"EMRS_System") as EMRS_System;
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.ResetTracking();
    this.m_tickGen += 1;
    this.m_active = true;
    this.m_tickRunning = true;
    this.ScheduleTickIn(EMRS_WarmupSeconds());
    if this.Verbose() {
      let line: String = "player attached, multiplier active, " + ToString(ArraySize(this.m_queue)) + " NPCs queued from the load";
      EMRS_Log(line);
    };
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.m_active = false;
    this.m_tickRunning = false;
    this.m_tickGen += 1;
    this.DeleteAllClones("player detached");
    ArrayClear(this.m_queue);
    this.ResetTracking();
  }

  private func ResetTracking() -> Void {
    ArrayClear(this.m_pending);
    ArrayClear(this.m_pendingDist);
    ArrayClear(this.m_seen);
    ArrayClear(this.m_clones);
    ArrayClear(this.m_cloneOwner);
    this.m_tickCount = 0;
  }

  private func Verbose() -> Bool {
    let s: ref<EMRS_Settings> = EMRS_Settings.Get(this.GetGameInstance());
    return IsDefined(s) && s.verboseLogging;
  }

  public func Enqueue(id: EntityID) -> Void {
    if !EntityID.IsDefined(id) {
      return;
    };
    let cap: Int32 = EMRS_MaxQueue();
    if !this.m_active {
      cap = EMRS_MaxInactiveQueue();
    };
    if ArraySize(this.m_queue) >= cap {
      return;
    };
    if ArrayContains(this.m_queue, id) || ArrayContains(this.m_pending, id) || ArrayContains(this.m_seen, id) || ArrayContains(this.m_clones, id) {
      return;
    };
    ArrayPush(this.m_queue, id);
  }

  private func OnEnqueueRequest(request: ref<EMRS_EnqueueRequest>) -> Void {
    if IsDefined(request) {
      this.Enqueue(request.entityID);
    };
  }

  public func IsTickRunning() -> Bool {
    return this.m_tickRunning;
  }

  public func TickGen() -> Int32 {
    return this.m_tickGen;
  }

  public func ScheduleTickIn(delay: Float) -> Void {
    if !this.m_tickRunning {
      return;
    };
    let cb: ref<EMRS_TickCallback> = new EMRS_TickCallback();
    cb.system = this;
    cb.gen = this.m_tickGen;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delay, false);
  }

  public func ScheduleTick() -> Void {
    this.ScheduleTickIn(EMRS_TickSeconds());
  }

  public func Tick() -> Void {
    if !this.m_active {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let s: ref<EMRS_Settings> = EMRS_Settings.Get(gi);
    if !IsDefined(s) {
      return;
    };
    if !s.enabled {
      if ArraySize(this.m_clones) > 0 {
        this.DeleteAllClones("disabled in settings");
      };
      ArrayClear(this.m_queue);
      ArrayClear(this.m_pending);
      ArrayClear(this.m_pendingDist);
      return;
    };
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) || player.IsDead() {
      return;
    };
    this.m_tickCount += 1;
    if this.m_tickCount % EMRS_SweepEveryTicks() == 0 {
      this.SweepClones(gi);
    };
    let budget: Int32 = EMRS_QueuePerTick();
    if ArraySize(this.m_queue) > EMRS_BacklogThreshold() {
      budget = EMRS_BacklogPerTick();
    };
    while budget > 0 && ArraySize(this.m_queue) > 0 {
      let last: Int32 = ArraySize(this.m_queue) - 1;
      let id: EntityID = this.m_queue[last];
      ArrayErase(this.m_queue, last);
      let dist: Float = 0.0;
      let outcome: Int32 = this.Consider(gi, s, player, id, true, dist);
      this.Route(id, outcome, dist);
      budget -= 1;
    };
    if this.m_tickCount % EMRS_RecheckEveryTicks() == 0 {
      this.RecheckPending(gi, s, player);
    };
    while ArraySize(this.m_seen) > 400 {
      ArrayErase(this.m_seen, 0);
    };
  }

  private func Route(id: EntityID, outcome: Int32, dist: Float) -> Void {
    if outcome == EMRS_OutcomeSettled() {
      ArrayPush(this.m_seen, id);
      return;
    };
    if outcome == EMRS_OutcomePending() {
      this.Defer(id, dist);
      return;
    };
  }

  private func Defer(id: EntityID, dist: Float) -> Void {
    if ArrayContains(this.m_pending, id) {
      return;
    };
    ArrayPush(this.m_pending, id);
    ArrayPush(this.m_pendingDist, dist);
    while ArraySize(this.m_pending) > EMRS_MaxPending() {
      this.EvictFarthest();
    };
  }

  private func EvictFarthest() -> Void {
    let n: Int32 = ArraySize(this.m_pending);
    if n == 0 {
      return;
    };
    let worst: Int32 = 0;
    let i: Int32 = 1;
    while i < n {
      if this.m_pendingDist[i] > this.m_pendingDist[worst] {
        worst = i;
      };
      i += 1;
    };
    ArrayErase(this.m_pending, worst);
    ArrayErase(this.m_pendingDist, worst);
  }

  private func RecheckPending(gi: GameInstance, s: ref<EMRS_Settings>, player: ref<PlayerPuppet>) -> Void {
    let i: Int32 = ArraySize(this.m_pending) - 1;
    while i >= 0 {
      let id: EntityID = this.m_pending[i];
      let dist: Float = 0.0;
      let outcome: Int32 = this.Consider(gi, s, player, id, false, dist);
      if outcome == EMRS_OutcomeSettled() {
        ArrayErase(this.m_pending, i);
        ArrayErase(this.m_pendingDist, i);
        ArrayPush(this.m_seen, id);
      } else {
        if outcome == EMRS_OutcomeGone() {
          ArrayErase(this.m_pending, i);
          ArrayErase(this.m_pendingDist, i);
        } else {
          this.m_pendingDist[i] = dist;
        };
      };
      i -= 1;
    };
  }

  private func Consider(gi: GameInstance, s: ref<EMRS_Settings>, player: ref<PlayerPuppet>, id: EntityID, firstLook: Bool, out dist: Float) -> Int32 {
    let npc: ref<NPCPuppet> = GameInstance.FindEntityByID(gi, id) as NPCPuppet;
    if !IsDefined(npc) || !npc.IsAttached() {
      return EMRS_OutcomeGone();
    };
    dist = Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition());
    let code: Int32 = this.Ineligible(gi, s, player, npc, firstLook, dist);
    if code > 0 {
      if (firstLook || code > EMRS_LastDeferredCode()) && s.verboseLogging {
        let detail: String = EMRS_ReasonText(code);
        if code == 22 || code == 25 {
          detail = detail + " (" + FloatToStringPrec(dist, 0) + " m)";
        };
        EMRS_Log("skip " + TDBID.ToStringDEBUG(npc.GetRecordID()) + ": " + detail);
      };
      if code >= EMRS_FirstDeferredCode() && code <= EMRS_LastDeferredCode() {
        return EMRS_OutcomePending();
      };
      return EMRS_OutcomeSettled();
    };
    let wanted: Int32 = s.multiplier - 1;
    if wanted <= 0 {
      return EMRS_OutcomeSettled();
    };
    let room: Int32 = s.maxClones - ArraySize(this.m_clones);
    if room <= 0 {
      if s.verboseLogging {
        EMRS_Log("skip " + TDBID.ToStringDEBUG(npc.GetRecordID()) + ": " + EMRS_ReasonText(23) + " (" + ToString(ArraySize(this.m_clones)) + ")");
      };
      return EMRS_OutcomeSettled();
    };
    if wanted > room {
      wanted = room;
    };
    let made: Int32 = 0;
    let i: Int32 = 0;
    while i < wanted {
      if this.SpawnClone(gi, s, npc, i, wanted) {
        made += 1;
      };
      i += 1;
    };
    if s.verboseLogging {
      EMRS_Log("cloned " + TDBID.ToStringDEBUG(npc.GetRecordID()) + " x" + ToString(made) + " (" + ToString(ArraySize(this.m_clones)) + " clones alive)");
    };
    return EMRS_OutcomeSettled();
  }

  private func Ineligible(gi: GameInstance, s: ref<EMRS_Settings>, player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, firstLook: Bool, dist: Float) -> Int32 {
    let npcID: EntityID = npc.GetEntityID();
    let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if npc.HasTag(EMRS_CloneTag()) || ArrayContains(this.m_clones, npcID) || (IsDefined(des) && (des.IsManaged(npcID) || des.IsTagged(npcID, EMRS_CloneTag()))) {
      return 1;
    };
    if npc.IsDead() || ScriptedPuppet.IsDefeated(npc) {
      return 2;
    };
    if !firstLook && Equals(npc.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
      return 24;
    };
    if npc.IsCrowd() {
      return 3;
    };
    if npc.IsCharacterCivilian() {
      return 4;
    };
    if npc.IsCharacterPolice() {
      return 5;
    };
    if npc.IsCharacterChildren() {
      return 6;
    };
    if npc.IsPlayerCompanion() {
      return 8;
    };
    let rarity: gamedataNPCRarity = npc.GetNPCRarity();
    if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) || Equals(rarity, gamedataNPCRarity.Officer) {
      return 9;
    };
    if !s.cloneElites && (Equals(rarity, gamedataNPCRarity.Elite) || Equals(rarity, gamedataNPCRarity.Rare)) {
      return 10;
    };
    let record: wref<Character_Record> = npc.GetRecord();
    if IsDefined(record) {
      let nameplate: wref<UINameplate_Record> = record.UiNameplate();
      if IsDefined(nameplate) && nameplate.GetID() == t"UINameplate.QuestSettings" {
        return 11;
      };
    };
    if IsDefined(record) {
      this.RememberRecord(record, rarity);
    };
    if VehicleComponent.IsMountedToVehicle(gi, npc) {
      return 20;
    };
    let hostile: Bool = Equals(npc.GetAttitudeTowards(player), EAIAttitude.AIA_Hostile);
    if !hostile {
      let neutralOk: Bool = s.cloneNeutralGangers && npc.IsCharacterGanger();
      if !neutralOk && s.cloneNeutralCorpos && IsDefined(record) {
        let faction: wref<Affiliation_Record> = record.Affiliation();
        if IsDefined(faction) && EMRS_IsCorpoOrSecurity(faction.Type()) {
          neutralOk = true;
        };
      };
      if !neutralOk {
        return 21;
      };
    };
    if dist > Cast<Float>(s.cloneRange) {
      return 22;
    };
    if !firstLook && dist < EMRS_MinDeferredMetres() {
      return 25;
    };
    return 0;
  }

  private func RememberRecord(record: wref<Character_Record>, rarity: gamedataNPCRarity) -> Void {
    let recordID: TweakDBID = record.GetID();
    if ArrayContains(this.m_poolRecords, recordID) {
      return;
    };
    let faction: wref<Affiliation_Record> = record.Affiliation();
    if !IsDefined(faction) {
      return;
    };
    ArrayPush(this.m_poolRecords, recordID);
    ArrayPush(this.m_poolAffiliation, faction.Type());
    ArrayPush(this.m_poolRarity, rarity);
    while ArraySize(this.m_poolRecords) > EMRS_MaxPool() {
      ArrayErase(this.m_poolRecords, 0);
      ArrayErase(this.m_poolAffiliation, 0);
      ArrayErase(this.m_poolRarity, 0);
    };
  }

  private func PickSibling(original: ref<NPCPuppet>) -> TweakDBID {
    let own: TweakDBID = original.GetRecordID();
    let record: wref<Character_Record> = original.GetRecord();
    if !IsDefined(record) {
      return own;
    };
    let faction: wref<Affiliation_Record> = record.Affiliation();
    if !IsDefined(faction) {
      return own;
    };
    let wantAffiliation: gamedataAffiliation = faction.Type();
    let wantRarity: gamedataNPCRarity = original.GetNPCRarity();
    let candidates: array<TweakDBID>;
    let i: Int32 = 0;
    let n: Int32 = ArraySize(this.m_poolRecords);
    while i < n {
      if Equals(this.m_poolAffiliation[i], wantAffiliation) && Equals(this.m_poolRarity[i], wantRarity) {
        ArrayPush(candidates, this.m_poolRecords[i]);
      };
      i += 1;
    };
    if ArraySize(candidates) == 0 {
      return own;
    };
    return candidates[RandRange(0, ArraySize(candidates))];
  }

  private func PlaceOnNavmesh(gi: GameInstance, originalPos: Vector4, wished: Vector4, spacing: Float, out placed: Vector4) -> Int32 {
    let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(gi);
    placed = originalPos;
    if !IsDefined(nav) {
      return 2;
    };
    let result: NavigationFindPointResult = nav.FindPointInSphereOnlyHumanNavmesh(wished, spacing * 0.5, NavGenAgentSize.Human, true);
    if Equals(result.status, worldNavigationRequestStatus.OK) {
      placed = result.point;
      return 0;
    };
    result = nav.FindPointInSphereOnlyHumanNavmesh(originalPos, spacing, NavGenAgentSize.Human, true);
    if Equals(result.status, worldNavigationRequestStatus.OK) {
      placed = result.point;
      return 1;
    };
    return 2;
  }

  private func SpawnClone(gi: GameInstance, s: ref<EMRS_Settings>, original: ref<NPCPuppet>, index: Int32, count: Int32) -> Bool {
    let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(des) || !des.IsReady() {
      return false;
    };
    let pos: Vector4 = original.GetWorldPosition();
    let spacing: Float = Cast<Float>(s.cloneSpacing) / 10.0;
    let angle: Float = 6.2831853 * Cast<Float>(index + 1) / Cast<Float>(count + 1);
    let offset: Vector4 = new Vector4(CosF(angle) * spacing, SinF(angle) * spacing, 0.0, 0.0);
    let placed: Vector4 = pos;
    let placement: Int32 = this.PlaceOnNavmesh(gi, pos, pos + offset, spacing, placed);
    if s.verboseLogging && placement > 0 {
      let why: String = "stacked on original, no walkable point: ";
      if placement == 1 {
        why = "placed near original, ring point not walkable: ";
      };
      let line: String = why + TDBID.ToStringDEBUG(original.GetRecordID());
      EMRS_Log(line);
    };
    let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
    let ownRecord: TweakDBID = original.GetRecordID();
    spec.recordID = ownRecord;
    if s.cloneSiblingRecords {
      spec.recordID = this.PickSibling(original);
    };
    let appearance: CName = original.GetCurrentAppearanceName();
    if s.randomizeAppearance || spec.recordID != ownRecord || !IsNameValid(appearance) {
      spec.appearanceName = n"random";
    } else {
      spec.appearanceName = appearance;
    };
    if s.verboseLogging && spec.recordID != ownRecord {
      let line: String = "sibling " + TDBID.ToStringDEBUG(ownRecord) + " -> " + TDBID.ToStringDEBUG(spec.recordID);
      EMRS_Log(line);
    };
    spec.position = placed;
    spec.orientation = original.GetWorldOrientation();
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.spawnInView = true;
    spec.alwaysSpawned = true;
    spec.active = true;
    ArrayPush(spec.tags, EMRS_CloneTag());
    let cloneID: EntityID = des.CreateEntity(spec);
    if !EntityID.IsDefined(cloneID) {
      return false;
    };
    ArrayPush(this.m_clones, cloneID);
    ArrayPush(this.m_cloneOwner, original.GetEntityID());
    return true;
  }

  private func SweepClones(gi: GameInstance) -> Void {
    let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    let i: Int32 = ArraySize(this.m_clones) - 1;
    while i >= 0 {
      let cloneID: EntityID = this.m_clones[i];
      if IsDefined(des) && !des.IsManaged(cloneID) {
        ArrayErase(this.m_clones, i);
        ArrayErase(this.m_cloneOwner, i);
      } else {
        let owner: ref<Entity> = GameInstance.FindEntityByID(gi, this.m_cloneOwner[i]);
        let shouldDelete: Bool = !IsDefined(owner);
        if !shouldDelete && IsDefined(player) {
          let cloneNpc: ref<NPCPuppet> = GameInstance.FindEntityByID(gi, cloneID) as NPCPuppet;
          if IsDefined(cloneNpc) && (cloneNpc.IsDead() || ScriptedPuppet.IsDefeated(cloneNpc)) {
            if Vector4.Distance(cloneNpc.GetWorldPosition(), player.GetWorldPosition()) > 45.0 {
              shouldDelete = true;
            };
          };
        };
        if shouldDelete {
          if IsDefined(des) && des.IsManaged(cloneID) {
            des.DeleteEntity(cloneID);
          };
          ArrayErase(this.m_clones, i);
          ArrayErase(this.m_cloneOwner, i);
          if this.Verbose() {
            EMRS_Log("clone removed, original gone or distant corpse");
          };
        };
      };
      i -= 1;
    };
  }

  private func DeleteAllClones(why: String) -> Void {
    let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let n: Int32 = ArraySize(this.m_clones);
    if IsDefined(des) {
      let i: Int32 = 0;
      while i < n {
        if des.IsManaged(this.m_clones[i]) {
          des.DeleteEntity(this.m_clones[i]);
        };
        i += 1;
      };
    };
    ArrayClear(this.m_clones);
    ArrayClear(this.m_cloneOwner);
    if n > 0 && this.Verbose() {
      EMRS_Log("removed " + ToString(n) + " clones (" + why + ")");
    };
  }

  public func CloneCount() -> Int32 {
    return ArraySize(this.m_clones);
  }

  public func PendingCount() -> Int32 {
    return ArraySize(this.m_pending);
  }

  public func PoolCount() -> Int32 {
    return ArraySize(this.m_poolRecords);
  }
}

public class EMRS_TickCallback extends DelayCallback {
  public let system: wref<EMRS_System>;
  public let gen: Int32;

  public func Call() -> Void {
    let sys: ref<EMRS_System> = this.system;
    if !IsDefined(sys) || !sys.IsTickRunning() {
      return;
    };
    if this.gen != sys.TickGen() {
      return;
    };
    sys.Tick();
    sys.ScheduleTick();
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let sys: ref<EMRS_System> = EMRS_System.Get(this.GetGame());
  if IsDefined(sys) {
    let req: ref<EMRS_EnqueueRequest> = new EMRS_EnqueueRequest();
    req.entityID = this.GetEntityID();
    sys.QueueRequest(req);
  };
  return result;
}

public static exec func EMRS_Status(gi: GameInstance) -> Void {
  let sys: ref<EMRS_System> = EMRS_System.Get(gi);
  let s: ref<EMRS_Settings> = EMRS_Settings.Get(gi);
  if IsDefined(sys) && IsDefined(s) {
    let line: String = "enabled=" + ToString(s.enabled) + " multiplier=" + ToString(s.multiplier)
      + " range=" + ToString(s.cloneRange) + " spacing=" + ToString(s.cloneSpacing) + " elites=" + ToString(s.cloneElites)
      + " neutralGangers=" + ToString(s.cloneNeutralGangers)
      + " neutralCorpos=" + ToString(s.cloneNeutralCorpos)
      + " randomLook=" + ToString(s.randomizeAppearance) + " siblings=" + ToString(s.cloneSiblingRecords)
      + " pool=" + ToString(sys.PoolCount())
      + " clones=" + ToString(sys.CloneCount()) + " cap=" + ToString(s.maxClones)
      + " pending=" + ToString(sys.PendingCount());
    EMRS_Log(line);
  };
}
