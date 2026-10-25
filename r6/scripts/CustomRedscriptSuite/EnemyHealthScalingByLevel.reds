// Pure redscript Enemy Health Auto-Scaling by Level for Cyberpunk 2077 2.5 (no TweakXL/Codeware required)
// Curved smoothstep ramp from 200% (2x) at level 10 to 500% (5x) at level 60.
// Levels below 10 also use 200% health; level 60 and above cap at 500%.
// Non-Johnny enemies additionally regenerate 0.1% of max health per second.

@addField(NPCPuppet)
private let m_customEnemyHealthRegenActive: Bool;

@addField(NPCPuppet)
private let m_customScaledHealthMod: ref<gameStatModifierData>;

@addField(NPCPuppet)
private let m_customScaledHealthLevel: Float;

@addField(NPCPuppet)
private let m_customScaledHealthMult: Float;

@addMethod(NPCPuppet)
public final static func IsJohnnyMemory(game: GameInstance) -> Bool {
  if !GameInstance.IsValid(game) {
    return false;
  }
  let controlled: ref<GameObject> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject();
  let puppet: ref<gamePuppetBase> = controlled as gamePuppetBase;
  return IsDefined(puppet) && Equals(puppet.GetRecordID(), t"Character.johnny_replacer");
}

@addMethod(NPCPuppet)
public final func ClearCustomEnemyHealthScaling() -> Void {
  let game: GameInstance = this.GetGame();
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
  let statsObjID: StatsObjectID = Cast<StatsObjectID>(this.GetEntityID());
  if IsDefined(statsSystem) && IsDefined(this.m_customScaledHealthMod) {
    statsSystem.RemoveModifier(statsObjID, this.m_customScaledHealthMod);
  };
  this.m_customScaledHealthMod = null;
  this.m_customScaledHealthLevel = 0.0;
  this.m_customScaledHealthMult = 1.0;
  this.ApplyCustomEnemyHealthRegeneration(false);
}

@addMethod(NPCPuppet)
public final func ApplyCustomEnemyHealthRegeneration(enabled: Bool) -> Void {
  let game: GameInstance = this.GetGame();
  let statPoolsSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(game);
  if !IsDefined(statPoolsSystem) {
    return;
  }
  let statsObjID: StatsObjectID = Cast<StatsObjectID>(this.GetEntityID());
  let regenMod: StatPoolModifier;
  regenMod.enabled = enabled;
  regenMod.rangeBegin = 0.0;
  regenMod.rangeEnd = 100.0;
  regenMod.startDelay = 0.0;
  regenMod.valuePerSec = 0.1;
  regenMod.delayOnChange = false;
  statPoolsSystem.RequestSettingModifier(statsObjID, gamedataStatPoolType.Health, gameStatPoolModificationTypes.Regeneration, regenMod);
  if enabled {
    statPoolsSystem.RequestMarkingStatPoolActive(statsObjID, gamedataStatPoolType.Health);
  };
  this.m_customEnemyHealthRegenActive = enabled;
}

@addMethod(NPCPuppet)
public final static func CalculateCustomHealthMultiplier(level: Float) -> Float {
  let effectiveLevel: Float = MaxF(level, 1.0);
  if effectiveLevel <= 10.0 {
    return 2.0;
  }
  let rawT: Float = (effectiveLevel - 10.0) / 50.0;
  let t: Float = ClampF(rawT, 0.0, 1.0);
  if t >= 1.0 {
    return 5.0;
  }
  let smoothT: Float = (3.0 * t * t) - (2.0 * t * t * t);
  return 2.0 + (3.0 * smoothT);
}

@addMethod(NPCPuppet)
public final const func GetCustomScaledHealthMultiplier() -> Float {
  if this.m_customScaledHealthMult > 1.0 {
    return this.m_customScaledHealthMult;
  }
  return 1.0;
}

@addMethod(NPCPuppet)
public final const func HasCustomScaledHealthModifier() -> Bool {
  return IsDefined(this.m_customScaledHealthMod);
}

