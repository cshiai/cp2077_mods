module MuchBetterAI.PunishWindows

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

public static func MBAI_RarityRank(rarity: gamedataNPCRarity) -> Int32 {
  switch rarity {
    case gamedataNPCRarity.Trash: return 0;
    case gamedataNPCRarity.Weak: return 1;
    case gamedataNPCRarity.Normal: return 2;
    case gamedataNPCRarity.Rare: return 3;
    case gamedataNPCRarity.Officer: return 4;
    case gamedataNPCRarity.Elite: return 5;
    case gamedataNPCRarity.Boss: return 6;
    case gamedataNPCRarity.MaxTac: return 7;
    default: return 2;
  };
}

public static func MBAI_PunishChance(rarity: gamedataNPCRarity) -> Float {
  switch rarity {
    case gamedataNPCRarity.Weak: return 0.25;
    case gamedataNPCRarity.Normal: return 0.35;
    case gamedataNPCRarity.Rare: return 0.50;
    case gamedataNPCRarity.Officer: return 0.70;
    case gamedataNPCRarity.Elite: return 0.85;
    case gamedataNPCRarity.Boss: return 0.0;
    case gamedataNPCRarity.MaxTac: return 0.0;
    default: return 0.0;
  };
}

public class MBAI_PunishWindowsSystem extends ScriptableSystem {
  private let m_player: wref<PlayerPuppet>;
  private let m_playerAttachedCallbackID: Uint32;
  private let m_playerDetachedCallbackID: Uint32;
  private let m_rightWeaponStateHandle: ref<CallbackHandle>;
  private let m_leftWeaponStateHandle: ref<CallbackHandle>;
  private let m_staminaListener: ref<MBAI_StaminaListener>;
  private let m_lastWindowOpenSim: Float;

  private func OnAttach() -> Void {
    let playerSystem: ref<PlayerSystem> = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if this.m_playerAttachedCallbackID == 0u {
      this.m_playerAttachedCallbackID = playerSystem.RegisterPlayerPuppetAttachedCallback(this, n"MBAI_OnPlayerAttached");
    };
    if this.m_playerDetachedCallbackID == 0u {
      this.m_playerDetachedCallbackID = playerSystem.RegisterPlayerPuppetDetachedCallback(this, n"MBAI_OnPlayerDetached");
    };
  }

  private func OnDetach() -> Void {
    this.MBAI_OnPlayerDetached(this.m_player);
    let playerSystem: ref<PlayerSystem> = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if this.m_playerAttachedCallbackID > 0u {
      playerSystem.UnregisterPlayerPuppetAttachedCallback(this.m_playerAttachedCallbackID);
      this.m_playerAttachedCallbackID = 0u;
    };
    if this.m_playerDetachedCallbackID > 0u {
      playerSystem.UnregisterPlayerPuppetDetachedCallback(this.m_playerDetachedCallbackID);
      this.m_playerDetachedCallbackID = 0u;
    };
  }

