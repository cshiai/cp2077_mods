module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*
import MuchBetterAI.Squad.*

@addField(NPCPuppet)
let m_mbaiStealthHitUntil: Float;

@addField(NPCPuppet)
let m_mbaiStealthHitInstigator: EntityID;

@addField(NPCPuppet)
let m_mbaiIncidentAnchor: Vector4;

@addField(NPCPuppet)
let m_mbaiIncidentAnchorUntil: Float;

@addField(NPCPuppet)
let m_mbaiAcousticAnchorPriorityUntil: Float;

public func MBAI_Search_SetIncidentAnchor(npc: ref<NPCPuppet>, pos: Vector4, until: Float, acousticEvidence: Bool) -> Void {
  if !IsDefined(npc) {
    return;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  if acousticEvidence || npc.m_mbaiAcousticAnchorPriorityUntil <= now {
    npc.m_mbaiIncidentAnchor = pos;
    npc.m_mbaiIncidentAnchorUntil = until;
  };
  if acousticEvidence {
    npc.m_mbaiAcousticAnchorPriorityUntil = now + 1.5;
  };
}

public func MBAI_Search_GetIncidentAnchor(npc: ref<NPCPuppet>, fallback: Vector4, now: Float) -> Vector4 {
  if IsDefined(npc) && npc.m_mbaiIncidentAnchorUntil > now {
    return npc.m_mbaiIncidentAnchor;
  };
  return fallback;
}

public func MBAI_StealthHit_CanIntercept(npc: ref<NPCPuppet>, evt: ref<gameHitEvent>, instigator: ref<PlayerPuppet>, weapon: ref<WeaponObject>) -> Bool {
  if !IsDefined(npc) || !IsDefined(evt) || !IsDefined(evt.attackData) || !IsDefined(instigator) {
    return false;
  };
  if !MBAI_ActorMovementEligible(npc) || !npc.IsAggressive() {
    return false;
  };
  let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
  if !Equals(state, gamedataNPCHighLevelState.Relaxed) && !Equals(state, gamedataNPCHighLevelState.Alerted) {
    return false;
  };
  if AttackData.IsDoT(evt.attackData) {
    return false;
  };
  if evt.attackData.HasFlag(hitFlag.WasKillingBlow) || evt.attackData.HasFlag(hitFlag.QuickHack) || evt.attackData.HasFlag(hitFlag.DealNoDamage) || !evt.attackData.HasFlag(hitFlag.SilentKillModifier) {
    return false;
  };
  if !IsDefined(weapon) {
    return false;
  };
  let attackType: gamedataAttackType = evt.attackData.GetAttackType();
  if AttackData.IsMelee(attackType) || AttackData.IsStrongMelee(attackType) {
    return false;
  };
  if instigator.GetTakeOverControlSystem().IsDeviceControlled() {
    return false;
  };
  let source: wref<GameObject> = evt.attackData.GetSource();
  if IsDefined(source as Device) || IsDefined(source as VehicleObject) {
    return false;
  };
  return true;
}

public func MBAI_StealthHit_AlertGroup(victim: ref<NPCPuppet>, incidentPos: Vector4, now: Float) -> Int32 {
  let anchorDuration: Float = 30.0;
  let anchorUntil: Float = now + anchorDuration;
  let alerted: Int32 = 0;

  if NotEquals(victim.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Alerted) {
    NPCPuppet.ChangeHighLevelState(victim, gamedataNPCHighLevelState.Alerted);
    alerted += 1;
  };
  MBAI_Search_SetIncidentAnchor(victim, incidentPos, anchorUntil, false);
  MBAI_RaiseAlert(victim, anchorDuration);

  let peers: array<ref<NPCPuppet>> = victim.GetNPCsAroundObject(40.0);
  let i: Int32 = 0;
  while i < ArraySize(peers) {
    let peer: ref<NPCPuppet> = peers[i];
    if MBAI_ActorMovementEligible(peer) && peer.IsAggressive() && peer.GetEntityID() != victim.GetEntityID() && MBAI_SameCombatGroup(victim, peer) && NotEquals(peer.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Combat) {
      if NotEquals(peer.GetHighLevelStateFromBlackboard(), gamedataNPCHighLevelState.Alerted) {
        NPCPuppet.ChangeHighLevelState(peer, gamedataNPCHighLevelState.Alerted);
        alerted += 1;
      };
      MBAI_Search_SetIncidentAnchor(peer, incidentPos, anchorUntil, false);
      MBAI_RaiseAlert(peer, anchorDuration);
    };
    i += 1;
  };
  return alerted;
}

@wrapMethod(ScriptedPuppet)
public final func PuppetDamagePipelineFinalized(evt: ref<gameHitEvent>) -> Void {
  let npc: ref<NPCPuppet> = this as NPCPuppet;
  let instigator: ref<PlayerPuppet> = IsDefined(evt) && IsDefined(evt.attackData) ? evt.attackData.GetInstigator() as PlayerPuppet : null;
  let weapon: ref<WeaponObject> = IsDefined(evt) && IsDefined(evt.attackData) ? evt.attackData.GetWeapon() : null;
  if !MBAI_StealthHit_CanIntercept(npc, evt, instigator, weapon) {
    wrappedMethod(evt);
    return;
  };

  let gi: GameInstance = this.GetGame();
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  let repeated: Bool = npc.m_mbaiStealthHitUntil > now && npc.m_mbaiStealthHitInstigator == instigator.GetEntityID();
  let triggerMode: gamedataTriggerMode = weapon.GetCurrentTriggerMode().Type();
  let automatic: Bool = Equals(triggerMode, gamedataTriggerMode.Burst) || Equals(triggerMode, gamedataTriggerMode.FullAuto);
  let sense: ref<SenseComponent> = npc.GetSensesComponent();
  let visible: Bool = IsDefined(sense) && sense.IsAgentVisible(instigator);
  let fullyDetected: Bool = npc.GetDetectionPercentage() >= 100.0;

  if repeated {
    npc.m_mbaiStealthHitUntil = 0.0;
    if this.ResolveHitIstigatorCooldown(instigator.GetEntityID()) && ScriptedPuppet.IsAlive(this) {
      GameObject.PlayVoiceOver(this, n"vo_any_damage_hit", n"Scripts:OnHit");
    };
    TargetTrackingExtension.OnHit(this, evt);
    MBAInfo("StealthHit", s"repeat hit escalated npc=\(ToString(npc.GetEntityID()))");
    return;
  };

  if automatic || visible || fullyDetected {
    npc.m_mbaiStealthHitUntil = 0.0;
    wrappedMethod(evt);
    return;
  };

  if this.ResolveHitIstigatorCooldown(instigator.GetEntityID()) && ScriptedPuppet.IsAlive(this) {
    GameObject.PlayVoiceOver(this, n"vo_any_damage_hit", n"Scripts:OnHit");
  };
  npc.m_mbaiStealthHitInstigator = instigator.GetEntityID();
  npc.m_mbaiStealthHitUntil = now + 2.0;
  let alerted: Int32 = MBAI_StealthHit_AlertGroup(npc, npc.GetWorldPosition(), now);
  MBAInfo("StealthHit", s"uncertain hit npc=\(ToString(npc.GetEntityID())) groupAlerted=\(alerted)");
}