@addMethod(NPCPuppet)
public final func ApplyCustomEnemyHealthScaling(fillHealthPool: Bool) -> Void {
  if this.IsDead() || ScriptedPuppet.IsDefeated(this) || this.IsIncapacitated() || this.IsPaperdoll() || this.IsVendor() || this.IsPlayerCompanion() || this.IsCrowd() || this.IsCharacterCivilian() {
    return;
  }

  let game: GameInstance = this.GetGame();
  let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
  if !IsDefined(statsSystem) {
    return;
  }

  let statsObjID: StatsObjectID = Cast<StatsObjectID>(this.GetEntityID());
  // Johnny's playable-memory sequences use an unscaled weapon set. Remove any
  // previously applied custom NPC health modifier and leave enemies vanilla.
  if NPCPuppet.IsJohnnyMemory(game) {
    this.ClearCustomEnemyHealthScaling();
    return;
  }
  let npcPowerLevel: Float = statsSystem.GetStatValue(statsObjID, gamedataStatType.PowerLevel);
  let npcLevel: Float = statsSystem.GetStatValue(statsObjID, gamedataStatType.Level);
  let effectiveLevel: Float = MaxF(npcPowerLevel, npcLevel);

  let player: ref<GameObject> = GameInstance.GetPlayerSystem(game).GetLocalPlayerControlledGameObject();
  if IsDefined(player) {
    let playerID: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    let playerLevel: Float = MaxF(
      statsSystem.GetStatValue(playerID, gamedataStatType.Level),
      statsSystem.GetStatValue(playerID, gamedataStatType.PowerLevel)
    );
    if effectiveLevel < 1.0 || (playerLevel > 60.0 && effectiveLevel >= 58.0 && effectiveLevel < playerLevel) {
      effectiveLevel = playerLevel;
    }
  }

  if effectiveLevel < 1.0 {
    return;
  }

  let targetMult: Float = NPCPuppet.CalculateCustomHealthMultiplier(effectiveLevel);
  if !this.m_customEnemyHealthRegenActive {
    this.ApplyCustomEnemyHealthRegeneration(true);
  };
  if IsDefined(this.m_customScaledHealthMod)
    && AbsF(effectiveLevel - this.m_customScaledHealthLevel) < 0.5
    && AbsF(targetMult - this.m_customScaledHealthMult) < 0.01 {
    return;
  }

  if IsDefined(this.m_customScaledHealthMod) {
    statsSystem.RemoveModifier(statsObjID, this.m_customScaledHealthMod);
    this.m_customScaledHealthMod = null;
  }

  this.m_customScaledHealthLevel = effectiveLevel;
  this.m_customScaledHealthMult = targetMult;

  if targetMult > 1.0 {
    let mod: ref<gameStatModifierData> = RPGManager.CreateStatModifier(
      gamedataStatType.Health,
      gameStatModifierType.Multiplier,
      targetMult
    );
    statsSystem.AddModifier(statsObjID, mod);
    this.m_customScaledHealthMod = mod;
  }

  if fillHealthPool {
    let statPoolsSystem: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(game);
    if IsDefined(statPoolsSystem) {
      let currentPct: Float = statPoolsSystem.GetStatPoolValue(statsObjID, gamedataStatPoolType.Health, true);
      if currentPct >= 95.0 {
        statPoolsSystem.RequestSettingStatPoolMaxValue(statsObjID, gamedataStatPoolType.Health, this);
      }
    }
  }
}

public class EHSL_ApplyRequest extends ScriptableSystemRequest {
  public let entityID: EntityID;
  public let fillHealthPool: Bool;
  public let clearOnly: Bool;
}

public class EHSL_ScaleAllRequest extends ScriptableSystemRequest {}

public class EHSL_System extends ScriptableSystem {
  public final static func Get(gi: GameInstance) -> ref<EHSL_System> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"EHSL_System") as EHSL_System;
  }

  private final func OnApplyRequest(request: ref<EHSL_ApplyRequest>) -> Void {
    if !IsDefined(request) || !EntityID.IsDefined(request.entityID) {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let npc: ref<NPCPuppet> = GameInstance.FindEntityByID(gi, request.entityID) as NPCPuppet;
    if !IsDefined(npc) || !npc.IsAttached() {
      return;
    };
    if request.clearOnly {
      npc.ClearCustomEnemyHealthScaling();
    } else {
      npc.ApplyCustomEnemyHealthScaling(request.fillHealthPool);
    };
  }

  private final func OnScaleAllRequest(request: ref<EHSL_ScaleAllRequest>) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let entityList: array<ref<Entity>> = GameInstance.GetEntityList(gi);
    let i: Int32 = 0;
    while i < ArraySize(entityList) {
      let npc: ref<NPCPuppet> = entityList[i] as NPCPuppet;
      if IsDefined(npc) && npc.IsAttached() {
        npc.ApplyCustomEnemyHealthScaling(false);
      };
      i += 1;
    };
  }
}

