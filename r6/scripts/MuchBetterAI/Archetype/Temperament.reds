module MuchBetterAI.Archetype

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*

public class MBAI_TemperamentSystem extends ScriptableSystem {
  private let m_tickID: DelayID;
  private let m_managedActors: array<wref<NPCPuppet>>;

  private func OnAttach() -> Void {
    MBAInfo("Temperament", "archetype temperament online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(3.0);
  }

  private func OnDetach() -> Void {
    this.RestoreAll();
    GameInstance.GetDelaySystem(this.GetGameInstance()).CancelDelay(this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_TemperamentTickCallback> = new MBAI_TemperamentTickCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Assign(gi, player);
    } else {
      this.RestoreAll();
    };
    this.ScheduleTick(2.0);
  }

  private final func Assign(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let enemies: array<wref<NPCPuppet>> = this.GatherEnemies(gi, player);
    this.RestoreReleased(enemies);
    let count: Int32 = ArraySize(enemies);
    let officerPos: array<Vector4>;
    let i: Int32 = 0;
    while i < count {
      let r: gamedataNPCRarity = enemies[i].GetNPCRarity();
      if Equals(r, gamedataNPCRarity.Officer) || Equals(r, gamedataNPCRarity.Elite) {
        ArrayPush(officerPos, enemies[i].GetWorldPosition());
      };
      i += 1;
    };
    i = 0;
    while i < count {
      let npc: wref<NPCPuppet> = enemies[i];
      let a: gamedataArchetypeType = MBAI_GetArchetype(npc);
      let g: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
      let aura: Int32 = this.OfficerNearby(npc, officerPos) ? 1 : 0;
      if Equals(npc.m_mbaiPersonalityTag, n"") {
        npc.m_mbaiPersonalityTag = MBAI_RollPersonality(g);
      };
      let shift: Int32 = MBAI_PersonalityShift(npc.m_mbaiPersonalityTag);
      let desired: Int32 = MBAI_ClampTemperamentScale(MBAI_TemperamentScale(a, g, aura) + shift);
      if !npc.m_mbaiTemperamentSet || npc.m_mbaiTemperamentScale != desired {
        if !npc.m_mbaiTemperamentSet {
          ArrayPush(this.m_managedActors, npc);
        };
        npc.m_mbaiTemperamentSet = true;
        npc.m_mbaiTemperamentScale = desired;
        this.ApplyTemperament(npc, a, g, desired);
      };
      i += 1;
    };
  }

  private final func OfficerNearby(npc: wref<NPCPuppet>, officerPos: array<Vector4>) -> Bool {
    let pos: Vector4 = npc.GetWorldPosition();
    let j: Int32 = 0;
    while j < ArraySize(officerPos) {
      let d: Float = Vector4.Distance(pos, officerPos[j]);
      if d > 0.1 && d <= 25.0 {
        return true;
      };
      j += 1;
    };
    return false;
  }

  private final func ApplyTemperament(npc: wref<NPCPuppet>, a: gamedataArchetypeType, g: MBAI_DoctrineGroup, scale: Int32) -> Void {
    let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
    let desired: TweakDBID = MBAI_TemperamentAbility(scale);
    if !npcSharp.m_mbaiTemperamentOwned {
      this.CaptureAuthoredTemperaments(npcSharp);
      if ArraySize(npcSharp.m_mbaiAuthoredTemperaments) == 1 && npcSharp.m_mbaiAuthoredTemperaments[0] == desired {
        return;
      };
      this.RemoveTemperaments(npcSharp, npcSharp.m_mbaiAuthoredTemperaments);
      npcSharp.m_mbaiTemperamentOwned = true;
    } else {
      if npcSharp.m_mbaiAppliedTemperament == desired {
        return;
      };
      if TDBID.IsValid(npcSharp.m_mbaiAppliedTemperament) {
        RPGManager.RemoveAbility(npcSharp, TweakDBInterface.GetGameplayAbilityRecord(npcSharp.m_mbaiAppliedTemperament));
      };
    };
    RPGManager.ApplyAbility(npcSharp, TweakDBInterface.GetGameplayAbilityRecord(desired));
    npcSharp.m_mbaiAppliedTemperament = desired;
    ScriptedPuppet.SendActionSignal(npcSharp, n"InterruptCoverSelection", 0.50);
    MBATrace("Temperament", s"archetype=\(ToString(a)) doctrine=\(ToString(g)) preset=\(scale) posture=\(MBAI_TemperamentName(scale)) personality=\(ToString(npcSharp.m_mbaiPersonalityTag))");
  }

  private final func CaptureAuthoredTemperaments(npc: ref<NPCPuppet>) -> Void {
    ArrayClear(npc.m_mbaiAuthoredTemperaments);
    let appliedPackages: array<TweakDBID>;
    let glp: ref<GameplayLogicPackageSystem> = GameInstance.GetGameplayLogicPackageSystem(npc.GetGame());
    glp.GetAppliedPackages(npc, appliedPackages);
    let catalog: array<TweakDBID> = MBAI_TemperamentAbilityCatalog();
    let i: Int32 = 0;
    while i < ArraySize(catalog) {
      let ability: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(catalog[i]);
      if IsDefined(ability) && IsDefined(ability.AbilityPackage()) && ArrayContains(appliedPackages, ability.AbilityPackage().GetID()) {
        ArrayPush(npc.m_mbaiAuthoredTemperaments, catalog[i]);
      };
      i += 1;
    };
  }

  private final func RemoveTemperaments(npc: ref<NPCPuppet>, abilities: array<TweakDBID>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(abilities) {
      RPGManager.RemoveAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(abilities[i]));
      i += 1;
    };
  }

