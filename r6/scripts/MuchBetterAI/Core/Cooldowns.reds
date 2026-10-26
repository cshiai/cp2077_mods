module MuchBetterAI.Core

import MuchBetterAI.Logging.*

@addField(NPCPuppet)
let m_mbaiOrderOwner: CName;

@addField(NPCPuppet)
let m_mbaiOrderExpiry: Float;

@addField(NPCPuppet)
let m_mbaiLeaseGeneration: Int32;

@addField(NPCPuppet)
let m_mbaiLeaseReacquireAfter: Float;

@addField(NPCPuppet)
let m_mbaiRoleTag: CName;

@addField(NPCPuppet)
let m_mbaiPersonalityTag: CName;

@addField(NPCPuppet)
let m_mbaiTemperamentSet: Bool;

@addField(NPCPuppet)
let m_mbaiTemperamentScale: Int32;

@addField(NPCPuppet)
let m_mbaiAuthoredTemperaments: array<TweakDBID>;

@addField(NPCPuppet)
let m_mbaiAppliedTemperament: TweakDBID;

@addField(NPCPuppet)
let m_mbaiTemperamentOwned: Bool;

@addField(NPCPuppet)
let m_mbaiLastBarkSim: Float;

@addField(NPCPuppet)
let m_mbaiCombatIntent: CName;

@addField(NPCPuppet)
let m_mbaiCombatIntentSource: CName;

@addField(NPCPuppet)
let m_mbaiCombatIntentUntil: Float;

public static func MBAI_TryBark(npc: ref<NPCPuppet>, voName: CName, ctx: CName, now: Float, minInterval: Float) -> Bool {
  if !IsDefined(npc) || npc.IsDead() {
    return false;
  };
  if now - npc.m_mbaiLastBarkSim < minInterval {
    return false;
  };
  npc.m_mbaiLastBarkSim = now;
  GameObject.PlayVoiceOver(npc, voName, ctx);
  return true;
}

public static func MBAI_ClaimExecutionLease(npc: ref<NPCPuppet>, owner: CName, duration: Float, now: Float) -> Int32 {
  if !IsDefined(npc) {
    return 0;
  };
  npc.m_mbaiLeaseGeneration += 1;
  if npc.m_mbaiLeaseGeneration <= 0 {
    npc.m_mbaiLeaseGeneration = 1;
  };
  npc.m_mbaiOrderOwner = owner;
  npc.m_mbaiOrderExpiry = now + MaxF(duration, 0.1);
  MBATrace("Lease", s"claim npc=\(ToString(npc.GetEntityID())) owner=\(ToString(owner)) token=\(npc.m_mbaiLeaseGeneration) until=\(npc.m_mbaiOrderExpiry)");
  return npc.m_mbaiLeaseGeneration;
}

public static func MBAI_ExecutionLeaseMatches(npc: wref<NPCPuppet>, owner: CName, token: Int32) -> Bool {
  return IsDefined(npc) && token > 0 && Equals(npc.m_mbaiOrderOwner, owner) && npc.m_mbaiLeaseGeneration == token;
}

public static func MBAI_ReleaseExecutionLease(npc: ref<NPCPuppet>, owner: CName, token: Int32, now: Float, reacquireDelay: Float) -> Bool {
  if !MBAI_ExecutionLeaseMatches(npc, owner, token) {
    if IsDefined(npc) {
      MBATrace("Lease", s"stale release rejected npc=\(ToString(npc.GetEntityID())) owner=\(ToString(owner)) token=\(token) activeOwner=\(ToString(npc.m_mbaiOrderOwner)) activeToken=\(npc.m_mbaiLeaseGeneration)");
    };
    return false;
  };
  npc.m_mbaiOrderOwner = n"";
  npc.m_mbaiOrderExpiry = 0.0;
  npc.m_mbaiLeaseReacquireAfter = MaxF(npc.m_mbaiLeaseReacquireAfter, now + MaxF(reacquireDelay, 0.0));
  MBATrace("Lease", s"release npc=\(ToString(npc.GetEntityID())) owner=\(ToString(owner)) token=\(token) guard=\(npc.m_mbaiLeaseReacquireAfter)");
  return true;
}

public static func MBAI_CanClaimExecutionLease(npc: wref<NPCPuppet>, owner: CName, now: Float) -> Bool {
  if !IsDefined(npc) || now < npc.m_mbaiLeaseReacquireAfter {
    return false;
  };
  return now >= npc.m_mbaiOrderExpiry || Equals(npc.m_mbaiOrderOwner, n"") || Equals(npc.m_mbaiOrderOwner, owner);
}

