module INCFCore

import Codeware.*

// INCF is a fixed profile.  Codeware 1.21.1+ and ArchiveXL 1.28.1+ are
// repository dependencies; the upstream requirements popup was removed so it
// cannot compete with CyberwareEx's QuestTrackerGameController hook or add a
// runtime configuration/localization surface.

@if(ModuleExists("Codeware"))
public class INCFCoreMarker extends ScriptableSystem {}

@if(ModuleExists("Codeware"))
public class INCFFloatingCrateNodeToggleCallback extends DelayCallback {
  private let m_service: wref<ImmersiveWorldFixesProcessing>;

  public static func Create(service: wref<ImmersiveWorldFixesProcessing>) -> ref<INCFFloatingCrateNodeToggleCallback> {
    let cb = new INCFFloatingCrateNodeToggleCallback();
    cb.m_service = service;
    return cb;
  }

  public func Call() -> Void {
    if IsDefined(this.m_service) {
      this.m_service.ResolveINACrateNodeState();
    }
  }
}

@if(ModuleExists("Codeware"))
public class ImmersiveWorldFixesProcessing extends ScriptableService {
  // Fixed source-controlled choice; no runtime settings listener is used.
  private let disableMagazineDebris: Bool = true;

  private let m_callbackSystem: wref<CallbackSystem>;
  private let m_initialized: Bool;

  private let m_inaTargetCarPresent: Bool;
  private let m_inaPendingCrateCheck: Bool;