  private final func MBAI_OnPlayerAttached(playerPuppet: ref<GameObject>) -> Void {
    this.MBAI_OnPlayerDetached(this.m_player);
    this.m_player = playerPuppet as PlayerPuppet;
    if !IsDefined(this.m_player) {
      return;
    };
    let bb: ref<IBlackboard> = this.m_player.GetPlayerStateMachineBlackboard();
    this.m_rightWeaponStateHandle = bb.RegisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.RightWeapon, this, n"MBAI_OnPlayerWeaponState");
    this.m_leftWeaponStateHandle = bb.RegisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.LeftWeapon, this, n"MBAI_OnPlayerWeaponState");
    let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let playerStatsID: StatsObjectID = Cast<StatsObjectID>(this.m_player.GetEntityID());
    if !IsDefined(this.m_staminaListener) {
      this.m_staminaListener = new MBAI_StaminaListener();
      this.m_staminaListener.m_system = this;
    };
    this.m_staminaListener.m_wasLow = statPools.GetStatPoolValue(playerStatsID, gamedataStatPoolType.Stamina, true) <= 15.0;
    statPools.RequestRegisteringListener(playerStatsID, gamedataStatPoolType.Stamina, this.m_staminaListener);
  }

  private final func MBAI_OnPlayerDetached(playerPuppet: ref<GameObject>) -> Void {
    if !IsDefined(this.m_player) || playerPuppet != this.m_player {
      return;
    };
    if IsDefined(this.m_rightWeaponStateHandle) {
      this.m_player.GetPlayerStateMachineBlackboard().UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.RightWeapon, this.m_rightWeaponStateHandle);
      this.m_rightWeaponStateHandle = null;
    };
    if IsDefined(this.m_leftWeaponStateHandle) {
      this.m_player.GetPlayerStateMachineBlackboard().UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.LeftWeapon, this.m_leftWeaponStateHandle);
      this.m_leftWeaponStateHandle = null;
    };
    if IsDefined(this.m_staminaListener) {
      GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestUnregisteringListener(Cast<StatsObjectID>(this.m_player.GetEntityID()), gamedataStatPoolType.Stamina, this.m_staminaListener);
    };
    this.m_player = null;
  }

  protected cb func MBAI_OnPlayerWeaponState(value: Int32) -> Bool {
    if Equals(IntEnum<gamePSMRangedWeaponStates>(value), gamePSMRangedWeaponStates.Reload) {
      this.MBAI_OpenWindow(1, "reload");
    };
    return false;
  }

  public final func MBAI_OnStaminaBroken() -> Void {
    this.MBAI_OpenWindow(2, "stamina");
  }

  public final func MBAI_OnHealUsed() -> Void {
    this.MBAI_OpenWindow(2, "heal");
  }

  private final func MBAI_OpenWindow(minRank: Int32, source: String) -> Void {
    if !IsDefined(this.m_player) {
      return;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    if now - this.m_lastWindowOpenSim < 0.3 {
      return;
    };
    this.m_lastWindowOpenSim = now;
    let cb: ref<MBAI_PunishEvalCallback> = new MBAI_PunishEvalCallback();
    cb.game = this.GetGameInstance();
    cb.minRank = minRank;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.02, false);
    MBAInfo("PunishWindows", "window opened source=" + source + " minRank=" + ToString(minRank));
  }

  public final func MBAI_EvaluatePunish(minRank: Int32) -> Void {
    if !IsDefined(this.m_player) {
      return;
    };
    let player: ref<PlayerPuppet> = this.m_player;
    let cautiousRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsCautious");
    let defensiveRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsDefensive");
    let recklessRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsReckless");
    let aggressiveRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsAggressive");
    let candidates: array<wref<NPCPuppet>> = this.MBAI_GatherEligible(player, minRank, cautiousRec, defensiveRec);
    let count: Int32 = ArraySize(candidates);
    if count <= 0 {
      return;
    };
    let origin: Vector4 = player.GetWorldPosition();
    let gi: GameInstance = this.GetGameInstance();
    let budget: Int32 = 2;
    let processed: array<EntityID>;
    let applied: Int32 = 0;
    while applied < budget {
      let bestIdx: Int32 = -1;
      let bestDist: Float = 100000.0;
      let i: Int32 = 0;
      while i < count {
        let npc: wref<NPCPuppet> = candidates[i];
        if IsDefined(npc) && !ArrayContains(processed, npc.GetEntityID()) {
          let d: Float = Vector4.Distance(origin, npc.GetWorldPosition());
          if d < bestDist {
            bestDist = d;
            bestIdx = i;
          };
        };
        i += 1;
      };
      if bestIdx < 0 {
        break;
      };
      let target: wref<NPCPuppet> = candidates[bestIdx];
      ArrayPush(processed, target.GetEntityID());
      let chance: Float = MBAI_PunishChance(target.GetNPCRarity()) * 1.15;
      if RandF() < chance {
        let fast: Bool = AIActionHelper.CheckAbility(target, recklessRec) || AIActionHelper.CheckAbility(target, aggressiveRec);
        let delay: Float = ClampF((fast ? 0.10 : 0.30) * MBAI_TemperamentPunishDelayMul(target), 0.05, 0.45);
        let applyCb: ref<MBAI_PunishApplyCallback> = new MBAI_PunishApplyCallback();
        applyCb.game = gi;
        applyCb.npcID = target.GetEntityID();
        GameInstance.GetDelaySystem(gi).DelayCallback(applyCb, delay, false);
        MBAInfo("PunishWindows", "push issued npc=" + ToString(target.GetEntityID()) + " rarity=" + ToString(target.GetNPCRarity()) + " posture=" + MBAI_TemperamentName(MBAI_GetTemperamentScale(target)) + " fast=" + ToString(fast) + " delay=" + ToString(delay) + " dist=" + ToString(bestDist));
        applied += 1;
      };
    };
    MBADebug("PunishWindows", "eval applied=" + ToString(applied) + " eligible=" + ToString(count) + " minRank=" + ToString(minRank));
  }

  private final func MBAI_GatherEligible(player: ref<PlayerPuppet>, minRank: Int32, cautiousRec: wref<GameplayAbility_Record>, defensiveRec: wref<GameplayAbility_Record>) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let targeting: ref<TargetingSystem> = GameInstance.GetTargetingSystem(player.GetGame());
    let query: TargetSearchQuery = TSQ_NPC();
    query.testedSet = TargetingSet.Complete;
    query.maxDistance = 60.0;
    query.filterObjectByDistance = true;
    query.includeSecondaryTargets = false;
    query.ignoreInstigator = true;
    let parts: array<TS_TargetPartInfo>;
    targeting.GetTargetParts(player, query, parts);
    let scanned: Int32 = 0;
    let rejRarity: Int32 = 0;
    let rejTemp: Int32 = 0;
    let rejLos: Int32 = 0;
    let seen: array<EntityID>;
    let i: Int32 = 0;
    while i < ArraySize(parts) {
      let comp: wref<TargetingComponent> = TS_TargetPartInfo.GetComponent(parts[i]);
      if IsDefined(comp) {
        let npc: wref<NPCPuppet> = comp.GetEntity() as NPCPuppet;
        if IsDefined(npc) && !ArrayContains(seen, npc.GetEntityID()) {
          ArrayPush(seen, npc.GetEntityID());
          scanned += 1;
          let reason: Int32 = this.MBAI_EligibleReason(npc, player, minRank, cautiousRec, defensiveRec);
          if reason == 0 {
            ArrayPush(result, npc);
          };
          if reason == 2 {
            rejRarity += 1;
          };
          if reason == 4 {
            rejTemp += 1;
          };
          if reason == 5 {
            rejLos += 1;
          };
        };
      };
      i += 1;
    };
    MBADebug("PunishWindows", "gather scanned=" + ToString(scanned) + " eligible=" + ToString(ArraySize(result)) + " rejRarity=" + ToString(rejRarity) + " rejTemp=" + ToString(rejTemp) + " rejLos=" + ToString(rejLos) + " minRank=" + ToString(minRank));
    return result;
  }

  private final func MBAI_EligibleReason(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, minRank: Int32, cautiousRec: wref<GameplayAbility_Record>, defensiveRec: wref<GameplayAbility_Record>) -> Int32 {
    if npc.IsDead() || npc.IsMechanical() || !npc.IsEnemy() {
      return 1;
    };
    if ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc) || ScriptedPuppet.IsPlayerCompanion(npc) || GameObject.IsFriendlyTowardsPlayer(npc) {
      return 1;
    };
    if MBAI_RarityRank(npc.GetNPCRarity()) < minRank {
      return 2;
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"MBAI.PunishCooldownEffect") {
      return 3;
    };
    if MBAI_IntentBlocksCommand(npc, n"Punish", EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()))) {
      return 3;
    };
    if AIActionHelper.CheckAbility(npc, cautiousRec) || AIActionHelper.CheckAbility(npc, defensiveRec) {
      return 4;
    };
    if !GameInstance.GetTargetingSystem(npc.GetGame()).IsVisibleTarget(npc, player) {
      return 5;
    };
    return 0;
  }
}

