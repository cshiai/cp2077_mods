// Fixed source profile derived from the upstream effect registry.  The
// External menu surface is intentionally removed; edit these defaults in Git
// and recompile instead of introducing a runtime menu or user.ini override.
module FXBegone

public class FXBegoneSettings extends ScriptableSystem {

  public let enabled: Bool = true;

  public let relicSickness: Bool = true;

  public let relicTeleport: Bool = true;

  public let johnnyTakesControl: Bool = true;

  public let johnnyGivesBackControl: Bool = true;

  public let johnnyAppearGlitch: Bool = true;

  public let johnnyTeleportGlitch: Bool = true;

  public let johnnyIdleGlitch: Bool = true;

  public let silverhandArm: Bool = true;

  public let lowHealth: Bool = true;

  public let lowHealthThreshold: Float = 40.0;

  public let hitFlash: Bool = true;

  public let meleeStunFlash: Bool = true;

  public let hitDirection: Bool = true;

  public let pain: Bool = true;

  public let fireDamage: Bool = true;

  public let plasmaDamage: Bool = true;

  public let stagger: Bool = true;

  public let bloodOnScreen: Bool = true;

  public let deathFade: Bool = true;

  public let explosionFlashes: Bool = true;

  public let drunk: Bool = true;

  public let drugged: Bool = true;

  public let poisoned: Bool = true;

  public let bleeding: Bool = true;

  public let burning: Bool = true;

  public let acid: Bool = true;

  public let electrocuted: Bool = true;

  public let emp: Bool = true;

  public let blinded: Bool = true;

  public let dizzy: Bool = true;

  public let exhausted: Bool = true;

  public let sandevistan: Bool = true;

  public let sandevistanOveruse: Bool = true;

  public let kerenzikov: Bool = true;

  public let berserk: Bool = true;

  public let adrenalineConverter: Bool = true;

  public let catchMeIfYouCan: Bool = true;

  public let troubleFinder: Bool = true;

  public let opticalCamo: Bool = true;

  public let bloodPump: Bool = true;

  public let secondHeart: Bool = true;

  public let healOnKill: Bool = true;

  public let healthMonitor: Bool = true;

  public let memoryBoost: Bool = true;

  public let microGenerator: Bool = true;

  public let staminaRegen: Bool = true;

  public let dischargeConnector: Bool = true;

  public let nanoPlates: Bool = true;

  public let iconicReady: Bool = true;

  public let personalSilencer: Bool = true;

  public let smartStorage: Bool = true;

  public let suddenAid: Bool = true;

  public let timeBank: Bool = true;

  public let cybermask: Bool = true;

  public let maxDoc: Bool = true;

  public let bounceBack: Bool = true;

  public let healthRegen: Bool = true;

  public let fury: Bool = true;

  public let overclock: Bool = true;

  public let focused: Bool = true;

  public let ripAndTear: Bool = true;

  public let cyberwareMalfunction: Bool = true;

  public let relicMeleeware: Bool = true;

  public let dash: Bool = true;

  public let beingHacked: Bool = true;

  public let netrunnerTrace: Bool = true;

  public let callInterference: Bool = true;

  public let personalLinkGlitch: Bool = true;

  public let rebootGlitch: Bool = true;

  public let burnoutGlitch: Bool = true;

  public let digitalSickness: Bool = true;

  public let rezoConnectionGlitch: Bool = true;

  public let cyberspaceWarp: Bool = true;

  public let cyberspaceTeleport: Bool = true;

  public let soulkiller: Bool = true;

  public let bdEnterExit: Bool = true;

  public let bdOverlay: Bool = true;

  public let bdEditorCues: Bool = true;

  public let scannerScanline: Bool = true;

  public let scannerLook: Bool = true;

  public let scannerVignette: Bool = true;

  public let scannerMarkers: Bool = true;

  public let beingScanned: Bool = true;

  public let sniperLaser: Bool = true;

  public let stealthVignette: Bool = true;

  public let zoom: Bool = true;

  public let quickScan: Bool = true;

  public let sunglasses: Bool = true;

  public let sprint: Bool = true;

  public let slide: Bool = true;

  public let vault: Bool = true;

  public let doubleJump: Bool = true;

  public let falling: Bool = true;

  public let hardLanding: Bool = true;

  public let waterOnScreen: Bool = true;

  public let vehicleSpeedBlur: Bool = true;

  public let fastTravelGlitch: Bool = true;

  public let timeSkipGlitch: Bool = true;

  public let sceneFastForward: Bool = true;

  public let loadingGlitch: Bool = true;

  public let holocallGlitch: Bool = true;

  public let inventoryGlitch: Bool = true;

  public let songbirdGlitching: Bool = true;

  public let songbirdSickness: Bool = true;

  public let blackwallOnScreen: Bool = true;

  public let cerberusBossGlitch: Bool = true;

  public let allEffectsOff: Bool = false;

  private func OnAttach() -> Void {
    this.Apply();
  }

