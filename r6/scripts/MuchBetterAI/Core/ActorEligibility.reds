module MuchBetterAI.Core


public func MBAI_ActorEligible(npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) || !npc.IsActive() || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc) {
    return false;
  };
  if npc.IsCharacterCivilian() || npc.IsCrowd() || npc.IsPlayerCompanion() || GameObject.IsFriendlyTowardsPlayer(npc) {
    return false;
  };
  return true;
}

public func MBAI_EnemyEligible(npc: wref<NPCPuppet>) -> Bool {
  return MBAI_ActorEligible(npc) && npc.IsEnemy() && npc.IsAggressive() && npc.IsOnAutonomousAI() && !npc.IsPaperdoll();
}

public func MBAI_PlayerAlertEligible(npc: wref<NPCPuppet>, player: wref<PlayerPuppet>) -> Bool {
  if !MBAI_ActorEligible(npc) || !IsDefined(player) || !npc.IsAggressive() || !npc.IsOnAutonomousAI() || npc.IsPaperdoll() {
    return false;
  };
  let attitude: EAIAttitude = GameObject.GetAttitudeTowards(npc, player);
  if Equals(attitude, EAIAttitude.AIA_Friendly) {
    return false;
  };
  if Equals(attitude, EAIAttitude.AIA_Hostile) {
    return true;
  };
  if !npc.IsConnectedToSecuritySystem() {
    return false;
  };
  let security: ref<SecuritySystemControllerPS> = npc.GetSecuritySystem();
  return IsDefined(security) && security.ShouldReactToTarget(player.GetEntityID(), npc.GetEntityID());
}

public func MBAI_ActorAuthoredControlFree(npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) || StatusEffectSystem.ObjectHasStatusEffectWithTag(npc, n"LoreAnim") || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Grappled") {
    return false;
  };
  let preset: gamedataReactionPresetType = npc.GetPuppetReactionPresetType();
  if Equals(preset, gamedataReactionPresetType.NoReaction) || Equals(preset, gamedataReactionPresetType.Follower) {
    return false;
  };
  let movePolicies: ref<MovePoliciesComponent> = npc.GetMovePolicesComponent();
  let puppetState: ref<IBlackboard> = npc.GetPuppetStateBlackboard();
  if !IsDefined(movePolicies) || !IsDefined(puppetState) {
    return false;
  };
  if movePolicies.IsOnOffMeshLink() || puppetState.GetBool(GetAllBlackboardDefs().PuppetState.WorkspotAnimationInProgress) {
    return false;
  };
  let gi: GameInstance = npc.GetGame();
  if GameInstance.GetWorkspotSystem(gi).IsActorInWorkspot(npc) || AIActionHelper.HasWorkspotAICommand(npc) {
    return false;
  };
  let scene: ref<SceneSystemInterface> = GameInstance.GetSceneSystem(gi).GetScriptInterface();
  return !IsDefined(scene) || !scene.IsEntityInDialogue(npc.GetEntityID()) && !scene.IsEntityInScene(npc.GetEntityID());
}

public func MBAI_ActorMovementEligible(npc: wref<NPCPuppet>) -> Bool {
  if !MBAI_ActorEligible(npc) || !npc.IsOnAutonomousAI() || npc.IsPaperdoll() || !MBAI_ActorAuthoredControlFree(npc) {
    return false;
  };
  let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
  return IsDefined(ai);
}

public func MBAI_ActorHasLegMobility(npc: wref<NPCPuppet>) -> Bool {
  return IsDefined(npc)
    && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.CrippledLegLeft")
    && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.CrippledLegRight")
    && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft")
    && !StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
}

public func MBAI_ActorHasNoActiveAICommand(npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) {
    return false;
  };
  let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
  if !IsDefined(ai) {
    return false;
  };
  if !ai.IsCommandActive(n"AICommand") {
    return true;
  };
  let activeCommandCount: Int32 = ai.GetActiveCommandsCount();
  if ai.IsCommandActive(n"AIInjectCombatTargetCommand") {
    activeCommandCount -= 1;
  };
  if ai.IsCommandActive(n"AIInjectCombatThreatCommand") {
    activeCommandCount -= 1;
  };
  return activeCommandCount <= 0;
}

public func MBAI_IsTrackedCommandRunning(ai: ref<AIHumanComponent>, cmd: ref<AICommand>) -> Bool {
  if !IsDefined(ai) || !IsDefined(cmd) {
    return false;
  };
  let state: AICommandState = ai.GetCommandState(cmd);
  return Equals(state, AICommandState.Enqueued) || Equals(state, AICommandState.Executing);
}

public func MBAI_EnemyMovementEligible(npc: wref<NPCPuppet>) -> Bool {
  return MBAI_EnemyEligible(npc) && MBAI_ActorMovementEligible(npc);
}

public func MBAI_PlayerAlertMovementEligible(npc: wref<NPCPuppet>, player: wref<PlayerPuppet>) -> Bool {
  return MBAI_PlayerAlertEligible(npc, player) && MBAI_ActorMovementEligible(npc);
}

public func MBAI_EnemyCanReceiveMovement(npc: wref<NPCPuppet>) -> Bool {
  return MBAI_EnemyMovementEligible(npc) && MBAI_ActorHasNoActiveAICommand(npc);
}

public func MBAI_PlayerAlertCanReceiveMovement(npc: wref<NPCPuppet>, player: wref<PlayerPuppet>) -> Bool {
  return MBAI_PlayerAlertMovementEligible(npc, player) && MBAI_ActorHasNoActiveAICommand(npc);
}