public class MBAI_StaminaListener extends ScriptStatPoolsListener {
  public let m_system: wref<MBAI_PunishWindowsSystem>;
  public let m_wasLow: Bool;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
    let isLow: Bool = newValue <= 15.0;
    if isLow && !this.m_wasLow && IsDefined(this.m_system) {
      this.m_system.MBAI_OnStaminaBroken();
    };
    this.m_wasLow = isLow;
  }
}

public class MBAI_PunishEvalCallback extends DelayCallback {
  public let game: GameInstance;
  public let minRank: Int32;

  public func Call() -> Void {
    let sys: ref<MBAI_PunishWindowsSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.PunishWindows.MBAI_PunishWindowsSystem") as MBAI_PunishWindowsSystem;
    if IsDefined(sys) {
      sys.MBAI_EvaluatePunish(this.minRank);
    };
  }
}

public class MBAI_PunishApplyCallback extends DelayCallback {
  public let game: GameInstance;
  public let npcID: EntityID;

  public func Call() -> Void {
    let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(this.game, this.npcID) as NPCPuppet;
    if !MBAI_EnemyCanReceiveMovement(npc) || npc.IsMechanical() {
      return;
    };
    let player: ref<PlayerPuppet> = GetPlayer(this.game);
    if !IsDefined(player) || !GameInstance.GetTargetingSystem(this.game).IsVisibleTarget(npc, player) {
      return;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.game));
    if MBAI_IntentBlocksCommand(npc, n"Punish", now) {
      return;
    };
    let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
    MBAI_SetIntent(npcSharp, n"PunishPush", n"Punish", 2.5, now);
    StatusEffectHelper.ApplyStatusEffect(npc, t"MBAI.DoPunishEffect");
    StatusEffectHelper.ApplyStatusEffect(npc, t"MBAI.PunishCooldownEffect");
  }
}
