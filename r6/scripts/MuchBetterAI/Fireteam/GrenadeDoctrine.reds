module MuchBetterAI.Fireteam

import MuchBetterAI.Logging.*

public enum MBAI_GrenadeKind {
  None = 0,
  Frag = 1,
  Flash = 2,
  EMP = 3,
  Biohazard = 4,
  Incendiary = 5,
  Mixed = 6
}

@addField(NPCPuppet)
let m_mbaiGrenadeDoctrineKind: CName;

@addField(NPCPuppet)
let m_mbaiGrenadeDoctrineUntil: Float;

public static func MBAI_GrenadeKindFor(npc: wref<NPCPuppet>) -> MBAI_GrenadeKind {
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseSmokeGrenades")) || AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseCuttingGrenades")) || AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseReconGrenades")) {
    return MBAI_GrenadeKind.Mixed;
  };
  let count: Int32 = 0;
  let kind: MBAI_GrenadeKind = MBAI_GrenadeKind.None;
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseFragGrenades")) {
    count += 1;
    kind = MBAI_GrenadeKind.Frag;
  };
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseFlashbangGrenades")) {
    count += 1;
    kind = MBAI_GrenadeKind.Flash;
  };
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseEMPGrenades")) {
    count += 1;
    kind = MBAI_GrenadeKind.EMP;
  };
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseBiohazardGrenades")) {
    count += 1;
    kind = MBAI_GrenadeKind.Biohazard;
  };
  if AIActionHelper.CheckAbility(npc, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanUseIncendiaryGrenades")) {
    count += 1;
    kind = MBAI_GrenadeKind.Incendiary;
  };
  return count == 1 ? kind : (count > 1 ? MBAI_GrenadeKind.Mixed : MBAI_GrenadeKind.None);
}

public static func MBAI_GrenadeScore(kind: MBAI_GrenadeKind, entrenched: Bool, group: MBAI_DoctrineGroup) -> Float {
  if !entrenched || !MBAI_DoctrineReactive(group) {
    return -1.0;
  };
  switch kind {
    case MBAI_GrenadeKind.Incendiary:
    case MBAI_GrenadeKind.Biohazard:
      return 3.0 * MBAI_DoctrineGrenadeWillingness(group);
    case MBAI_GrenadeKind.Frag:
      return 2.5 * MBAI_DoctrineGrenadeWillingness(group);
    case MBAI_GrenadeKind.Flash:
    case MBAI_GrenadeKind.EMP:
      return 2.0 * MBAI_DoctrineGrenadeWillingness(group);
  };
  return -1.0;
}

public static func MBAI_GrenadeKindName(kind: MBAI_GrenadeKind) -> CName {
  switch kind {
    case MBAI_GrenadeKind.Frag:
      return n"Frag";
    case MBAI_GrenadeKind.Flash:
      return n"Flash";
    case MBAI_GrenadeKind.EMP:
      return n"EMP";
    case MBAI_GrenadeKind.Biohazard:
      return n"Biohazard";
    case MBAI_GrenadeKind.Incendiary:
      return n"Incendiary";
    case MBAI_GrenadeKind.Mixed:
      return n"Mixed";
  };
  return n"None";
}

@wrapMethod(NPCPuppet)
protected cb func OnNPCStartThrowingGrenadeEvent(evt: ref<NPCThrowingGrenadeEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());
  if IsDefined(player) && IsDefined(evt) && IsDefined(evt.target) && Equals(evt.target.GetEntityID(), player.GetEntityID()) && IsNameValid(this.m_mbaiGrenadeDoctrineKind) && now <= this.m_mbaiGrenadeDoctrineUntil {
    MBAInfo("Fireteam", "grenade throw-start receipt npc=" + ToString(this.GetEntityID()) + " planned=" + NameToString(this.m_mbaiGrenadeDoctrineKind));
    this.m_mbaiGrenadeDoctrineKind = n"";
    this.m_mbaiGrenadeDoctrineUntil = 0.0;
  };
  return result;
}
