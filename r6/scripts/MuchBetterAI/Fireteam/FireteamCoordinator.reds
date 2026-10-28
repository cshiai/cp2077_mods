module MuchBetterAI.Fireteam

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Nerve.*
import MuchBetterAI.Stealth.*
import MuchBetterAI.Squad.*

public class MBAI_TrackedOrder {
  public let id: EntityID;
  public let role: MBAI_Role;
  public let group: MBAI_DoctrineGroup;
  public let squadName: CName;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let nativeUntil: Float;
  public let fallbackAttempted: Bool;
  public let reacquireUsed: Bool;
  public let pairID: Int32;
  public let startTime: Float;
  public let startHealth: Float;
  public let flankVec: Vector4;
  public let initialPlayerPos: Vector4;
  public let startedVisible: Bool;
  public let lastPos: Vector4;
  public let lastProgressTime: Float;
  public let pushThrough: Bool;
  public let holdUntil: Float;
}

public class MBAI_GrenadeOrder {
  public let id: EntityID;
  public let cmd: ref<AICommand>;
  public let leaseToken: Int32;
  public let until: Float;
  public let executingSince: Float;
}

public class MBAI_ContainmentSector {
  public let fallbackID: EntityID;
  public let squadName: CName;
  public let point: Vector4;
  public let playerPos: Vector4;
  public let until: Float;
}

public class MBAI_FlankSearch {
  public let npcPos: Vector4;
  public let playerPos: Vector4;
  public let requireOpposite: Bool;
  public let oppositeOf: Vector4;
  public let point: Vector4;
  public let oppositeDot: Float;
}

public class MBAI_FireteamSystem extends ScriptableSystem {
  private let m_orders: array<ref<MBAI_TrackedOrder>>;
  private let m_grenadeOrders: array<ref<MBAI_GrenadeOrder>>;
  private let m_containmentSectors: array<ref<MBAI_ContainmentSector>>;
  private let m_tickID: DelayID;
  private let m_lastPlayerPos: Vector4;
  private let m_playerStillSince: Float;
  private let m_behaviorSeeded: Bool;
  private let m_nextPairID: Int32;

  private func OnAttach() -> Void {
    MBAInfo("Fireteam", "coordinator online");
    this.m_tickID = GetInvalidDelayID();
    this.ScheduleTick(2.0);
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    MBAI_CancelDelay(gi, this.m_tickID);
    this.m_tickID = GetInvalidDelayID();
    this.CancelAll(gi, EngineTime.ToFloat(GameInstance.GetSimTime(gi)));
  }

  private final func ScheduleTick(delay: Float) -> Void {
    let ds = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    ds.CancelDelay(this.m_tickID);
    let cb: ref<MBAI_FireteamTickCallback> = new MBAI_FireteamTickCallback();
    cb.game = this.GetGameInstance();
    this.m_tickID = ds.DelayCallback(cb, delay, false);
  }

  private final func HasFireteamBlockingCommand(ai: ref<AIHumanComponent>) -> Bool {
    return ai.IsCommandActive(n"AIMoveToCommand") || ai.IsCommandActive(n"AIHoldPositionCommand") || ai.IsCommandActive(n"AIThrowGrenadeCommand");
  }

