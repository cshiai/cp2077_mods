module MuchBetterAI.Core

public struct MBAI_CombatSnapshotStats {
  public let enemyRefreshes: Int32;
  public let enemyReuses: Int32;
  public let nearbyRefreshes: Int32;
  public let nearbyReuses: Int32;
}

public class MBAI_CombatSnapshotSystem extends ScriptableSystem {
  private let m_playerID: EntityID;
  private let m_enemyActors: array<wref<NPCPuppet>>;
  private let m_nearbyActors: array<wref<NPCPuppet>>;
  private let m_enemyOrigin: Vector4;
  private let m_nearbyOrigin: Vector4;
  private let m_enemyCapturedAt: Float;
  private let m_nearbyCapturedAt: Float;
  private let m_enemyValid: Bool;
  private let m_nearbyValid: Bool;
  private let m_enemyRefreshes: Int32;
  private let m_enemyReuses: Int32;
  private let m_nearbyRefreshes: Int32;
  private let m_nearbyReuses: Int32;

  private func OnDetach() -> Void {
    this.Clear();
  }

  public final func EnemyActors(player: ref<PlayerPuppet>, radius: Float, maxAge: Float) -> array<wref<NPCPuppet>> {
    let empty: array<wref<NPCPuppet>>;
    if !IsDefined(player) {
      return empty;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    this.Prepare(player, now);
    if !this.m_enemyValid || now - this.m_enemyCapturedAt > maxAge {
      this.RefreshEnemies(player, now);
    } else {
      this.m_enemyReuses += 1;
    };
    return this.WithinRadius(this.m_enemyActors, player.GetWorldPosition(), MinF(radius, 60.0));
  }

  public final func NearbyActors(player: ref<PlayerPuppet>, radius: Float, maxAge: Float) -> array<wref<NPCPuppet>> {
    let empty: array<wref<NPCPuppet>>;
    if !IsDefined(player) {
      return empty;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    this.Prepare(player, now);
    if !this.m_nearbyValid || now - this.m_nearbyCapturedAt > maxAge {
      this.RefreshNearby(player, now);
    } else {
      this.m_nearbyReuses += 1;
    };
    return this.WithinRadius(this.m_nearbyActors, player.GetWorldPosition(), MinF(radius, 45.0));
  }

  public final const func Stats() -> MBAI_CombatSnapshotStats {
    let result: MBAI_CombatSnapshotStats;
    result.enemyRefreshes = this.m_enemyRefreshes;
    result.enemyReuses = this.m_enemyReuses;
    result.nearbyRefreshes = this.m_nearbyRefreshes;
    result.nearbyReuses = this.m_nearbyReuses;
    return result;
  }

  private final func Prepare(player: ref<PlayerPuppet>, now: Float) -> Void {
    let playerChanged: Bool = (this.m_enemyValid || this.m_nearbyValid) && !Equals(this.m_playerID, player.GetEntityID());
    let timeRewound: Bool = (this.m_enemyValid && now < this.m_enemyCapturedAt) || (this.m_nearbyValid && now < this.m_nearbyCapturedAt);
    // A one-frame cache must survive small player movement.  The old
    // `> 0.0` test invalidated every snapshot as soon as V moved, turning all
    // consumers back into repeated targeting queries.  Refresh after a
    // meaningful displacement instead.
    let originChanged: Bool = (this.m_enemyValid && Vector4.Distance(player.GetWorldPosition(), this.m_enemyOrigin) > 3.0)
      || (this.m_nearbyValid && Vector4.Distance(player.GetWorldPosition(), this.m_nearbyOrigin) > 3.0);
    if playerChanged || timeRewound || originChanged {
      this.Clear();
    };
    this.m_playerID = player.GetEntityID();
  }

  private final func RefreshEnemies(player: ref<PlayerPuppet>, now: Float) -> Void {
    ArrayClear(this.m_enemyActors);
    let query: TargetSearchQuery = TSQ_EnemyNPC();
    query.testedSet = TargetingSet.Complete;
    query.maxDistance = 60.0;
    query.filterObjectByDistance = true;
    query.includeSecondaryTargets = false;
    query.ignoreInstigator = true;
    let parts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(this.GetGameInstance()).GetTargetParts(player, query, parts);
    let seen: array<EntityID>;
    let i: Int32 = 0;
    while i < ArraySize(parts) {
      let component: wref<TargetingComponent> = TS_TargetPartInfo.GetComponent(parts[i]);
      if IsDefined(component) {
        let npc: wref<NPCPuppet> = component.GetEntity() as NPCPuppet;
        if IsDefined(npc) && !ArrayContains(seen, npc.GetEntityID()) {
          ArrayPush(seen, npc.GetEntityID());
          ArrayPush(this.m_enemyActors, npc);
        };
      };
      i += 1;
    };
    this.m_enemyOrigin = player.GetWorldPosition();
    this.m_enemyCapturedAt = now;
    this.m_enemyValid = true;
    this.m_enemyRefreshes += 1;
  }

  private final func RefreshNearby(player: ref<PlayerPuppet>, now: Float) -> Void {
    ArrayClear(this.m_nearbyActors);
    let actors: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(45.0);
    let i: Int32 = 0;
    while i < ArraySize(actors) {
      if IsDefined(actors[i]) {
        ArrayPush(this.m_nearbyActors, actors[i]);
      };
      i += 1;
    };
    this.m_nearbyOrigin = player.GetWorldPosition();
    this.m_nearbyCapturedAt = now;
    this.m_nearbyValid = true;
    this.m_nearbyRefreshes += 1;
  }

  private final func WithinRadius(actors: array<wref<NPCPuppet>>, origin: Vector4, radius: Float) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let i: Int32 = 0;
    while i < ArraySize(actors) {
      let npc: wref<NPCPuppet> = actors[i];
      if IsDefined(npc) && Vector4.Distance(origin, npc.GetWorldPosition()) <= radius {
        ArrayPush(result, npc);
      };
      i += 1;
    };
    return result;
  }

  private final func Clear() -> Void {
    ArrayClear(this.m_enemyActors);
    ArrayClear(this.m_nearbyActors);
    this.m_enemyCapturedAt = 0.0;
    this.m_nearbyCapturedAt = 0.0;
    this.m_enemyValid = false;
    this.m_nearbyValid = false;
  }
}

public func MBAI_EnemyCombatActors(gi: GameInstance, player: ref<PlayerPuppet>, radius: Float, maxAge: Float) -> array<wref<NPCPuppet>> {
  let empty: array<wref<NPCPuppet>>;
  if !IsDefined(player) {
    return empty;
  };
  let system: ref<MBAI_CombatSnapshotSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_CombatSnapshotSystem") as MBAI_CombatSnapshotSystem;
  if !IsDefined(system) {
    return empty;
  };
  return system.EnemyActors(player, radius, maxAge);
}

public func MBAI_NearbyCombatActors(gi: GameInstance, player: ref<PlayerPuppet>, radius: Float, maxAge: Float) -> array<wref<NPCPuppet>> {
  let empty: array<wref<NPCPuppet>>;
  if !IsDefined(player) {
    return empty;
  };
  let system: ref<MBAI_CombatSnapshotSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_CombatSnapshotSystem") as MBAI_CombatSnapshotSystem;
  if !IsDefined(system) {
    return empty;
  };
  return system.NearbyActors(player, radius, maxAge);
}

public func MBAI_GetCombatSnapshotStats(gi: GameInstance) -> MBAI_CombatSnapshotStats {
  let empty: MBAI_CombatSnapshotStats;
  let system: ref<MBAI_CombatSnapshotSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Core.MBAI_CombatSnapshotSystem") as MBAI_CombatSnapshotSystem;
  if !IsDefined(system) {
    return empty;
  };
  return system.Stats();
}
