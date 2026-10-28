// Source-controlled, no-settings street-fight scheduler.
// It only seeds fights between already-spawned open-world actors. Dynamic
// duplication is delegated to EMRS so there is one 24-entity owner.
module StreetActivity

import MuchBetterAI.Core.*
import PostCombatFix.*
import SimpleDroneCompanion.*

public func StreetActivity_TickSeconds() -> Float = 5.0;
public func StreetActivity_WarmupSeconds() -> Float = 20.0;
public func StreetActivity_MinSeedDistance() -> Float = 10.0;
public func StreetActivity_MaxSeedDistance() -> Float = 42.0;
public func StreetActivity_ActiveSeconds() -> Float = 150.0;
public func StreetActivity_MinCooldownSeconds() -> Float = 480.0;
public func StreetActivity_MaxCooldownSeconds() -> Float = 720.0;
public func StreetActivity_EncounterCloneCount() -> Int32 = 1;

private func StreetActivity_PlayerEligible(player: wref<PlayerPuppet>) -> Bool {
  if !IsDefined(player) || player.IsDead() || IsEntityInInteriorArea(player)
    || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat") {
    return false;
  }
  let safeArea = GameInstance.GetSafeAreaManager(player.GetGame());
  return !IsDefined(safeArea) || !safeArea.IsPointInSafeArea(player.GetWorldPosition());
}

private func StreetActivity_Affiliation(npc: wref<NPCPuppet>) -> gamedataAffiliation {
  if !IsDefined(npc) {
    return gamedataAffiliation.Unknown;
  }
  let record: wref<Character_Record> = npc.GetRecord();
  if !IsDefined(record) || !IsDefined(record.Affiliation()) {
    return gamedataAffiliation.Unknown;
  }
  return record.Affiliation().Type();
}

private func StreetActivity_IsGang(affiliation: gamedataAffiliation) -> Bool {
  return Equals(affiliation, gamedataAffiliation.Animals)
    || Equals(affiliation, gamedataAffiliation.Maelstrom)
    || Equals(affiliation, gamedataAffiliation.MaelstromAndroid)
    || Equals(affiliation, gamedataAffiliation.TygerClaws)
    || Equals(affiliation, gamedataAffiliation.Valentinos)
    || Equals(affiliation, gamedataAffiliation.SixthStreet)
    || Equals(affiliation, gamedataAffiliation.SixthStreetAndroid)
    || Equals(affiliation, gamedataAffiliation.TheMox)
    || Equals(affiliation, gamedataAffiliation.VoodooBoys)
    || Equals(affiliation, gamedataAffiliation.Scavengers)
    || Equals(affiliation, gamedataAffiliation.ScavengersAndroid)
    || Equals(affiliation, gamedataAffiliation.Wraiths)
    || Equals(affiliation, gamedataAffiliation.WraithsAndroid)
    || Equals(affiliation, gamedataAffiliation.crimson_harvest)
    || Equals(affiliation, gamedataAffiliation.highriders);
}

private func StreetActivity_IsAuthority(affiliation: gamedataAffiliation) -> Bool {
  return Equals(affiliation, gamedataAffiliation.NCPD)
    || Equals(affiliation, gamedataAffiliation.Militech)
    || Equals(affiliation, gamedataAffiliation.Arasaka)
    || Equals(affiliation, gamedataAffiliation.Barghest)
    || Equals(affiliation, gamedataAffiliation.KangTao);
}

private func StreetActivity_IsRivalPair(first: wref<NPCPuppet>, second: wref<NPCPuppet>) -> Bool {
  let firstAffiliation: gamedataAffiliation = StreetActivity_Affiliation(first);
  let secondAffiliation: gamedataAffiliation = StreetActivity_Affiliation(second);
  if Equals(firstAffiliation, gamedataAffiliation.Unknown)
    || Equals(secondAffiliation, gamedataAffiliation.Unknown)
    || Equals(firstAffiliation, secondAffiliation) {
    return false;
  }
  let firstGang: Bool = StreetActivity_IsGang(firstAffiliation);
  let secondGang: Bool = StreetActivity_IsGang(secondAffiliation);
  let firstAuthority: Bool = StreetActivity_IsAuthority(firstAffiliation);
  let secondAuthority: Bool = StreetActivity_IsAuthority(secondAffiliation);
  if firstGang && secondGang {
    return true;
  }
  // Authority intervention is intentionally rare, but uses actors already in
  // the world rather than creating a separate police wave.
  if (firstAuthority && secondGang) || (secondAuthority && firstGang) {
    return RandF() <= 0.15;
  }
  return false;
}

