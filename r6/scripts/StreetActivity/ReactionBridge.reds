// Fixed, no-settings reaction bridge derived from the useful narrow portion of
// NIGHT CITY ALIVE.  It deliberately does not import NCA's 2.31 traffic hook,
// global attitude table, or high-density stimulus preset.
module StreetActivity.Reactions

@wrapMethod(StimFilters)
public static func CanTriggerCombatDirectly(stimType: gamedataStimType) -> Bool {
  let vanilla: Bool = wrappedMethod(stimType);
  return vanilla
    || Equals(stimType, gamedataStimType.VehicleHit)
    || Equals(stimType, gamedataStimType.HijackVehicle);
}

@wrapMethod(ReactionManagerComponent)
private final func ShouldTriggerAggressiveCrowdNPCCombat(stimEvent: ref<StimuliEvent>) -> Bool {
  let vanilla: Bool = wrappedMethod(stimEvent);
  if vanilla {
    return true;
  }
  if !IsDefined(stimEvent) {
    return false;
  }

  let playerPuppet: ref<PlayerPuppet> = stimEvent.sourceObject as PlayerPuppet;
  let owner: ref<GameObject> = this.GetOwner();
  if !IsDefined(playerPuppet) || !IsDefined(owner) {
    return false;
  }
  let game: GameInstance = owner.GetGame();
  let mounted: Bool = VehicleComponent.IsMountedToVehicle(game, owner);

  if StatusEffectSystem.ObjectHasStatusEffectWithTag(playerPuppet, n"NoCombat") {
    return false;
  }
  let playerState: ref<IBlackboard> = playerPuppet.GetPlayerStateMachineBlackboard();
  if IsDefined(playerState)
    && playerState.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Zones) == 2 {
    return false;
  }
  let safeArea = GameInstance.GetSafeAreaManager(game);
  if IsDefined(safeArea) && safeArea.IsPointInSafeArea(playerPuppet.GetWorldPosition()) {
    return false;
  }
  if stimEvent.IsTagInStimuli(n"NonAggressiveCrowd") {
    return false;
  }
  if !mounted && !this.IsTargetInFront(playerPuppet, 120.0) {
    return false;
  }
  if !mounted && !this.IsTargetInFront(playerPuppet, 100.0, true) {
    return false;
  }

  let activeWeapon: ref<WeaponObject> = GameObject.GetActiveWeapon(playerPuppet);
  let distanceSquared: Float = Vector4.DistanceSquared(owner.GetWorldPosition(), playerPuppet.GetWorldPosition());
  let maxDistance: Float;
  if IsDefined(activeWeapon) && WeaponObject.IsRanged(activeWeapon.GetItemID()) {
    maxDistance = TweakDBInterface.GetFloat(t"AIGeneralSettings.distanceToTriggerAggressiveCrowdRanged", 15.0);
  } else {
    maxDistance = TweakDBInterface.GetFloat(t"AIGeneralSettings.distanceToTriggerAggressiveCrowdMelee", 5.0);
  }
  if distanceSquared >= maxDistance * maxDistance {
    return false;
  }

  if !this.m_driverAllowedToGetAggressive
    && Equals(stimEvent.GetStimType(), gamedataStimType.HijackVehicle)
    && mounted {
    return false;
  }
  if !mounted {
    let navigation: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(game);
    if IsDefined(navigation) && !navigation.IsPointOnNavmesh(owner, owner.GetWorldPosition(), 0.1) {
      return false;
    }
  }
  return true;
}
