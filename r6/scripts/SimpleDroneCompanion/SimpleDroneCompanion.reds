// SimpleDroneCompanion
//
// A source-controlled, vanilla-first companion backend for two session-bound
// Militech Minotaurs.  It deliberately owns only lifecycle, fixed input, the
// follower role, and a bounded watchdog.  There is no CET/Lua, Mod Settings,
// localization, persistence, JSON, custom archive, or fleet UI.
//
// C1 + C2 are represented by a small record seam: the declarative
// SimpleDroneMinotaurA/B records carry the fixed weapon package, while the
// vanilla Character.militech_base_minotaur ID is retained as a safe fallback
// if a future TweakXL load omits the private records.  Replacing that seam
// does not change the entity lifecycle or combat hooks.

module SimpleDroneCompanion

public func SDC_Tag() -> CName {
  return n"SimpleDroneCompanion";
}

public func SDC_MaxDrones() -> Int32 {
  return 2;
}

public func SDC_VanillaRecord() -> TweakDBID {
  return t"Character.militech_base_minotaur";
}

public func SDC_StaticRecord(slot: Int32) -> TweakDBID {
  if slot == 1 {
    return t"Character.SimpleDroneMinotaurB";
  };
  return t"Character.SimpleDroneMinotaurA";
}

public func SDC_WeaponRecord() -> TweakDBID {
  return t"SimpleDroneCompanion.MinotaurWeapon";
}

public func SDC_WeaponLeftRecord() -> TweakDBID {
  return t"SimpleDroneCompanion.MinotaurWeaponLeft";
}

// Comparison seam for the later smoke-test pass.  Keep this source-level
// constant false while W1's deterministic weapon package is selected; a
// reviewed Git edit can make C1 (the untouched vanilla record) the primary
// path without changing lifecycle, input, or combat code.
public func SDC_UseVanillaRecordPath() -> Bool {
  return false;
}

public func SDC_RecordForSlot(slot: Int32) -> TweakDBID {
  // C2 is the primary path because it is the only path that can carry W1's
  // static weapon record.  The source-level C1 switch and missing-record
  // fallback keep the vanilla implementation available for comparison.
  if SDC_UseVanillaRecordPath() {
    return SDC_VanillaRecord();
  };
  let staticRecord: TweakDBID = SDC_StaticRecord(slot);
  if IsDefined(TweakDBInterface.GetRecord(staticRecord)) {
    return staticRecord;
  };
  return SDC_VanillaRecord();
}

@addField(ScriptedPuppet)
public let m_sdcCompanion: Bool;

@addField(ScriptedPuppet)
public let m_sdcSlot: Int32;

@wrapMethod(ScriptedPuppet)
protected cb func OnDetach() -> Bool {
  // DynamicEntitySystem may reuse a streamed puppet object.  Clear the
  // marker before the engine releases it so a later ordinary NPC can never
  // inherit companion combat rules or kill-credit routing.
  this.m_sdcCompanion = false;
  this.m_sdcSlot = -1;
  return wrappedMethod();
}

public func SDC_IsCompanion(obj: wref<GameObject>) -> Bool {
  let puppet: wref<ScriptedPuppet> = obj as ScriptedPuppet;
  return IsDefined(puppet) && puppet.m_sdcCompanion;
}

private func SDC_Player(gi: GameInstance) -> ref<PlayerPuppet> {
  return GetPlayer(gi);
}

private func SDC_ValidPlayer(player: wref<PlayerPuppet>) -> Bool {
  return IsDefined(player) && player.IsAttached() && !player.IsDead();
}

private func SDC_OffsetForSlot(slot: Int32) -> Vector4 {
  if slot == 1 {
    return new Vector4(-3.0, -1.5, 0.0, 0.0);
  };
  return new Vector4(3.0, -1.5, 0.0, 0.0);
}