private func StreetActivity_IsCandidate(npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) || !npc.IsActive() || npc.IsDead()
    || ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc)
    || npc.IsCrowd() || npc.IsCharacterCivilian()
    || SDC_IsCompanion(npc)
    || npc.IsCharacterChildren() || npc.IsPlayerCompanion()
    || VehicleComponent.IsMountedToVehicle(npc.GetGame(), npc) {
    return false;
  }
  let affiliation: gamedataAffiliation = StreetActivity_Affiliation(npc);
  if !StreetActivity_IsGang(affiliation) && !StreetActivity_IsAuthority(affiliation) {
    return false;
  }
  let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
  if Equals(state, gamedataNPCHighLevelState.Combat)
    || Equals(state, gamedataNPCHighLevelState.Dead)
    || Equals(state, gamedataNPCHighLevelState.Unconscious) {
    return false;
  }
  return MBAI_ActorAuthoredControlFree(npc);
}

public class StreetActivitySystem extends ScriptableSystem {
  private let m_tickID: DelayID;
  private let m_nextSeedAt: Float;
  private let m_activeUntil: Float;
  private let m_encounterStartedAt: Float;
  private let m_activeEncounter: Bool;
  private let m_escalated: Bool;
  private let m_seedA: EntityID;
  private let m_seedB: EntityID;

  private func OnAttach() -> Void {
    this.m_tickID = GetInvalidDelayID();
    this.m_nextSeedAt = 0.0;
    this.m_activeUntil = 0.0;
    this.m_encounterStartedAt = 0.0;
    this.m_activeEncounter = false;
    this.m_escalated = false;
    this.ScheduleTick(StreetActivity_WarmupSeconds());
  }

  private func OnDetach() -> Void {
    let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if IsDefined(delay) {
      delay.CancelDelay(this.m_tickID);
    }
    this.m_tickID = GetInvalidDelayID();
    this.m_activeEncounter = false;
    this.m_escalated = false;
  }

  private final func ScheduleTick(seconds: Float) -> Void {
    let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(delay) {
      this.m_tickID = GetInvalidDelayID();
      return;
    }
    delay.CancelDelay(this.m_tickID);
    let callback: ref<StreetActivityTickCallback> = new StreetActivityTickCallback();
    callback.game = this.GetGameInstance();
    this.m_tickID = delay.DelayCallback(callback, seconds, false);
  }