public static func MBAI_FiredRecently(npc: ref<NPCPuppet>, now: Float) -> Bool {
  if !IsDefined(npc) {
    return false;
  };
  return npc.m_mbaiLastShotAtPlayerSim > 0.0 && (now - npc.m_mbaiLastShotAtPlayerSim < 3.0);
}

public static func MBAI_IsOrderAvailable(npc: ref<NPCPuppet>, systemName: CName, now: Float) -> Bool {
  if !IsDefined(npc) {
    return false;
  };
  if MBAI_FiredRecently(npc, now) {
    return false;
  };
  return MBAI_CanClaimExecutionLease(npc, systemName, now);
}

public static func MBAI_SetIntent(npc: ref<NPCPuppet>, intent: CName, source: CName, duration: Float, now: Float) -> Void {
  if !IsDefined(npc) {
    return;
  };
  npc.m_mbaiCombatIntent = intent;
  npc.m_mbaiCombatIntentSource = source;
  npc.m_mbaiCombatIntentUntil = now + MaxF(duration, 0.1);
}

public static func MBAI_ClearIntent(npc: ref<NPCPuppet>, source: CName) -> Void {
  if !IsDefined(npc) {
    return;
  };
  if Equals(source, n"") || Equals(npc.m_mbaiCombatIntentSource, source) {
    npc.m_mbaiCombatIntent = n"";
    npc.m_mbaiCombatIntentSource = n"";
    npc.m_mbaiCombatIntentUntil = 0.0;
  };
}

public static func MBAI_GetIntent(npc: wref<NPCPuppet>, now: Float) -> CName {
  if !IsDefined(npc) || now >= npc.m_mbaiCombatIntentUntil {
    return n"";
  };
  return npc.m_mbaiCombatIntent;
}

public static func MBAI_GetIntentSource(npc: wref<NPCPuppet>, now: Float) -> CName {
  if !IsDefined(npc) || now >= npc.m_mbaiCombatIntentUntil {
    return n"";
  };
  return npc.m_mbaiCombatIntentSource;
}

public static func MBAI_IntentIsManeuver(intent: CName) -> Bool {
  if Equals(intent, n"FireteamFlank") || Equals(intent, n"FireteamRush") {
    return true;
  };
  if Equals(intent, n"FireteamBoundAdvance") || Equals(intent, n"NervePanic") || Equals(intent, n"NerveReposition") || Equals(intent, n"NerveFallback") {
    return true;
  };
  if Equals(intent, n"NetrunnerReposition") || Equals(intent, n"Search") || Equals(intent, n"SearchHunter") {
    return true;
  };
  if Equals(intent, n"SearchFan") || Equals(intent, n"SearchLKP") || Equals(intent, n"TakedownHeard") || Equals(intent, n"PunishPush") || Equals(intent, n"CoverBail") {
    return true;
  };
  if Equals(intent, n"CounterPerchDeny") || Equals(intent, n"CounterPerchCordon") {
    return true;
  };
  if Equals(intent, n"FootworkReposition") {
    return true;
  };
  return false;
}

public static func MBAI_IntentBlocksCommand(npc: wref<NPCPuppet>, requester: CName, now: Float) -> Bool {
  if IsDefined(npc) && StatusEffectSystem.ObjectHasStatusEffect(npc, t"AIQuickHackStatusEffect.Hacking") {
    return true;
  };
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"NetrunnerCast") {
    return true;
  };
  if Equals(intent, n"") || Equals(MBAI_GetIntentSource(npc, now), requester) {
    return false;
  };
  return MBAI_IntentIsManeuver(intent);
}

public static func MBAI_IntentShotQuality(npc: wref<NPCPuppet>, now: Float) -> Float {
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"FireteamAnchor") || Equals(intent, n"FireteamBoundHold") {
    return 1.05;
  };
  if Equals(intent, n"FireteamSuppress") {
    return 0.90;
  };
  if Equals(intent, n"NetrunnerCast") {
    return 0.78;
  };
  if Equals(intent, n"NervePanic") {
    return 0.68;
  };
  if Equals(intent, n"NerveFallback") || Equals(intent, n"NerveReposition") {
    return 0.76;
  };
  if Equals(intent, n"FireteamFlank") || Equals(intent, n"FireteamRush") || Equals(intent, n"FireteamBoundAdvance") {
    return 0.84;
  };
  if Equals(intent, n"NetrunnerReposition") || Equals(intent, n"Search") || Equals(intent, n"SearchHunter") || Equals(intent, n"SearchFan") || Equals(intent, n"SearchLKP") {
    return 0.80;
  };
  if Equals(intent, n"CounterPerchDeny") || Equals(intent, n"CounterPerchCordon") {
    return 0.80;
  };
  return 1.0;
}

