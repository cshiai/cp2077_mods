// SimpleDroneCompanion
//
// A source-controlled, vanilla-first companion backend for six session-bound
// Militech combat drones (two Minotaurs, two Octants, and two Cerberus units).
// It deliberately owns only lifecycle, fixed input, the
// follower role, and a bounded watchdog. There is no CET/Lua, Mod Settings,
// localization, persistence, JSON, custom archive, or fleet UI.
//
// C1/C2/C3 are represented by a small record seam: declarative Minotaur,
// Octant, and Cerberus records carry the fixed companion payloads, while
// vanilla IDs remain safe fallbacks if a future TweakXL load omits a private
// record. Replacing that seam does not change lifecycle or combat hooks.

module SimpleDroneCompanion

public func SDC_Tag() -> CName {
  return n"SimpleDroneCompanion";
}

public func SDC_MaxDrones() -> Int32 {
  return 6;
}

public func SDC_VanillaRecord() -> TweakDBID {
  return t"Character.militech_base_minotaur";
}

public func SDC_VanillaOctantRecord() -> TweakDBID {
  return t"Character.militech_drone_octant_hard";
}

public func SDC_VanillaCerberusRecord() -> TweakDBID {
  return t"Character.q305_cerberus_robot";
}

public func SDC_StaticRecord(slot: Int32) -> TweakDBID {
  if slot == 1 {
    return t"Character.SimpleDroneMinotaurB";
  };
  if slot == 2 {
    return t"Character.SimpleDroneOctantA";
  };
  if slot == 3 {
    return t"Character.SimpleDroneOctantB";
  };
  if slot == 4 {
    return t"Character.SimpleDroneCerberusA";
  };
  if slot == 5 {
    return t"Character.SimpleDroneCerberusB";
  };
  return t"Character.SimpleDroneMinotaurA";
}

public func SDC_WeaponRecord() -> TweakDBID {
  return t"SimpleDroneCompanion.MinotaurWeapon";
}

public func SDC_WeaponLeftRecord() -> TweakDBID {
  return t"SimpleDroneCompanion.MinotaurWeaponLeft";
}

