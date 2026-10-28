module NightCityTrafficOverhaul.VehicleLights

import NightCityTrafficOverhaul.Settings.{NCTOSettings}

public func DaytimeStartHour() -> Int32 = 6;
public func DaytimeEndHour() -> Int32 = 21;

public func LightStateDelayInSeconds() -> Float = 0.5;

func AllVehicleLightTypes() -> array<vehicleELightType> = [
  vehicleELightType.Head,
  vehicleELightType.Brake,
  vehicleELightType.LeftBlinker,
  vehicleELightType.RightBlinker,
  vehicleELightType.Reverse,
  vehicleELightType.Interior,
  vehicleELightType.Utility,
  vehicleELightType.Default,
  vehicleELightType.Blinkers
];

public class NCTOEnvironmentSystem extends ScriptableSystem {
  private let settings: ref<NCTOSettings>;
  private let isRaining: Bool;

  private let weatherListener: ref<NCTOWeatherListener>;
  private let weatherListenerID: Uint32;

  public static func GetInstance(game: GameInstance) -> ref<NCTOEnvironmentSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"NightCityTrafficOverhaul.VehicleLights.NCTOEnvironmentSystem") as NCTOEnvironmentSystem;
  }

  private func OnAttach() -> Void {
    this.settings = NCTOSettings.Get();

    let weatherSystem = GameInstance.GetWeatherSystem(this.GetGameInstance());
    if !IsDefined(weatherSystem) { return; }

    this.isRaining = Equals(weatherSystem.GetRainIntensityType(), worldRainIntensity.HeavyRain);
    this.weatherListener = new NCTOWeatherListener();
    this.weatherListener.Initialize(this);
    this.weatherListenerID = weatherSystem.RegisterWeatherListener(this.weatherListener);
  }

  private func OnDetach() -> Void {
    let weatherSystem = GameInstance.GetWeatherSystem(this.GetGameInstance());
    if IsDefined(weatherSystem) && IsDefined(this.weatherListener) {
      weatherSystem.UnregisterWeatherListener(this.weatherListenerID);
    }
    this.weatherListener = null;
    this.weatherListenerID = 0u;

  }

  public func SetRaining(raining: Bool) -> Void {
    this.isRaining = raining;
  }

  public func IsRaining() -> Bool = this.isRaining;

  public func IsModEnabled() -> Bool = IsDefined(this.settings) && this.settings.modEnabled;
  public func AreDynamicLightsEnabled() -> Bool = IsDefined(this.settings) && this.settings.dynamicLights;
  public func AreUtilityLightsEnabled() -> Bool = IsDefined(this.settings) && this.settings.utilityLights;

  public func AffectsTrafficLights() -> Bool =
    this.IsModEnabled() && (this.AreDynamicLightsEnabled() || this.AreUtilityLightsEnabled());

  public func IsDaytime() -> Bool {
    let timeSystem = GameInstance.GetTimeSystem(this.GetGameInstance());
    if !IsDefined(timeSystem) { return false; }
    let hours = GameTime.Hours(timeSystem.GetGameTime());
    return hours >= DaytimeStartHour() && hours < DaytimeEndHour();
  }
}

public class NCTOWeatherListener extends WeatherScriptListener {
  private let owner: wref<NCTOEnvironmentSystem>;

  public func Initialize(system: ref<NCTOEnvironmentSystem>) -> Void {
    this.owner = system;
  }

  public func OnRainIntensityChanged(rainIntensity: Float) -> Void {}

  public func OnRainIntensityTypeChanged(rainIntensityType: worldRainIntensity) -> Void {
    if !IsDefined(this.owner) { return; }

    if Equals(rainIntensityType, worldRainIntensity.HeavyRain) {
      this.owner.SetRaining(true);
      return;
    }
    if Equals(rainIntensityType, worldRainIntensity.NoRain) {
      this.owner.SetRaining(false);
    }
  }
}

public class ApplyLightStateDelayedEvent extends Event {}

func GetActiveEnvironmentSystem(game: GameInstance) -> ref<NCTOEnvironmentSystem> {
  let envSystem = NCTOEnvironmentSystem.GetInstance(game);
  if !IsDefined(envSystem) || !envSystem.AffectsTrafficLights() { return null; }
  return envSystem;
}

@addMethod(VehicleComponent)
private final func IsTrafficVehicle() -> Bool {
  let vehicle = this.GetVehicle();
  return IsDefined(vehicle) && vehicle.IsCrowdVehicle();
}

@addMethod(VehicleComponent)
private final func ForceLightsOff(controller: ref<vehicleController>) -> Void {
  if !IsDefined(controller) { return; }
  for lightType in AllVehicleLightTypes() {
    controller.ToggleLights(false, lightType);
  }
}

@addMethod(VehicleComponent)
private final func ApplyTrafficLightState() -> Void {
  if !this.IsTrafficVehicle() { return; }

  let vehicle = this.GetVehicle();
  let envSystem = GetActiveEnvironmentSystem(vehicle.GetGame());
  if !IsDefined(envSystem) { return; }

  let controller = this.GetVehicleController();
  if !IsDefined(controller) { return; }

  if envSystem.AreDynamicLightsEnabled() && !envSystem.IsRaining() && envSystem.IsDaytime() {
    this.ForceLightsOff(controller);
  }

  if envSystem.AreUtilityLightsEnabled() {
    controller.ToggleLights(true, vehicleELightType.Utility);
  }
}

@addMethod(VehicleComponent)
protected cb func OnApplyLightStateDelayedEvent(evt: ref<ApplyLightStateDelayedEvent>) -> Bool {
  this.ApplyTrafficLightState();
  return true;
}

@wrapMethod(VehicleComponent)
private final func OnGameAttach() -> Void {
  wrappedMethod();

  if !this.IsTrafficVehicle() { return; }

  let vehicle = this.GetVehicle();
  let envSystem = GetActiveEnvironmentSystem(vehicle.GetGame());
  if !IsDefined(envSystem) { return; }

  let delaySystem = GameInstance.GetDelaySystem(vehicle.GetGame());
  if !IsDefined(delaySystem) { return; }

  delaySystem.DelayEvent(vehicle, new ApplyLightStateDelayedEvent(), LightStateDelayInSeconds());
}
