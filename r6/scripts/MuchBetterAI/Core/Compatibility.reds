module MuchBetterAI.Core


@if(ModuleExists("ImmersiveShootingAI.Configurations"))
public static func MBAI_ISAIInstalled() -> Bool {
  return true;
}

@if(!ModuleExists("ImmersiveShootingAI.Configurations"))
public static func MBAI_ISAIInstalled() -> Bool {
  return false;
}

public static func MBAI_OwnsSuppressionFire() -> Bool {
  return !MBAI_ISAIInstalled();
}

// DelaySystem is torn down before some scriptable systems receive OnDetach.
// Keep lifecycle cleanup and periodic scheduling fail-closed instead of
// dereferencing a transient null native service.
public func MBAI_CancelDelay(gi: GameInstance, id: DelayID) -> Void {
  let delay = GameInstance.GetDelaySystem(gi);
  if IsDefined(delay) {
    delay.CancelDelay(id);
  }
}