  public final func Tick() -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if StreetActivity_PlayerEligible(player) {
      if this.m_activeEncounter && now >= this.m_activeUntil {
        this.m_activeEncounter = false;
        this.m_escalated = false;
        let clearedID: EntityID;
        this.m_seedA = clearedID;
        this.m_seedB = clearedID;
      } else if this.m_activeEncounter && !this.m_escalated && now >= this.m_encounterStartedAt + 60.0 {
        this.EscalateEncounter(now);
      }
      if !this.m_activeEncounter && now >= this.m_nextSeedAt {
        this.TrySeedEncounter(player, now);
      }
    }
    this.ScheduleTick(StreetActivity_TickSeconds());
  }

  private final func TrySeedEncounter(player: ref<PlayerPuppet>, now: Float) -> Void {
    let nearby: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(90.0);
    let count: Int32 = ArraySize(nearby);
    let i: Int32 = 0;
    while i < count {
      let first: ref<NPCPuppet> = nearby[i];
      if StreetActivity_IsCandidate(first) {
        let j: Int32 = i + 1;
        while j < count {
          let second: ref<NPCPuppet> = nearby[j];
          if StreetActivity_IsCandidate(second) {
            let distance: Float = Vector4.Distance(first.GetWorldPosition(), second.GetWorldPosition());
            if distance >= StreetActivity_MinSeedDistance()
            && distance <= StreetActivity_MaxSeedDistance()
            && StreetActivity_IsRivalPair(first, second) {
              this.StartEncounter(first, second, now);
              return;
            }
          }
          j += 1;
        }
      }
      i += 1;
    }
    // Quiet profile: a failed opportunity does not spin every tick; it waits
    // for the next normal pacing window.
    this.m_nextSeedAt = now + StreetActivity_MinCooldownSeconds();
  }

  private final func EscalateEncounter(now: Float) -> Void {
    this.m_escalated = true;
    let first: ref<NPCPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_seedA) as NPCPuppet;
    let second: ref<NPCPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_seedB) as NPCPuppet;
    if IsDefined(first) && StreetActivity_IsCandidate(first) {
      EMRS_RequestEncounterClones(this.GetGameInstance(), this.m_seedA, StreetActivity_EncounterCloneCount());
    }
    if IsDefined(second) && StreetActivity_IsCandidate(second) {
      EMRS_RequestEncounterClones(this.GetGameInstance(), this.m_seedB, StreetActivity_EncounterCloneCount());
    }
    if IsDefined(first) && IsDefined(second) {
      let firstBroadcaster: ref<StimBroadcasterComponent> = first.GetStimBroadcasterComponent();
      let secondBroadcaster: ref<StimBroadcasterComponent> = second.GetStimBroadcasterComponent();
      if IsDefined(firstBroadcaster) {
        firstBroadcaster.SendDrirectStimuliToTarget(first, gamedataStimType.MeleeAttack, second);
      }
      if IsDefined(secondBroadcaster) {
        secondBroadcaster.SendDrirectStimuliToTarget(second, gamedataStimType.MeleeAttack, first);
      }
    }
    this.m_activeUntil = now + StreetActivity_ActiveSeconds();
  }

  private final func StartEncounter(first: ref<NPCPuppet>, second: ref<NPCPuppet>, now: Float) -> Void {
    this.m_seedA = first.GetEntityID();
    this.m_seedB = second.GetEntityID();
    this.m_activeEncounter = true;
    this.m_encounterStartedAt = now;
    this.m_escalated = false;
    this.m_activeUntil = now + StreetActivity_ActiveSeconds();
    this.m_nextSeedAt = now + StreetActivity_MinCooldownSeconds() + RandF() * (StreetActivity_MaxCooldownSeconds() - StreetActivity_MinCooldownSeconds());

    // Let PCF use assigned vehicles when these actors have them, while still
    // falling back to a bounded foot retreat for actors without a vehicle.
    PCFMarkStreetActivityOwned(first);
    PCFMarkStreetActivityOwned(second);

    // Reuse EMRS's single bounded dynamic-entity owner. The original actors
    // remain the fight seed; clones inherit their faction/record and may join
    // the same AI situation after attachment.
    EMRS_RequestEncounterClones(this.GetGameInstance(), this.m_seedA, StreetActivity_EncounterCloneCount());
    EMRS_RequestEncounterClones(this.GetGameInstance(), this.m_seedB, StreetActivity_EncounterCloneCount());

    let firstBroadcaster: ref<StimBroadcasterComponent> = first.GetStimBroadcasterComponent();
    let secondBroadcaster: ref<StimBroadcasterComponent> = second.GetStimBroadcasterComponent();
    if IsDefined(firstBroadcaster) {
      firstBroadcaster.SendDrirectStimuliToTarget(first, gamedataStimType.MeleeAttack, second);
    }
    if IsDefined(secondBroadcaster) {
      secondBroadcaster.SendDrirectStimuliToTarget(second, gamedataStimType.MeleeAttack, first);
    }
  }
}

public class StreetActivityTickCallback extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let system: ref<StreetActivitySystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"StreetActivity.StreetActivitySystem") as StreetActivitySystem;
    if IsDefined(system) {
      system.Tick();
    }
  }
}