private func SDC_SpawnPosition(player: ref<PlayerPuppet>, slot: Int32) -> Vector4 {
  let desired: Vector4 = player.GetWorldPosition() + SDC_OffsetForSlot(slot);
  let navigation: ref<NavigationSystem> = GameInstance.GetNavigationSystem(player.GetGame());
  if !IsDefined(navigation) {
    return desired;
  };
  let result: NavigationFindPointResult = navigation.FindPointInSphereOnlyHumanNavmesh(
    desired, 3.0, NavGenAgentSize.Human, true);
  if Equals(result.status, worldNavigationRequestStatus.OK) {
    return result.point;
  };
  return desired;
}

public func SDC_IsDeadLike(puppet: wref<ScriptedPuppet>) -> Bool {
  if !IsDefined(puppet) {
    return true;
  };
  if puppet.IsDead() || ScriptedPuppet.IsDefeated(puppet) || ScriptedPuppet.IsUnconscious(puppet) {
    return true;
  };
  let state: gamedataNPCHighLevelState = puppet.GetHighLevelStateFromBlackboard();
  return Equals(state, gamedataNPCHighLevelState.Dead)
    || Equals(state, gamedataNPCHighLevelState.Unconscious);
}

private func SDC_ApplyFollowerRole(puppet: ref<NPCPuppet>, player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(puppet) || !IsDefined(player) {
    return;
  };
  let attitude = puppet.GetAttitudeAgent();
  let playerAttitude = player.GetAttitudeAgent();
  if IsDefined(attitude) && IsDefined(playerAttitude) {
    attitude.SetAttitudeGroup(playerAttitude.GetAttitudeGroup());
    attitude.SetAttitudeTowards(playerAttitude, EAIAttitude.AIA_Friendly);
  };

  let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
  if !IsDefined(ai) {
    return;
  };
  let names: array<CName>;
  let role: ref<AIFollowerRole> = new AIFollowerRole();
  role.SetSimpleDroneFollowerRef(CreateEntityReference("#player", names));
  let roleCommand: ref<AIAssignRoleCommand> = new AIAssignRoleCommand();
  roleCommand.role = role;
  ai.SendCommand(roleCommand);

  let tracker: ref<TargetTrackerComponent> = puppet.GetTargetTrackerComponent();
  if IsDefined(tracker) {
    tracker.SetCurrentPreset(t"TargetTracking.FollowerPreset");
  };

  SDC_IssueFollow(puppet, player);
}

// A2 seam: the selected vanilla follower path is always attempted first.  If
// the engine rejects that command (for example while a Minotaur is restored
// from a streaming boundary), this fixed direct move command is the minimal
// custom fallback.  It is not a scheduler, setting, or second AI package.
public func SDC_TryCustomFollowFallback(puppet: ref<NPCPuppet>, player: ref<PlayerPuppet>) -> Bool {
  if !IsDefined(puppet) || !IsDefined(player) {
    return false;
  };
  let state: gamedataNPCHighLevelState = puppet.GetHighLevelStateFromBlackboard();
  if Equals(state, gamedataNPCHighLevelState.Combat) || Equals(state, gamedataNPCHighLevelState.Alerted) {
    return false;
  };
  let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
  if !IsDefined(ai) {
    return false;
  };
  let move: ref<AIMoveToCommand> = new AIMoveToCommand();
  let position: WorldPosition;
  WorldPosition.SetVector4(position, player.GetWorldPosition());
  AIPositionSpec.SetWorldPosition(move.movementTarget, position);
  move.movementType = moveMovementType.Run;
  move.ignoreNavigation = false;
  move.desiredDistanceFromTarget = 7.0;
  move.finishWhenDestinationReached = true;
  move.ignoreInCombat = false;
  return ai.SendCommand(move);
}

