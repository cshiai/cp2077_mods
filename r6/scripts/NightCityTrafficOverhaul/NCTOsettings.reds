// Fixed, source-controlled NCTO profile.
// Runtime Mod Settings/RCF integration is intentionally removed.
// Change values in this file through Git only.
module NightCityTrafficOverhaul.Settings

enum outsideGangsMode {
  SINGLE = 0,
  MIXED = 1
}

enum hijackDifficulty {
  VANILLA = 0,
  TRIVIAL = 1,
  MEDIUM = 2,
  HARD = 3,
  IMPOSSIBLE = 4
}

public class NCTOSettings {

    public static func Get() -> ref<NCTOSettings> {
        let self: ref<NCTOSettings> = new NCTOSettings();
        return self;
    }

    // MASTER

    let modEnabled: Bool = true;

    let autoDistributeModdedVehicles: Bool = false;

    let autoSetRandomPassengers: Bool = false;

    let normalizeVanillaTraffic: Bool = false;

    let normalizeVanillaTrafficWeight: Int32 = 20;
    
    let betterPanicReaction: Bool = true;

    let trafficHijackDifficulty : hijackDifficulty = hijackDifficulty.VANILLA;

    let dynamicLights: Bool = true;

    let utilityLights: Bool = true;

    let showLogs: Bool = false;

    // FACTION VEHICLES

    let secondaryGangsProbability: Float = 50.0;

    let outsideGangsProbability: Float = 10.0;

    let outsideGangsModeOption : outsideGangsMode = outsideGangsMode.SINGLE;

    let sixthStreetTaxiDriver: Bool = true;

    let gangsFrontPassengersProbability: Float = 50.0;
 
    let gangsBackPassengersProbability: Float = 25.0;

    let policeFrontPassengersProbability: Float = 100.0;
 
    let policeBackPassengersProbability: Float = 0;

    // TRAFFIC SPEED SETTINGS

    let sportVehiclesMaxSpeed: Float = 41.0;

    let sportVehiclesAcceleration: Float = 1.0;

    let sportBikesMaxSpeed: Float = 41.0;

    let sportBikesAcceleration: Float = 1.0;

    let SUVMaxSpeed: Float = 31.0;

    let SUVAcceleration: Float = 1.0;

    let normalVehiclesMaxSpeed: Float = 31.0;

    let normalVehiclesAcceleration: Float = 1.0;

    let truckVehiclesMaxSpeed: Float = 28.0;

    let trucksAcceleration: Float = 1.0;

    let miniVehiclesMaxSpeed: Float = 26.0;

    let miniVehiclesAcceleration: Float = 1.0;

    // BADLANDS
      
    let badlandsTurf: Int32 = 7;

    let badlandsGang1: Int32 = 3;

    let badlandsGang2: Int32 = 3;

    let badlandsPolice: Int32 = 3;

    let badlandsTaxi: Int32 = 4;

    let badlandsUtility: Int32 = 10;

    let badlandsModded: Int32 = 0;

    // CHARTER HILL
    let charterHillTurf: Int32 = 4;

    let charterHillPolice: Int32 = 4;
    
    let charterHillBus: Int32 = 7;

    let charterHillDelamain: Int32 = 8;
 
    let charterHillModded: Int32 = 0;

    // CITY CENTER
    let cityCenterTurf1: Int32 = 5;

    let cityCenterTurf2: Int32 = 5;

    let cityCenterTurf3: Int32 = 5;

    let cityCenterPolice: Int32 = 8;

    let cityCenterExtra1: Int32 = 3;
    
    let cityCenterTaxi: Int32 = 2;
    
    let cityCenterBus: Int32 = 8;

    let cityCenterDelamain: Int32 = 10;

    let cityCenterUtility: Int32 = 2;

    let cityCenterModded: Int32 = 0;

    // DOGTOWN
      
    let dogtownTurf: Int32 = 5;

    let dogtownGang1: Int32 = 2;

    let dogtownGang2: Int32 = 2;

    let dogtownTaxi: Int32 = 4;

    let dogtownModded: Int32 = 0;

    // HEYWOOD
    let heywoodTurf: Int32 = 5;

    // let heywoodGang1: Int32 = 5;

    let heywoodGang2: Int32 = 2;

    let heywoodIncursions: Int32 = 4;
    
    let heywoodPolice: Int32 = 3;

    let heywoodTaxi: Int32 = 6;
    
    let heywoodBus: Int32 = 8;

    let heywoodDelamain: Int32 = 10;

    let heywoodUtility: Int32 = 3;

    let heywoodModded: Int32 = 0;

    // JAPANTOWN
    let japantownTurf: Int32 = 5;

    let japantownGang1: Int32 = 2;

    let japantownGang2: Int32 = 2;

    let japantownIncursions: Int32 = 4;
    
    let japantownPolice: Int32 = 3;

    let japantownTaxi: Int32 = 6;
    
    let japantownBus: Int32 = 6;

    let japantownDelamain: Int32 = 10;

    let japantownUtility: Int32 = 5;

    let japantownModded: Int32 = 0;

    // KABUKI
    let kabukiTurf: Int32 = 3;

    let kabukiGang1: Int32 = 3;

    let kabukiGang2: Int32 = 3;

    let kabukiIncursions: Int32 = 3;
    
    let kabukiPolice: Int32 = 3;

    let kabukiTaxi: Int32 = 4;
    
    let kabukiBus: Int32 = 0;

    let kabukiDelamain: Int32 = 6;

    let kabukiUtility: Int32 = 5;

    let kabukiModded: Int32 = 0;

    // LITTLE CHINA
    let littleChinaTurf: Int32 = 5;

    let littleChinaGang1: Int32 = 5;

    let littleChinaGang2: Int32 = 4;

    let littleChinaIncursions: Int32 = 5;

    let littleChinaPolice: Int32 = 7;

    let littleChinaTaxi: Int32 = 7;

    let littleChinaBus: Int32 = 8;

    let littleChinaDelamain: Int32 = 10;

    let littleChinaUtility: Int32 = 8;

    let littleChinaModded: Int32 = 0;

    // NORTH OAK
    let northOakTurf: Int32 = 5;

    let northOakPolice: Int32 = 5;

    let northOakDelamain: Int32 = 10;
    
    let northOakModded: Int32 = 0;

    // NORTHSIDE
    let northsideTurf: Int32 = 5;

    let northsideGang1: Int32 = 5;

    let northsideGang2: Int32 = 3;

    let northsideIncursions: Int32 = 3;
    
    let northsidePolice: Int32 = 3;

    let northsideTaxi: Int32 = 5;
    
    let northsideBus: Int32 = 7;

    let northsideDelamain: Int32 = 6;

    let northsideUtility: Int32 = 9;

    let northsideModded: Int32 = 0;

    // PACIFICA
    let pacificaTurf: Int32 = 5;

    let pacificaGang1: Int32 = 5;

    let pacificaGang2: Int32 = 5;

    let pacificaIncursions: Int32 = 3;

    let pacificaTaxi: Int32 = 5;

    let pacificaModded: Int32 = 0;

    // SANTO DOMINGO
    let santoDomingoTurf: Int32 = 5;

    // let santoDomingoGang1: Int32 = 5;

    let santoDomingoGang2: Int32 = 3;

    let santoDomingoIncursions: Int32 = 4;
    
    let santoDomingoPolice: Int32 = 3;

    let santoDomingoTaxi: Int32 = 10;
    
    let santoDomingoBus: Int32 = 8;

    let santoDomingoUtility: Int32 = 6;

    let santoDomingoModded: Int32 = 0;


}