// Fixed-width health bars avoid allocating/concatenating ten short strings on
// every HUD refresh.  The companion HUD only ever requests values in 0..10.
private func SDC_HealthBarString(filled: Int32) -> String {
  switch filled {
    case 0: return "..........";
    case 1: return "|.........";
    case 2: return "||........";
    case 3: return "|||.......";
    case 4: return "||||......";
    case 5: return "|||||.....";
    case 6: return "||||||....";
    case 7: return "|||||||...";
    case 8: return "||||||||..";
    case 9: return "|||||||||.";
    case 10: return "||||||||||";
  };
  return "..........";
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
  // static weapon record. The source-level C1 switch and missing-record
  // fallback keep the vanilla implementation available for comparison.
  if SDC_UseVanillaRecordPath() {
    if slot >= 4 {
      return SDC_VanillaCerberusRecord();
    };
    return slot >= 2 ? SDC_VanillaOctantRecord() : SDC_VanillaRecord();
  };
  let staticRecord: TweakDBID = SDC_StaticRecord(slot);
  if IsDefined(TweakDBInterface.GetRecord(staticRecord)) {
    return staticRecord;
  };
  if slot >= 4 {
    return SDC_VanillaCerberusRecord();
  };
  return slot >= 2 ? SDC_VanillaOctantRecord() : SDC_VanillaRecord();
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
  switch slot {
    case 1:
      return new Vector4(-3.0, -1.5, 0.0, 0.0);
    case 2:
      return new Vector4(4.0, 1.0, 0.0, 0.0);
    case 3:
      return new Vector4(-4.0, 1.0, 0.0, 0.0);
    case 4:
      return new Vector4(5.0, -3.0, 0.0, 0.0);
    case 5:
      return new Vector4(-5.0, -3.0, 0.0, 0.0);
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
  if !IsDefined(ai) {
    return;
  };
  // Keep the session-bound squad with V across streaming/fast traversal
  // without a per-frame scan. Combat/alerted puppets return above; only an
  // idle follower farther than 45m is snapped to a nearby nav point.
  if Vector4.Distance(puppet.GetWorldPosition(), player.GetWorldPosition()) > 45.0 {
    let teleportation = GameInstance.GetTeleportationFacility(player.GetGame());
    if IsDefined(teleportation) {
      teleportation.Teleport(puppet, SDC_SpawnPosition(player, puppet.m_sdcSlot), Vector4.ToRotation(player.GetWorldForward()));
      return;
    }
  };
  if ai.IsCommandActive(n"AIFollowTargetCommand") {
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
  private let m_hudHeaderText: wref<inkText>;
  private let m_hudStatusText: wref<inkText>;
  private let m_hudPanel: wref<inkWidget>;
  private let m_hudRoot: wref<inkWidget>;
  private let m_lastHudHeader: String;
  private let m_lastHudStatus: String;

  public final static func Get(gi: GameInstance) -> ref<SDC_System> {
    let system: ref<SDC_System> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"SimpleDroneCompanion.SDC_System") as SDC_System;
    if !IsDefined(system) {
      system = GameInstance.GetScriptableSystemsContainer(gi).Get(n"SDC_System") as SDC_System;
    };
    return system;
  }

  private func OnAttach() -> Void {
    this.m_tickID = GetInvalidDelayID();
    this.m_lastInputAt = -1.0;
    this.m_lastHudHeader = "";
    this.m_lastHudStatus = "";
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
    this.RefreshHud();
    // Keep no background timer alive for the idle reminder.  The panel is
    // hosted above the healthbar's auto-hidden container; the watchdog is
    // reserved for live/pending drone entities only.
    if this.ActiveCount() > 0 {
      this.StartWatchdog();
    } else {
      this.m_watchdogRunning = false;
      this.CancelWatchdog();
    };
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

  public func BindHudWidgets(headerText: ref<inkText>, statusText: ref<inkText>, panel: ref<inkWidget>, root: ref<inkWidget>) -> Void {
    this.m_hudHeaderText = headerText;
    this.m_hudStatusText = statusText;
    this.m_hudPanel = panel;
    this.m_hudRoot = root;
    this.m_lastHudHeader = "";
    this.m_lastHudStatus = "";
    this.RefreshHud();
  }

  private func BuildSlotHudLine(slot: Int32, statPools: ref<StatPoolsSystem>) -> String {
    let label: String = "M1 MINOTAUR";
    switch slot {
      case 1:
        label = "M2 MINOTAUR";
        break;
      case 2:
        label = "O1 OCTANT  ";
        break;
      case 3:
        label = "O2 OCTANT  ";
        break;
      case 4:
        label = "C1 CERBERUS";
        break;
      case 5:
        label = "C2 CERBERUS";
        break;
    };
    if slot < 0 || slot >= ArraySize(this.m_slotIDs) || !EntityID.IsDefined(this.m_slotIDs[slot]) {
      return label + " [----------] OFFLINE";
    }
    let id: EntityID = this.m_slotIDs[slot];
    let puppet: ref<NPCPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as NPCPuppet;
    if this.m_slotPending[slot] && !IsDefined(puppet) {
      return label + " [..........] SPAWNING";
    }
    if !IsDefined(puppet) || SDC_IsDeadLike(puppet) || !IsDefined(statPools) {
      return label + " [----------] OFFLINE";
    }
    let hpPct: Float = statPools.GetStatPoolValue(Cast<StatsObjectID>(id), gamedataStatPoolType.Health, true);
    if hpPct <= 0.0 {
      return label + " [----------] OFFLINE";
    }
    let hp: Int32 = RoundF(hpPct);
    if hp < 1 { hp = 1; }
    if hp > 100 { hp = 100; }
    let filled: Int32 = RoundF(Cast<Float>(hp) * 0.10);
    if filled < 1 { filled = 1; }
    if filled > 10 { filled = 10; }
    return label + " [" + SDC_HealthBarString(filled) + "] " + IntToString(hp) + "%";
  }

  private func BuildHudStatusText(statPools: ref<StatPoolsSystem>) -> String {
    if this.ActiveCount() == 0 {
      return "Ready: 2x Minotaur + 2x Octant + 2x Cerberus";
    }
    return this.BuildSlotHudLine(0, statPools) + "\n"
      + this.BuildSlotHudLine(1, statPools) + "\n"
      + this.BuildSlotHudLine(2, statPools) + "\n"
      + this.BuildSlotHudLine(3, statPools) + "\n"
      + this.BuildSlotHudLine(4, statPools) + "\n"
      + this.BuildSlotHudLine(5, statPools);
  }

  public func RefreshHud() -> Void {
    if !IsDefined(this.m_hudHeaderText) {
      return;
    }
    if IsDefined(this.m_hudRoot) {
      this.m_hudRoot.SetVisible(true);
      this.m_hudRoot.SetOpacity(1.0);
    };
    if IsDefined(this.m_hudPanel) {
      this.m_hudPanel.SetVisible(true);
      this.m_hudPanel.SetOpacity(1.0);
    };
    let count: Int32 = this.ActiveCount();
    let header: String;
    let status: String;
    if count == 0 {
      header = "[F9] SUMMON DRONES (0/6)";
      status = "Ready: 2x Minotaur + 2x Octant + 2x Cerberus";
    } else {
      header = "[F9] DRONE SQUAD (" + IntToString(count) + "/6) — PRESS F9 TO DISMISS";
      let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
      status = this.BuildHudStatusText(statPools);
    }
    if NotEquals(header, this.m_lastHudHeader) {
      this.m_hudHeaderText.SetText(header);
      this.m_lastHudHeader = header;
    }
    if IsDefined(this.m_hudStatusText) {
      if NotEquals(status, this.m_lastHudStatus) {
        this.m_hudStatusText.SetText(status);
        this.m_lastHudStatus = status;
      }
      this.m_hudStatusText.SetVisible(true);
    }
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
    if this.ActiveCount() > 0 {
      this.StartWatchdog();
    } else {
      this.m_watchdogRunning = false;
      this.CancelWatchdog();
    };
    if this.ActiveCount() > 0 {
      this.ShowVanillaMessage("DRONES DEPLOYED");
    } else {
      this.ShowVanillaMessage("DRONE DEPLOYMENT FAILED");
    };
    this.RefreshHud();
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
    this.RefreshHud();
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
    this.RefreshHud();
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
      this.CancelWatchdog();
      this.RefreshHud();
      return;
    };
    this.ScheduleWatchdog(1.0);
    this.RefreshHud();
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
  let system: ref<SDC_System> = SDC_System.Get(this.GetGame());
  if IsDefined(system) {
    system.DeleteAll();
  };
  return wrappedMethod();
}

@addMethod(AIFollowerRole)
public final func SetSimpleDroneFollowerRef(followerRef: EntityReference) -> Void {
  this.followerRef = followerRef;
}

@wrapMethod(healthbarWidgetGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
  if !IsDefined(root) {
    root = this.GetRootCompoundWidget();
  }
  if !IsDefined(root) {
    return result;
  }

  // Parent the persistent reminder above the container whose vanilla health
  // bar controller auto-hides at full health/out of combat.  This avoids a
  // polling timer solely to undo that visibility transition.
  let host: ref<inkCompoundWidget> = root.GetParentWidget() as inkCompoundWidget;
  if !IsDefined(host) {
    host = root;
  }

  let panel: ref<inkVerticalPanel> = new inkVerticalPanel();
  panel.SetName(n"SDC_DroneHudPanel");
  panel.SetAnchor(inkEAnchor.TopLeft);
  panel.SetAnchorPoint(Vector2(0.0, 0.0));
  panel.SetMargin(inkMargin(20.0, 115.0, 0.0, 0.0));
  panel.SetFitToContent(true);
  panel.Reparent(host);

  let headerText: ref<inkText> = new inkText();
  headerText.SetName(n"SDC_DroneHudHeader");
  headerText.SetFontFamily("base\\gameplay\\gui\\fonts\\rajdhani\\rajdhani.inkfontfamily");
  headerText.SetFontStyle(n"Semi-Bold");
  headerText.SetFontSize(20);
  headerText.SetFitToContent(true);
  headerText.SetTintColor(new HDRColor(0.36, 0.96, 1.0, 0.92));
  headerText.SetHorizontalAlignment(textHorizontalAlignment.Left);
  headerText.SetVerticalAlignment(textVerticalAlignment.Top);
  headerText.SetText("[F9] SUMMON DRONES (0/6)");
  headerText.Reparent(panel);

  let statusText: ref<inkText> = new inkText();
  statusText.SetName(n"SDC_DroneHudStatus");
  statusText.SetFontFamily("base\\gameplay\\gui\\fonts\\rajdhani\\rajdhani.inkfontfamily");
  statusText.SetFontStyle(n"Regular");
  statusText.SetFontSize(18);
  statusText.SetFitToContent(true);
  statusText.SetTintColor(new HDRColor(0.62, 1.0, 0.52, 0.92));
  statusText.SetHorizontalAlignment(textHorizontalAlignment.Left);
  statusText.SetVerticalAlignment(textVerticalAlignment.Top);
  statusText.SetText("Ready: 2x Minotaur + 2x Octant + 2x Cerberus");
  statusText.SetVisible(true);
  statusText.Reparent(panel);

  // healthbarWidgetGameController hides its vanilla root while V is at full
  // health/out of combat.  The companion reminder is persistent, so keep the
  // parent host and our panel visible/opaque rather than inheriting that hide
  // state.
  host.SetVisible(true);
  host.SetOpacity(1.0);
  panel.SetVisible(true);
  panel.SetOpacity(1.0);

  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    let system: ref<SDC_System> = SDC_System.Get(player.GetGame());
    if IsDefined(system) {
      system.BindHudWidgets(headerText, statusText, panel, host);
    }
  }
  return result;
}

@wrapMethod(healthbarWidgetGameController)
protected cb func OnUninitialize() -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    let system: ref<SDC_System> = SDC_System.Get(player.GetGame());
    if IsDefined(system) {
      system.BindHudWidgets(null, null, null, null);
    }
  }
  return wrappedMethod();
}