private func SDC_IssueFollow(puppet: ref<NPCPuppet>, player: ref<PlayerPuppet>) -> Void {
  if !IsDefined(puppet) || !IsDefined(player) {
    return;
  };
  let state: gamedataNPCHighLevelState = puppet.GetHighLevelStateFromBlackboard();
  if Equals(state, gamedataNPCHighLevelState.Combat) || Equals(state, gamedataNPCHighLevelState.Alerted) {
    return;
  };
  let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
  if !IsDefined(ai) || ai.IsCommandActive(n"AIFollowTargetCommand") {
    return;
  };
  let follow: ref<AIFollowTargetCommand> = new AIFollowTargetCommand();
  follow.target = player;
  follow.desiredDistance = 9.0;
  follow.tolerance = 3.0;
  follow.lookAtTarget = player;
  follow.matchSpeed = true;
  follow.stopWhenDestinationReached = false;
  follow.teleport = false;
  follow.movementType = moveMovementType.Run;
  if !ai.SendCommand(follow) {
    SDC_TryCustomFollowFallback(puppet, player);
  };
}

public class SDC_System extends ScriptableSystem {
  private let m_active: Bool;
  private let m_listenerRegistered: Bool;
  private let m_inputRegistered: Bool;
  private let m_padModifierHeld: Bool;
  private let m_lastInputAt: Float;
  private let m_watchdogRunning: Bool;
  private let m_generation: Int32;
  private let m_watchdogGeneration: Int32;
  private let m_tickID: DelayID;
  private let m_slotIDs: array<EntityID>;
  private let m_slotPending: array<Bool>;
  private let m_slotGeneration: array<Int32>;