  private func Apply() -> Void {
    let toggles: array<Bool>;
    ArrayPush(toggles, this.enabled);
    ArrayPush(toggles, this.relicSickness);
    ArrayPush(toggles, this.relicTeleport);
    ArrayPush(toggles, this.johnnyTakesControl);
    ArrayPush(toggles, this.johnnyGivesBackControl);
    ArrayPush(toggles, this.johnnyAppearGlitch);
    ArrayPush(toggles, this.johnnyTeleportGlitch);
    ArrayPush(toggles, this.johnnyIdleGlitch);
    ArrayPush(toggles, this.silverhandArm);
    ArrayPush(toggles, this.lowHealth);
    ArrayPush(toggles, this.hitFlash);
    ArrayPush(toggles, this.meleeStunFlash);
    ArrayPush(toggles, this.hitDirection);
    ArrayPush(toggles, this.pain);
    ArrayPush(toggles, this.fireDamage);
    ArrayPush(toggles, this.plasmaDamage);
    ArrayPush(toggles, this.stagger);
    ArrayPush(toggles, this.bloodOnScreen);
    ArrayPush(toggles, this.deathFade);
    ArrayPush(toggles, this.explosionFlashes);
    ArrayPush(toggles, this.drunk);
    ArrayPush(toggles, this.drugged);
    ArrayPush(toggles, this.poisoned);
    ArrayPush(toggles, this.bleeding);
    ArrayPush(toggles, this.burning);
    ArrayPush(toggles, this.acid);
    ArrayPush(toggles, this.electrocuted);
    ArrayPush(toggles, this.emp);
    ArrayPush(toggles, this.blinded);
    ArrayPush(toggles, this.dizzy);
    ArrayPush(toggles, this.exhausted);
    ArrayPush(toggles, this.sandevistan);
    ArrayPush(toggles, this.sandevistanOveruse);
    ArrayPush(toggles, this.kerenzikov);
    ArrayPush(toggles, this.berserk);
    ArrayPush(toggles, this.adrenalineConverter);
    ArrayPush(toggles, this.catchMeIfYouCan);
    ArrayPush(toggles, this.troubleFinder);
    ArrayPush(toggles, this.opticalCamo);
    ArrayPush(toggles, this.bloodPump);
    ArrayPush(toggles, this.secondHeart);
    ArrayPush(toggles, this.healOnKill);
    ArrayPush(toggles, this.healthMonitor);
    ArrayPush(toggles, this.memoryBoost);
    ArrayPush(toggles, this.microGenerator);
    ArrayPush(toggles, this.staminaRegen);
    ArrayPush(toggles, this.dischargeConnector);
    ArrayPush(toggles, this.nanoPlates);
    ArrayPush(toggles, this.iconicReady);
    ArrayPush(toggles, this.personalSilencer);
    ArrayPush(toggles, this.smartStorage);
    ArrayPush(toggles, this.suddenAid);
    ArrayPush(toggles, this.timeBank);
    ArrayPush(toggles, this.cybermask);
    ArrayPush(toggles, this.maxDoc);
    ArrayPush(toggles, this.bounceBack);
    ArrayPush(toggles, this.healthRegen);
    ArrayPush(toggles, this.fury);
    ArrayPush(toggles, this.overclock);
    ArrayPush(toggles, this.focused);
    ArrayPush(toggles, this.ripAndTear);
    ArrayPush(toggles, this.cyberwareMalfunction);
    ArrayPush(toggles, this.relicMeleeware);
    ArrayPush(toggles, this.dash);
    ArrayPush(toggles, this.beingHacked);
    ArrayPush(toggles, this.netrunnerTrace);
    ArrayPush(toggles, this.callInterference);
    ArrayPush(toggles, this.personalLinkGlitch);
    ArrayPush(toggles, this.rebootGlitch);
    ArrayPush(toggles, this.burnoutGlitch);
    ArrayPush(toggles, this.digitalSickness);
    ArrayPush(toggles, this.rezoConnectionGlitch);
    ArrayPush(toggles, this.cyberspaceWarp);
    ArrayPush(toggles, this.cyberspaceTeleport);
    ArrayPush(toggles, this.soulkiller);
    ArrayPush(toggles, this.bdEnterExit);
    ArrayPush(toggles, this.bdOverlay);
    ArrayPush(toggles, this.bdEditorCues);
    ArrayPush(toggles, this.scannerScanline);
    ArrayPush(toggles, this.scannerLook);
    ArrayPush(toggles, this.scannerVignette);
    ArrayPush(toggles, this.scannerMarkers);
    ArrayPush(toggles, this.beingScanned);
    ArrayPush(toggles, this.sniperLaser);
    ArrayPush(toggles, this.stealthVignette);
    ArrayPush(toggles, this.zoom);
    ArrayPush(toggles, this.quickScan);
    ArrayPush(toggles, this.sunglasses);
    ArrayPush(toggles, this.sprint);
    ArrayPush(toggles, this.slide);
    ArrayPush(toggles, this.vault);
    ArrayPush(toggles, this.doubleJump);
    ArrayPush(toggles, this.falling);
    ArrayPush(toggles, this.hardLanding);
    ArrayPush(toggles, this.waterOnScreen);
    ArrayPush(toggles, this.vehicleSpeedBlur);
    ArrayPush(toggles, this.fastTravelGlitch);
    ArrayPush(toggles, this.timeSkipGlitch);
    ArrayPush(toggles, this.sceneFastForward);
    ArrayPush(toggles, this.loadingGlitch);
    ArrayPush(toggles, this.holocallGlitch);
    ArrayPush(toggles, this.inventoryGlitch);
    ArrayPush(toggles, this.songbirdGlitching);
    ArrayPush(toggles, this.songbirdSickness);
    ArrayPush(toggles, this.blackwallOnScreen);
    ArrayPush(toggles, this.cerberusBossGlitch);
    ArrayPush(toggles, this.allEffectsOff);
    let sliders: array<Float>;
    ArrayPush(sliders, this.lowHealthThreshold);
    SetToggles(toggles);
    SetSliders(sliders);
    StopDisabled(this.GetGameInstance());
  }
}
