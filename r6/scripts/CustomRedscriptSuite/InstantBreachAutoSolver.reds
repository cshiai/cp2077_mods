// Q5: Instant Access Point & Breach Protocol Auto-Solver
// Pure Redscript (0 dependencies) for Cyberpunk 2077 v2.5:
// 1. Jacking into any Access Point skips the hex-matrix minigame screen and
//    automatically completes all 3 Datamine Daemons (Basic + Advanced + Master + Q003).
// 2. Any non-skipped quest/shard breach minigame has 1-step sequences and a 12-slot buffer.

public static func IBS_EnsureAllDataminePrograms(bb: ref<IBlackboard>) -> Void {
  if !IsDefined(bb) {
    return;
  };
  let activePrograms: array<TweakDBID> = FromVariant<array<TweakDBID>>(bb.GetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms));
  let basicID: TweakDBID = t"MinigameAction.NetworkDataMineLootAll";
  let advID: TweakDBID = t"MinigameAction.NetworkDataMineLootAllAdvanced";
  let masterID: TweakDBID = t"MinigameAction.NetworkDataMineLootAllMaster";
  let q003ID: TweakDBID = t"MinigameAction.NetworkLootQ003";

  if !ArrayContains(activePrograms, basicID) {
    ArrayPush(activePrograms, basicID);
  };
  if !ArrayContains(activePrograms, advID) {
    ArrayPush(activePrograms, advID);
  };
  if !ArrayContains(activePrograms, masterID) {
    ArrayPush(activePrograms, masterID);
  };
  if !ArrayContains(activePrograms, q003ID) {
    ArrayPush(activePrograms, q003ID);
  };
  bb.SetVariant(GetAllBlackboardDefs().HackingMinigame.ActivePrograms, ToVariant(activePrograms), true);
}

@wrapMethod(ScriptableDeviceComponentPS)
public final func OnToggleNetrunnerDive(evt: ref<ToggleNetrunnerDive>) -> EntityNotificationType {
  if IsDefined(evt) && !evt.ShouldTerminate() {
    let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
    IBS_EnsureAllDataminePrograms(minigameBB);
    this.SetMinigameState(HackingMinigameState.Succeeded);
    evt.m_skipMinigame = true;
  };
  return wrappedMethod(evt);
}

@wrapMethod(AccessPointControllerPS)
private final func RefreshSlaves(const devices: script_ref<array<ref<DeviceComponentPS>>>) -> Void {
  let minigameBB: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().HackingMinigame);
  IBS_EnsureAllDataminePrograms(minigameBB);
  wrappedMethod(devices);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnEvaluateMinigame(evt: ref<EvaluateMinigame>) -> Bool {
  if IsDefined(evt) && IsDefined(evt.minigameBB) {
    IBS_EnsureAllDataminePrograms(evt.minigameBB);
  };
  return wrappedMethod(evt);
}

@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func DefineLength(combinedPowerLevel: Float, bufferSize: Int32, numPrograms: Int32) -> Int32 {
  return 1;
}

@wrapMethod(HackingMinigameGameController)
public final func ScaleBuffer(entity: ref<Entity>, out size: Float, powerLevel: Float, player: ref<PlayerPuppet>) -> Void {
  wrappedMethod(entity, size, powerLevel, player);
  if size < 12.0 {
    size = 12.0;
  };
}