  public final static func Get(gi: GameInstance) -> ref<SDC_System> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"SDC_System") as SDC_System;
  }

  private func OnAttach() -> Void {
    this.m_tickID = GetInvalidDelayID();
    this.m_lastInputAt = -1.0;
    this.ResetSlots();
  }

  private func OnDetach() -> Void {
    this.m_generation += 1;
    this.m_active = false;
    this.m_watchdogRunning = false;
    this.CancelWatchdog();
    this.DeleteAll();
    this.UnregisterInputListener();
    this.UnregisterDynamicListener();
    this.ResetSlots();
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_generation += 1;
    this.m_active = true;
    // A repeated attach can occur across a save transition without a fully
    // ordered detach callback.  Retire any still-managed IDs before replacing
    // the slot table, otherwise the next session would orphan dynamic bodies.
    this.DeleteAll();
    this.ResetSlots();
    this.RegisterInputListener();
    this.RegisterDynamicListener();
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.m_generation += 1;
    this.m_active = false;
    this.m_watchdogRunning = false;
    this.CancelWatchdog();
    this.DeleteAll();
    this.UnregisterInputListener();
    this.UnregisterDynamicListener();
    this.ResetSlots();
  }

  private func ResetSlots() -> Void {
    let i: Int32 = 0;
    ArrayClear(this.m_slotIDs);
    ArrayClear(this.m_slotPending);
    ArrayClear(this.m_slotGeneration);
    while i < SDC_MaxDrones() {
      let invalidID: EntityID;
      ArrayPush(this.m_slotIDs, invalidID);
      ArrayPush(this.m_slotPending, false);
      ArrayPush(this.m_slotGeneration, 0);
      i += 1;
    };
  }

  private func RegisterDynamicListener() -> Void {
    if this.m_listenerRegistered {
      return;
    };
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(dynamicEntities) {
      return;
    };
    dynamicEntities.RegisterListener(SDC_Tag(), this, n"OnSDCDynamicEntityEvent");
    this.m_listenerRegistered = true;
  }

  private func UnregisterDynamicListener() -> Void {
    if !this.m_listenerRegistered {
      return;
    };
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if IsDefined(dynamicEntities) {
      dynamicEntities.UnregisterListener(SDC_Tag(), this, n"OnSDCDynamicEntityEvent");
    };
    this.m_listenerRegistered = false;
  }

  private func RegisterInputListener() -> Void {
    if this.m_inputRegistered {
      return;
    };
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnSDCKeyInput")
      .SetLifetime(CallbackLifetime.Session);
    this.m_inputRegistered = true;
  }

  private func UnregisterInputListener() -> Void {
    if !this.m_inputRegistered {
      return;
    };
    GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnSDCKeyInput");
    this.m_inputRegistered = false;
    this.m_padModifierHeld = false;
  }

  private cb func OnSDCKeyInput(event: ref<KeyInputEvent>) -> Void {
    if !IsDefined(event) {
      return;
    };
    let key: EInputKey = event.GetKey();
    if Equals(key, EInputKey.IK_Pad_LeftShoulder) {
      this.m_padModifierHeld = !Equals(event.GetAction(), EInputAction.IACT_Release);
      return;
    };
    if !Equals(event.GetAction(), EInputAction.IACT_Press) {
      return;
    };
    let keyboard: Bool = Equals(key, EInputKey.IK_F9);
    let controller: Bool = this.m_padModifierHeld && Equals(key, EInputKey.IK_Pad_X_SQUARE);
    if !keyboard && !controller {
      return;
    };
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return;
    };
    let player: ref<PlayerPuppet> = SDC_Player(this.GetGameInstance());
    if !SDC_ValidPlayer(player) {
      return;
    };
    this.TryToggleFromInput();
  }

  public func TryToggleFromInput() -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    if this.m_lastInputAt >= 0.0 && now - this.m_lastInputAt < 0.25 {
      return;
    };
    this.m_lastInputAt = now;
    this.Toggle();
  }

  public func Toggle() -> Void {
    if !this.m_active {
      return;
    };
    let active: Int32 = this.ActiveCount();
    if active > 0 {
      this.DeleteAll();
      this.ShowVanillaMessage("DRONES DISMISSED");
      return;
    };
    this.SpawnAll();
  }

  private func ShowVanillaMessage(message: String) -> Void {
    // Vanilla warning-message channel; no custom widget, localization file,
    // or Codeware UI layer is introduced for U1 feedback.
    PreventionSystem.ShowMessage(this.GetGameInstance(), message, 3.0);
  }

  public func ActiveCount() -> Int32 {
    let count: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(this.m_slotIDs) {
      if EntityID.IsDefined(this.m_slotIDs[i]) {
        count += 1;
      };
      i += 1;
    };
    return count;
  }

  public func IsActiveDrone(obj: wref<GameObject>) -> Bool {
    return SDC_IsCompanion(obj);
  }

  public func SpawnAll() -> Void {
    let player: ref<PlayerPuppet> = SDC_Player(this.GetGameInstance());
    if !this.m_active || !SDC_ValidPlayer(player) {
      return;
    };
    this.RegisterDynamicListener();
    let i: Int32 = 0;
    while i < SDC_MaxDrones() {
      this.SpawnSlot(i, player);
      i += 1;
    };
    this.StartWatchdog();
    if this.ActiveCount() > 0 {
      this.ShowVanillaMessage("DRONES DEPLOYED");
    } else {
      this.ShowVanillaMessage("DRONE DEPLOYMENT FAILED");
    };
  }

  private func SpawnSlot(slot: Int32, player: ref<PlayerPuppet>) -> Void {
    if slot < 0 || slot >= SDC_MaxDrones() || !IsDefined(player) {
      return;
    };
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(dynamicEntities) || !dynamicEntities.IsReady() {
      return;
    };
    if EntityID.IsDefined(this.m_slotIDs[slot]) {
      if dynamicEntities.IsManaged(this.m_slotIDs[slot]) {
        return;
      };
      this.ClearSlot(slot);
    };

    this.m_slotGeneration[slot] += 1;
    let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
    spec.recordID = SDC_RecordForSlot(slot);
    spec.position = SDC_SpawnPosition(player, slot);
    spec.orientation = player.GetWorldOrientation();
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = true;
    spec.spawnInView = true;
    spec.active = true;
    ArrayPush(spec.tags, SDC_Tag());
    let entityID: EntityID = dynamicEntities.CreateEntity(spec);
    if !EntityID.IsDefined(entityID) {
      return;
    };
    this.m_slotIDs[slot] = entityID;
    this.m_slotPending[slot] = true;
  }

  private cb func OnSDCDynamicEntityEvent(evt: ref<DynamicEntityEvent>) -> Void {
    if !IsDefined(evt) || !Equals(evt.GetEntityTag(), SDC_Tag()) {
      return;
    };
    let entityID: EntityID = evt.GetEntityID();
    let slot: Int32 = this.FindSlot(entityID);
    if slot < 0 {
      return;
    };
    switch evt.GetEventType() {
      case DynamicEntityEventType.Spawned:
        this.ResolveSlot(slot, entityID);
        break;
      case DynamicEntityEventType.Dead:
        let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if IsDefined(dynamicEntities) && dynamicEntities.IsManaged(entityID) {
          dynamicEntities.DeleteEntity(entityID);
        };
        this.ClearSlot(slot);
        break;
      case DynamicEntityEventType.Despawned:
      case DynamicEntityEventType.Deleted:
        this.ClearSlot(slot);
        break;
    };
  }

  private func FindSlot(entityID: EntityID) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_slotIDs) {
      if this.m_slotIDs[i] == entityID {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  private func ResolveSlot(slot: Int32, entityID: EntityID) -> Void {
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let puppet: ref<NPCPuppet>;
    if IsDefined(dynamicEntities) {
      puppet = dynamicEntities.GetEntity(entityID) as NPCPuppet;
    };
    if !IsDefined(puppet) {
      puppet = GameInstance.FindEntityByID(this.GetGameInstance(), entityID) as NPCPuppet;
    };
    if !IsDefined(puppet) {
      // A Spawned notification can arrive one frame before the puppet is
      // attached to the entity map.  Keep the request pending so the bounded
      // watchdog can resolve it on its next pass instead of losing the drone.
      return;
    };
    let player: ref<PlayerPuppet> = SDC_Player(this.GetGameInstance());
    if !SDC_ValidPlayer(player) {
      return;
    };
    puppet.m_sdcCompanion = true;
    puppet.m_sdcSlot = slot;
    this.m_slotPending[slot] = false;
    SDC_ApplyFollowerRole(puppet, player);
  }

  public func DeleteAll() -> Void {
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let i: Int32 = 0;
    while i < ArraySize(this.m_slotIDs) {
      if IsDefined(dynamicEntities) && EntityID.IsDefined(this.m_slotIDs[i]) && dynamicEntities.IsManaged(this.m_slotIDs[i]) {
        dynamicEntities.DeleteEntity(this.m_slotIDs[i]);
      };
      this.ClearSlot(i);
      i += 1;
    };
    this.m_watchdogRunning = false;
    this.CancelWatchdog();
  }

  private func ClearSlot(slot: Int32) -> Void {
    if slot < 0 || slot >= ArraySize(this.m_slotIDs) {
      return;
    };
    this.m_slotGeneration[slot] += 1;
    let invalidID: EntityID;
    this.m_slotIDs[slot] = invalidID;
    this.m_slotPending[slot] = false;
  }

  private func StartWatchdog() -> Void {
    if this.m_watchdogRunning {
      return;
    };
    this.m_watchdogRunning = true;
    this.m_watchdogGeneration += 1;
    this.ScheduleWatchdog(1.0);
  }

  private func ScheduleWatchdog(seconds: Float) -> Void {
    if !this.m_watchdogRunning {
      return;
    };
    let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(delay) {
      this.m_watchdogRunning = false;
      return;
    };
    let callback: ref<SDC_WatchdogCallback> = new SDC_WatchdogCallback();
    callback.system = this;
    callback.generation = this.m_watchdogGeneration;
    this.m_tickID = delay.DelayCallback(callback, seconds, false);
  }

  private func CancelWatchdog() -> Void {
    let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if IsDefined(delay) {
      delay.CancelDelay(this.m_tickID);
    };
    this.m_tickID = GetInvalidDelayID();
  }

  public func WatchdogTick(generation: Int32) -> Void {
    if !this.m_watchdogRunning || generation != this.m_watchdogGeneration || !this.m_active {
      return;
    };
    let dynamicEntities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let player: ref<PlayerPuppet> = SDC_Player(this.GetGameInstance());
    let i: Int32 = 0;
    while i < ArraySize(this.m_slotIDs) {
      let id: EntityID = this.m_slotIDs[i];
      if EntityID.IsDefined(id) && IsDefined(dynamicEntities) && !dynamicEntities.IsManaged(id) {
        this.ClearSlot(i);
      } else if EntityID.IsDefined(id) && this.m_slotPending[i] && IsDefined(dynamicEntities)
        && !dynamicEntities.IsSpawning(id) && !dynamicEntities.IsSpawned(id) {
        // A failed streaming request can leave a managed-but-never-spawned ID.
        // Do not keep the watchdog alive forever for that stale request.
        if dynamicEntities.IsManaged(id) {
          dynamicEntities.DeleteEntity(id);
        };
        this.ClearSlot(i);
      } else if EntityID.IsDefined(id) {
        let puppet: ref<NPCPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as NPCPuppet;
        if !IsDefined(puppet) && this.m_slotPending[i] && dynamicEntities.IsSpawned(id) {
          this.ResolveSlot(i, id);
          puppet = GameInstance.FindEntityByID(this.GetGameInstance(), id) as NPCPuppet;
        };
        if IsDefined(puppet) {
          if SDC_IsDeadLike(puppet) {
            if IsDefined(dynamicEntities) && dynamicEntities.IsManaged(id) {
              dynamicEntities.DeleteEntity(id);
            };
            this.ClearSlot(i);
          } else if IsDefined(player) {
            SDC_IssueFollow(puppet, player);
          };
        };
      };
      i += 1;
    };
    if this.ActiveCount() == 0 {
      this.m_watchdogRunning = false;
      return;
    };
    this.ScheduleWatchdog(1.0);
  }

  public func InjectThreat(attacker: wref<GameObject>) -> Void {
    if !IsDefined(attacker) {
      return;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_slotIDs) {
      if EntityID.IsDefined(this.m_slotIDs[i]) {
        let drone: ref<NPCPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_slotIDs[i]) as NPCPuppet;
        if IsDefined(drone) && !SDC_IsDeadLike(drone) {
          TargetTrackingExtension.InjectThreat(drone, attacker);
        };
      };
      i += 1;
    };
  }

  public func ActiveSlotIDs() -> array<EntityID> {
    return this.m_slotIDs;
  }
}

