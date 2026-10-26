module MuchBetterAI.Core

public static func MBAI_GetCombatContact(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, out tracked: TrackedLocation, out position: Vector4) -> Bool {
  if !IsDefined(npc) || !IsDefined(player) || !TargetTrackingExtension.GetTrackedLocation(npc, player, tracked) {
    return false;
  };
  if tracked.visible {
    position = player.GetWorldPosition();
    return true;
  };
  position = tracked.sharedLocation.position;
  let tracker: ref<TargetTrackerComponent> = npc.GetTargetTrackerComponent();
  return IsDefined(tracker) && !Vector4.IsZero(position) && tracker.IsPositionValid(position);
}

public static func MBAI_ApplyCombatFacing(cmd: ref<AIMoveToCommand>, player: ref<PlayerPuppet>, tracked: TrackedLocation) -> Void {
  if tracked.visible {
    AIPositionSpec.SetEntity(cmd.facingTarget, EntityGameInterface.GetEntity(player.GetEntity()));
    cmd.rotateEntityTowardsFacingTarget = true;
  } else {
    cmd.rotateEntityTowardsFacingTarget = false;
  };
}
