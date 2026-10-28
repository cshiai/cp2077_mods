module NightCityTrafficOverhaul

import NightCityTrafficOverhaul.Settings.*
import NightCityTrafficOverhaul.DistrictDB.*
import NightCityTrafficOverhaul.VehicleDB.*
import NightCityTrafficOverhaul.ModdedVehicleDB.*


// Vehicle Selector Frontend
@if(ModuleExists("VehicleSelectorHelper"))
import VehicleSelectorHelper.*

// Combat Cab Taxi System Mod
@if(ModuleExists("CombatCabTaxiSystem"))
import CombatCabTaxiSystem.*

public class NightCityTrafficOverhaul extends ScriptableSystem {

    let callbackSystem: ref<CallbackSystem>;
    let settings: ref<NCTOSettings>;
    let allVehicles: array<TweakDBID>;
    let registryPatched: Bool;

    private func OnAttach() {
        let sysHandler = GameInstance.GetSystemRequestsHandler();
        if IsDefined(sysHandler) && sysHandler.IsPreGame() { return; }
        this.callbackSystem = GameInstance.GetCallbackSystem();
        this.callbackSystem.RegisterCallback(n"Resource/Loaded", this, n"OnSectorLoaded")
            .AddTarget(ResourceTarget.Path(r"base\\worlds\\03_night_city\\_compiled\\default\\always_loaded_1.streamingsector"));

        this.settings = new NCTOSettings();
        if (this.settings.modEnabled){
            this.allVehicles = getAllVehicles();
            setTrafficSecurity(this.allVehicles);
            setTrafficSpeeds(this.allVehicles);
            setPassengersProbability();
        }
    }

    private func OnDetach() {
        if IsDefined(this.callbackSystem) {
            this.callbackSystem.UnregisterCallback(n"Resource/Loaded", this);
        }
        this.callbackSystem = null;
        this.settings = null;
        this.registryPatched = false;
    }

    private cb func OnSectorLoaded(event: ref<ResourceEvent>) {
        if this.registryPatched || !IsDefined(this.settings) || !this.settings.modEnabled {
            return;
        }
        addTrafficVehicles(event);
        this.registryPatched = true;
    }

    public final static func Log(message: String) -> Void {
        // Fixed profile: diagnostics are permanently disabled.
    }

}


@wrapMethod(VehicleComponent)
private final func VehicleDefaultStateSetup() -> Void {

    let defaultStateWasSet = this.GetPS().GetHasDefaultStateBeenSet();
    wrappedMethod();
    if defaultStateWasSet {
        return;
    }

    let settings = new NCTOSettings();
    let hijackDifficulty: Int32 = EnumInt(settings.trafficHijackDifficulty);

    if (NotEquals(hijackDifficulty, 0)){

        let vehicle = this.GetVehicle();
        let state: EQuestVehicleDoorState;
        let door: EVehicleDoor;

        if (
            IsDefined(vehicle) &&
            !IsDefined(vehicle as BikeObject) &&
            !vehicle.IsPlayerVehicle() &&
            !vehicle.IsStolen() &&
            !vehicle.IsCrowdVehicle() &&
            !vehicle.IsQuest()
            )
            {
            state = EQuestVehicleDoorState.LockAll;
            this.CreateAndSendDefaultStateEvent(door, state);
        }

    }
}



// VEHICLES
public func vehicleCheck(list: array<TweakDBID>, listName: String) -> array<TweakDBID>{
    let areMissingVehicles: Bool = false;
    let newList: array<TweakDBID>;
    let index: Int32 = 0;
    
    for vehicle in list {
        if ( StrContains( TDBID.ToStringDEBUG( vehicle ), "Vehicle")) {
            ArrayPush(newList, vehicle);
        } else {
            areMissingVehicles = true;
        }
    }

    if(areMissingVehicles){
        NightCityTrafficOverhaul.Log(s"\(listName) - Invalid vehicles found");
        for vehicle in list {
            NightCityTrafficOverhaul.Log(s"    \(index). \(TDBID.ToStringDEBUG(vehicle))");
            index += 1;
        }
    }
    return newList;
}

public func getAllVehicles() -> array<TweakDBID> {

    // VEHICLE LISTS
    let allVehicles: array<TweakDBID>;
    let vanillaList: array<TweakDBID>;
    let NCTOList: array<TweakDBID>;
    let customList: array<TweakDBID>;
    let moddedList: array<TweakDBID> = FromVariant(TweakDBInterface.GetFlat(t"Vehicle.vehicle_list.list"));

    let vehicleListIndex: Int32 = 0;
    let lastVanillaIndex: Int32 = ArrayFindFirst(moddedList, t"Vehicle.v_sportbike1_yaiba_muramasa_regular_ns_nr");

    for vehicle in moddedList {
        if(vehicleListIndex > lastVanillaIndex){ArrayPush(allVehicles, vehicle);}
        vehicleListIndex += 1;
    }

    customList = vehicleCheck(CUSTOM_VEHICLE_LIST(),  "CUSTOM_VEHICLE_LIST()");
    for vehicle in customList {ArrayPush(allVehicles, vehicle);}

    NCTOList = vehicleCheck(NCTO_VEHICLE_LIST(),  "NCTO_VEHICLE_LIST()");
    for vehicle in NCTOList {ArrayPush(allVehicles, vehicle);}

    vanillaList = vehicleCheck(VANILLA_VEHICLE_LIST(),  "VANILLA_VEHICLE_LIST()");
    for vehicle in vanillaList {ArrayPush(allVehicles, vehicle);}

    return allVehicles;
}

// Taxi Work Mod compatibility
@if(ModuleExists("TaxiWorkNightCity"))
public func TaxiModInstalled() -> Bool = true;

@if(!ModuleExists("TaxiWorkNightCity"))
public func TaxiModInstalled() -> Bool = false;


// Combat Cab Taxi System Mod compatibility
@if(ModuleExists("CombatCabTaxiSystem"))
private func GetCombatCabFleet(ganger: Bool, vanillaFleet: array<TweakDBID>) -> array<TweakDBID> {
    if ganger { return vehicleCheck(TAXI_FLEET_COMBAT_CAB_GANGER(), "TAXI_FLEET_COMBAT_CAB_GANGER()"); }
    return vehicleCheck(TAXI_FLEET_COMBAT_CAB_CIVILIAN(), "TAXI_FLEET_COMBAT_CAB_CIVILIAN()");
}

@if(!ModuleExists("CombatCabTaxiSystem"))
private func GetCombatCabFleet(ganger: Bool, vanillaFleet: array<TweakDBID>) -> array<TweakDBID> {
    return vanillaFleet;
}

// Vehicle Selector Frontend compatibility
@if(ModuleExists("VehicleSelectorHelper"))
private func GetVSFFleet(district: String, vanillaFleet: array<TweakDBID>) -> array<TweakDBID> {
    switch district {
    case "Badlands": return vehicleCheck(vsfModdedBadlands(), "MODDED_BADLANDS()");
    case "CharterHill": return vehicleCheck(vsfModdedCharterHill(), "MODDED_CHARTER_HILL()");
    case "CityCenter": return vehicleCheck(vsfModdedCityCenter(), "MODDED_CITY_CENTER()");
    case "Dogtown": return vehicleCheck(vsfModdedDogtown(), "MODDED_DOGTOWN()");
    case "Heywood": return vehicleCheck(vsfModdedHeywood(), "MODDED_HEYWOOD()");
    case "Japantown": return vehicleCheck(vsfModdedJapantown(), "MODDED_JAPANTOWN()");
    case "Kabuki": return vehicleCheck(vsfModdedKabuki(), "MODDED_KABUKI()");
    case "LittleChina": return vehicleCheck(vsfModdedLittleChina(), "MODDED_LITTLE_CHINA()");
    case "NorthOak": return vehicleCheck(vsfModdedNorthOak(), "MODDED_NORTH_OAK()");
    case "Northside": return vehicleCheck(vsfModdedNorthside(), "MODDED_NORTHSIDE()");
    case "Pacifica": return vehicleCheck(vsfModdedPacifica(), "MODDED_PACIFICA()");
    case "SantoDomingo": return vehicleCheck(vsfModdedSantoDomingo(), "MODDED_SANTO_DOMINGO()");
    }
    return vanillaFleet;
}

@if(!ModuleExists("VehicleSelectorHelper"))
private func GetVSFFleet(district: String, vanillaFleet: array<TweakDBID>) -> array<TweakDBID> {
    return vanillaFleet;
}

public func NCTOWriteLog(message: String) -> Void {
    // Compatibility shim retained for source-level call sites; no runtime output.
}