  private final func RestoreReleased(enemies: array<wref<NPCPuppet>>) -> Void {
    let i: Int32 = ArraySize(this.m_managedActors) - 1;
    while i >= 0 {
      let npc: wref<NPCPuppet> = this.m_managedActors[i];
      if !IsDefined(npc) || !this.ContainsEnemy(enemies, npc.GetEntityID()) || !this.IsEligible(npc) {
        if IsDefined(npc) {
          this.RestoreTemperament(npc as NPCPuppet);
        };
        ArrayErase(this.m_managedActors, i);
      };
      i -= 1;
    };
  }

  private final func ContainsEnemy(enemies: array<wref<NPCPuppet>>, id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(enemies) {
      if Equals(enemies[i].GetEntityID(), id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func RestoreTemperament(npc: ref<NPCPuppet>) -> Void {
    if !npc.m_mbaiTemperamentOwned {
      npc.m_mbaiAppliedTemperament = t"";
      ArrayClear(npc.m_mbaiAuthoredTemperaments);
      npc.m_mbaiTemperamentSet = false;
      return;
    };
    if TDBID.IsValid(npc.m_mbaiAppliedTemperament) {
      RPGManager.RemoveAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(npc.m_mbaiAppliedTemperament));
    };
    let i: Int32 = 0;
    while i < ArraySize(npc.m_mbaiAuthoredTemperaments) {
      RPGManager.ApplyAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(npc.m_mbaiAuthoredTemperaments[i]));
      i += 1;
    };
    npc.m_mbaiTemperamentOwned = false;
    npc.m_mbaiAppliedTemperament = t"";
    ArrayClear(npc.m_mbaiAuthoredTemperaments);
    npc.m_mbaiTemperamentSet = false;
    ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 0.50);
  }

  private final func RestoreAll() -> Void {
    let i: Int32 = ArraySize(this.m_managedActors) - 1;
    while i >= 0 {
      let npc: wref<NPCPuppet> = this.m_managedActors[i];
      if IsDefined(npc) {
        this.RestoreTemperament(npc as NPCPuppet);
      };
      ArrayErase(this.m_managedActors, i);
      i -= 1;
    };
  }

  private final func GatherEnemies(gi: GameInstance, player: ref<PlayerPuppet>) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let candidates: array<wref<NPCPuppet>> = MBAI_EnemyCombatActors(gi, player, 60.0, 1.90);
    let i: Int32 = 0;
    while i < ArraySize(candidates) {
      let npc: wref<NPCPuppet> = candidates[i];
      if IsDefined(npc) && this.IsEligible(npc) {
        ArrayPush(result, npc);
      };
      i += 1;
    };
    return result;
  }

  private final func IsEligible(npc: wref<NPCPuppet>) -> Bool {
    if !MBAI_EnemyEligible(npc) || !MBAI_ActorAuthoredControlFree(npc) || npc.IsMechanical() {
      return false;
    };
    let rarity: gamedataNPCRarity = npc.GetNPCRarity();
    if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    return Equals(ai.GetHighLevelState(), gamedataNPCHighLevelState.Combat);
  }
}

public class MBAI_TemperamentTickCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_TemperamentSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Archetype.MBAI_TemperamentSystem") as MBAI_TemperamentSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}

public static func MBAI_TemperamentScale(a: gamedataArchetypeType, g: MBAI_DoctrineGroup, auraBonus: Int32) -> Int32 {
  let scale: Int32 = MBAI_ArchetypeTemperBase(a) + MBAI_TemperamentShift(g) + auraBonus;
  return MBAI_ClampTemperamentScale(scale);
}

public static func MBAI_TemperamentAbilityCatalog() -> array<TweakDBID> {
  let result: array<TweakDBID>;
  ArrayPush(result, t"Ability.IsCautious");
  ArrayPush(result, t"Ability.IsDefensive");
  ArrayPush(result, t"Ability.IsBalanced");
  ArrayPush(result, t"Ability.IsAggressive");
  ArrayPush(result, t"Ability.IsReckless");
  return result;
}

private static func MBAI_ArchetypeTemperBase(a: gamedataArchetypeType) -> Int32 {
  if MBAI_ArchetypeIsMelee(a) {
    return 4;
  };
  if MBAI_ArchetypeIsShotgunner(a) {
    return 3;
  };
  if MBAI_ArchetypeIsSniper(a) {
    return 1;
  };
  if MBAI_ArchetypeIsHangBack(a) {
    return 0;
  };
  if MBAI_ArchetypeIsCloseRange(a) {
    return 3;
  };
  return 2;
}

private static func MBAI_TemperamentShift(g: MBAI_DoctrineGroup) -> Int32 {
  switch g {
    case MBAI_DoctrineGroup.BullCharge:
    case MBAI_DoctrineGroup.ChromeRush:
      return 2;
    case MBAI_DoctrineGroup.RaiderStrike:
    case MBAI_DoctrineGroup.Overwhelm:
    case MBAI_DoctrineGroup.BrotherhoodPush:
    case MBAI_DoctrineGroup.RelentlessAdvance:
      return 1;
    case MBAI_DoctrineGroup.BladeWave:
    case MBAI_DoctrineGroup.WeekendWarriors:
      return 0;
    case MBAI_DoctrineGroup.FixAndFlank:
    case MBAI_DoctrineGroup.CallAndCoordinate:
    case MBAI_DoctrineGroup.CowardsSwarm:
    case MBAI_DoctrineGroup.MeasuredExecution:
      return -1;
    case MBAI_DoctrineGroup.LockAndHold:
    case MBAI_DoctrineGroup.WallAroundRunner:
    case MBAI_DoctrineGroup.DefensivePerimeter:
      return -2;
    default:
      break;
  };
  return 0;
}
