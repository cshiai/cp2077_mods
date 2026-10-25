/* 
The Nullifier 
robber804

Version 1.0.0: 	- Initial Release, combined NCFN and NCVN
				- Change broken lights to PTLU_Everywhere and update settings
				- Fixed logic in NCVN
				- Threaded codeware 1.20+ required
				- Adjusted settings for brokenlights to more closely match game defaults
Version 1.0.1:	- Updated SceneDiffuse, removed particle settings
Version 1.0.2:	- Skip job dispatch entirely when every sub-feature flag is off - DV
				- Hash maps now build even when ModSettings isn't installed - DV
				- Merged double cast+IsDefined in ProcessEntity component loop - DV
				- Updated descriptions of options
				- Exclude headlights from light changes
Version 1.0.3	- Fix holo calls
Version 1.0.4	- Actually fix holo calls
Version 1.0.5	- Removed RT Intensity slider
				- Removed scene specular slider
				- Removed fog vol slider
Version 1.1.0	- fixed emissive light on some proxy mesh
				- removed useInParticles as it caused fog/smoke to flicker
				- removed useInTransparents as it can make particles too bright, thanks theCyanideX
				- fixed matte look on some metal, thanks theCyanideX
				- broken light fix disabled by default
Version 1.2.0	- Removed dead code
				- support for RT and Raster
Version 1.2.1	- fix compile error
Version 1.2.2	- bug fixes
Version 1.3.0	- Removed most lighting changes
				- Fixed random crash
Version 1.3.1	- Fixed Compile error
Version 1.3.2	- Fixed duplicate function
Version 1.3.3	- Removed dead code
Version 1.4.0	- Remove Kill Triggers and World Boundary Nodes
Version 1.4.1	- Possible fix for race condition
Version 1.4.2	- Fix compile error
Version 1.4.3	- Fix race conditoin in Kill Triggers and World Boundary Nodes
Version 1.4.4	- rewrote handlers to make them more performant
				- Fix removal of killTriggers embedded in notifiers
Version 1.4.5	- Fixed some weather not getting nulled near stadium
Version 1.4.6	- Razer Huges fight added as exclusion
				- Updated for 2.5
Version 1.5.0	- null Forbidden Vehcile Nodes
				- null photomode restrictions
				
*/

class TheNullifier extends ScriptableService 
{
	@runtimeProperty("ModSettings.mod", "The Nullifier")
	@runtimeProperty("ModSettings.displayName", "Enabled")
	let enabled: Bool = true;
	
	@runtimeProperty("ModSettings.mod", "The Nullifier")
	@runtimeProperty("ModSettings.category", "Features")
	@runtimeProperty("ModSettings.category.order", "1")
	@runtimeProperty("ModSettings.displayName", "Night City Visuals Nulled")
	@runtimeProperty("ModSettings.description", "Makes weather and lighting consistent for weather mods like Nova City.")
	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncvnEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "The Nullifier")
	@runtimeProperty("ModSettings.category", "Features")
	@runtimeProperty("ModSettings.category.order", "1")
	@runtimeProperty("ModSettings.displayName", "Night City Fog Nulled")
	@runtimeProperty("ModSettings.description", "Removes only the static fog in game not weather related fog or dust, smoke or nitrogen.")
	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncfnEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "The Nullifier")
	@runtimeProperty("ModSettings.category", "Features")
	@runtimeProperty("ModSettings.category.order", "1")
	@runtimeProperty("ModSettings.displayName", "Kill Triggers Nulled")
	@runtimeProperty("ModSettings.description", "Removes Kill Triggers, explore where you want.")
	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncktnEnabled: Bool = true;

	@runtimeProperty("ModSettings.mod", "The Nullifier")
	@runtimeProperty("ModSettings.category", "Features")
	@runtimeProperty("ModSettings.category.order", "1")
	@runtimeProperty("ModSettings.displayName", "World Boundaries Nulled")
	@runtimeProperty("ModSettings.description", "Removes game world boundaries, explore where you want.")
	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncwbnEnabled: Bool = true;

//	@runtimeProperty("ModSettings.mod", "The Nullifier")
//	@runtimeProperty("ModSettings.category", "Features")
//	@runtimeProperty("ModSettings.category.order", "1")
//	@runtimeProperty("ModSettings.displayName", "Forbidden Vehichles Nulled")
//	@runtimeProperty("ModSettings.description", "Removes forbidden vehichle zones, park/drive where you want.")
//	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncfvnEnabled: Bool = false;