public class SDC_WatchdogCallback extends DelayCallback {
  public let system: wref<SDC_System>;
  public let generation: Int32;

  public func Call() -> Void {
    let current: ref<SDC_System> = this.system;
    if IsDefined(current) {
      current.WatchdogTick(this.generation);
    };
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnSDCPlayerKeyInput");
  let system: ref<SDC_System> = SDC_System.Get(this.GetGame());
  if IsDefined(system) {
    system.DeleteAll();
  };
  return wrappedMethod();
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnSDCPlayerKeyInput")
    .SetLifetime(CallbackLifetime.Session);
  return result;
}

@addField(PlayerPuppet)
private let m_sdcPlayerPadModifierHeld: Bool;

@addMethod(PlayerPuppet)
protected cb func OnSDCPlayerKeyInput(event: ref<KeyInputEvent>) -> Void {
  if !IsDefined(event) {
    return;
  };
  let key: EInputKey = event.GetKey();
  if Equals(key, EInputKey.IK_Pad_LeftShoulder) {
    this.m_sdcPlayerPadModifierHeld = !Equals(event.GetAction(), EInputAction.IACT_Release);
    return;
  };
  if !Equals(event.GetAction(), EInputAction.IACT_Press) {
    return;
  };
  let keyboard: Bool = Equals(key, EInputKey.IK_F9);
  let controller: Bool = this.m_sdcPlayerPadModifierHeld && Equals(key, EInputKey.IK_Pad_X_SQUARE);
  if !keyboard && !controller || GameInstance.GetSystemRequestsHandler().IsPreGame() || this.IsDead() {
    return;
  };
  let system: ref<SDC_System> = SDC_System.Get(this.GetGame());
  if IsDefined(system) {
    system.TryToggleFromInput();
  };
}

@addMethod(AIFollowerRole)
public final func SetSimpleDroneFollowerRef(followerRef: EntityReference) -> Void {
  this.followerRef = followerRef;
}