  private final func ShouldLetVanillaFight(npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, group: MBAI_DoctrineGroup) -> Bool {
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, contactPosition) || !tracked.visible {
      return false;
    };
    if MBAI_IsPushThrough(group, MBAI_GetArchetype(npc)) {
      return false;
    };
    let rangeBonus: Float = 0.0;
    switch MBAI_GetTemperamentScale(npc) {
      case 0:
        rangeBonus = -2.0;
        break;
      case 1:
        rangeBonus = -1.0;
        break;
      case 3:
        rangeBonus = 2.0;
        break;
      case 4:
        rangeBonus = 4.0;
        break;
      default:
        break;
    };
    return Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) <= MaxF(8.0, MBAI_DoctrineCommitDepth(group) + 5.0 + rangeBonus);
  }

  public final func Tick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) {
      this.Evaluate(gi, player);
    } else {
      this.CancelAll(gi, EngineTime.ToFloat(GameInstance.GetSimTime(gi)));
    };
    this.ScheduleTick(ArraySize(this.m_orders) > 0 || ArraySize(this.m_grenadeOrders) > 0 ? 0.35 : 1.5);
  }

  private final func Evaluate(gi: GameInstance, player: ref<PlayerPuppet>) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    this.MonitorGrenades(gi, player, now);
    this.MonitorOrders(gi, player, now);
    this.PruneContainmentSectors(now);
    let squad: array<wref<NPCPuppet>> = this.GatherSquad(gi, player);
    let count: Int32 = ArraySize(squad);
    let counterPerch: ref<MBAI_CounterPerchSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_CounterPerchSystem") as MBAI_CounterPerchSystem;
    if IsDefined(counterPerch) {
      counterPerch.EvaluateCounterPerch(gi, player, squad, now, this);
    };
    if count == 0 {
      return;
    };
    let entrenched: Bool = this.PlayerEntrenched(gi, player, now);
    let inCover: Bool = this.PlayerInCover(gi, player);
    let coverPressure: Bool = inCover && now - this.m_playerStillSince >= 3.0;
    let activeRunner: Bool = this.HasAnyActiveRunner(squad, now);
    if (coverPressure || activeRunner) {
      this.TrySuppressor(player, squad, count, coverPressure, now);
    };
    if entrenched {
      this.TryGrenadeDoctrine(gi, player, squad, entrenched, now);
    };
    this.TickBound(gi, player, squad, count, inCover, now);
    let i: Int32 = 0;
    while i < count {
      let npc: wref<NPCPuppet> = squad[i];
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      if !MBAI_CounterPerchActive(gi, npc, player, now) && !this.IsTracked(npc.GetEntityID()) && (now - npcSharp.m_mbaiLastOrderEnd > 4.5) && MBAI_IsOrderAvailable(npcSharp, n"Fireteam", now) && !MBAI_IntentBlocksCommand(npcSharp, n"Fireteam", now) {
        let rarity: gamedataNPCRarity = npc.GetNPCRarity();
        let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), rarity);
        let role: MBAI_Role = MBAI_GetOrStampRole(npcSharp);
        let combatGroupCount: Int32 = this.CombatGroupCount(squad, npc);
        if combatGroupCount >= 2 && Equals(role, MBAI_Role.Anchor) {
          let anchorBase: Float = MBAI_DoctrineAnchorChance(group);
          if this.HasActiveRunner(squad, npc, now) {
            anchorBase = MinF(1.0, anchorBase + 0.25);
          };
          if this.CountRoleGroup(MBAI_Role.Anchor, group, npc) < 2 && RandF() < anchorBase * MBAI_TemperamentCommandPressure(npc) {
            this.IssueAnchor(gi, npc, group, now);
          };
        } else {
          if combatGroupCount >= 2 && Equals(role, MBAI_Role.Flanker) {
            let numbersMul: Float = 1.0;
            if MBAI_DoctrineNumbersGated(group) && this.SameDoctrineCount(squad, group, npc) < 3 {
              numbersMul = MBAI_DoctrineLowNumbersChanceMul(group);
            };
            if (inCover || MBAI_ArchetypeIsCloseRange(MBAI_GetArchetype(npc))) && this.CountRoleGroup(MBAI_Role.Flanker, group, npc) < MBAI_DoctrineBudget(group) && !this.DirectorRotationHold(MBAI_Role.Flanker, group, npc, now) {
              let chance: Float = MBAI_TierFlankChance(rarity) * MBAI_DoctrineChanceMul(group) * MBAI_TemperamentCommandPressure(npc) * 1.25 * numbersMul;
              let awareMul: Float = MBAI_DoctrinePlayerAwarenessMul(group);
              let facing: Bool = this.IsPlayerLookingAtNPC(player, npc.GetWorldPosition());
              chance *= facing ? (1.0 - awareMul) : (1.0 + awareMul);
              chance *= this.FunnelPenalty(npc, squad, group);
              if this.GroupHasOfficer(squad, group, npc) {
                chance *= 1.25;
              };
              if MBAI_DoctrineReactive(group) {
                chance *= 1.6;
              };
              if this.HasActiveAnchor(group, npc, now) {
                chance *= 1.5;
                MBAInfo("Fireteam", "fire-and-maneuver boost npc=" + ToString(npc.GetEntityID()) + " group=" + ToString(EnumInt(group)));
              };
              chance = MinF(chance, 1.0);
              if RandF() < chance {
                if Equals(group, MBAI_DoctrineGroup.CowardsSwarm) {
                  this.IssueRush(gi, player, npc, now);
                } else {
                  this.IssueFlank(gi, player, npc, group, now);
                };
              };
            };
          };
        };
      };
      i += 1;
    };
  }

  private final func TrySuppressor(player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, count: Int32, coverPressure: Bool, now: Float) -> Void {
    if !MBAI_OwnsSuppressionFire() {
      return;
    };
    let picked: wref<NPCPuppet>;
    let pickedActive: Int32 = 0;
    let bestScore: Float = 0.0;
    let bestDist: Float = 0.0;
    let pickedGroup: MBAI_DoctrineGroup = MBAI_DoctrineGroup.Baseline;
    let i: Int32 = 0;
    while i < count {
      let npc: wref<NPCPuppet> = squad[i];
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      let firedRecently: Bool = npcSharp.m_mbaiLastShotAtPlayerSim > 0.0 && (now - npcSharp.m_mbaiLastShotAtPlayerSim < 3.0);
      let tracked: TrackedLocation;
      let contactPosition: Vector4;
      let hasVisibleContact: Bool = MBAI_GetCombatContact(npc, player, tracked, contactPosition) && tracked.visible;
      if IsDefined(npc) && !MBAI_IsSuppressing(npcSharp, now) && !this.IsManeuvering(npc.GetEntityID()) && !MBAI_IntentIsManeuver(MBAI_GetIntent(npcSharp, now)) && !MBAI_IntentBlocksCommand(npcSharp, n"Fireteam", now) && firedRecently && hasVisibleContact && (coverPressure || this.HasActiveRunner(squad, npc, now)) {
        let d: Float = Vector4.Distance(npc.GetWorldPosition(), contactPosition);
        let weaponScore: Float = this.SuppressorWeaponScore(npc, d);
        if weaponScore > 0.0 {
          let groupCount: Int32 = this.CombatGroupCount(squad, npc);
          let active: Int32 = this.ActiveSuppressorCount(squad, npc, now);
          let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
          let limit: Int32 = MBAI_DoctrineSuppressorLimit(group, groupCount);
          if groupCount >= 2 && active < limit {
            let role: MBAI_Role = MBAI_GetOrStampRole(npcSharp);
            let roleScore: Float = Equals(role, MBAI_Role.Anchor) ? 1.15 : (Equals(role, MBAI_Role.Flanker) ? 0.85 : 1.0);
            let stabilityScore: Float = Vector4.Length2D(npc.GetVelocity()) < 1.5 ? 1.10 : 0.90;
            let score: Float = weaponScore * roleScore * stabilityScore;
            if score > bestScore {
              bestScore = score;
              bestDist = d;
              pickedActive = active;
              pickedGroup = group;
              picked = npc;
            };
          };
        };
      };
      i += 1;
    };
    if IsDefined(picked) {
      let duration: Float = MBAI_DoctrineSuppressDuration(pickedGroup);
      MBAI_MarkSuppress(picked as NPCPuppet, now + duration);
      MBAI_SetIntent(picked as NPCPuppet, n"FireteamSuppress", n"Fireteam", duration, now);
      MBAInfo("Fireteam", s"suppressor designated npc=\(ToString(picked.GetEntityID())) group=\(EnumInt(pickedGroup)) dist=\(bestDist) score=\(bestScore) active=\(pickedActive + 1) duration=\(duration)");
    };
  }

  private final func SuppressorWeaponScore(npc: wref<NPCPuppet>, distance: Float) -> Float {
    let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(npc);
    if !IsDefined(weapon) {
      return 0.0;
    };
    let weaponRecord: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
    if !IsDefined(weaponRecord) || Equals(weaponRecord.Evolution().Type(), gamedataWeaponEvolution.Smart) {
      return 0.0;
    };
    switch RPGManager.GetItemType(weapon.GetItemID()) {
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
        return distance <= 40.0 ? 1.50 : 0.60;
      case gamedataItemType.Wea_AssaultRifle:
        if distance < 8.0 {
          return 0.75;
        };
        return distance <= 38.0 ? 1.25 : 0.65;
      case gamedataItemType.Wea_SubmachineGun:
        if distance < 6.0 {
          return 0.70;
        };
        return distance <= 26.0 ? 1.10 : 0.40;
      default:
        return 0.0;
    };
  }

  private final func ActiveSuppressorCount(squad: array<wref<NPCPuppet>>, member: wref<NPCPuppet>, now: Float) -> Int32 {
    let count: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      if MBAI_SameCombatGroup(member, squad[i]) && MBAI_IsSuppressing(squad[i] as NPCPuppet, now) {
        count += 1;
      };
      i += 1;
    };
    return count;
  }

  private final func CombatGroupCount(squad: array<wref<NPCPuppet>>, member: wref<NPCPuppet>) -> Int32 {
    let count: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      if MBAI_SameCombatGroup(member, squad[i]) {
        count += 1;
      };
      i += 1;
    };
    return count;
  }

  private final func HasActiveRunner(squad: array<wref<NPCPuppet>>, member: wref<NPCPuppet>, now: Float) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let npc: wref<NPCPuppet> = squad[i];
      if IsDefined(npc) && MBAI_SameCombatGroup(member, npc) {
        let intent: CName = MBAI_GetIntent(npc, now);
        if Equals(intent, n"NetrunnerCast") || Equals(intent, n"NetrunnerReposition") {
          return true;
        };
      };
      i += 1;
    };
    return false;
  }

  private final func HasAnyActiveRunner(squad: array<wref<NPCPuppet>>, now: Float) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let intent: CName = MBAI_GetIntent(squad[i], now);
      if Equals(intent, n"NetrunnerCast") || Equals(intent, n"NetrunnerReposition") {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func HasActiveAnchor(group: MBAI_DoctrineGroup, member: wref<NPCPuppet>, now: Float) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let o: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if Equals(o.role, MBAI_Role.Anchor) && Equals(o.group, group) && o.holdUntil > now && MBAI_CombatGroupMatches(o.squadName, o.id, member) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func IsPlayerLookingAtNPC(player: ref<PlayerPuppet>, npcPos: Vector4) -> Bool {
    let playerPos: Vector4 = player.GetWorldPosition();
    let toNpc: Vector4 = npcPos - playerPos;
    let d: Float = Vector4.Length(toNpc);
    if d < 0.1 {
      return true;
    };
    let toNpcNorm: Vector4 = toNpc / d;
    let fwd: Vector4 = player.GetWorldForward();
    let dot: Float = fwd.X * toNpcNorm.X + fwd.Y * toNpcNorm.Y;
    return dot > 0.6;
  }

  private final func FunnelPenalty(candidate: wref<NPCPuppet>, squad: array<wref<NPCPuppet>>, group: MBAI_DoctrineGroup) -> Float {
    let cPos: Vector4 = candidate.GetWorldPosition();
    let cId: EntityID = candidate.GetEntityID();
    let clustered: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let other: wref<NPCPuppet> = squad[i];
      if IsDefined(other) && !Equals(other.GetEntityID(), cId) && MBAI_SameCombatGroup(candidate, other) {
        let og: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(other), other.GetNPCRarity());
        if Equals(og, group) && Vector4.Distance(cPos, other.GetWorldPosition()) < 2.5 {
          clustered += 1;
        };
      };
      i += 1;
    };
    if clustered >= 2 {
      return 0.4;
    };
    if clustered >= 1 {
      return 0.7;
    };
    return 1.0;
  }

  private final func DirectorRotationHold(role: MBAI_Role, group: MBAI_DoctrineGroup, member: wref<NPCPuppet>, now: Float) -> Bool {
    let cadence: Int32 = MBAI_DoctrinePushCadence(group);
    let window: Float = 2.5;
    if cadence == 0 {
      window = 1.5;
    };
    if cadence == 2 {
      window = 4.0;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let o: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if Equals(o.role, role) && Equals(o.group, group) && MBAI_CombatGroupMatches(o.squadName, o.id, member) && (now - o.startTime < window) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func IssueFlank(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, group: MBAI_DoctrineGroup, now: Float) -> Bool {
    if !MBAI_ActorHasLegMobility(npc) || this.ShouldLetVanillaFight(npc, player, group) {
      return false;
    };
    let tracked: TrackedLocation;
    let playerPos: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, playerPos) {
      return false;
    };
    let search: ref<MBAI_FlankSearch> = new MBAI_FlankSearch();
    search.npcPos = npc.GetWorldPosition();
    search.playerPos = playerPos;
    let oppositeOf: Vector4;
    search.requireOpposite = MBAI_DoctrineOpposesActiveFlank(group) && this.GetActiveFlankPoint(group, npc, now, playerPos, oppositeOf);
    search.oppositeOf = oppositeOf;
    if !this.FindLOSPoint(gi, GameInstance.GetAINavigationSystem(gi), npc, search) {
      if search.requireOpposite {
        MBADebug("Fireteam", "containment rejected npc=" + ToString(npc.GetEntityID()) + " reason=no-opposite-nav");
      };
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Fireteam", now) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, search.point);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = true;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      let flankDist: Float = Vector4.Distance(search.npcPos, search.point);
      let window: Float = ClampF(flankDist / 5.0, 3.5, 7.0);
      let leaseToken: Int32 = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Fireteam", window, now);
      MBAI_SetIntent(npc as NPCPuppet, n"FireteamFlank", n"Fireteam", window, now);
      let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(gi);
      let order: ref<MBAI_TrackedOrder> = new MBAI_TrackedOrder();
      order.id = npc.GetEntityID();
      order.role = MBAI_Role.Flanker;
      order.group = group;
      this.StampOrderGroup(order, npc);
      order.cmd = cmd;
      order.leaseToken = leaseToken;
      order.startTime = now;
      order.startHealth = 100.0;
      if IsDefined(statPools) {
        order.startHealth = statPools.GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, false);
      }
      order.flankVec = search.point;
      order.initialPlayerPos = playerPos;
      order.startedVisible = tracked.visible;
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
      order.pushThrough = MBAI_IsPushThrough(group, MBAI_GetArchetype(npc));
      order.holdUntil = now + window;
      ArrayPush(this.m_orders, order);
      MBAInfo("Fireteam", "flank issued npc=" + ToString(order.id) + " group=" + ToString(EnumInt(group)) + " rarity=" + ToString(npc.GetNPCRarity()) + " posture=" + MBAI_TemperamentName(MBAI_GetTemperamentScale(npc)) + " push=" + ToString(order.pushThrough) + " opposite=" + ToString(search.requireOpposite) + " sectorDot=" + ToString(search.oppositeDot) + " dist=" + ToString(flankDist) + " window=" + ToString(window));
      MBAI_TryBark(npc as NPCPuppet, n"battlecry_curse", n"MBAI:FlankCommit", now, 6.0);
    };
    return ok;
  }

  private final func IssueRush(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, now: Float) -> Bool {
    if !MBAI_ActorHasLegMobility(npc) || this.ShouldLetVanillaFight(npc, player, MBAI_DoctrineGroup.CowardsSwarm) {
      return false;
    };
    let tracked: TrackedLocation;
    let playerPos: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, playerPos) {
      return false;
    };
    let order: ref<MBAI_TrackedOrder> = new MBAI_TrackedOrder();
    order.id = npc.GetEntityID();
    order.role = MBAI_Role.Flanker;
    order.group = MBAI_DoctrineGroup.CowardsSwarm;
    this.StampOrderGroup(order, npc);
    order.startTime = now;
    order.nativeUntil = now + 1.25;
    order.flankVec = playerPos;
    order.initialPlayerPos = playerPos;
    order.lastPos = npc.GetWorldPosition();
    order.lastProgressTime = now;
    order.pushThrough = true;
    order.holdUntil = now + 5.0;
    ArrayPush(this.m_orders, order);
    MBAI_SetIntent(npc as NPCPuppet, n"FireteamRush", n"Fireteam", 5.0, now);
    ScriptedPuppet.SendActionSignal(npc, n"GracefulCombatInterruption", 1.0);
    MBAInfo("Fireteam", s"rush assigned npc=\(ToString(order.id)) rarity=\(npc.GetNPCRarity()) posture=\(MBAI_TemperamentName(MBAI_GetTemperamentScale(npc)))");
    MBAI_TryBark(npc as NPCPuppet, n"battlecry_curse", n"MBAI:RushCommit", now, 6.0);
    return true;
  }

  private final func SendRushFallback(player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, order: ref<MBAI_TrackedOrder>, now: Float) -> Bool {
    if !MBAI_ActorHasLegMobility(npc) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Fireteam", now) {
      return false;
    };
    let tracked: TrackedLocation;
    let playerPos: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, playerPos) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, playerPos);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = MaxF(2.0, 12.0 - MBAI_DoctrineCommitDepth(MBAI_DoctrineGroup.CowardsSwarm));
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = true;
    if !ai.SendCommand(cmd) {
      return false;
    };
    order.cmd = cmd;
    order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Fireteam", 3.5, now);
    order.fallbackAttempted = true;
    order.startTime = now;
    order.lastPos = npc.GetWorldPosition();
    order.lastProgressTime = now;
    return true;
  }

  private final func FindLOSPoint(gi: GameInstance, nav: ref<AINavigationSystem>, npc: wref<NPCPuppet>, search: ref<MBAI_FlankSearch>) -> Bool {
    let bestScore: Float = 999.0;
    let bestPoint: Vector4;
    let bestOppositeDot: Float = 1.0;
    let found: Bool = false;
    let currentDist: Float = Vector4.Distance(search.npcPos, search.playerPos);
    let baseRadius: Float = ClampF(currentDist, 5.0, 12.0);
    let ringCount: Int32 = 3;
    let ringMul: array<Float>;
    ArrayPush(ringMul, 0.8);
    ArrayPush(ringMul, 1.0);
    ArrayPush(ringMul, 1.3);
    let angleCount: Int32 = 12;
    let goodEnough: Float = baseRadius;
    let stopSearch: Bool = false;
    let oppositeDirection: Vector4;
    let hasOppositeDirection: Bool = false;
    if search.requireOpposite {
      oppositeDirection = search.oppositeOf - search.playerPos;
      if Vector4.Length(oppositeDirection) > 0.5 {
        oppositeDirection = Vector4.Normalize(oppositeDirection);
        hasOppositeDirection = true;
      };
    };
    let a: Int32 = 0;
    while a < angleCount && !stopSearch {
      let angle: Float = (Cast<Float>(a) / Cast<Float>(angleCount)) * 6.2831854820251465;
      let ux: Float = CosF(angle);
      let uy: Float = SinF(angle);
      let r: Int32 = 0;
      while r < ringCount && !stopSearch {
        let radius: Float = baseRadius * ringMul[r];
        let candidate: Vector4 = search.playerPos;
        candidate.X += ux * radius;
        candidate.Y += uy * radius;
        let snapped: Vector4 = nav.GetNearestNavmeshPointBelow(npc, candidate, 2.5, 4);
        if !Vector4.IsZero(snapped) {
          let oppositeDot: Float = 1.0;
          let sectorValid: Bool = !search.requireOpposite;
          if search.requireOpposite && hasOppositeDirection {
            let candidateDirection: Vector4 = snapped - search.playerPos;
            if Vector4.Length(candidateDirection) > 0.5 {
              oppositeDot = Vector4.Dot(oppositeDirection, Vector4.Normalize(candidateDirection));
              sectorValid = oppositeDot < -0.25;
            };
          };
          if sectorValid && MBAI_CorpseLOS.RayClearBetween(gi, snapped, search.playerPos) {
            let distToNPC: Float = Vector4.Distance(search.npcPos, snapped);
            let fromNPC: Vector4 = search.npcPos - search.playerPos;
            let fromCandidate: Vector4 = snapped - search.playerPos;
            let sidePenalty: Float = 1.0;
            if Vector4.Length(fromNPC) > 0.5 && Vector4.Length(fromCandidate) > 0.5 {
              sidePenalty = AbsF(Vector4.Dot(Vector4.Normalize(fromNPC), Vector4.Normalize(fromCandidate)));
            };
            let score: Float = distToNPC + sidePenalty * baseRadius * 1.5;
            if score < bestScore {
              bestScore = score;
              bestPoint = snapped;
              bestOppositeDot = oppositeDot;
              found = true;
              if distToNPC <= goodEnough && sidePenalty < 0.45 {
                stopSearch = true;
              };
            };
          };
        };
        r += 1;
      };
      a += 1;
    };
    if search.requireOpposite && !found {
      return false;
    };
    if found {
      search.point = bestPoint;
      search.oppositeDot = bestOppositeDot;
    };
    return found;
  }

  private final func GetActiveFlankPoint(group: MBAI_DoctrineGroup, member: wref<NPCPuppet>, now: Float, playerPos: Vector4, out result: Vector4) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if Equals(order.role, MBAI_Role.Flanker)
        && Equals(order.group, group)
        && order.holdUntil > now
        && !Vector4.IsZero(order.flankVec)
        && Vector4.Distance(order.initialPlayerPos, playerPos) <= 4.0
        && MBAI_CombatGroupMatches(order.squadName, order.id, member) {
        result = order.flankVec;
        return true;
      };
      i += 1;
    };
    i = 0;
    while i < ArraySize(this.m_containmentSectors) {
      let sector: ref<MBAI_ContainmentSector> = this.m_containmentSectors[i];
      if sector.until > now && Vector4.Distance(sector.playerPos, playerPos) <= 4.0 && MBAI_CombatGroupMatches(sector.squadName, sector.fallbackID, member) {
        result = sector.point;
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func RecordContainmentSector(order: ref<MBAI_TrackedOrder>, npc: wref<NPCPuppet>, playerPos: Vector4, now: Float) -> Void {
    if !IsDefined(npc) || !Equals(order.group, MBAI_DoctrineGroup.FixAndFlank) {
      return;
    };
    let point: Vector4 = npc.GetWorldPosition();
    if Vector4.IsZero(point) {
      return;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_containmentSectors) {
      let current: ref<MBAI_ContainmentSector> = this.m_containmentSectors[i];
      if MBAI_CombatGroupMatches(current.squadName, current.fallbackID, npc) {
        current.fallbackID = order.id;
        current.squadName = order.squadName;
        current.point = point;
        current.playerPos = playerPos;
        current.until = now + 4.0;
        MBADebug("Fireteam", "containment sector updated npc=" + ToString(order.id) + " until=" + ToString(current.until));
        return;
      };
      i += 1;
    };
    let sector: ref<MBAI_ContainmentSector> = new MBAI_ContainmentSector();
    sector.fallbackID = order.id;
    sector.squadName = order.squadName;
    sector.point = point;
    sector.playerPos = playerPos;
    sector.until = now + 4.0;
    ArrayPush(this.m_containmentSectors, sector);
    MBADebug("Fireteam", "containment sector stored npc=" + ToString(order.id) + " until=" + ToString(sector.until));
  }

  private final func PruneContainmentSectors(now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_containmentSectors) - 1;
    while i >= 0 {
      if this.m_containmentSectors[i].until <= now {
        ArrayErase(this.m_containmentSectors, i);
      };
      i -= 1;
    };
  }

  private final func IssueAnchor(gi: GameInstance, npc: wref<NPCPuppet>, group: MBAI_DoctrineGroup, now: Float) -> Bool {
    let order: ref<MBAI_TrackedOrder> = new MBAI_TrackedOrder();
    order.id = npc.GetEntityID();
    order.role = MBAI_Role.Anchor;
    order.group = group;
    this.StampOrderGroup(order, npc);
    order.startTime = now;
    order.nativeUntil = now + 1.25;
    order.flankVec = npc.GetWorldPosition();
    order.lastPos = order.flankVec;
    order.lastProgressTime = now;
    order.holdUntil = now + 5.0;
    ArrayPush(this.m_orders, order);
    MBAI_SetIntent(npc as NPCPuppet, n"FireteamAnchor", n"Fireteam", 5.0, now);
    MBAInfo("Fireteam", "anchor assigned npc=" + ToString(order.id) + " group=" + ToString(EnumInt(order.group)) + " rarity=" + ToString(npc.GetNPCRarity()) + " posture=" + MBAI_TemperamentName(MBAI_GetTemperamentScale(npc)));
    let a: gamedataArchetypeType = MBAI_GetArchetype(npc);
    let anchorVo: CName = MBAI_ArchetypeIsSniper(a) ? n"sniper_warning" : n"heavy_warning";
    MBAI_TryBark(npc as NPCPuppet, anchorVo, n"MBAI:AnchorSet", now, 10.0);
    return true;
  }

  private final func SendShortHold(npc: wref<NPCPuppet>, order: ref<MBAI_TrackedOrder>, now: Float) -> Bool {
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Fireteam", now) {
      return false;
    };
    let cmd: ref<AIHoldPositionCommand> = new AIHoldPositionCommand();
    cmd.duration = 1.5;
    cmd.ignoreInCombat = false;
    if !ai.SendCommand(cmd) {
      return false;
    };
    order.cmd = cmd;
    order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Fireteam", 1.5, now);
    order.fallbackAttempted = true;
    return true;
  }

  private final func MonitorOrders(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(gi);
    let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      let remove: Bool = false;
      let reason: String = "";
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      let aggressiveOrder: Bool = Equals(order.role, MBAI_Role.Flanker) || Equals(order.role, MBAI_Role.BoundAdvance);
      let legMobilityLost: Bool = aggressiveOrder && IsDefined(npc) && !MBAI_ActorHasLegMobility(npc);
      let tracked: TrackedLocation;
      let contactPosition: Vector4;
      let hasCombatContact: Bool = MBAI_GetCombatContact(npc, player, tracked, contactPosition);
      if !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || legMobilityLost || !MBAI_EnemyMovementEligible(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player) || !hasCombatContact {
        remove = true;
        reason = legMobilityLost ? "leg-mobility-lost" : (IsDefined(npc) ? (hasCombatContact ? "ownership-changed" : "contact-lost") : "dead");
      } else {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) {
          remove = true;
          reason = "no-ai-component";
        } else {
          if StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
            remove = true;
            reason = "netrunner-hacking";
          } else {
            if IsDefined(nerve) && nerve.HasActiveAssignment(order.id) {
              remove = true;
              reason = "nerve-break";
            } else {
              if Equals(order.role, MBAI_Role.Anchor) {
                if now >= order.holdUntil {
                  remove = true;
                  reason = "anchor-complete";
                } else {
                  let laneDistance: Float = Vector4.Distance(npc.GetWorldPosition(), order.flankVec);
                  if laneDistance > 4.5 {
                    remove = true;
                    reason = "anchor-abandoned";
                  } else {
                    if now >= order.nativeUntil && laneDistance > 2.5 && !order.fallbackAttempted {
                      this.SendShortHold(npc, order, now);
                    };
                    this.ObserveOptionalCommand(npc, order, now);
                  };
                };
              } else {
                if Equals(order.role, MBAI_Role.BoundHold) || Equals(order.role, MBAI_Role.BoundAdvance) {
                  if order.pairID <= 0 || !this.HasPairMate(order) {
                    remove = true;
                    reason = "bound-pair-invalid";
                  } else {
                    if Equals(order.role, MBAI_Role.BoundHold) {
                      let laneDistance: Float = Vector4.Distance(npc.GetWorldPosition(), order.flankVec);
                      if laneDistance > 4.5 {
                        remove = true;
                        reason = "bound-hold-abandoned";
                      } else {
                        if now >= order.nativeUntil && laneDistance > 2.5 && !order.fallbackAttempted {
                          this.SendShortHold(npc, order, now);
                        };
                        this.ObserveOptionalCommand(npc, order, now);
                      };
                    } else {
                      if !IsDefined(order.cmd) {
                        remove = true;
                        reason = "bound-advance-lost";
                      } else {
                        let state: AICommandState = ai.GetCommandState(order.cmd);
                        if Equals(state, AICommandState.Interrupted) {
                          MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Fireteam", order.leaseToken, now, 1.0);
                          order.cmd = null;
                          order.nativeUntil = now + 1.0;
                          order.holdUntil = MaxF(order.holdUntil, now + 3.0);
                        } else {
                          if Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) || now >= order.holdUntil {
                            if npc.m_mbaiIncomingFireUntil <= now && this.PairReadyToFlip(order.pairID) {
                              this.FlipStablePair(gi, player, nerve, order.pairID, now);
                            };
                          };
                        };
                      };
                      if Equals(order.role, MBAI_Role.BoundAdvance) && !IsDefined(order.cmd) && now >= order.nativeUntil {
                        if !MBAI_ActorHasNoActiveAICommand(npc) {
                          if now >= order.holdUntil {
                            this.InvalidatePair(order.pairID);
                            remove = true;
                            reason = "bound-reaction-timeout";
                          };
                        } else {
                          if order.reacquireUsed {
                            this.InvalidatePair(order.pairID);
                            remove = true;
                            reason = "bound-reacquire-exhausted";
                          } else {
                            order.reacquireUsed = true;
                            if !this.SendBoundMove(gi, player, npc, order, now) {
                              this.InvalidatePair(order.pairID);
                              remove = true;
                              reason = "bound-reacquire-unavailable";
                            };
                          };
                        };
                      };
                    };
                  };
                } else {
                  if Equals(order.group, MBAI_DoctrineGroup.CowardsSwarm) {
                    let startDistance: Float = Vector4.Distance(order.lastPos, order.initialPlayerPos);
                    let currentDistance: Float = Vector4.Distance(npc.GetWorldPosition(), order.initialPlayerPos);
                    let nativeReceipt: Bool = startDistance - currentDistance >= 1.5 || npc.m_mbaiLastShotAtPlayerSim >= order.startTime;
                    if nativeReceipt {
                      remove = true;
                      reason = order.fallbackAttempted ? "rush-fallback-receipt" : "rush-native-receipt";
                    } else {
                      if now >= order.holdUntil {
                        remove = true;
                        reason = "rush-timeout";
                      } else {
                        if !IsDefined(order.cmd) && now >= order.nativeUntil {
                          if order.fallbackAttempted && order.reacquireUsed {
                            remove = true;
                            reason = "rush-reacquire-exhausted";
                          } else {
                            let wasFallback: Bool = order.fallbackAttempted;
                            if this.SendRushFallback(player, npc, order, now) {
                              if wasFallback {
                                order.reacquireUsed = true;
                              };
                            } else {
                              remove = true;
                              reason = "rush-fallback-unavailable";
                            };
                          };
                        } else {
                          if IsDefined(order.cmd) {
                            let state: AICommandState = ai.GetCommandState(order.cmd);
                            if Equals(state, AICommandState.Interrupted) {
                              MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Fireteam", order.leaseToken, now, 1.0);
                              order.cmd = null;
                              order.nativeUntil = now + 1.0;
                            } else {
                              if Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) {
                                remove = true;
                                reason = "rush-fallback-ended";
                              };
                            };
                          };
                        };
                      };
                    };
                  } else {
                    if !IsDefined(order.cmd) {
                      remove = true;
                      reason = "flank-command-lost";
                    } else {
                      let state: AICommandState = ai.GetCommandState(order.cmd);
                      let elapsed: Float = now - order.startTime;
                      if Vector4.Distance(contactPosition, order.initialPlayerPos) > 4.0 {
                        remove = true;
                        reason = "player-moved";
                      } else {
                        if (order.holdUntil > 0.0 && now >= order.holdUntil) || (order.holdUntil <= 0.0 && elapsed > 8.0) {
                          remove = true;
                          reason = "window-closed";
                        } else {
                          if Equals(state, AICommandState.Interrupted) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) {
                            remove = true;
                            reason = "flank-command-ended";
                          } else {
                            if elapsed > 1.0 && Equals(state, AICommandState.Success) {
                              remove = true;
                              reason = "arrived";
                            } else {
                              let curPos: Vector4 = npc.GetWorldPosition();
                              if !order.pushThrough {
                                let peel: Float = MBAI_DoctrinePeelThreshold(order.group);
                                if peel > 0.0 && IsDefined(statPools) {
                                  let pctHP: Float = statPools.GetStatPoolValue(Cast<StatsObjectID>(order.id), gamedataStatPoolType.Health, true) / 100.0;
                                  if pctHP < peel {
                                    remove = true;
                                    reason = "peel";
                                  };
                                } else if peel <= 0.0 && IsDefined(statPools) {
                                  let hp: Float = statPools.GetStatPoolValue(Cast<StatsObjectID>(order.id), gamedataStatPoolType.Health, false);
                                  if hp < order.startHealth - 1.0 {
                                    remove = true;
                                    reason = "took-fire";
                                  };
                                };
                              };
                              if !remove && !order.startedVisible && tracked.visible {
                                remove = true;
                                reason = "los-gained";
                                ScriptedPuppet.SendActionSignal(npc, n"InterruptCoverSelection", 1.0);
                              };
                              if !remove {
                                if Vector4.Distance(curPos, order.lastPos) > 1.0 {
                                  order.lastPos = curPos;
                                  order.lastProgressTime = now;
                                } else {
                                  if now - order.lastProgressTime > 3.0 {
                                    remove = true;
                                    reason = "stalled";
                                  };
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
      if remove {
        if order.pairID > 0 {
          this.InvalidatePair(order.pairID);
        };
        MBAInfo("Fireteam", "order end npc=" + ToString(order.id) + " role=" + ToString(EnumInt(order.role)) + " elapsed=" + ToString(now - order.startTime) + " reason=" + reason);
        if Equals(reason, "arrived") || Equals(reason, "los-gained") {
          this.RecordContainmentSector(order, npc, contactPosition, now);
        };
        this.EndTrackedOrder(npc, order, now);
        ArrayErase(this.m_orders, i);
      };
      i -= 1;
    };
  }

  private final func ObserveOptionalCommand(npc: wref<NPCPuppet>, order: ref<MBAI_TrackedOrder>, now: Float) -> Void {
    if IsDefined(order.cmd) {
      let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
      if IsDefined(ai) {
        let state: AICommandState = ai.GetCommandState(order.cmd);
        if Equals(state, AICommandState.Interrupted) || Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled) {
          MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Fireteam", order.leaseToken, now, 0.5);
          order.cmd = null;
        };
      };
    };
  }

  private final func EndTrackedOrder(npc: wref<NPCPuppet>, order: ref<MBAI_TrackedOrder>, now: Float) -> Void {
    if IsDefined(npc) {
      let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
      if IsDefined(ai) && IsDefined(order.cmd) {
        ai.CancelCommand(order.cmd);
      };
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      MBAI_ReleaseExecutionLease(npcSharp, n"Fireteam", order.leaseToken, now, 0.5);
      npcSharp.m_mbaiLastOrderEnd = now;
      MBAI_ClearIntent(npcSharp, n"Fireteam");
    };
  }

  private final func HasPairMate(order: ref<MBAI_TrackedOrder>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let candidate: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if candidate.pairID == order.pairID && !Equals(candidate.id, order.id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func PairReadyToFlip(pairID: Int32) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if order.pairID == pairID && Equals(order.role, MBAI_Role.BoundHold) && IsDefined(order.cmd) {
        return false;
      };
      i += 1;
    };
    return true;
  }

  private final func InvalidatePair(pairID: Int32) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if this.m_orders[i].pairID == pairID {
        this.m_orders[i].pairID = 0;
      };
      i += 1;
    };
  }

  private final func FlipStablePair(gi: GameInstance, player: ref<PlayerPuppet>, nerve: ref<MBAI_NerveSystem>, pairID: Int32, now: Float) -> Void {
    let hold: ref<MBAI_TrackedOrder>;
    let advance: ref<MBAI_TrackedOrder>;
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if order.pairID == pairID {
        if Equals(order.role, MBAI_Role.BoundHold) {
          hold = order;
        } else {
          if Equals(order.role, MBAI_Role.BoundAdvance) {
            advance = order;
          };
        };
      };
      i += 1;
    };
    if !IsDefined(hold) || !IsDefined(advance) {
      return;
    };
    let holdNPC: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, hold.id) as NPCPuppet;
    let advanceNPC: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, advance.id) as NPCPuppet;
    if !MBAI_EnemyMovementEligible(holdNPC) || !MBAI_EnemyMovementEligible(advanceNPC) {
      this.InvalidatePair(pairID);
      return;
    };
    if StatusEffectSystem.ObjectHasStatusEffect(holdNPC, t"AIQuickHackStatusEffect.Hacking") || (IsDefined(nerve) && nerve.HasActiveAssignment(hold.id)) || now < hold.nativeUntil || holdNPC.m_mbaiIncomingFireUntil > now || !MBAI_ActorHasNoActiveAICommand(holdNPC) || !MBAI_CanClaimExecutionLease(holdNPC, n"Fireteam", now) {
      return;
    };
    let advanceAI: ref<AIHumanComponent> = advanceNPC.GetAIControllerComponent();
    if IsDefined(advanceAI) && IsDefined(advance.cmd) {
      advanceAI.CancelCommand(advance.cmd);
    };
    MBAI_ReleaseExecutionLease(advanceNPC as NPCPuppet, n"Fireteam", advance.leaseToken, now, 0.5);
    advance.cmd = null;
    advance.role = MBAI_Role.BoundHold;
    advance.flankVec = advanceNPC.GetWorldPosition();
    advance.fallbackAttempted = false;
    advance.nativeUntil = now + 1.25;
    advance.holdUntil = now + 3.0;
    MBAI_SetIntent(advanceNPC as NPCPuppet, n"FireteamBoundHold", n"Fireteam", 3.0, now);
    hold.role = MBAI_Role.BoundAdvance;
    hold.fallbackAttempted = false;
    hold.reacquireUsed = false;
    hold.holdUntil = now + 3.0;
    if this.SendBoundMove(gi, player, holdNPC, hold, now) {
      MBAI_SetIntent(holdNPC as NPCPuppet, n"FireteamBoundAdvance", n"Fireteam", 3.0, now);
    } else {
      hold.pairID = 0;
      advance.pairID = 0;
    };
  }

  public final func HasActiveOrder(id: EntityID) -> Bool {
    if this.IsTracked(id) {
      return true;
    };
    let i: Int32 = 0;
    while i < ArraySize(this.m_grenadeOrders) {
      if Equals(this.m_grenadeOrders[i].id, id) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public final func YieldManeuverToCounterPerch(npc: wref<NPCPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if Equals(order.id, npc.GetEntityID()) && (Equals(order.role, MBAI_Role.Flanker) || Equals(order.role, MBAI_Role.BoundAdvance)) {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) && IsDefined(order.cmd) {
          ai.CancelCommand(order.cmd);
        };
        let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
        npcSharp.m_mbaiLastOrderEnd = now;
        MBAI_ReleaseExecutionLease(npcSharp, n"Fireteam", order.leaseToken, now, 0.5);
        MBAI_ClearIntent(npcSharp, n"Fireteam");
        ArrayErase(this.m_orders, i);
        MBAInfo("Fireteam", "maneuver yielded to counter-perch npc=" + ToString(order.id));
      };
      i -= 1;
    };
  }

  private final func IsTracked(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if this.m_orders[i].id == id {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func IsManeuvering(id: EntityID) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      if this.m_orders[i].id == id && (Equals(this.m_orders[i].role, MBAI_Role.Flanker) || Equals(this.m_orders[i].role, MBAI_Role.Rescue) || Equals(this.m_orders[i].role, MBAI_Role.BoundAdvance)) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  private final func CountRoleGroup(role: MBAI_Role, group: MBAI_DoctrineGroup, member: wref<NPCPuppet>) -> Int32 {
    let n: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(this.m_orders) {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      if Equals(order.role, role) && Equals(order.group, group) && MBAI_CombatGroupMatches(order.squadName, order.id, member) {
        n += 1;
      };
      i += 1;
    };
    return n;
  }

  private final func GroupHasOfficer(squad: array<wref<NPCPuppet>>, group: MBAI_DoctrineGroup, member: wref<NPCPuppet>) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let candidate: wref<NPCPuppet> = squad[i];
      let r: gamedataNPCRarity = candidate.GetNPCRarity();
      if MBAI_SameCombatGroup(member, candidate) && (Equals(r, gamedataNPCRarity.Officer) || Equals(r, gamedataNPCRarity.Elite) || Equals(r, gamedataNPCRarity.Boss) || Equals(r, gamedataNPCRarity.MaxTac)) {
        if Equals(MBAI_GetDoctrineGroup(MBAI_GetAffiliation(candidate), r), group) {
          return true;
        };
      };
      i += 1;
    };
    return false;
  }

  private final func SameDoctrineCount(squad: array<wref<NPCPuppet>>, group: MBAI_DoctrineGroup, member: wref<NPCPuppet>) -> Int32 {
    let n: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      if MBAI_SameCombatGroup(member, squad[i]) && Equals(MBAI_GetDoctrineGroup(MBAI_GetAffiliation(squad[i]), squad[i].GetNPCRarity()), group) {
        n += 1;
      };
      i += 1;
    };
    return n;
  }

  private final func PlayerInCover(gi: GameInstance, player: ref<PlayerPuppet>) -> Bool {
    let blackboard = GameInstance.GetBlackboardSystem(gi);
    let bb: ref<IBlackboard> = IsDefined(blackboard)
      ? blackboard.GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine)
      : null;
    return IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().PlayerStateMachine.UsingCover);
  }

  private final func PlayerEntrenched(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Bool {
    let pos: Vector4 = player.GetWorldPosition();
    if !this.m_behaviorSeeded {
      this.m_lastPlayerPos = pos;
      this.m_playerStillSince = now;
      this.m_behaviorSeeded = true;
    } else {
      if Vector4.Distance(pos, this.m_lastPlayerPos) > 2.0 {
        this.m_lastPlayerPos = pos;
        this.m_playerStillSince = now;
      };
    };
    if now - this.m_playerStillSince > 4.0 {
      return true;
    };
    let blackboard = GameInstance.GetBlackboardSystem(gi);
    let bb: ref<IBlackboard> = IsDefined(blackboard)
      ? blackboard.GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine)
      : null;
    if IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().PlayerStateMachine.UsingCover) {
      return true;
    };
    return false;
  }

  private final func TryGrenadeDoctrine(gi: GameInstance, player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, entrenched: Bool, now: Float) -> Void {
    let budgets: ref<MBAI_SquadAbilityBudgetSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Squad.MBAI_SquadAbilityBudgetSystem") as MBAI_SquadAbilityBudgetSystem;
    if !IsDefined(budgets) {
      return;
    };
    let picked: wref<NPCPuppet>;
    let pickedKind: MBAI_GrenadeKind = MBAI_GrenadeKind.None;
    let bestScore: Float = -1.0;
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let npc: wref<NPCPuppet> = squad[i];
      let rarity: gamedataNPCRarity = npc.GetNPCRarity();
      if NotEquals(rarity, gamedataNPCRarity.Boss) && NotEquals(rarity, gamedataNPCRarity.MaxTac) {
        let tracked: TrackedLocation;
        let contactPosition: Vector4;
        if this.CombatGroupCount(squad, npc) >= 2 && MBAI_GetCombatContact(npc, player, tracked, contactPosition) && tracked.visible {
          let kind: MBAI_GrenadeKind = MBAI_GrenadeKindFor(npc);
          if NotEquals(kind, MBAI_GrenadeKind.None) && NotEquals(kind, MBAI_GrenadeKind.Mixed) {
            let distance: Float = Vector4.Distance(contactPosition, npc.GetWorldPosition());
            if distance > 8.0 && distance < 30.0 && budgets.GrenadeReady(npc, now) && !this.HasActiveOrder(npc.GetEntityID()) && MBAI_IsOrderAvailable(npc as NPCPuppet, n"Fireteam", now) && !MBAI_IntentBlocksCommand(npc as NPCPuppet, n"Fireteam", now) {
              let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), rarity);
              let score: Float = MBAI_GrenadeScore(kind, entrenched, group);
              if score > bestScore {
                bestScore = score;
                picked = npc;
                pickedKind = kind;
              };
            };
          };
        };
      };
      i += 1;
    };
    if IsDefined(picked) && this.IssueGrenade(picked, pickedKind, now) {
      budgets.SpendGrenade(picked, now);
    };
  }

  private final func IssueGrenade(npc: wref<NPCPuppet>, kind: MBAI_GrenadeKind, now: Float) -> Bool {
    if MBAI_IntentBlocksCommand(npc as NPCPuppet, n"Fireteam", now) {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) || !MBAI_ActorHasNoActiveAICommand(npc) || this.HasFireteamBlockingCommand(ai) {
      return false;
    };
    let cmd: ref<AIThrowGrenadeCommand> = new AIThrowGrenadeCommand();
    let noNames: array<CName>;
    cmd.targetOverridePuppetRef = CreateEntityReference("#player", noNames);
    cmd.duration = 4.0;
    cmd.once = true;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      let npcSharp: ref<NPCPuppet> = npc as NPCPuppet;
      npcSharp.m_mbaiGrenadeDoctrineKind = MBAI_GrenadeKindName(kind);
      npcSharp.m_mbaiGrenadeDoctrineUntil = now + 5.0;
      let leaseToken: Int32 = MBAI_ClaimExecutionLease(npcSharp, n"Fireteam", 4.0, now);
      let order: ref<MBAI_GrenadeOrder> = new MBAI_GrenadeOrder();
      order.id = npc.GetEntityID();
      order.cmd = cmd;
      order.leaseToken = leaseToken;
      order.until = now + 8.0;
      ArrayPush(this.m_grenadeOrders, order);
      MBAI_SetIntent(npcSharp, n"FireteamGrenade", n"Fireteam", 4.0, now);
      MBAInfo("Fireteam", "grenade doctrine issued npc=" + ToString(npc.GetEntityID()) + " planned=" + NameToString(npcSharp.m_mbaiGrenadeDoctrineKind) + " rarity=" + ToString(npc.GetNPCRarity()) + " posture=" + MBAI_TemperamentName(MBAI_GetTemperamentScale(npc)));
      MBAI_TryBark(npcSharp, n"grenade_throw", n"MBAI:GrenadeDoctrine", now, 4.0);
    };
    return ok;
  }

  private final func GatherSquad(gi: GameInstance, player: ref<PlayerPuppet>) -> array<wref<NPCPuppet>> {
    let result: array<wref<NPCPuppet>>;
    let nerve: ref<MBAI_NerveSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Nerve.MBAI_NerveSystem") as MBAI_NerveSystem;
    let origin: Vector4 = player.GetWorldPosition();
    let candidates: array<wref<NPCPuppet>> = MBAI_EnemyCombatActors(gi, player, 45.0, 0.30);
    let i: Int32 = 0;
    while i < ArraySize(candidates) {
      let npc: wref<NPCPuppet> = candidates[i];
      if IsDefined(npc) && this.IsEligible(npc, origin, player) && !(IsDefined(nerve) && nerve.HasActiveAssignment(npc.GetEntityID())) {
        ArrayPush(result, npc);
      };
      i += 1;
    };
    return result;
  }

  private final func IsEligible(npc: wref<NPCPuppet>, origin: Vector4, player: ref<PlayerPuppet>) -> Bool {
    if !MBAI_EnemyMovementEligible(npc) || npc.IsMechanical() {
      return false;
    };
    let d: Float = Vector4.Distance(origin, npc.GetWorldPosition());
    if d < 6.0 || d > 45.0 {
      return false;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    if !Equals(ai.GetHighLevelState(), gamedataNPCHighLevelState.Combat) {
      return false;
    };
    return NPCPuppet.IsInCombatWithTarget(npc, player);
  }

  private final func IsHighTierRarity(r: gamedataNPCRarity) -> Bool {
    return Equals(r, gamedataNPCRarity.Officer) || Equals(r, gamedataNPCRarity.Elite) || Equals(r, gamedataNPCRarity.Boss) || Equals(r, gamedataNPCRarity.MaxTac);
  }

  private final func CountBoundGroup(group: MBAI_DoctrineGroup, member: wref<NPCPuppet>) -> Int32 {
    return this.CountRoleGroup(MBAI_Role.BoundHold, group, member) + this.CountRoleGroup(MBAI_Role.BoundAdvance, group, member);
  }

  private final func TickBound(gi: GameInstance, player: ref<PlayerPuppet>, squad: array<wref<NPCPuppet>>, count: Int32, inCover: Bool, now: Float) -> Void {
    if !inCover {
      return;
    };
    let firstIndex: Int32 = 0;
    while firstIndex < count {
      let first: wref<NPCPuppet> = squad[firstIndex];
      let tracked: TrackedLocation;
      let playerPos: Vector4;
      if MBAI_GetCombatContact(first, player, tracked, playerPos) {
        if this.BoundCandidateReady(gi, first, player, now) {
          let rarity: gamedataNPCRarity = first.GetNPCRarity();
          let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(first), rarity);
          let coordTier: Int32 = MBAI_DoctrineCoordinationTier(group);
          let needCount: Int32 = coordTier >= 2 ? 3 : 2;
          if MBAI_DoctrineBounds(group) && coordTier >= 1 && this.SameDoctrineCount(squad, group, first) >= needCount && Vector4.Distance(first.GetWorldPosition(), playerPos) > 18.0 {
            let high: Bool = this.IsHighTierRarity(rarity);
            if (high || this.GroupHasOfficer(squad, group, first)) && this.CountBoundGroup(group, first) < 4 {
              let chance: Float = (high ? 0.5 : 0.25) * MBAI_TemperamentCommandPressure(first);
              if RandF() < chance {
                let partner: wref<NPCPuppet> = this.FindBoundPartner(gi, squad, first, group, player, playerPos, now);
                if IsDefined(partner) {
                  this.StartBoundPair(gi, player, first, partner, group, now);
                  return;
                };
              };
            };
          };
        };
      };
      firstIndex += 1;
    };
  }

  private final func BoundCandidateReady(gi: GameInstance, npc: wref<NPCPuppet>, player: ref<PlayerPuppet>, now: Float) -> Bool {
    return IsDefined(npc)
      && !MBAI_CounterPerchActive(gi, npc, player, now)
      && !this.IsTracked(npc.GetEntityID())
      && MBAI_IsOrderAvailable(npc as NPCPuppet, n"Fireteam", now)
      && !MBAI_IntentBlocksCommand(npc as NPCPuppet, n"Fireteam", now);
  }

  private final func FindBoundPartner(gi: GameInstance, squad: array<wref<NPCPuppet>>, first: wref<NPCPuppet>, group: MBAI_DoctrineGroup, player: ref<PlayerPuppet>, playerPos: Vector4, now: Float) -> wref<NPCPuppet> {
    let i: Int32 = 0;
    while i < ArraySize(squad) {
      let candidate: wref<NPCPuppet> = squad[i];
      if IsDefined(candidate)
        && !Equals(candidate.GetEntityID(), first.GetEntityID())
        && MBAI_SameCombatGroup(first, candidate)
        && Equals(MBAI_GetDoctrineGroup(MBAI_GetAffiliation(candidate), candidate.GetNPCRarity()), group)
        && Vector4.Distance(candidate.GetWorldPosition(), playerPos) > 18.0
        && this.BoundCandidateReady(gi, candidate, player, now) {
        return candidate;
      };
      i += 1;
    };
    return null;
  }

  private final func StartBoundPair(gi: GameInstance, player: ref<PlayerPuppet>, holdNPC: wref<NPCPuppet>, advanceNPC: wref<NPCPuppet>, group: MBAI_DoctrineGroup, now: Float) -> Bool {
    let hold: ref<MBAI_TrackedOrder> = new MBAI_TrackedOrder();
    hold.id = holdNPC.GetEntityID();
    hold.role = MBAI_Role.BoundHold;
    hold.group = group;
    this.StampOrderGroup(hold, holdNPC);
    hold.startTime = now;
    hold.nativeUntil = now + 1.25;
    hold.flankVec = holdNPC.GetWorldPosition();
    hold.lastPos = hold.flankVec;
    hold.holdUntil = now + 3.0;

    let advance: ref<MBAI_TrackedOrder> = new MBAI_TrackedOrder();
    advance.id = advanceNPC.GetEntityID();
    advance.role = MBAI_Role.BoundAdvance;
    advance.group = group;
    this.StampOrderGroup(advance, advanceNPC);
    advance.startTime = now;
    advance.holdUntil = now + 3.0;
    if !this.SendBoundMove(gi, player, advanceNPC, advance, now) {
      return false;
    };

    this.m_nextPairID += 1;
    if this.m_nextPairID <= 0 {
      this.m_nextPairID = 1;
    };
    hold.pairID = this.m_nextPairID;
    advance.pairID = this.m_nextPairID;
    ArrayPush(this.m_orders, hold);
    ArrayPush(this.m_orders, advance);
    MBAI_SetIntent(holdNPC as NPCPuppet, n"FireteamBoundHold", n"Fireteam", 3.0, now);
    MBAI_SetIntent(advanceNPC as NPCPuppet, n"FireteamBoundAdvance", n"Fireteam", 3.0, now);
    let tracked: TrackedLocation;
    let contactPosition: Vector4;
    if MBAI_GetCombatContact(holdNPC, player, tracked, contactPosition) {
      if MBAI_OwnsSuppressionFire() && this.SuppressorWeaponScore(holdNPC, Vector4.Distance(holdNPC.GetWorldPosition(), contactPosition)) > 0.0 {
        MBAI_MarkSuppress(holdNPC as NPCPuppet, now + 3.0);
      };
    };
    MBAInfo("Fireteam", "bound pair started pair=" + ToString(this.m_nextPairID) + " hold=" + ToString(hold.id) + " advance=" + ToString(advance.id) + " group=" + ToString(EnumInt(group)));
    return true;
  }

  private final func SendBoundMove(gi: GameInstance, player: ref<PlayerPuppet>, npc: wref<NPCPuppet>, order: ref<MBAI_TrackedOrder>, now: Float) -> Bool {
    if !MBAI_ActorHasLegMobility(npc) || !MBAI_ActorHasNoActiveAICommand(npc) || !MBAI_CanClaimExecutionLease(npc, n"Fireteam", now) {
      return false;
    };
    let nav: ref<AINavigationSystem> = GameInstance.GetAINavigationSystem(gi);
    let advPoint: Vector4;
    let zeroOffset: Vector4;
    if !nav.GetFurthestNavmeshPointInFront(npc, 2.5, 5, advPoint, zeroOffset, true) {
      return false;
    };
    let tracked: TrackedLocation;
    let playerPos: Vector4;
    if !MBAI_GetCombatContact(npc, player, tracked, playerPos) {
      return false;
    };
    if Vector4.Distance(advPoint, playerPos) >= Vector4.Distance(npc.GetWorldPosition(), playerPos) {
      return false;
    };
    let jittered: Vector4 = advPoint;
    jittered.X += (RandF() - 0.5) * 6.0;
    jittered.Y += (RandF() - 0.5) * 6.0;
    if nav.IsPointOnNavmesh(npc, jittered, 1.5) && Vector4.Distance(jittered, playerPos) < Vector4.Distance(npc.GetWorldPosition(), playerPos) {
      advPoint = jittered;
    };
    let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
    if !IsDefined(ai) {
      return false;
    };
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let destWp: WorldPosition;
    WorldPosition.SetVector4(destWp, advPoint);
    AIPositionSpec.SetWorldPosition(cmd.movementTarget, destWp);
    MBAI_ApplyCombatFacing(cmd, player, tracked);
    cmd.movementType = moveMovementType.Run;
    cmd.ignoreNavigation = false;
    cmd.desiredDistanceFromTarget = 0.0;
    cmd.finishWhenDestinationReached = true;
    cmd.ignoreInCombat = false;
    let ok: Bool = ai.SendCommand(cmd);
    if ok {
      order.cmd = cmd;
      order.leaseToken = MBAI_ClaimExecutionLease(npc as NPCPuppet, n"Fireteam", 3.0, now);
      order.lastPos = npc.GetWorldPosition();
      order.lastProgressTime = now;
    };
    return ok;
  }

  private final func MonitorGrenades(gi: GameInstance, player: ref<PlayerPuppet>, now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_grenadeOrders) - 1;
    while i >= 0 {
      let order: ref<MBAI_GrenadeOrder> = this.m_grenadeOrders[i];
      let npc: wref<NPCPuppet> = GameInstance.FindEntityByID(gi, order.id) as NPCPuppet;
      let remove: Bool = !MBAI_EnemyMovementEligible(npc) || !NPCPuppet.IsInCombatWithTarget(npc, player);
      if !remove {
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if !IsDefined(ai) || !IsDefined(order.cmd) {
          remove = true;
        } else {
          let state: AICommandState = ai.GetCommandState(order.cmd);
          remove = Equals(state, AICommandState.Interrupted) || Equals(state, AICommandState.Success) || Equals(state, AICommandState.Failure) || Equals(state, AICommandState.Cancelled);
          if !remove {
            if Equals(state, AICommandState.Executing) {
              if order.executingSince <= 0.0 {
                order.executingSince = now;
              };
              remove = now - order.executingSince > 6.0;
            } else {
              remove = now >= order.until;
            };
          };
        };
      };
      if remove {
        this.EndGrenadeOrder(npc, order, now);
        ArrayErase(this.m_grenadeOrders, i);
      };
      i -= 1;
    };
  }

  private final func EndGrenadeOrder(npc: wref<NPCPuppet>, order: ref<MBAI_GrenadeOrder>, now: Float) -> Void {
    if IsDefined(npc) {
      let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
      if IsDefined(ai) && IsDefined(order.cmd) {
        ai.CancelCommand(order.cmd);
      };
      MBAI_ReleaseExecutionLease(npc as NPCPuppet, n"Fireteam", order.leaseToken, now, 0.5);
      MBAI_ClearIntent(npc as NPCPuppet, n"Fireteam");
    };
  }

  private final func CancelAll(gi: GameInstance, now: Float) -> Void {
    let counterPerch: ref<MBAI_CounterPerchSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"MuchBetterAI.Fireteam.MBAI_CounterPerchSystem") as MBAI_CounterPerchSystem;
    if IsDefined(counterPerch) {
      counterPerch.Reset(gi, now);
    };
    let grenadeIndex: Int32 = ArraySize(this.m_grenadeOrders) - 1;
    while grenadeIndex >= 0 {
      let grenade: ref<MBAI_GrenadeOrder> = this.m_grenadeOrders[grenadeIndex];
      this.EndGrenadeOrder(GameInstance.FindEntityByID(gi, grenade.id) as NPCPuppet, grenade, now);
      ArrayErase(this.m_grenadeOrders, grenadeIndex);
      grenadeIndex -= 1;
    };
    let i: Int32 = ArraySize(this.m_orders) - 1;
    while i >= 0 {
      let order: ref<MBAI_TrackedOrder> = this.m_orders[i];
      this.EndTrackedOrder(GameInstance.FindEntityByID(gi, order.id) as NPCPuppet, order, now);
      ArrayErase(this.m_orders, i);
      i -= 1;
    };
    this.m_playerStillSince = 0.0;
    this.m_behaviorSeeded = false;
    ArrayClear(this.m_containmentSectors);
  }

  private final func StampOrderGroup(order: ref<MBAI_TrackedOrder>, npc: wref<NPCPuppet>) -> Void {
    order.squadName = MBAI_CombatGroupSquadName(npc);
  }
}

public class MBAI_FireteamTickCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let sys: ref<MBAI_FireteamSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Fireteam.MBAI_FireteamSystem") as MBAI_FireteamSystem;
    if IsDefined(sys) {
      sys.Tick();
    };
  }
}