// TRAFFIC SETTINGS
public func setTrafficSpeeds(list: array<TweakDBID>) -> Void {

    let settings = new NCTOSettings();

    // BETTER PANIC REACTIONS EFFECT
    if (Equals(settings.betterPanicReaction, true)){
        // CIVILIAN INCREASED BUMPING TOLERANCE
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline5.output", t"ReactionOutput.LookAt");
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline9.output", t"ReactionOutput.LookAt");
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline10.output", t"ReactionOutput.LookAt");
        TweakDBManager.UpdateRecord(t"ReactionPresets.InVehicle_Civilian");
    
        // CIVILIZED PANIC DRIVING
        TweakDBManager.SetFlat(t"Crowds.PanicDrivingPattern.settings", t"Crowds.NCTO_PanicDrivingSlow");
        TweakDBManager.UpdateRecord(t"Crowds.PanicDrivingPattern");

    } else {
        // RESTORE VANILLA PANIC REACTIONS
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline5.output", t"ReactionOutput.Flee");
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline9.output", t"ReactionOutput.Flee");
        TweakDBManager.SetFlat(t"ReactionPresets.InVehicle_Civilian_inline10.output", t"ReactionOutput.Flee");
        TweakDBManager.UpdateRecord(t"ReactionPresets.InVehicle_Civilian");
        TweakDBManager.SetFlat(t"Crowds.PanicDrivingPattern.settings", t"Crowds.PanicDriving");
        TweakDBManager.UpdateRecord(t"Crowds.PanicDrivingPattern");                

    }

    // USER SPEED SETTINGS
    let sportVehiclesMaxSpeed: Float = settings.sportVehiclesMaxSpeed;
    let sportBikesMaxSpeed: Float = settings.sportBikesMaxSpeed;
    let SUVMaxSpeed: Float = settings.SUVMaxSpeed;
    let normalVehiclesMaxSpeed: Float = settings.normalVehiclesMaxSpeed;
    let truckVehiclesMaxSpeed: Float = settings.truckVehiclesMaxSpeed;
    let miniVehiclesMaxSpeed: Float = settings.miniVehiclesMaxSpeed;

    let sportVehiclesAcceleration: Float = settings.sportVehiclesAcceleration;
    let sportBikesAcceleration: Float = settings.sportBikesAcceleration;
    let SUVAcceleration: Float = settings.SUVAcceleration;
    let normalVehiclesAcceleration: Float = settings.normalVehiclesAcceleration;
    let trucksAcceleration: Float = settings.trucksAcceleration;
    let miniVehiclesAcceleration: Float = settings.miniVehiclesAcceleration;

    // VANILLA DRIVING SETTINGS
    let crowdPackage: TweakDBID;
    let bikeCheck: TweakDBID;

    // Crowds.Bike_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Bike_Sport_Driving.maxSpeed", sportBikesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.Bike_Sport_Driving.acceleration", 8.0 * sportBikesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Bike_Sport_Driving");

    // Crowds.Sport_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Car_Sport_Driving.maxSpeed", sportVehiclesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.Car_Sport_Driving.acceleration", 8.0 * sportVehiclesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Car_Sport_Driving");

    // Crowds.SUV_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.SUV_Normal_Driving.maxSpeed", SUVMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.SUV_Normal_Driving.acceleration", 4.5 * SUVAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.SUV_Normal_Driving");

    // Crowds.Commoners_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Commoners_Normal_Driving.maxSpeed", normalVehiclesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.Commoners_Normal_Driving.acceleration", 6.0 * normalVehiclesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Commoners_Normal_Driving");

    // Crowds.Truck_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Truck_Normal_Driving.maxSpeed", truckVehiclesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.Truck_Normal_Driving.acceleration", 3.5 * trucksAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Truck_Normal_Driving");

    TweakDBManager.SetFlat(t"Crowds.Truck_Slow_Driving.maxSpeed", truckVehiclesMaxSpeed * 0.9 );
    TweakDBManager.SetFlat(t"Crowds.Truck_Slow_Driving.acceleration", 2.5 * trucksAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Truck_Slow_Driving");

    // Crowds.Mini_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Mini_Normal_Driving.maxSpeed", miniVehiclesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.Mini_Normal_Driving.acceleration", 5.0 * miniVehiclesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Mini_Normal_Driving");

    TweakDBManager.SetFlat(t"Crowds.Mini_Slow_Driving.maxSpeed", miniVehiclesMaxSpeed * 0.8 );
    TweakDBManager.SetFlat(t"Crowds.Mini_Slow_Driving.acceleration", 4.0 * miniVehiclesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.Mini_Slow_Driving");

    // Crowds.DefaultCarPackage:
    TweakDBManager.SetFlat(t"Crowds.DefaultDriving.maxSpeed", normalVehiclesMaxSpeed );
    TweakDBManager.SetFlat(t"Crowds.DefaultDriving.acceleration", 5.0 * normalVehiclesAcceleration );
    TweakDBManager.UpdateRecord(t"Crowds.DefaultDriving");

    for vehicle in list {
        crowdPackage = FromVariant(TweakDBInterface.GetFlat(vehicle+t".crowdMemberSettings"));
        TweakDBManager.UpdateRecord(crowdPackage);
        TweakDBManager.SetFlat(vehicle+t".crowdMemberSettings", crowdPackage);
        TweakDBManager.UpdateRecord(vehicle);
        bikeCheck = FromVariant(TweakDBInterface.GetFlat(vehicle+t".type"));
        if (Equals(bikeCheck, t"Vehicle.Bike")) {
            TweakDBManager.SetFlat(vehicle+t".crowdMemberSettings", t"Crowds.Sportbike_DrivingPackage");
            TweakDBManager.UpdateRecord(vehicle);
        }

    }

}

public func setTrafficSecurity(vehicleList: array<TweakDBID>) -> Void {

    let settings = new NCTOSettings();
    let securityLevel: Int32 = EnumInt(settings.trafficHijackDifficulty);

    if (NotEquals(securityLevel, 0)){

        let hijackDifficulty: String;

        switch (securityLevel){
            case 1: hijackDifficulty = "TRIVIAL"; break;
            case 2: hijackDifficulty = "MEDIUM"; break;
            case 3: hijackDifficulty = "HARD"; break;
            case 4: hijackDifficulty = "IMPOSSIBLE"; break;
            default: hijackDifficulty = "none"; break;
        }

        for vehicle in vehicleList {
            TweakDBManager.SetFlat(vehicle+t".hijackDifficulty", hijackDifficulty);
            TweakDBManager.SetFlat(vehicle+t".crackLockDifficulty", hijackDifficulty);
            TweakDBManager.UpdateRecord(vehicle);
        }
    } 

}

public func resetTrafficSecurity(vehicleList: array<TweakDBID>) -> Void {
    let crowdPackage: TweakDBID;
    for vehicle in vehicleList {
        let hijackDifficulty: String = FromVariant(TweakDBInterface.GetFlat(vehicle+t".hijackDifficulty"));
        TweakDBManager.SetFlat(vehicle+t".hijackDifficulty", hijackDifficulty);
        TweakDBManager.SetFlat(vehicle+t".crackLockDifficulty", hijackDifficulty);
        TweakDBManager.UpdateRecord(vehicle);
    }
}

public func setPassengersProbability() -> Void {

    let settings = new NCTOSettings();

    // PASSENGERS
    TweakDBManager.SetFlat(t"Passengers.policePassengerFrontEntry.probability", settings.policeFrontPassengersProbability / 100.0);
    TweakDBManager.UpdateRecord(t"Passengers.policePassengerFrontEntry");
    TweakDBManager.SetFlat(t"Passengers.policePassengerBackEntry.probability", settings.policeBackPassengersProbability / 100.0);
    TweakDBManager.UpdateRecord(t"Passengers.policePassengerBackEntry");

    let gangFrontPassengerList = GANG_FRONT_PASSENGER_LIST();
    let gangBackPassengerList = GANG_BACK_PASSENGER_LIST();

    for passenger in gangFrontPassengerList {
        TweakDBManager.SetFlat(passenger+t".probability", settings.gangsFrontPassengersProbability / 100.0);
        TweakDBManager.UpdateRecord(passenger);
    }

    for passenger in gangBackPassengerList {
        TweakDBManager.SetFlat(passenger+t".probability", settings.gangsBackPassengersProbability / 100.0);
        TweakDBManager.UpdateRecord(passenger);
    }

}

public func resetTrafficSpeeds(list: array<TweakDBID>) -> Void {

    // Crowds.Sport_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Car_Sport_Driving.maxSpeed", 41.0 );
    TweakDBManager.SetFlat(t"Crowds.Car_Sport_Driving.acceleration", 8.0);
    TweakDBManager.UpdateRecord(t"Crowds.Car_Sport_Driving");

    // Crowds.SUV_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.SUV_Normal_Driving.maxSpeed", 31.0 );
    TweakDBManager.SetFlat(t"Crowds.SUV_Normal_Driving.acceleration", 4.5 );
    TweakDBManager.UpdateRecord(t"Crowds.SUV_Normal_Driving");

    // Crowds.Commoners_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Commoners_Normal_Driving.maxSpeed", 31.0 );
    TweakDBManager.SetFlat(t"Crowds.Commoners_Normal_Driving.acceleration", 6.0 );
    TweakDBManager.UpdateRecord(t"Crowds.Commoners_Normal_Driving");

    // Crowds.Truck_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Truck_Normal_Driving.maxSpeed", 28.0 );
    TweakDBManager.SetFlat(t"Crowds.Truck_Normal_Driving.acceleration", 3.5 );
    TweakDBManager.UpdateRecord(t"Crowds.Truck_Normal_Driving");

    TweakDBManager.SetFlat(t"Crowds.Truck_Slow_Driving.maxSpeed", 25.0 );
    TweakDBManager.SetFlat(t"Crowds.Truck_Slow_Driving.acceleration", 2.5 );
    TweakDBManager.UpdateRecord(t"Crowds.Truck_Slow_Driving");

    // Crowds.Mini_DrivingPackage:
    TweakDBManager.SetFlat(t"Crowds.Mini_Normal_Driving.maxSpeed", 26.0 );
    TweakDBManager.SetFlat(t"Crowds.Mini_Normal_Driving.acceleration", 5.0 );
    TweakDBManager.UpdateRecord(t"Crowds.Mini_Normal_Driving");

    TweakDBManager.SetFlat(t"Crowds.Mini_Slow_Driving.maxSpeed", 21.0 );
    TweakDBManager.SetFlat(t"Crowds.Mini_Slow_Driving.acceleration", 4.0 );
    TweakDBManager.UpdateRecord(t"Crowds.Mini_Slow_Driving");
    
    // Crowds.DefaultCarPackage:
    TweakDBManager.SetFlat(t"Crowds.DefaultDriving.maxSpeed", 32.0 );
    TweakDBManager.SetFlat(t"Crowds.DefaultDriving.acceleration", 5.0 );
    TweakDBManager.UpdateRecord(t"Crowds.DefaultDriving");

    let crowdPackage: TweakDBID;
    for vehicle in list {
        crowdPackage = FromVariant(TweakDBInterface.GetFlat(vehicle+t".crowdMemberSettings"));
        TweakDBManager.UpdateRecord(crowdPackage);
        TweakDBManager.SetFlat(vehicle+t".crowdMemberSettings", crowdPackage);
        TweakDBManager.UpdateRecord(vehicle);

    }
}

// TRAFFIC SYSTEM
public func filterUnwantedVanillaVehicles(node: ref<worldCommunityRegistryNode>, dataI: Int32, periodI: Int32) -> Void {
    let toRemove: array<Int32>;
    let charDatas = node.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData;
    let i: Int32 = 0;
    while i < ArraySize(charDatas) {
        let vehicle: TweakDBID = charDatas[i].characterRecordId;
        if (
            Equals(vehicle, t"Vehicle.v_standard2_archer_hella_police_prevention") ||
            Equals(vehicle, t"Vehicle.v_standard2_villefort_cortes_police_prevention") ||
            Equals(vehicle, t"Vehicle.v_standard3_chevalier_emperor_police_prevention") ||
            Equals(vehicle, t"Vehicle.v_standard25_mahir_mox") ||
            Equals(vehicle, t"Vehicle.v_sport2_villefort_alvarado_mox") ||
            Equals(vehicle, t"Vehicle.v_standard2_archer_quartz_tyger") ||
            Equals(vehicle, t"Vehicle.v_standard25_villefort_columbus_tyger") ||
            Equals(vehicle, t"Vehicle.v_sport2_mizutani_shion_tyger") ||
            Equals(vehicle, t"Vehicle.v_sport1_quadra_turbo_tyger_claw") ||
            Equals(vehicle, t"Vehicle.v_standard2_chevalier_thrax_maelstrom") ||
            Equals(vehicle, t"Vehicle.v_standard2_thorton_galena_maelstrom") ||
            Equals(vehicle, t"Vehicle.v_standard2_thorton_galena_nomad") ||
            Equals(vehicle, t"Vehicle.v_standard25_thorton_colby_nomad")
            )
            {
            ArrayPush(toRemove, i);
        };
        i += 1;
    };
    let r: Int32 = ArraySize(toRemove) - 1;
    while r >= 0 {
        ArrayErase(node.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, toRemove[r]);
        r -= 1;
    };
}

public func createCharacterData(vehicleName: TweakDBID, weight: Float) -> gameCrowdTemplateCharacterData {
    let newCharacterData: gameCrowdTemplateCharacterData;
    newCharacterData.characterRecordId = vehicleName;
    newCharacterData.weight = weight;
    return newCharacterData;
}

public func SetCharDataRecordID(node: ref<worldCommunityRegistryNode>, dataI: Int32, periodI: Int32, charDataI: Int32, vehicle: TweakDBID) {
    node.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData[charDataI].characterRecordId = vehicle;
}

public func SetCharDataWeight(node: ref<worldCommunityRegistryNode>, dataI: Int32, periodI: Int32, charDataI: Int32, weight: Float) {
    node.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData[charDataI].weight = weight;
}

public func matchRandomPassengersSlots(basePassengers: array<TweakDBID>, desiredPassengers: array<TweakDBID>) -> array<TweakDBID>{
    let newPassengers: array<TweakDBID>;
    let i = 0;
    let slots = ArraySize(basePassengers);
    if (slots < 1){ slots = 1; }

    while i < slots {
        ArrayPush(newPassengers, desiredPassengers[i]);
        i += 1;
    }

    return newPassengers;
}

public func CrowdRegistryNodeIndices() -> array<Int32> = [3495, 3256];

public func ProbeCommunityRegistryNode(resource: ref<worldStreamingSector>) -> ref<worldCommunityRegistryNode> {
    let count: Int32 = resource.GetNodeCount();
    for index in CrowdRegistryNodeIndices() {
        if index < count {
            let node = resource.GetNode(index) as worldCommunityRegistryNode;
            if IsDefined(node) {
                return node;
            }
        }
    }
    return null;
}

public func FindCommunityRegistryNode(resource: ref<worldStreamingSector>) -> ref<worldCommunityRegistryNode> {
    let count: Int32 = resource.GetNodeCount();
    let i: Int32 = 0;
    while i < count {
        let node = resource.GetNode(i) as worldCommunityRegistryNode;
        if IsDefined(node) {
            NightCityTrafficOverhaul.Log(s"Crowd registry node is not at a known index - found at \(i).");
            return node;
        }
        i += 1;
    }
    return null;
}

// MAIN TRAFFIC FUNCTION
public func addTrafficVehicles(event: ref<ResourceEvent>) -> Void {

    let settings = new NCTOSettings();
    let allVehicles = getAllVehicles();

    // public transport
    let taxiFleet: array<TweakDBID>;
    let delamainFleet: array<TweakDBID>;
    let busFleet: array<TweakDBID>;

    // police
    let ncpdFleet: array<TweakDBID>;
    let ncpdHighFleet: array<TweakDBID>;
    let militechFleet: array<TweakDBID>;
    let arasakaFleet: array<TweakDBID>;
    let securityCharterHillFleet: array<TweakDBID>;

    // utility
    let companyFleet: array<TweakDBID>;
    let badlandsUtilityFleet: array<TweakDBID>;
    let cityCenterExtrasFleet: array<TweakDBID>;
    let cityCenterUtilityFleet: array<TweakDBID>;
    let littleChinaUtilityFleet: array<TweakDBID>;
    let japantownUtilityFleet: array<TweakDBID>;
    let northsideUtilityFleet: array<TweakDBID>;

    // gang
    let aldelcaldosFleet: array<TweakDBID>;
    let animalsFleet: array<TweakDBID>;
    let barghestFleet: array<TweakDBID>;
    let kangtaoFleet: array<TweakDBID>;
    let maelstromFleet: array<TweakDBID>;
    let moxFleet: array<TweakDBID>;
    let scavFleet: array<TweakDBID>;
    let sixthstreetFleet: array<TweakDBID>;
    let tygerFleet: array<TweakDBID>;
    let valentinoFleet: array<TweakDBID>;
    let voodooFleet: array<TweakDBID>;
    let wraithFleet: array<TweakDBID>;

    // modded
    let badlandsModdedFleet: array<TweakDBID>;
    let charterHillModdedFleet: array<TweakDBID>;
    let cityCenterModdedFleet: array<TweakDBID>;
    let dogtownModdedFleet: array<TweakDBID>;
    let heywoodModdedFleet: array<TweakDBID>;
    let japantownModdedFleet: array<TweakDBID>;
    let kabukiModdedFleet: array<TweakDBID>;
    let littleChinaModdedFleet: array<TweakDBID>;
    let northOakModdedFleet: array<TweakDBID>;
    let northsideModdedFleet: array<TweakDBID>;
    let pacificaModdedFleet: array<TweakDBID>;
    let santodomingoModdedFleet: array<TweakDBID>;

    // modded test list
    let testModdedFleet: array<TweakDBID>;

    // active gangs
    let isActiveBadlandsGang1: Bool = false;
    let isActiveBadlandsGang2: Bool = false;
    let isActiveDogtownGang1: Bool = false;
    let isActiveDogtownGang2: Bool = false;
    let isActiveHeywoodGang1: Bool = false;
    let isActiveHeywoodGang2: Bool = false;
    let isActiveJapantownGang1: Bool = false;
    let isActiveJapantownGang2: Bool = false;
    let isActiveKabukiGang1: Bool = false;
    let isActiveKabukiGang2: Bool = false;
    let isActiveLittleChinaGang1: Bool = false;
    let isActiveLittleChinaGang2: Bool = false;
    let isActiveNorthsideGang1: Bool = false;
    let isActiveNorthsideGang2: Bool = false;
    let isActivePacificaGang1: Bool = false;
    let isActivePacificaGang2: Bool = false;
    let isActiveSantoDomingoGang1: Bool = false;
    let isActiveSantoDomingoGang2: Bool = false;

    // ACTIVE INCURSIONS
    let isActiveHeywoodIncursion: Bool = false;
    let isActiveJapantownIncursion: Bool = false;
    let isActiveKabukiIncursion: Bool = false;
    let isActiveLittleChinaIncursion: Bool = false;
    let isActiveNorthsideIncursion: Bool = false;
    let isActivePacificaIncursion: Bool = false;
    let isActiveSantoDomingoIncursion: Bool = false;

    // INCURSIONS FLEETS
    let heywoodIncursion: array<TweakDBID>;
    let japantownIncursion: array<TweakDBID>;
    let kabukiIncursion: array<TweakDBID>;
    let littleChinaIncursion: array<TweakDBID>;
    let northsideIncursion: array<TweakDBID>;
    let pacificaIncursion: array<TweakDBID>;
    let santoDomingoIncursion: array<TweakDBID>;

    // TAXIS
    if (settings.sixthStreetTaxiDriver){taxiFleet = vehicleCheck(TAXI_FLEET(), "TAXI_FLEET()");}
    else {taxiFleet = vehicleCheck(TAXI_FLEET_PASSIVE(), "TAXI_FLEET_PASSIVE()");}

    // TAXI WORK MOD
    if (TaxiModInstalled()){
        taxiFleet = [];
    }

    // COMBAT CAB TAXI SYSTEM
    taxiFleet = GetCombatCabFleet(settings.sixthStreetTaxiDriver, taxiFleet);

    // DELAMAIN
    delamainFleet = vehicleCheck(DELAMAIN_FLEET(), "DELAMAIN_FLEET()");

    // DRIVE A BUS MOD COMPATIBILITY
    if (ArrayContains(allVehicles, t"Vehicle.cs_savable_mahir_mt28_coach_dab")){busFleet = vehicleCheck(BUS_FLEET_MOD(), "BUS_FLEET_MOD()");}
    else {busFleet =  vehicleCheck(BUS_FLEET(), "BUS_FLEET()");}

    // NCPD
    ncpdFleet = vehicleCheck(POLICE_NCPD_FLEET(), "POLICE_NCPD_FLEET()");
    ncpdHighFleet = vehicleCheck(POLICE_NCPD_HIGH_FLEET(), "POLICE_NCPD_HIGH_FLEET()");

    // SECURITY
    securityCharterHillFleet = vehicleCheck(SECURITY_CHARTER_HILL_FLEET(), "SECURITY_CHARTER_HILL_FLEET()");

    // UTILITY / CIV
    badlandsUtilityFleet = vehicleCheck(BADLANDS_UTILITY_FLEET(), "BADLANDS_UTILITY_FLEET()");
    cityCenterExtrasFleet = vehicleCheck(CITY_CENTER_EXTRAS_FLEET(), "CITY_CENTER_EXTRAS_FLEET()");
    cityCenterUtilityFleet = vehicleCheck(CITY_CENTER_UTILITY_FLEET(), "CITY_CENTER_UTILITY_FLEET()");
    companyFleet = vehicleCheck(COMPANY_SERVICES_FLEET(), "COMPANY_SERVICES_FLEET()");
    japantownUtilityFleet = vehicleCheck(JAPANTOWN_UTILITY_FLEET(), "JAPANTOWN_UTILITY_FLEET()");
    littleChinaUtilityFleet = vehicleCheck(LITTLE_CHINA_UTILITY_FLEET(), "LITTLE_CHINA_UTILITY_FLEET()");
    northsideUtilityFleet = vehicleCheck(NORTHSIDE_UTILITY_FLEET(), "NORTHSIDE_UTILITY_FLEET()");

    // GANG LISTS
    aldelcaldosFleet = vehicleCheck(GANG_ALDELCADOS_FLEET(), "GANG_ALDELCADOS_FLEET()");
    animalsFleet = vehicleCheck(GANG_ANIMALS_FLEET(), "GANG_ANIMALS_FLEET()");
    arasakaFleet = vehicleCheck(SECURITY_ARASAKA_FLEET(), "SECURITY_ARASAKA_FLEET()");
    barghestFleet = vehicleCheck(GANG_BARGHEST_FLEET(), "GANG_BARGHEST_FLEET()");
    kangtaoFleet = vehicleCheck(GANG_KANGTAO_FLEET(), "GANG_KANGTAO_FLEET()");
    maelstromFleet = vehicleCheck(GANG_MAESLTROM_FLEET(), "GANG_MAESLTROM_FLEET()");
    militechFleet = vehicleCheck(POLICE_MILITECH_FLEET(), "POLICE_MILITECH_FLEET()");
    moxFleet = vehicleCheck(GANG_MOX_FLEET(), "GANG_MOX_FLEET()");
    sixthstreetFleet = vehicleCheck(GANG_SIXTHSTREET_FLEET(), "GANG_SIXTHSTREET_FLEET()");
    scavFleet = vehicleCheck(GANG_SCAVENGERS_FLEET(), "GANG_SCAVENGERS_FLEET()");
    tygerFleet = vehicleCheck(GANG_TYGER_FLEET(), "GANG_TYGER_FLEET()");
    valentinoFleet = vehicleCheck(GANG_VALENTINOS_FLEET(), "GANG_VALENTINOS_FLEET()");
    voodooFleet = vehicleCheck(GANG_VOODOO_FLEET(), "GANG_VOODOO_FLEET()");
    wraithFleet = vehicleCheck(GANG_WRAITH_FLEET(), "GANG_WRAITH_FLEET()");

    // MODDED LISTS

    let autoDistribution = settings.autoDistributeModdedVehicles;
    let autoOccupy = settings.autoSetRandomPassengers;

    if (autoDistribution || autoOccupy){

        let moddedList: array<TweakDBID> = FromVariant(TweakDBInterface.GetFlat(t"Vehicle.vehicle_list.list"));

        let vehicleListIndex: Int32 = 0;
        let lastVanillaIndex: Int32 = ArrayFindFirst(moddedList, t"Vehicle.v_sportbike1_yaiba_muramasa_regular_ns_nr");

        let randomPassengers: array<TweakDBID>;
        let passengersSelection: array<TweakDBID>;
        let passengersHighClass: array<array<TweakDBID>> = [[t"Passengers.CitizenRichDriverEntry", t"Passengers.CitizenRichPassengerFrontEntry", t"Passengers.CitizenRichPassengerBackEntry"], [t"Passengers.CorpoArasakaDriverEntry", t"Passengers.CorpoArasakaPassengerFrontEntry", t"Passengers.CorpoArasakaPassengerBackEntry"], [t"Passengers.CorporatDriverEntry", t"Passengers.CorporatPassengerFrontEntry", t"Passengers.CorporatPassengerBackEntry"]];
        let passengersLowClass: array<array<TweakDBID>> = [[t"Passengers.LowlifeDriverEntry", t"Passengers.LowlifePassengerFrontEntry", t"Passengers.LowlifePassengerBackEntry"], [t"Passengers.LowlifeRedneckDriverEntry", t"Passengers.LowlifeRedneckPassengerFrontEntry", t"Passengers.LowlifeRedneckPassengerBackEntry"], [t"Passengers.NightLifeDriverEntry", t"Passengers.NightLifePassengerFrontEntry", t"Passengers.NightLifePassengerBackEntry"]];
        let passengersWorkers: array<array<TweakDBID>> = [[t"Passengers.MunicipialMaleDriverEntry", t"Passengers.MunicipialMalePassengerFrontEntry", t"Passengers.MunicipialMalePassengerBackEntry"], [t"Passengers.WorkerDriverEntry", t"Passengers.WorkerPassengerFrontEntry", t"Passengers.WorkerPassengerBackEntry"]];

        let passengersNCPD: array<TweakDBID> = [t"Passengers.policeDriverEntry", t"Passengers.policePassengerFrontEntry", t"Passengers.PolicePassengerBackEntry"];
        let passengersAldecaldos: array<TweakDBID> = [t"Passengers.AldecaldosDriverEntry", t"Passengers.AldecaldosPassengerFrontEntry", t"Passengers.AldecaldosPassengerBackEntry"];
        let passengersAnimals: array<TweakDBID> = [t"Passengers.AnimalsDriverEntry", t"Passengers.AnimalsPassengerFrontEntry", t"Passengers.AnimalsPassengerBackEntry"];
        let passengersArasaka: array<TweakDBID> = [t"Passengers.ArasakaCorpoDriverEntry", t"Passengers.ArasakaCorpoGuardFrontPassengerEntry", t"Passengers.ArasakaCorpoPassengerBackEntry"];
        let passengersKangTao: array<TweakDBID> = [t"Passengers.KangtaoDriverEntry", t"Passengers.KangtaoPassengerFrontEntry", t"Passengers.KangtaoPassengerBackEntry"];
        let passengersMaelstrom: array<TweakDBID> = [t"Passengers.MaelstromDriverEntry", t"Passengers.MaelstromPassengerFrontEntry", t"Passengers.MaelstromPassengerBackEntry"];
        let passengersMilitech: array<TweakDBID> = [t"Passengers.MilitechDriverEntry", t"Passengers.MilitechPassengerFrontEntry", t"Passengers.MilitechPassengerBackEntry"];
        let passengersMox: array<TweakDBID> = [t"Passengers.MoxDriverEntry", t"Passengers.MoxPassengerFrontEntry", t"Passengers.MoxPassengerBackEntry"];
        let passengersScavengers: array<TweakDBID> = [t"Passengers.ScavengersDriverEntry", t"Passengers.ScavengersPassengerFrontEntry", t"Passengers.ScavengersPassengerBackEntry"];
        let passengersSixthStreet: array<TweakDBID> = [t"Passengers.SixthstreetDriverEntry", t"Passengers.SixthstreetPassengerFrontEntry", t"Passengers.SixthstreetPassengerBackEntry"];
        let passengersTyger: array<TweakDBID> = [t"Passengers.TygerDriverEntry", t"Passengers.TygerPassengerFrontEntry", t"Passengers.TygerPassengerBackEntry"];
        let passengersValentinos: array<TweakDBID> = [t"Passengers.ValentinosDriverEntry", t"Passengers.ValentinosPassengerFrontEntry", t"Passengers.ValentinosPassengerBackEntry"];
        let passengersVoodooBoys: array<TweakDBID> = [t"Passengers.VoodooDriverEntry", t"Passengers.VoodooPassengerFrontEntry", t"Passengers.VoodooPassengerBackEntry"];
        let passengersWraiths: array<TweakDBID> = [t"Passengers.WraithDriverEntry", t"Passengers.WraithPassengerFrontEntry", t"Passengers.WraithPassengerBackEntry"];

        for vehicle in moddedList {
            if(vehicleListIndex > lastVanillaIndex){

                let vehicleCategories: array<CName> = FromVariant(TweakDBInterface.GetFlat(vehicle+t".visualTags"));
                let vehicleCategory: String = NameToString(ArrayPop(vehicleCategories));
                let vehicleRandomPassengers: array<TweakDBID> = FromVariant(TweakDBInterface.GetFlat(vehicle+t".randomPassengers"));
                let vehicleSlots: Int32 = ArraySize(vehicleRandomPassengers);

                switch (vehicleCategory) {
                case "Poor":
                    if (autoDistribution){
                        ArrayPush(badlandsModdedFleet, vehicle);
                        ArrayPush(dogtownModdedFleet, vehicle);
                        ArrayPush(kabukiModdedFleet, vehicle);
                        ArrayPush(northsideModdedFleet, vehicle);
                        ArrayPush(pacificaModdedFleet, vehicle);
                        ArrayPush(santodomingoModdedFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersLowClass[RandRange(0, ArraySize(passengersLowClass))];
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Standard":
                    if (autoDistribution){
                        ArrayPush(kabukiModdedFleet, vehicle);
                        ArrayPush(northsideModdedFleet, vehicle);
                        ArrayPush(santodomingoModdedFleet, vehicle);
                        ArrayPush(heywoodModdedFleet, vehicle);
                        ArrayPush(japantownModdedFleet, vehicle);
                        ArrayPush(littleChinaModdedFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersLowClass[RandRange(0, ArraySize(passengersLowClass))];
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Premium":
                    if (autoDistribution){
                        ArrayPush(heywoodModdedFleet, vehicle);
                        ArrayPush(japantownModdedFleet, vehicle);
                        ArrayPush(littleChinaModdedFleet, vehicle);
                        ArrayPush(charterHillModdedFleet, vehicle);
                        ArrayPush(cityCenterModdedFleet, vehicle);
                        ArrayPush(northOakModdedFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersHighClass[RandRange(0, ArraySize(passengersHighClass))];
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Sport":
                    if (autoDistribution){
                        ArrayPush(heywoodModdedFleet, vehicle);
                        ArrayPush(japantownModdedFleet, vehicle);
                        ArrayPush(littleChinaModdedFleet, vehicle);
                        ArrayPush(charterHillModdedFleet, vehicle);
                        ArrayPush(cityCenterModdedFleet, vehicle);
                        ArrayPush(northOakModdedFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersHighClass[RandRange(0, ArraySize(passengersHighClass))];
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "NCPD":
                    if (autoDistribution){
                        ArrayPush(ncpdFleet, vehicle);
                        ArrayPush(ncpdHighFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersNCPD;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Aldecados":
                    if (autoDistribution){
                        ArrayPush(aldelcaldosFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersAldecaldos;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Animals":
                    if (autoDistribution){
                        ArrayPush(animalsFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersAnimals;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Arasaka":
                    if (autoDistribution){
                        ArrayPush(arasakaFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersArasaka;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "KangTao":
                    if (autoDistribution){
                        ArrayPush(kangtaoFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersKangTao;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Maelstrom":
                    if (autoDistribution){
                        ArrayPush(maelstromFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersMaelstrom;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Militech":
                    if (autoDistribution){
                        ArrayPush(militechFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersMilitech;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "TheMox":
                    if (autoDistribution){
                        ArrayPush(moxFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersMox;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "SixthStreet":
                    if (autoDistribution){
                        ArrayPush(sixthstreetFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersSixthStreet;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Scavengers":
                    if (autoDistribution){
                        ArrayPush(scavFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersScavengers;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "TygerClaws":
                    if (autoDistribution){
                        ArrayPush(tygerFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersTyger;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Valentinos":
                    if (autoDistribution){
                        ArrayPush(valentinoFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersValentinos;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "VoodooBoys":
                    if (autoDistribution){
                        ArrayPush(voodooFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersVoodooBoys;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                case "Wraiths":
                    if (autoDistribution){
                        ArrayPush(wraithFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersWraiths;
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                default:
                    if (autoDistribution){
                        ArrayPush(kabukiModdedFleet, vehicle);
                        ArrayPush(northsideModdedFleet, vehicle);
                        ArrayPush(santodomingoModdedFleet, vehicle);
                        ArrayPush(heywoodModdedFleet, vehicle);
                        ArrayPush(japantownModdedFleet, vehicle);
                        ArrayPush(littleChinaModdedFleet, vehicle);
                    }
                    if (autoOccupy){
                        passengersSelection = passengersLowClass[RandRange(0, ArraySize(passengersLowClass))];
                        randomPassengers = matchRandomPassengersSlots(vehicleRandomPassengers, passengersSelection);
                        TweakDBManager.SetFlat(vehicle+t".randomPassengers", randomPassengers);
                    }
                    break;
                }
            }
            vehicleListIndex += 1;
        }

    } else {
        badlandsModdedFleet = GetVSFFleet("Badlands", vehicleCheck(MODDED_BADLANDS(), "MODDED_BADLANDS()"));
        charterHillModdedFleet = GetVSFFleet("CharterHill", vehicleCheck(MODDED_CHARTER_HILL(), "MODDED_CHARTER_HILL()"));
        cityCenterModdedFleet = GetVSFFleet("CityCenter", vehicleCheck(MODDED_CITY_CENTER(), "MODDED_CITY_CENTER()"));
        dogtownModdedFleet = GetVSFFleet("Dogtown", vehicleCheck(MODDED_DOGTOWN(), "MODDED_DOGTOWN()"));
        heywoodModdedFleet = GetVSFFleet("Heywood", vehicleCheck(MODDED_HEYWOOD(), "MODDED_HEYWOOD()"));
        japantownModdedFleet = GetVSFFleet("Japantown", vehicleCheck(MODDED_JAPANTOWN(), "MODDED_JAPANTOWN()"));
        kabukiModdedFleet = GetVSFFleet("Kabuki", vehicleCheck(MODDED_KABUKI(), "MODDED_KABUKI()"));
        littleChinaModdedFleet = GetVSFFleet("LittleChina", vehicleCheck(MODDED_LITTLE_CHINA(), "MODDED_LITTLE_CHINA()"));
        northOakModdedFleet = GetVSFFleet("NorthOak", vehicleCheck(MODDED_NORTH_OAK(), "MODDED_NORTH_OAK()"));
        northsideModdedFleet = GetVSFFleet("Northside", vehicleCheck(MODDED_NORTHSIDE(), "MODDED_NORTHSIDE()"));
        pacificaModdedFleet = GetVSFFleet("Pacifica", vehicleCheck(MODDED_PACIFICA(), "MODDED_PACIFICA()"));
        santodomingoModdedFleet = GetVSFFleet("SantoDomingo", vehicleCheck(MODDED_SANTO_DOMINGO(), "MODDED_SANTO_DOMINGO()"));
    }

    testModdedFleet = vehicleCheck(MODDED_TEST_LIST(), "MODDED_TEST_LIST()");

    // ACTIVE SECONDARY GANGS
    let secondaryGangsChances: Float = settings.secondaryGangsProbability / 100.0;

    if(secondaryGangsChances >= RandF()){isActiveBadlandsGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveBadlandsGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveDogtownGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveDogtownGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveHeywoodGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveHeywoodGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveJapantownGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveJapantownGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveKabukiGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveKabukiGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveLittleChinaGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveLittleChinaGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveNorthsideGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveNorthsideGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActivePacificaGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActivePacificaGang2 = true;};
    if(secondaryGangsChances >= RandF()){isActiveSantoDomingoGang1 = true;};
    if(secondaryGangsChances >= RandF()){isActiveSantoDomingoGang2 = true;};

    // ACTIVE INCURSIONS
    let outsideGangsChances: Float = settings.outsideGangsProbability / 100.0;

    if(outsideGangsChances >= RandF()){isActiveHeywoodIncursion = true;};
    if(outsideGangsChances >= RandF()){isActiveJapantownIncursion = true;};
    if(outsideGangsChances >= RandF()){isActiveKabukiIncursion = true;};
    if(outsideGangsChances >= RandF()){isActiveLittleChinaIncursion = true;};
    if(outsideGangsChances >= RandF()){isActiveNorthsideIncursion = true;};
    if(outsideGangsChances >= RandF()){isActivePacificaIncursion = true;};
    if(outsideGangsChances >= RandF()){isActiveSantoDomingoIncursion = true;};

    // INCURSIONS MODE
    let outsideGangsMode: String;

    switch (settings.outsideGangsModeOption){
        case 0: outsideGangsMode = "SINGLE"; break;
        case 1: outsideGangsMode = "MIXED"; break;
    }

    if(Equals(outsideGangsMode, "MIXED")){

        if isActiveHeywoodIncursion {
            for vehicle in sixthstreetFleet{ArrayPush(heywoodIncursion, vehicle);}
            for vehicle in animalsFleet{ArrayPush(heywoodIncursion, vehicle);}
            for vehicle in tygerFleet{ArrayPush(heywoodIncursion, vehicle);}   
        }

        if isActiveJapantownIncursion {
            for vehicle in sixthstreetFleet{ArrayPush(japantownIncursion, vehicle);}
            for vehicle in animalsFleet{ArrayPush(japantownIncursion, vehicle);}
            for vehicle in tygerFleet{ArrayPush(japantownIncursion, vehicle);}   
        }

        if isActiveJapantownIncursion {
            for vehicle in maelstromFleet{ArrayPush(japantownIncursion, vehicle);}
            for vehicle in valentinoFleet{ArrayPush(japantownIncursion, vehicle);}
            for vehicle in sixthstreetFleet{ArrayPush(japantownIncursion, vehicle);}   
        }

        if isActiveKabukiIncursion {
            for vehicle in maelstromFleet{ArrayPush(kabukiIncursion, vehicle);}
            for vehicle in valentinoFleet{ArrayPush(kabukiIncursion, vehicle);}
            for vehicle in sixthstreetFleet{ArrayPush(kabukiIncursion, vehicle);}   
        }

        if isActiveLittleChinaIncursion {
            for vehicle in valentinoFleet{ArrayPush(littleChinaIncursion, vehicle);}
            for vehicle in sixthstreetFleet{ArrayPush(littleChinaIncursion, vehicle);}
            for vehicle in animalsFleet{ArrayPush(littleChinaIncursion, vehicle);}   
        }

        if isActiveNorthsideIncursion {
            for vehicle in tygerFleet{ArrayPush(northsideIncursion, vehicle);}
            for vehicle in sixthstreetFleet{ArrayPush(northsideIncursion, vehicle);}
        }

        if isActivePacificaIncursion {
            for vehicle in tygerFleet{ArrayPush(pacificaIncursion, vehicle);}
            for vehicle in valentinoFleet{ArrayPush(pacificaIncursion, vehicle);}
        }

        if isActiveSantoDomingoIncursion {
            for vehicle in valentinoFleet{ArrayPush(santoDomingoIncursion, vehicle);}
            for vehicle in animalsFleet{ArrayPush(santoDomingoIncursion, vehicle);}
            for vehicle in maelstromFleet{ArrayPush(santoDomingoIncursion, vehicle);}
        }

    } else if (Equals(outsideGangsMode, "SINGLE")){

        let chances: Float;

        chances = RandF();
        if (chances > 0.5){heywoodIncursion = GANG_SIXTHSTREET_FLEET();}
        else if (chances > 0.25){heywoodIncursion = GANG_ANIMALS_FLEET();}
        else {heywoodIncursion = GANG_TYGER_FLEET();}

        chances = RandF();
        if (chances > 0.5){japantownIncursion = GANG_MAESLTROM_FLEET();}
        else if (chances > 0.25){japantownIncursion = GANG_VALENTINOS_FLEET();}
        else {japantownIncursion = GANG_SIXTHSTREET_FLEET();}
        
        chances = RandF();
        if (chances > 0.5){kabukiIncursion = GANG_MAESLTROM_FLEET();}
        else if (chances > 0.25){kabukiIncursion = GANG_VALENTINOS_FLEET();}
        else {kabukiIncursion = GANG_SIXTHSTREET_FLEET();}
        
        chances = RandF();
        if (chances > 0.66){littleChinaIncursion = GANG_VALENTINOS_FLEET();}
        else  if (chances > 0.33){littleChinaIncursion = GANG_SIXTHSTREET_FLEET();}
        else {littleChinaIncursion = GANG_ANIMALS_FLEET();}
        
        chances = RandF();
        if (chances > 0.3){northsideIncursion = GANG_TYGER_FLEET();}
        else {northsideIncursion = GANG_SIXTHSTREET_FLEET();}
        
        chances = RandF();
        if (chances > 0.5){pacificaIncursion = GANG_TYGER_FLEET();}
        else {pacificaIncursion = GANG_VALENTINOS_FLEET();}
        
        chances = RandF();
        if (chances > 0.5){santoDomingoIncursion = GANG_VALENTINOS_FLEET();}
        else if (chances > 0.2){santoDomingoIncursion = GANG_ANIMALS_FLEET();}
        else {santoDomingoIncursion = GANG_MAESLTROM_FLEET();}

    }


    // ADDING VEHICLES

    let districtDB: array<String>;
    let district: String;
    let timeOfDay: String;
    let crowdType: gameCrowdEntryType;
    let sampleSize: Int32 = 30;
    let scale: Float = 100.0;
    let weightBonusSmall: Float = 1.12;
    let weightBonusBig: Float = 1.25;

    let turfGangPool: array<TweakDBID>;
    let extraGang1Pool: array<TweakDBID>;
    let extraGang2Pool: array<TweakDBID>;
    let incursionGangPool: array<TweakDBID>;
    let policePool: array<TweakDBID>;
    let taxiPool: array<TweakDBID>;
    let delamainPool: array<TweakDBID>;
    let busPool: array<TweakDBID>;
    let utilityPool: array<TweakDBID>;
    let moddedPool: array<TweakDBID>;

    let turfGangWeight: Float;
    let extraGang1Weight: Float;
    let extraGang2Weight: Float;
    let incursionGangWeight: Float;
    let policeWeight: Float;
    let taxiWeight: Float;
    let delamainWeight: Float;
    let busWeight: Float;
    let utilityWeight: Float;
    let moddedWeight: Float;
    let extrasWeight: Float;


    // SYSTEM
    let resource = event.GetResource() as worldStreamingSector;
    if !IsDefined(resource) {return;}

    let comReg = ProbeCommunityRegistryNode(resource);
    if !IsDefined(comReg) {
        comReg = FindCommunityRegistryNode(resource);
    }
    if !IsDefined(comReg) {
        NightCityTrafficOverhaul.Log("worldCommunityRegistryNode not found - no vehicles injected.");
        return;
    }

    let datas = comReg.crowdCreationRegistry.creationData;
    let dataI = 0;

    districtDB = DistrictDbForRegistrySize(ArraySize(datas));
    if ArraySize(districtDB) == 0 {
        NightCityTrafficOverhaul.Log(s"No district database for a crowd registry of \(ArraySize(datas)) entries (922 = game 2.31, 924 = game 2.5) - no vehicles injected.");
        return;
    }
    NightCityTrafficOverhaul.Log(s"Crowd registry has \(ArraySize(datas)) entries - using the game \(DistrictDbGameVersion(ArraySize(datas))) district database.");

    while dataI < ArraySize(datas) {
        let periods = datas[dataI].timePeriods;
        let periodI = 0;
        let charDatas = periods[periodI].charactersData;

        turfGangWeight = 0.0;
        extraGang1Weight = 0.0;
        extraGang2Weight = 0.0;
        incursionGangWeight = 0.0;
        policeWeight = 0.0;
        taxiWeight = 0.0;
        delamainWeight = 0.0;
        busWeight = 0.0;
        utilityWeight = 0.0;
        moddedWeight = 0.0;

        turfGangPool = [];
        extraGang1Pool = [];
        extraGang2Pool = [];
        incursionGangPool = [];
        policePool = [];
        taxiPool = [];
        delamainPool = [];
        busPool = [];
        utilityPool = [];
        moddedPool = [];

        district = districtDB[dataI];

        switch (district){
            case "Veh_BADLANDS":
                turfGangWeight = Cast<Float>(settings.badlandsTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.badlandsGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.badlandsGang2) / scale;
                incursionGangWeight = 0.0;
                policeWeight = Cast<Float>(settings.badlandsPolice) / scale;
                taxiWeight = Cast<Float>(settings.badlandsTaxi) / scale;
                delamainWeight = 0.0;
                busWeight = 0.0;
                utilityWeight = Cast<Float>(settings.badlandsUtility) / scale;
                moddedWeight = Cast<Float>(settings.badlandsModded) / scale;

                turfGangPool = wraithFleet;
                if(isActiveBadlandsGang1){extraGang1Pool = aldelcaldosFleet;}
                if(isActiveBadlandsGang2){extraGang2Pool = scavFleet;}
                incursionGangPool = [];
                policePool = militechFleet;
                taxiPool = taxiFleet;
                delamainPool = [];
                busPool = [];
                utilityPool = badlandsUtilityFleet;
                moddedPool = badlandsModdedFleet;
                break;

            case "Veh_CHARTER_HILL":
                turfGangWeight = Cast<Float>(settings.charterHillTurf) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = 0.0;
                incursionGangWeight = 0.0;
                policeWeight = Cast<Float>(settings.charterHillPolice) / scale;
                taxiWeight = 0.0;
                delamainWeight = Cast<Float>(settings.charterHillDelamain) / scale;
                busWeight = Cast<Float>(settings.charterHillBus) / scale;
                utilityWeight = 0.0;
                moddedWeight = Cast<Float>(settings.charterHillModded) / scale;

                turfGangPool = securityCharterHillFleet;
                extraGang1Pool = [];
                extraGang2Pool = [];
                incursionGangPool = [];
                policePool = ncpdHighFleet;
                taxiPool = [];
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = [];
                moddedPool = charterHillModdedFleet;
                break;

            case "Veh_CITY_CENTER":
                turfGangWeight = Cast<Float>(settings.cityCenterTurf1) / scale;
                extraGang1Weight = Cast<Float>(settings.cityCenterTurf2) / scale;
                extraGang2Weight = Cast<Float>(settings.cityCenterTurf3) / scale;
                incursionGangWeight = Cast<Float>(settings.cityCenterExtra1) / scale;
                policeWeight = Cast<Float>(settings.cityCenterPolice) / scale;
                taxiWeight = Cast<Float>(settings.cityCenterTaxi) / scale;
                delamainWeight = Cast<Float>(settings.cityCenterDelamain) / scale;
                busWeight = Cast<Float>(settings.cityCenterBus) / scale;
                utilityWeight = Cast<Float>(settings.cityCenterUtility) / scale;
                moddedWeight = Cast<Float>(settings.cityCenterModded) / scale;

                turfGangPool = kangtaoFleet;
                extraGang1Pool = arasakaFleet;
                extraGang2Pool = militechFleet;
                incursionGangPool = cityCenterExtrasFleet;
                policePool = ncpdHighFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = cityCenterUtilityFleet;
                moddedPool = cityCenterModdedFleet;
                break;

            case "Veh_DOGTOWN":
                turfGangWeight = Cast<Float>(settings.dogtownTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.dogtownGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.dogtownGang2) / scale;
                incursionGangWeight = 0.0;
                policeWeight = 0.0;
                taxiWeight = Cast<Float>(settings.dogtownTaxi) / scale;
                delamainWeight = 0.0;
                busWeight = 0.0;
                utilityWeight = 0.0;
                moddedWeight = Cast<Float>(settings.dogtownModded) / scale;

                turfGangPool = barghestFleet;
                if(isActiveDogtownGang1){extraGang1Pool = voodooFleet;}
                if(isActiveDogtownGang2){extraGang2Pool = scavFleet;}
                incursionGangPool = [];
                policePool = [];
                taxiPool = taxiFleet;
                delamainPool = [];
                busPool = [];
                utilityPool = [];
                moddedPool = dogtownModdedFleet;
                break;

            case "Veh_HEYWOOD":
                turfGangWeight = Cast<Float>(settings.heywoodTurf) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = Cast<Float>(settings.heywoodGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.heywoodIncursions) / scale;
                policeWeight = Cast<Float>(settings.heywoodPolice) / scale;
                taxiWeight = Cast<Float>(settings.heywoodTaxi) / scale;
                delamainWeight = Cast<Float>(settings.heywoodDelamain) / scale;
                busWeight = Cast<Float>(settings.heywoodBus) / scale;
                utilityWeight = Cast<Float>(settings.heywoodUtility) / scale;
                moddedWeight = Cast<Float>(settings.heywoodModded) / scale;

                turfGangPool = valentinoFleet;
                extraGang1Pool = [];
                if(isActiveHeywoodGang2){extraGang2Pool = scavFleet;}
                if(isActiveHeywoodIncursion){incursionGangPool = heywoodIncursion;}
                policePool = ncpdFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = companyFleet;
                moddedPool = heywoodModdedFleet;
                break;

            case "Veh_JAPANTOWN":
                turfGangWeight = Cast<Float>(settings.japantownTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.japantownGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.japantownGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.japantownIncursions) / scale;
                policeWeight = Cast<Float>(settings.japantownPolice) / scale;
                taxiWeight = Cast<Float>(settings.japantownTaxi) / scale;
                delamainWeight = Cast<Float>(settings.japantownDelamain) / scale;
                busWeight = Cast<Float>(settings.japantownBus) / scale;
                utilityWeight = Cast<Float>(settings.japantownUtility) / scale;
                moddedWeight = Cast<Float>(settings.japantownModded) / scale;

                turfGangPool = tygerFleet;
                if(isActiveJapantownGang1){extraGang1Pool = moxFleet;}
                if(isActiveJapantownGang2){extraGang2Pool = scavFleet;}
                if(isActiveJapantownIncursion){incursionGangPool = japantownIncursion;}
                policePool = ncpdFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = japantownUtilityFleet;
                moddedPool = japantownModdedFleet;
                break;

            case "Veh_KABUKI":
                turfGangWeight = Cast<Float>(settings.kabukiTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.kabukiGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.kabukiGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.kabukiIncursions) / scale;
                policeWeight = Cast<Float>(settings.kabukiPolice) / scale;
                taxiWeight = Cast<Float>(settings.kabukiTaxi) / scale;
                delamainWeight = Cast<Float>(settings.kabukiDelamain) / scale;
                busWeight = Cast<Float>(settings.kabukiBus) / scale;
                utilityWeight = Cast<Float>(settings.kabukiUtility) / scale;
                moddedWeight = Cast<Float>(settings.kabukiModded) / scale;

                turfGangPool = tygerFleet;
                extraGang1Pool = moxFleet;
                if(isActiveKabukiGang2){extraGang2Pool = scavFleet;}
                if(isActiveKabukiIncursion){incursionGangPool = kabukiIncursion;}
                policePool = ncpdFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = japantownUtilityFleet;
                moddedPool = kabukiModdedFleet;
                break;

            case "Veh_LITTLE_CHINA":
                turfGangWeight = Cast<Float>(settings.littleChinaTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.littleChinaGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.littleChinaGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.littleChinaIncursions) / scale;
                policeWeight = Cast<Float>(settings.littleChinaPolice) / scale;
                taxiWeight = Cast<Float>(settings.littleChinaTaxi) / scale;
                delamainWeight = Cast<Float>(settings.littleChinaDelamain) / scale;
                busWeight = Cast<Float>(settings.littleChinaBus) / scale;
                utilityWeight = Cast<Float>(settings.littleChinaUtility) / scale;
                moddedWeight = Cast<Float>(settings.littleChinaModded) / scale;

                turfGangPool = maelstromFleet;
                extraGang1Pool = tygerFleet;
                if(isActiveLittleChinaGang2){extraGang2Pool = scavFleet;}
                if(isActiveLittleChinaIncursion){incursionGangPool = littleChinaIncursion;}
                policePool = ncpdHighFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = littleChinaUtilityFleet;
                moddedPool = littleChinaModdedFleet;
                break;

            case "Veh_NORTH_OAK":
                turfGangWeight = Cast<Float>(settings.northOakTurf) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = 0.0;
                incursionGangWeight = 0.0;
                policeWeight = Cast<Float>(settings.northOakPolice) / scale;
                taxiWeight = 0.0;
                delamainWeight = Cast<Float>(settings.northOakDelamain) / scale;
                busWeight = 0.0; 
                utilityWeight = 0.0;
                moddedWeight = Cast<Float>(settings.northOakModded) / scale;

                turfGangPool = securityCharterHillFleet;
                extraGang1Pool = [];
                extraGang2Pool = [];
                incursionGangPool = [];
                policePool = ncpdHighFleet;
                taxiPool = [];
                delamainPool = delamainFleet;
                busPool = [];
                utilityPool = [];
                moddedPool = northOakModdedFleet;
                break;

            case "Veh_NORTHSIDE":
                turfGangWeight = Cast<Float>(settings.northsideTurf) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = Cast<Float>(settings.northsideGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.northsideIncursions) / scale;
                policeWeight = Cast<Float>(settings.northsidePolice) / scale;
                taxiWeight = Cast<Float>(settings.northsideTaxi) / scale;
                delamainWeight = Cast<Float>(settings.northsideDelamain) / scale;
                busWeight = Cast<Float>(settings.northsideBus) / scale;
                utilityWeight = Cast<Float>(settings.northsideUtility) / scale;
                moddedWeight = Cast<Float>(settings.northsideModded) / scale;

                turfGangPool = maelstromFleet;
                extraGang1Pool = [];
                if(isActiveNorthsideGang2){extraGang2Pool = scavFleet;}
                if(isActiveNorthsideIncursion){incursionGangPool = northsideIncursion;}
                policePool = ncpdFleet;
                taxiPool = taxiFleet;
                delamainPool = delamainFleet;
                busPool = busFleet;
                utilityPool = northsideUtilityFleet;
                moddedPool = northsideModdedFleet;
                break;

            case "Veh_ARASAKA":
                turfGangWeight = Cast<Float>(settings.northsideGang1) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = 0.0;
                incursionGangWeight = 0.0;
                policeWeight = Cast<Float>(settings.northsidePolice) / scale;
                taxiWeight = 0.0;
                delamainWeight = Cast<Float>(settings.northsideDelamain) / scale;
                busWeight = 0.0;
                utilityWeight = 0.0;
                moddedWeight = Cast<Float>(settings.northsideModded) / scale;

                turfGangPool = arasakaFleet;
                extraGang1Pool = [];
                extraGang2Pool = [];
                incursionGangPool = [];
                policePool = ncpdFleet;
                taxiPool = [];
                delamainPool = delamainFleet;
                busPool = [];
                utilityPool = [];
                moddedPool = northsideModdedFleet;
                break;

            case "Veh_PACIFICA":
                turfGangWeight = Cast<Float>(settings.pacificaTurf) / scale;
                extraGang1Weight = Cast<Float>(settings.pacificaGang1) / scale;
                extraGang2Weight = Cast<Float>(settings.pacificaGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.pacificaIncursions) / scale;
                policeWeight = 0.0;
                taxiWeight = Cast<Float>(settings.pacificaTaxi) / scale;
                delamainWeight = 0.0;
                busWeight = 0.0;
                utilityWeight = 0.0;
                moddedWeight = Cast<Float>(settings.pacificaModded) / scale;

                turfGangPool = voodooFleet;
                extraGang1Pool = animalsFleet;
                extraGang2Pool = scavFleet;
                if(isActivePacificaIncursion){incursionGangPool = pacificaIncursion;}
                policePool = [];
                taxiPool = taxiFleet;
                delamainPool = [];
                busPool = [];
                utilityPool = [];
                moddedPool = pacificaModdedFleet;
                break;

            case "Veh_SANTO_DOMINGO":
                turfGangWeight = Cast<Float>(settings.santoDomingoTurf) / scale;
                extraGang1Weight = 0.0;
                extraGang2Weight = Cast<Float>(settings.santoDomingoGang2) / scale;
                incursionGangWeight = Cast<Float>(settings.santoDomingoIncursions) / scale;
                policeWeight = Cast<Float>(settings.santoDomingoPolice) / scale;
                taxiWeight = Cast<Float>(settings.santoDomingoTaxi) / scale;
                delamainWeight = 0.0;
                busWeight = Cast<Float>(settings.santoDomingoBus) / scale;
                utilityWeight = Cast<Float>(settings.santoDomingoUtility) / scale;
                moddedWeight = Cast<Float>(settings.santoDomingoModded) / scale;

                turfGangPool = sixthstreetFleet;
                extraGang1Pool = [];
                if(isActiveSantoDomingoGang2){extraGang2Pool = scavFleet;}
                if(isActiveSantoDomingoIncursion){incursionGangPool = santoDomingoIncursion;}
                policePool = ncpdFleet;
                taxiPool = taxiFleet;
                delamainPool = [];
                busPool = busFleet;
                utilityPool = companyFleet;
                moddedPool = santodomingoModdedFleet;
                break;

            default:
                turfGangWeight = 0.0;
                extraGang1Weight = 0.0;
                extraGang2Weight = 0.0;
                incursionGangWeight = 0.0;
                policeWeight = 0.0;
                taxiWeight = 0.0;
                delamainWeight = 0.0;
                busWeight = 0.0;
                utilityWeight = 0.0;
                moddedWeight = 0.0;

                turfGangPool = [];
                extraGang1Pool = [];
                extraGang2Pool = [];
                incursionGangPool = [];
                policePool = [];
                taxiPool = [];
                delamainPool = [];
                busPool = [];
                utilityPool = [];
                moddedPool = [];
                break;
        }

        while periodI < 4 {
            let charDataI = 0;

            crowdType = periods[periodI].crowdType;

            if (Equals(crowdType, gameCrowdEntryType.Vehicle)){

                // TESTING TOOL
                if (ArraySize(testModdedFleet) > 0 ) {
                    for vehicle in charDatas {
                        let vehicleType = testModdedFleet[RandRange(0, ArraySize(testModdedFleet))];
                        SetCharDataRecordID(comReg, dataI, periodI, charDataI, vehicleType);
                        charDataI += 1;
                    }
                    charDataI = 0;

                // NORMAL GAMEPLAY
                } else {

                    // REMOVING BLACKLISTED VANILLA VEHICLES
                    filterUnwantedVanillaVehicles(comReg, dataI, periodI);

                    // NORMALIZATION OF VANILLA TRAFFIC
                    if (settings.normalizeVanillaTraffic){
                        let normalizedValue: Float = Cast<Float>(settings.normalizeVanillaTrafficWeight) / scale;
                        for vehicle in charDatas {
                            SetCharDataWeight(comReg, dataI, periodI, charDataI, normalizedValue);
                            charDataI += 1;
                        }
                    }

                    // ADDING VEHICLES
                    switch (periodI){
                        case 0: timeOfDay = "Morning"; 
                            for vehicle in turfGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, turfGangWeight)); }
                            for vehicle in extraGang1Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang1Weight)); }
                            for vehicle in extraGang2Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang2Weight)); }
                            for vehicle in incursionGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, incursionGangWeight)); }
                            for vehicle in policePool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, policeWeight)); }
                            for vehicle in taxiPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, taxiWeight * weightBonusSmall)); }
                            for vehicle in delamainPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, delamainWeight * weightBonusSmall)); }
                            for vehicle in busPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, busWeight * weightBonusSmall)); }
                            for vehicle in utilityPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, utilityWeight* weightBonusBig)); }
                            for vehicle in moddedPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, moddedWeight)); }
                            break;
                        case 1: timeOfDay = "Day"; 
                            for vehicle in turfGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, turfGangWeight)); }
                            for vehicle in extraGang1Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang1Weight * weightBonusSmall)); }
                            for vehicle in extraGang2Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang2Weight * weightBonusSmall)); }
                            for vehicle in incursionGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, incursionGangWeight)); }
                            for vehicle in policePool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, policeWeight * weightBonusBig)); }
                            for vehicle in taxiPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, taxiWeight * weightBonusBig)); }
                            for vehicle in delamainPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, delamainWeight * weightBonusBig)); }
                            for vehicle in busPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, busWeight * weightBonusBig)); }
                            for vehicle in utilityPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, utilityWeight)); }
                            for vehicle in moddedPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, moddedWeight)); }
                            break;
                        case 2: timeOfDay = "Evening"; 
                            for vehicle in turfGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, turfGangWeight * weightBonusSmall)); }
                            for vehicle in extraGang1Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang1Weight)); }
                            for vehicle in extraGang2Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang2Weight)); }
                            for vehicle in incursionGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, incursionGangWeight)); }
                            for vehicle in policePool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, policeWeight * weightBonusSmall)); }
                            for vehicle in taxiPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, taxiWeight * weightBonusSmall)); }
                            for vehicle in delamainPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, delamainWeight * weightBonusSmall)); }
                            for vehicle in busPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, busWeight * weightBonusSmall)); }
                            for vehicle in utilityPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, utilityWeight)); }
                            for vehicle in moddedPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, moddedWeight)); }
                            break;
                        case 3: timeOfDay = "Night"; 
                            for vehicle in turfGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, turfGangWeight * weightBonusBig)); }
                            for vehicle in extraGang1Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang1Weight)); }
                            for vehicle in extraGang2Pool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, extraGang2Weight)); }
                            for vehicle in incursionGangPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, incursionGangWeight * weightBonusSmall)); }
                            for vehicle in policePool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, policeWeight)); }
                            for vehicle in taxiPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, taxiWeight)); }
                            for vehicle in delamainPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, delamainWeight)); }
                            for vehicle in busPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, busWeight)); }
                            for vehicle in utilityPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, utilityWeight * weightBonusSmall)); }
                            for vehicle in moddedPool { ArrayPush(comReg.crowdCreationRegistry.creationData[dataI].timePeriods[periodI].charactersData, createCharacterData(vehicle, moddedWeight)); }
                            break;
                    }
                }

            }

            periodI += 1;
        }

        dataI += 1;
    }
}