  private cb func OnLoad() {
    if this.m_initialized {
      return;
    }

    this.m_callbackSystem = GameInstance.GetCallbackSystem();
    if !IsDefined(this.m_callbackSystem) {
      return;
    }

    this.m_initialized = true;

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Loaded", this, n"OnAudioEventsMetadataLoaded")
      .AddTarget(ResourceTarget.Path(r"base\\sound\\event\\eventsmetadata.json"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Load", this, n"OnMagazineDebrisSectorLoad")
      .AddTarget(ResourceTarget.Type(n"worldStreamingSector"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Load", this, n"OnSelectiveMagazineParticleLoad")
      .AddTarget(ResourceTarget.Path(r"ep1\\fx\\enviroment\\smoke\\e_smoke_dust_street_blowing_big_001.particle"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Load", this, n"OnSelectiveMagazineParticleLoad")
      .AddTarget(ResourceTarget.Path(r"ep1\\fx\\enviroment\\debris\\e_debris_magazines_tornado_001.particle"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Load", this, n"OnSelectiveMagazineParticleLoad")
      .AddTarget(ResourceTarget.Path(r"ep1\\fx\\enviroment\\debris\\e_debris_magazines_tornado_002.particle"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Load", this, n"OnSelectiveMagazineParticleLoad")
      .AddTarget(ResourceTarget.Path(r"ep1\\fx\\enviroment\\debris\\e_debris_magazines_tornado_003.particle"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/PostLoad", this, n"q305sectorProc")
      .AddTarget(ResourceTarget.Path(r"base\\worlds\\03_night_city\\_compiled\\default\\ep1\\exterior_-43_-39_0_0.streamingsector"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Ready", this, n"FixJapanTownAirLeaningWorkspot")
      .AddTarget(ResourceTarget.Path(r"base\\worlds\\03_night_city\\_compiled\\default\\exterior_-6_9_0_1.streamingsector"));

    this.m_callbackSystem
      .RegisterCallback(n"Resource/Ready", this, n"OnAirportQuestSectorReady")
      .AddTarget(ResourceTarget.Path(r"base\\worlds\\03_night_city\\_compiled\\default\\ep1\\quest_08e17fd8f7744ca7.streamingsector"));

    // Restrict the lifecycle seam to the two templates that own INCF's
    // entity fixes.  Without these targets the callback runs for every NPC,
    // vehicle, and prop assembled in Night City.
    this.m_callbackSystem
      .RegisterCallback(n"Entity/Assemble", this, n"OnEntityAssemble")
      .AddTarget(EntityTarget.Template(r"base\\open_world\\minor_activities\\pacifica\\coastview\\ma_pac_cvi_14\\entities\\ma_pac_cvi_14_destroy_wreck_car_01.ent"))
      .AddTarget(EntityTarget.Template(r"base\\gameplay\\loot\\containers\\crates\\crate_small.ent"));
    this.m_callbackSystem
      .RegisterCallback(n"Entity/Extract", this, n"OnEntityExtract")
      .AddTarget(EntityTarget.Template(r"base\\open_world\\minor_activities\\pacifica\\coastview\\ma_pac_cvi_14\\entities\\ma_pac_cvi_14_destroy_wreck_car_01.ent"));
  }

  private func OnDetach() -> Void {
    if !IsDefined(this.m_callbackSystem) {
      return;
    }

    this.m_callbackSystem.UnregisterCallback(n"Resource/Loaded", this);
    this.m_callbackSystem.UnregisterCallback(n"Resource/Load", this);
    this.m_callbackSystem.UnregisterCallback(n"Resource/PostLoad", this);
    this.m_callbackSystem.UnregisterCallback(n"Resource/Ready", this);
    this.m_callbackSystem.UnregisterCallback(n"Entity/Assemble", this);
    this.m_callbackSystem.UnregisterCallback(n"Entity/Extract", this);
    this.m_callbackSystem = null;
    this.m_initialized = false;
  }

  private cb func OnAudioEventsMetadataLoaded(event: ref<ResourceEvent>) -> Void {
    let jsonResource = event.GetResource() as JsonResource;
    let audioEvents: ref<audioAudioEventArray>;
    let index: Int32 = 0;

    if !IsDefined(jsonResource) {
      return;
    }

    audioEvents = jsonResource.root as audioAudioEventArray;

    if !IsDefined(audioEvents) {
      return;
    }

    while index < ArraySize(audioEvents.events) {
      if Equals(audioEvents.events[index].redId, n"sq017_sc_08_ladder") {
        audioEvents.events[index].wwiseId = 3765346442u;
        return;
      }

      index += 1;
    }
  }

  private cb func OnMagazineDebrisSectorLoad(event: ref<ResourceEvent>) -> Void {
    let sector = event.GetResource() as worldStreamingSector;
    let node: ref<worldStaticParticleNode>;
    let index: Int32 = 0;
    let nodeCount: Int32;
    let path: ResRef;

    if !this.disableMagazineDebris || !IsDefined(sector) {
      return;
    }

    nodeCount = sector.GetNodeCount();
    while index < nodeCount {
      node = sector.GetNode(index) as worldStaticParticleNode;

      if IsDefined(node) {
        path = ResourceAsyncRef.GetPath(node.particleSystem);
      }

      if IsDefined(node) && (
        Equals(path, r"base\\fx\\environment\\debris\\e_debris_magazines.particle")
        || Equals(path, r"base\\fx\\environment\\debris\\e_debris_magazines_slow.particle")
        || Equals(path, r"ep1\\fx\\enviroment\\debris\\e_debris_magazines_slow_002.particle")
        || Equals(path, r"base\\fx\\environment\\debris\\e_debris_magazines_surface.particle")
        || Equals(path, r"ep1\\fx\\enviroment\\debris\\e_debris_magazines_slow_001.particle")
      ) {
        node.forcedAutoHideDistance = 0.01;
        node.forcedAutoHideRange = 0.01;
      }

      index += 1;
    }
  }

  private cb func OnSelectiveMagazineParticleLoad(event: ref<ResourceEvent>) -> Void {
    let particle = event.GetResource() as CParticleSystem;
    let emitter: ref<CParticleEmitter>;
    let index: Int32 = 0;

    if !this.disableMagazineDebris || !IsDefined(particle) {
      return;
    }

    while index < ArraySize(particle.emitters) {
      emitter = particle.emitters[index];

      if IsDefined(emitter) && (
        Equals(emitter.editorName, "Magazine 01")
        || Equals(emitter.editorName, "Magazine 02")
        || Equals(emitter.editorName, "Magazine Air")
      ) {
        emitter.isEnabled = false;
        emitter.maxParticles = Cast<Uint16>(0u);
      }

      index += 1;
    }
  }

  private cb func q305sectorProc(event: ref<ResourceEvent>) {
    let sector: ref<worldStreamingSector> = event.GetResource() as worldStreamingSector;
    if !IsDefined(sector) {
      return;
    }

    let count: Int32 = sector.GetNodeSetupCount();

    if count < 728 {
      return;
    }

    let maxI: Int32 = 516;
    if (211 + maxI) >= count {
      maxI = count - 212;
    }
    if maxI <= 0 {
      return;
    }

    let i: Int32 = 1;
    while i <= maxI {
      let suffix: String = (i < 10) ? ("0" + ToString(i)) : ToString(i);
      let newNodeRef: NodeRef = CreateNodeRef("$/03_night_city/#q305_fix/#explosion_fix_node_" + suffix);
      let setup = sector.GetNodeSetup(211 + i);
      if IsDefined(setup) {
        setup.SetNodeRef(newNodeRef);
      }
      i += 1;
    }
  }

  private cb func FixJapanTownAirLeaningWorkspot(event: ref<ResourceEvent>) {
    let sector: ref<worldStreamingSector> = event.GetResource() as worldStreamingSector;

    if !IsDefined(sector) {
      return;
    }

    if sector.GetNodeSetupCount() != 2296 {
      return;
    }

    let nodes = sector.GetNodes();
    if ArraySize(nodes) <= 32 {
      return;
    }
    let node = nodes[32] as worldAISpotNode;

    if !IsDefined(node) {
      return;
    }

    let newSpot = new AIActionSpot();
    newSpot.resource *= r"base\\workspots\\common\\ground\\generic__stand_ground_cigarette__smoke__01.workspot";
    newSpot.useClippingSpace = false;

    node.spot = newSpot;
  }

  private cb func OnAirportQuestSectorReady(event: ref<ResourceEvent>) {
    let sector: ref<worldStreamingSector> = event.GetResource() as worldStreamingSector;

    if !IsDefined(sector) {
      return;
    }

    let count: Int32 = sector.GetNodeSetupCount();

    if count != 4 && count != 6 {
      return;
    }

    this.DisableAirportShuttleProxyNode();
  }

  public func DisableAirportShuttleProxyNode() -> Void {
    let worldStateSystem = GameInstance.GetWorldStateSystem();
    if !IsDefined(worldStateSystem) {
      return;
    }
    worldStateSystem.ToggleNode(
      ToNodeRef("$/03_night_city/nw4/#nw4_air_traffic/#air_traffic_space_shuttle_002/_entityProxyMesh"),
      false
    );
  }

  private cb func OnEntityAssemble(event: ref<EntityLifecycleEvent>) {
    let entity = event.GetEntity();

    if !IsDefined(entity) {
      return;
    }

    let templatePath: ResRef = entity.GetTemplatePath();

    if templatePath == r"base\\open_world\\minor_activities\\pacifica\\coastview\\ma_pac_cvi_14\\entities\\ma_pac_cvi_14_destroy_wreck_car_01.ent"
      && Equals(entity.GetCurrentAppearanceName(), n"default") {
      this.m_inaTargetCarPresent = true;
      this.SetINACrateNodeActive(true);
      return;
    }

    if templatePath == r"base\\gameplay\\loot\\containers\\crates\\crate_small.ent"
      && Equals(entity.GetCurrentAppearanceName(), n"crate_small_entropy_a") {
      if this.m_inaPendingCrateCheck {
        return;
      }
      this.m_inaPendingCrateCheck = true;

      GameInstance
        .GetDelaySystem(GetGameInstance())
        .DelayCallback(INCFFloatingCrateNodeToggleCallback.Create(this), 1.00, false);
    }
  }

  private cb func OnEntityExtract(event: ref<EntityLifecycleEvent>) {
    let entity = event.GetEntity();

    if !IsDefined(entity) {
      return;
    }

    let templatePath: ResRef = entity.GetTemplatePath();

    if templatePath == r"base\\open_world\\minor_activities\\pacifica\\coastview\\ma_pac_cvi_14\\entities\\ma_pac_cvi_14_destroy_wreck_car_01.ent"
      && Equals(entity.GetCurrentAppearanceName(), n"default") {
      this.m_inaTargetCarPresent = false;
    }
  }

  public func ResolveINACrateNodeState() -> Void {
    if !this.m_inaPendingCrateCheck {
      return;
    }

    if this.m_inaTargetCarPresent {
      this.SetINACrateNodeActive(true);
      this.m_inaTargetCarPresent = false;
      this.m_inaPendingCrateCheck = false;
      return;
    }

    this.SetINACrateNodeActive(false);
    this.m_inaPendingCrateCheck = false;
  }

  private final func SetINACrateNodeActive(active: Bool) -> Void {
    let worldStateSystem = GameInstance.GetWorldStateSystem();
    if !IsDefined(worldStateSystem) {
      return;
    }
    worldStateSystem.ToggleNode(
      ToNodeRef("$/03_night_city/se1/loc_ma_bls_ina_se1_10_prefabBM2XS4I/loc_ma_bls_ina_se1_10_gameplay_prefabGZ2VZLQ/loc_ma_bls_ina_se1_10_loot_prefabHRTZ3AQ/{ma_bls_ina_se1_10_crate}_prefab6CFLOIY"),
      active
    );
  }
}
