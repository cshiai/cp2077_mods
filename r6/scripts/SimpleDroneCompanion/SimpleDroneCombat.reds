// Narrow combat integration for SimpleDroneCompanion.
// Every hook is marker-gated before it can alter engine behavior.  Ordinary
// NPCs, player weapons, Cazanu, EMRS clones, and other companions continue
// through their vanilla/MBAI paths unchanged.

module SimpleDroneCompanion

private func SDC_EnemyEngaged(owner: wref<ScriptedPuppet>, target: wref<GameObject>) -> Bool {
  if !IsDefined(owner) || !IsDefined(target) || SDC_IsCompanion(owner) {
    return false;
  };
  let player: ref<PlayerPuppet> = GetPlayer(owner.GetGame());
  if owner.IsHostile() || (IsDefined(player) && Equals(owner.GetAttitudeTowards(player), EAIAttitude.AIA_Hostile)) {
    return true;
  };
  let state: gamedataNPCHighLevelState = owner.GetHighLevelStateFromBlackboard();
  return Equals(state, gamedataNPCHighLevelState.Combat)
    || Equals(state, gamedataNPCHighLevelState.Alerted);
}

private func SDC_IsIgnoredDamage(hitEvent: ref<gameHitEvent>) -> Bool {
  return IsDefined(hitEvent)
    && IsDefined(hitEvent.attackData)
    && (hitEvent.attackData.HasFlag(hitFlag.DealNoDamage)
      || hitEvent.attackData.HasFlag(hitFlag.FriendlyFireIgnored));
}

@wrapMethod(GameObject)
public final func FindAndRewardKiller(killType: gameKillType, opt instigator: wref<GameObject>) -> Void {
  // Drone kills remain ordinary vanilla kills, but V owns the reward/credit.
  // This also rewrites the received-damage history so later assist/loot code
  // cannot retain a stale dynamic-entity owner.
  if SDC_IsCompanion(instigator) {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());
    if IsDefined(player) {
      let i: Int32 = 0;
      while i < ArraySize(this.m_receivedDamageHistory) {
        if SDC_IsCompanion(this.m_receivedDamageHistory[i].source) {
          this.m_receivedDamageHistory[i].source = player;
        };
        i += 1;
      };
      instigator = player;
    };
  };
  wrappedMethod(killType, instigator);
}

@wrapMethod(DamageSystem)
private final func Process(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
  if !IsDefined(hitEvent) || !IsDefined(hitEvent.attackData) || !IsDefined(hitEvent.target) {
    wrappedMethod(hitEvent, cache);
    return;
  };
  let instigator: wref<ScriptedPuppet> = hitEvent.attackData.GetInstigator() as ScriptedPuppet;
  let target: wref<ScriptedPuppet> = hitEvent.target as ScriptedPuppet;
  if IsDefined(instigator) && IsDefined(target) {
    let instDrone: Bool = SDC_IsCompanion(instigator);
    let targetDrone: Bool = SDC_IsCompanion(target);
    let ignored: Bool = SDC_IsIgnoredDamage(hitEvent);

    // Drones may hurt enemies and enemies may hurt drones.  They never hurt V
    // or one another, while V may still damage/dismiss a drone normally.
    if instDrone && (target.IsPlayer() || targetDrone) && !ignored {
      return;
    };

    // A marked drone's first hit is enough to make that enemy's own tracker
    // consider the drone; no periodic target scan is needed.
    if instDrone && !target.IsPlayer() && !targetDrone && !ignored && !SDC_IsDeadLike(target) {
      TargetTrackingExtension.InjectThreat(target, instigator);
    };

    // A hostile hit on V is an event-driven attention handoff, not a global
    // scan.  The bounded system owns at most two destination drones.
    if target.IsPlayer() && !instDrone && !targetDrone && !ignored && instigator.IsHostile() {
      let system: ref<SDC_System> = SDC_System.Get(target.GetGame());
      if IsDefined(system) {
        system.InjectThreat(instigator);
      };
    };
  };
  wrappedMethod(hitEvent, cache);
  if IsDefined(target) && SDC_IsCompanion(target) && !SDC_IsIgnoredDamage(hitEvent) {
    let system: ref<SDC_System> = SDC_System.Get(target.GetGame());
    if IsDefined(system) {
      system.RefreshHud();
    };
  };
}

@wrapMethod(ReactionManagerComponent)
protected cb func OnDetectedEvent(evt: ref<OnDetectedEvent>) -> Bool {
  if IsDefined(evt) && IsDefined(evt.target) && evt.isVisible && SDC_IsCompanion(evt.target) {
    let owner: wref<ScriptedPuppet> = this.GetOwnerPuppet();
    if SDC_EnemyEngaged(owner, evt.target) {
      TargetTrackingExtension.InjectThreat(owner, evt.target);
    };
  };
  return wrappedMethod(evt);
}

@wrapMethod(SenseComponent)
public final static func ShouldIgnoreIfPlayerCompanion(owner: wref<Entity>, target: wref<Entity>) -> Bool {
  let targetObject: wref<GameObject> = target as GameObject;
  let ownerPuppet: wref<ScriptedPuppet> = owner as ScriptedPuppet;
  if SDC_IsCompanion(targetObject) && IsDefined(ownerPuppet) && ownerPuppet.IsHostile() {
    return false;
  };
  return wrappedMethod(owner, target);
}

@wrapMethod(AIActionHelper)
public final static func TryChangingAttitudeToHostile(owner: ref<ScriptedPuppet>, target: ref<GameObject>) -> Bool {
  // A follower must not flip its attitude toward V because of an explosion,
  // ricochet, or an AI target handoff.  This guard is marker-only.
  if SDC_IsCompanion(owner) && IsDefined(target) && target.IsPlayer() {
    return false;
  };
  return wrappedMethod(owner, target);
}