public static func MBAI_IntentFirstShotWindup(npc: wref<NPCPuppet>, now: Float) -> Float {
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"FireteamAnchor") || Equals(intent, n"FireteamBoundHold") {
    return 0.94;
  };
  if Equals(intent, n"FireteamSuppress") {
    return 1.04;
  };
  if Equals(intent, n"NervePanic") {
    return 1.25;
  };
  if MBAI_IntentIsManeuver(intent) || Equals(intent, n"NetrunnerCast") {
    return 1.14;
  };
  return 1.0;
}

public static func MBAI_IntentSpacingMul(npc: wref<NPCPuppet>, now: Float) -> Float {
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"FireteamAnchor") || Equals(intent, n"FireteamBoundHold") {
    return 0.88;
  };
  if Equals(intent, n"NerveFallback") || Equals(intent, n"Search") || Equals(intent, n"SearchHunter") || Equals(intent, n"SearchFan") || Equals(intent, n"SearchLKP") {
    return 1.18;
  };
  if MBAI_IntentIsManeuver(intent) {
    return 0.92;
  };
  return 1.0;
}

public static func MBAI_IntentTrackingMul(npc: wref<NPCPuppet>, now: Float) -> Float {
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"FireteamAnchor") || Equals(intent, n"FireteamBoundHold") {
    return 1.08;
  };
  if Equals(intent, n"NervePanic") || Equals(intent, n"NetrunnerCast") {
    return 0.82;
  };
  if MBAI_IntentIsManeuver(intent) {
    return 0.90;
  };
  return 1.0;
}

public static func MBAI_IntentNetrunnerCadenceMul(npc: wref<NPCPuppet>, now: Float) -> Float {
  let intent: CName = MBAI_GetIntent(npc, now);
  if Equals(intent, n"NetrunnerCast") {
    return 0.94;
  };
  if Equals(intent, n"NetrunnerReposition") {
    return 1.20;
  };
  if Equals(intent, n"NervePanic") || Equals(intent, n"NerveFallback") || Equals(intent, n"NerveReposition") {
    return 1.35;
  };
  return 1.0;
}

public static func MBAI_ClampTemperamentScale(scale: Int32) -> Int32 {
  if scale < 0 {
    return 0;
  };
  if scale > 4 {
    return 4;
  };
  return scale;
}

public static func MBAI_GetTemperamentScale(npc: wref<NPCPuppet>) -> Int32 {
  if !IsDefined(npc) || !npc.m_mbaiTemperamentSet {
    return 2;
  };
  return MBAI_ClampTemperamentScale(npc.m_mbaiTemperamentScale);
}

public static func MBAI_TemperamentAbility(scale: Int32) -> TweakDBID {
  switch MBAI_ClampTemperamentScale(scale) {
    case 0: return t"Ability.IsCautious";
    case 1: return t"Ability.IsDefensive";
    case 2: return t"Ability.IsBalanced";
    case 3: return t"Ability.IsAggressive";
    default: return t"Ability.IsReckless";
  };
}

public static func MBAI_TemperamentName(scale: Int32) -> String {
  switch MBAI_ClampTemperamentScale(scale) {
    case 0: return "Cautious";
    case 1: return "Defensive";
    case 2: return "Balanced";
    case 3: return "Aggressive";
    default: return "Reckless";
  };
}

public static func MBAI_TemperamentCommandPressure(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 0.65;
    case 1: return 0.85;
    case 2: return 1.00;
    case 3: return 0.92;
    default: return 0.78;
  };
}

public static func MBAI_TemperamentShotDiscipline(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 0.94;
    case 1: return 1.04;
    case 2: return 1.00;
    case 3: return 0.97;
    default: return 0.91;
  };
}

public static func MBAI_TemperamentNerveThresholdMul(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 1.18;
    case 1: return 1.08;
    case 2: return 1.00;
    case 3: return 0.92;
    default: return 0.82;
  };
}

public static func MBAI_TemperamentPunishDelayMul(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 1.35;
    case 1: return 1.15;
    case 2: return 1.00;
    case 3: return 0.85;
    default: return 0.70;
  };
}

public static func MBAI_TemperamentNetrunnerCadenceMul(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 1.15;
    case 1: return 1.08;
    case 2: return 1.00;
    case 3: return 0.94;
    default: return 0.88;
  };
}

public static func MBAI_TemperamentNetrunnerRepositionMul(npc: wref<NPCPuppet>) -> Float {
  switch MBAI_GetTemperamentScale(npc) {
    case 0: return 1.25;
    case 1: return 1.15;
    case 2: return 1.00;
    case 3: return 0.90;
    default: return 0.75;
  };
}