@addMethod(NPCPuppet)
public final func QueueCustomHealthScaling(fillHealthPool: Bool, clearOnly: Bool) -> Void {
  let sys: ref<EHSL_System> = EHSL_System.Get(this.GetGame());
  if IsDefined(sys) {
    let req: ref<EHSL_ApplyRequest> = new EHSL_ApplyRequest();
    req.entityID = this.GetEntityID();
    req.fillHealthPool = fillHealthPool;
    req.clearOnly = clearOnly;
    sys.QueueRequest(req);
  };
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  this.QueueCustomHealthScaling(true, false);
  return result;
}

@wrapMethod(NPCManager)
private final func SetNPCArchetypeData(record: wref<Character_Record>) -> Void {
  wrappedMethod(record);
  if IsDefined(this.m_owner) {
    this.m_owner.QueueCustomHealthScaling(true, false);
  }
}

@wrapMethod(NPCPuppet)
public static final func ChangeHighLevelState(obj: ref<GameObject>, newState: gamedataNPCHighLevelState) -> Void {
  wrappedMethod(obj, newState);
  let npc: ref<NPCPuppet> = obj as NPCPuppet;
  if IsDefined(npc) {
    npc.QueueCustomHealthScaling(false, false);
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  if !this.HasCustomScaledHealthModifier() {
    this.QueueCustomHealthScaling(true, false);
  }
  return wrappedMethod(evt);
}

@wrapMethod(PlayerDevelopmentData)
public final func ScaleNPCsToPlayerLevel() -> Void {
  wrappedMethod();
  if !IsDefined(this.m_owner) {
    return;
  }
  let sys: ref<EHSL_System> = EHSL_System.Get(this.m_owner.GetGame());
  if IsDefined(sys) {
    let req: ref<EHSL_ScaleAllRequest> = new EHSL_ScaleAllRequest();
    sys.QueueRequest(req);
  }
}

@wrapMethod(DamageSystem)
private final func PreProcess(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Bool {
  if IsDefined(hitEvent) && IsDefined(hitEvent.target) {
    let npc: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
    if IsDefined(npc) {
      if NPCPuppet.IsJohnnyMemory(npc.GetGame()) {
        npc.ClearCustomEnemyHealthScaling();
      } else if !npc.HasCustomScaledHealthModifier() {
        npc.ApplyCustomEnemyHealthScaling(true);
      }
    }
  }
  return wrappedMethod(hitEvent, cache);
}

// Prevent vanilla story-mode / percentage-based damage scaling from multiplying player damage
// by targetHealth / baseNPCHealth and canceling out the custom health multiplier.
@wrapMethod(DamageSystem)
private final func ScalePlayerDamage(hitEvent: ref<gameHitEvent>) -> Void {
  wrappedMethod(hitEvent);
  if !IsDefined(hitEvent) || !IsDefined(hitEvent.target) || !IsDefined(hitEvent.attackComputed) {
    return;
  }
  let targetPuppet: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
  if IsDefined(targetPuppet) && NotEquals(targetPuppet.GetNPCRarity(), gamedataNPCRarity.Boss) && NotEquals(targetPuppet.GetNPCRarity(), gamedataNPCRarity.MaxTac) {
    let mult: Float = targetPuppet.GetCustomScaledHealthMultiplier();
    if mult > 1.0 {
      hitEvent.attackComputed.MultAttackValue(1.0 / mult);
    }
  }
}

@wrapMethod(DamageSystem)
private final func ProcessDeviceExplosionDamageToTierNPC(hitEvent: ref<gameHitEvent>) -> Void {
  let prevTotal: Float = 0.0;
  if IsDefined(hitEvent) && IsDefined(hitEvent.attackComputed) {
    prevTotal = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
  }
  wrappedMethod(hitEvent);
  if !IsDefined(hitEvent) || !IsDefined(hitEvent.target) || !IsDefined(hitEvent.attackComputed) {
    return;
  }
  let newTotal: Float = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
  if newTotal != prevTotal {
    let npc: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
    if IsDefined(npc) {
      let mult: Float = npc.GetCustomScaledHealthMultiplier();
      if mult > 1.0 {
        hitEvent.attackComputed.MultAttackValue(1.0 / mult);
      }
    }
  }
}