//	@runtimeProperty("ModSettings.mod", "The Nullifier")
//	@runtimeProperty("ModSettings.category", "Features")
//	@runtimeProperty("ModSettings.category.order", "1")
//	@runtimeProperty("ModSettings.displayName", "Photomode Restrictions Nulled")
//	@runtimeProperty("ModSettings.description", "Removes photomode restrictions.")
//	@runtimeProperty("ModSettings.dependency", "enabled")
	let ncprnEnabled: Bool = false;

	private let pyramidSongHash: Uint64;
	private let darkMatterHash: Uint64;
	
	private let pyramidNodes: array<Int32>;
	private let darkMatterNodes: array<Int32>;
	
	private let isInitialized: Bool = false;

	let exceptionMap: ref<inkIntHashMap>;
	let fogMap: ref<inkIntHashMap>;
	let NodeIDMap: ref<inkIntHashMap>;
	let killMap: ref<inkIntHashMap>;

	private cb func OnInitialize() {
		if !(this.isInitialized) { this.InitializeHashLibrary(); }
	}
	
	private cb func OnLoad() {
		if !this.enabled { return; }
		if !this.isInitialized { this.InitializeHashLibrary(); }
		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/Loaded", this, n"ProcessRestrictions").AddTarget(ResourceTarget.Type(n"worldStreamingSector"));

		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/PostLoad", this, n"ProcessFogNulled").AddTarget(ResourceTarget.Type(n"worldStreamingSector"));
//		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/PostLoad", this, n"ProcessQuestPhasePMR_Removal").AddTarget(ResourceTarget.Type(n"questQuestPhaseResource"));
//		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/PostLoad", this, n"ProcessScenePMR_Removal").AddTarget(ResourceTarget.Type(n"scnSceneResource"));
//		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/PostLoad", this, n"ProcessQuestPMR_Removal").AddTarget(ResourceTarget.Type(n"questQuestResource"));

//		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/Ready", this, n"ProcessVehicleForbiddenAreaNode").AddTarget(ResourceTarget.Type(n"worldStreamingSector"));
		GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/Ready", this, n"ProcessVisualsNulled").AddTarget(ResourceTarget.Type(n"worldStreamingSector"));

		this.RegisterModSettingsListener();
	}

	@if(ModuleExists( "ModSettingsModule" ))
	private func RegisterModSettingsListener() {
        ModSettings.RegisterListenerToClass(this);
		ModSettings.RegisterListenerToModifications(this);
	}
	@if(!ModuleExists("ModSettingsModule"))
	private func RegisterModSettingsListener() {}

	private cb func ProcessVisualsNulled( event: ref<ResourceEvent> ) {
		if !this.ncktnEnabled && !this.ncvnEnabled { return; }
		let sector = event.GetResource() as worldStreamingSector;
		if !IsDefined(sector) || Equals(sector.category, worldStreamingSectorCategory.Navigation) || Equals(sector.category, worldStreamingSectorCategory.AlwaysLoaded) { return; }

		let sectorPathHash = ResRef.GetHash(event.GetPath());
		let count = sector.GetNodeSetupCount();
		let index = 0;

		while index < count {
			let setup = sector.GetNodeSetup(index);
			if IsDefined(setup) {
				let node = sector.GetNode(Cast<Int32>(setup.GetNodeIndex()));
				let trigger = node as worldTriggerAreaNode;

				if IsDefined(trigger) && Equals(node.GetClassName(), n"worldTriggerAreaNode") {
					let persistentID = Cast<PersistentID>(setup.GetGlobalNodeID());
					let hashValue = persistentID.entityHash;

					if this.ncktnEnabled && IsDefined(this.killMap) && this.killMap.KeyExist(hashValue)  {
						this.HandleKillTrigger(trigger);
					} 
					else if this.ncvnEnabled && IsDefined(this.NodeIDMap) && IsDefined(this.exceptionMap) && this.NodeIDMap.KeyExist(hashValue)	&& !this.exceptionMap.KeyExist(sectorPathHash) {
						if Equals(sectorPathHash, this.pyramidSongHash) {
							if !ArrayContains(this.pyramidNodes, index) {
								this.HandleEnvironment(trigger);
								this.HandleWeather(trigger);
							}
						} 
						else if Equals(sectorPathHash, this.darkMatterHash) {
							if ArrayContains(this.darkMatterNodes, index) {
								this.HandleEnvironment(trigger);
								this.HandleWeather(trigger);
							}
						} 
						else {
							this.HandleEnvironment(trigger);
							this.HandleWeather(trigger);
						}
					}
				}
			}
			index += 1;
		}
	}

	private cb func ProcessFogNulled(event: ref<ResourceEvent>) 
	{
		if(!this.ncfnEnabled) { return; }

		let sector = event.GetResource() as worldStreamingSector;
		if !IsDefined(sector) { return; }
		let sectorPathHash = sector.path.GetHash();

		if(this.fogMap.KeyExist(sectorPathHash) || Equals(sector.category, worldStreamingSectorCategory.Navigation) || Equals(sector.category, worldStreamingSectorCategory.AlwaysLoaded)) { return; }
		
		let index = 0;
		let count = sector.GetNodeSetupCount();

		while index < count {
			let setup = sector.GetNodeSetup(index);	
			if IsDefined(setup) {
				let node = sector.GetNode(Cast<Int32>(setup.GetNodeIndex()));
				let fog = node as worldStaticFogVolumeNode;
				
				if IsDefined(fog) { fog.isVisibleInGame = false; }
			}
			index += 1;
		}
	}

	private cb func ProcessRestrictions( event: ref<ResourceEvent> ) {
		if !this.ncktnEnabled && !this.ncwbnEnabled { return; }
		let sector = event.GetResource() as worldStreamingSector;
		if !IsDefined(sector) || Equals(sector.category, worldStreamingSectorCategory.Navigation) || Equals(sector.category, worldStreamingSectorCategory.AlwaysLoaded) { return; }

		let count = sector.GetNodeSetupCount();
		let index = 0;

		while index < count {
			let setup = sector.GetNodeSetup(index);
			if IsDefined(setup) {
				let node = sector.GetNode(Cast<Int32>(setup.GetNodeIndex()));
				if IsDefined(node) {
					let className = node.GetClassName();

					switch className {
						case n"gameKillTriggerNode":
							if !this.ncktnEnabled { break; }
							this.ProcessWorldAreaShapeNode( node );
							break;
						case n"gameWorldBoundaryNode":
							if !this.ncwbnEnabled { break; }
							this.ProcessWorldAreaShapeNode( node );
							break;
					}
				}
			}
			index += 1;
		}
	}
	
	private func ProcessWorldAreaShapeNode(node: ref<worldNode>) {
		let trigger = node as worldAreaShapeNode;
		if IsDefined(trigger) {
			let zero: Vector3 = new Vector3(0.0, 0.0, 0.0);
			let index = 0;
			for point in trigger.outline.points {
				trigger.outline.points[index] = zero;
				index += 1;
			}
			trigger.outline.height = 0.0;
		}
	}

	private func HandleKillTrigger(trigger: ref<worldTriggerAreaNode>) {
		let index = ArraySize(trigger.notifiers) - 1;
		while index >= 0 {
			if IsDefined(trigger.notifiers[index] as questTriggerNotifier_Quest) {
				ArrayErase(trigger.notifiers, index);
			}
			index -= 1;
		}
	}

	private func HandleWeather(trigger: ref<worldTriggerAreaNode>) {
		let index = ArraySize(trigger.notifiers) - 1;
		while index >= 0 {
			if IsDefined(trigger.notifiers[index] as worldWeatherAreaNotifier) {
				ArrayErase(trigger.notifiers, index);
			}
			index -= 1;
		}
	}

	private func HandleEnvironment(trigger: ref<worldTriggerAreaNode>) {
		let index = ArraySize(trigger.notifiers) - 1;
		while index >= 0 {
			if IsDefined(trigger.notifiers[index] as worldEnvAreaNotifier) {
				ArrayErase(trigger.notifiers, index);
			}
			index -= 1;
		}
	}

	private cb func ProcessVehicleForbiddenAreaNode(event: ref<ResourceEvent>) {
		if !this.ncfvnEnabled { return; }
		let sector = event.GetResource() as worldStreamingSector;
		if (Equals(sector.category, worldStreamingSectorCategory.Navigation) || Equals(sector.category, worldStreamingSectorCategory.AlwaysLoaded)) { return; }
			
		for node in sector.GetNodes() {
			let forbidden = node as worldVehicleForbiddenAreaNode;
			if IsDefined(forbidden) {
				ArrayClear(forbidden.notifiers);
			}
			else {
				let interior = node as worldInteriorAreaNode;
				if IsDefined(interior) {
					let index = ArraySize(interior.notifiers) - 1;
					while index >= 0 {
						if IsDefined(interior.notifiers[index] as worldVehicleForbiddenAreaNotifier) {
							ArrayErase(interior.notifiers, index);
						}
						index -= 1;
					}
				}
			}
		}
    }	

    private cb func ProcessScenePMR_Removal(event: ref<ResourceEvent>) {
		if !this.ncprnEnabled { return; }
        let scene = event.GetResource() as scnSceneResource;
        if !IsDefined(scene) { return; }

        let questNode: ref<scnQuestNode>;
        let nodeDefinition: ref<questGameManagerNodeDefinition>;
        let restrict: ref<questGameplayRestrictions_NodeType>;
        for node in scene.sceneGraph.graph {
            questNode = node as scnQuestNode;
            if IsDefined(questNode) {
                nodeDefinition = questNode.questNode as questGameManagerNodeDefinition;
                if IsDefined(nodeDefinition) {
                    restrict = nodeDefinition.type as questGameplayRestrictions_NodeType;
                    if IsDefined(restrict) {
						ArrayRemove(restrict.restrictionIDs, t"GameplayRestriction.NoPhotoMode");
                    }
                }
            }
        }
    }

    private cb func ProcessQuestPMR_Removal(event: ref<ResourceEvent>) {
		if !this.ncprnEnabled { return; }
        let quest = event.GetResource() as questQuestResource;
        if !IsDefined(quest) { return; }

        for node in quest.graph.nodes {
            let gameManagerNode = node as questGameManagerNodeDefinition;
            if IsDefined(gameManagerNode) {
                let restrict = gameManagerNode.type as questGameplayRestrictions_NodeType;
                if IsDefined(node) {
					ArrayRemove(restrict.restrictionIDs, t"GameplayRestriction.NoPhotoMode");
                }
            }
        }
    }

    private cb func ProcessQuestPhasePMR_Removal(event: ref<ResourceEvent>) {
		if !this.ncprnEnabled { return; }
        let qPhase = event.GetResource() as questQuestPhaseResource;
        if !IsDefined(qPhase) { return; }

        for node in qPhase.graph.nodes {
            let gameManagerNode = node as questGameManagerNodeDefinition;
            if IsDefined(gameManagerNode) {
                let restrict = gameManagerNode.type as questGameplayRestrictions_NodeType;
                if IsDefined(restrict) {
					ArrayRemove(restrict.restrictionIDs, t"GameplayRestriction.NoPhotoMode");
                }
            }
        }
    }

	private func InitializeHashLibrary() {
		if this.isInitialized { return; }
		
		this.fogMap = new inkIntHashMap();
		let fog = [
			3012169062658049765ul,	//"base\worlds\03_night_city\_compiled\default\quest_483fad5d221eb27f.streamingsector", //red dirt bar
			17175477121902804555ul,	//"base\worlds\03_night_city\_compiled\default\exterior_-6_0_2_2.streamingsector", 		//arasaka tower
			16754088566340504268ul,	//"base\worlds\03_night_city\_compiled\default\interior_177_-48_6_0.streamingsector", 	//concert as johnny, love like fire
			17846823862810601880ul,	//"base\worlds\03_night_city\_compiled\default\interior_11_-3_0_4.streamingsector", 	//concert as johnny, transmission #1
			13554617829332014667ul,	//"base\worlds\03_night_city\_compiled\default\interior_44_-12_1_2.streamingsector", 	//concert as johnny, transmission #2
			1455724676986766903ul	//"base\worlds\03_night_city\_compiled\default\interior_9_-3_2_4.streamingsector" 		//devil ending
		];
		for hash in fog {
			this.fogMap.Insert(hash, 1);
		}

		this.killMap = new inkIntHashMap();
		let kill = [
			2129031774482521906ul,	//"base\worlds\03_night_city\_compiled\default\quest_71b28e90733cd3a6.streamingsector", //#bls_ina_se5_border_patrols/#bls_ina_se5_tr_border_kill
			2480668857846099694ul	//"base\worlds\03_night_city\_compiled\default\quest_769927088f9d9c0c.streamingsector", //#q000_ow_border_illegal_crossing_kill_trigger
		];
		for hash in kill {
			this.killMap.Insert(hash, 1);
		}

		this.NodeIDMap = new inkIntHashMap();
		let NodeIDHashes = [
			0ul,
			3411731970021893140ul,	//T_Japan_Town_ColorGrading
			12913896672925309501ul,	//T_Vista_Del_Rey_ColorGrading
			12435876186534753387ul, //arr_trigger_ow_prefabHABY6RA
			12980175519935341392ul,	//charter_hill_tr_001
			513034362520119559ul	//wellsprings_tr
			];
			for hash in NodeIDHashes {
				this.NodeIDMap.Insert(hash, 1);
			}

		this.exceptionMap = new inkIntHashMap();
		let sectorHashes = [
			9580329194159431588ul,   //base\worlds\03_night_city\_compiled\default\exterior_15_2_6_2.streamingsector         //sun ending
			5958640450272326392ul,   //base\worlds\03_night_city\_compiled\default\ep1\exterior_-1_0_0_6.streamingsector     //Tower ending
			8539234258441371901ul,   //base\worlds\03_night_city\_compiled\default\exterior_-7_-4_0_4.streamingsector        //Spaceport ending
			11423637002921693735ul,  //base\worlds\03_night_city\_compiled\default\exterior_4_-3_0_3.streamingsector         //harris dream bd pt1
			7567707410307743172ul,   //base\worlds\03_night_city\_compiled\default\exterior_-7_-5_0_2.streamingsector        //harris dream bd pt2
			7283245298247736279ul,   //base\worlds\03_night_city\_compiled\default\exterior_1_-9_-1_0.streamingsector        //judy sample BD
			13289113946171760586ul,  //base\worlds\03_night_city\_compiled\default\exterior_-14_-15_0_1.streamingsector      //Disaster Piece BD
			10484639991579225667ul,  //base\worlds\03_night_city\_compiled\default\exterior_-7_-8_0_2.streamingsector        //judy double life BD, inside chaple
			8674988576109700383ul,   //base\worlds\03_night_city\_compiled\default\exterior_-7_-4_0_2.streamingsector        //judy double life BD, outside chaple
			17175477121902804555ul,  //base\worlds\03_night_city\_compiled\default\exterior_-6_0_2_2.streamingsector         //paralez bd
			9903342448234951128ul,   //base\worlds\03_night_city\_compiled\default\exterior_0_0_0_6.streamingsector          //arasaka tower
			16754088566340504268ul,  //base\worlds\03_night_city\_compiled\default\interior_177_-48_6_0.streamingsector      //concert as johnny, love like fire
			13554617829332014667ul,  //base\worlds\03_night_city\_compiled\default\interior_44_-12_1_2.streamingsector       //concert as johnny, love like fire
			17846823862810601880ul,  //base\worlds\03_night_city\_compiled\default\interior_11_-3_0_4.streamingsector        //concert as johnny, transmission
			12172481799580688631ul,  //base\worlds\03_night_city\_compiled\default\ep1\exterior_-1_-1_0_5.streamingsector    //Dog eat Dog
//			9750455521736200326ul,   //base\worlds\03_night_city\_compiled\default\ep1\exterior_-1_-1_0_6.streamingsector    //weather directly outside stadium near road		
			7062403257328816272ul,   //base\worlds\03_night_city\_compiled\default\ep1\exterior_-3_-4_0_3.streamingsector    //Dog eat Dog			
			14097025457928325067ul,  //base\worlds\03_night_city\_compiled\default\ep1\exterior_-23_-28_0_0.streamingsector  //Dog eat Dog			
			6844086886441367935ul,   //base\worlds\03_night_city\_compiled\default\exterior_-10_-8_0_2.streamingsector       //Razer Huges fight			
			5140784489671482520ul    //nightmare scene in deceptious bug fix
		];
		for hash in sectorHashes {
			this.exceptionMap.Insert(hash, 1);
		}

		this.pyramidSongHash = 	5347071904151188838ul; //exterior_0_-1_0_6.streamingsector
		this.darkMatterHash = 15719446892790392061ul; //exterior_-2_0_0_2.streamingsector

		/* need to be verified after each game update */

		this.pyramidNodes = [351, 352, 353, 354, 355];

		/* {trigger_bottom}, {trigger_transition}, {trigger_local}, {trigger_adaption}, {trigger_lake} */

		this.darkMatterNodes = [794];
		/* {trigger_postprocess} */

		this.isInitialized = true;
		return;
	}
}
