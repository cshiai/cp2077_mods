module MuchBetterAI.Netrunner

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Squad.*

public enum MBAI_NetProfile {
  Apex = 0,
  IceWarden = 1,
  Corpo = 2,
  ChromeButcher = 3,
  BladeSupport = 4,
  ScavRig = 5,
  Baseline = 6
}

public class MBAI_NetrunnerAttempt {
  public let leaned: Bool;
  public let pick: TweakDBID;
  public let targetName: String;
  public let nativeName: String;
  public let profile: MBAI_NetProfile;
  public let cap: Int32;
  public let now: Float;
}

@addField(NPCPuppet)
let m_mbaiLastHack: Float;

@addField(NPCPuppet)
let m_mbaiHackCD: array<Float>;

@addField(NPCPuppet)
let m_mbaiNetrunnerAttempt: ref<MBAI_NetrunnerAttempt>;

@wrapMethod(AISubActionQuickHack_Record_Implementation)
public final static func Activate(context: ScriptExecutionContext, record: wref<AISubActionQuickHack_Record>) -> Void {
  let nrn: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !MBAI_EnemyEligible(nrn) {
    wrappedMethod(context, record);
    return;
  };
  nrn.m_mbaiNetrunnerAttempt = null;
  MBAI_NetrunnerEnsureCD(nrn);
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(nrn.GetGame()));
  let mult: Float = 0.85;
  let prof: MBAI_NetProfile = MBAI_NetrunnerProfile(MBAI_GetAffiliation(nrn));
  let cap: Int32 = MBAI_NetrunnerTierCap(nrn.GetNPCRarity());
  let nativeName: String = TDBID.ToStringDEBUG(record.ActionResult().GetRecordID());
  if StrContains(nativeName, "Reveal") {
    wrappedMethod(context, record);
    return;
  };
  let isUltimate: Bool = StrContains(nativeName, "Ultimate");
  let leaned: Bool = false;
  let pick: TweakDBID;
  if isUltimate {
    if cap < 3 || !MBAI_NetrunnerUltimateGateMet(nrn) {
      pick = MBAI_NetrunnerCapHack(cap);
      leaned = true;
      MBAInfo("Netrunner", s"cap-downgrade by=\(TDBID.ToStringDEBUG(nrn.GetRecordID())) prof=\(MBAI_NetProfileName(prof)) from=Ultimate to=\(TDBID.ToStringDEBUG(pick)) cap=\(cap) rarity=\(ToString(nrn.GetNPCRarity()))");
    };
  } else {
    leaned = MBAI_NetrunnerPickHack(nrn, prof, pick);
    if leaned && MBAI_NetrunnerHackStrength(TDBID.ToStringDEBUG(pick)) > cap {
      MBAInfo("Netrunner", s"cap-downgrade by=\(TDBID.ToStringDEBUG(nrn.GetRecordID())) prof=\(MBAI_NetProfileName(prof)) from=\(TDBID.ToStringDEBUG(pick)) strength=\(MBAI_NetrunnerHackStrength(TDBID.ToStringDEBUG(pick))) cap=\(cap)");
      pick = MBAI_NetrunnerCapHack(cap);
    };
  };
  let targetName: String = leaned ? TDBID.ToStringDEBUG(pick) : nativeName;
  let globalReady: Bool = MBAI_NetrunnerGlobalReady(nrn, prof, mult, now);
  let hackReady: Bool = MBAI_NetrunnerHackReady(nrn, prof, targetName, mult, now);
  if !globalReady || !hackReady {
    let reason: String = !globalReady ? "global" : "per-hack";
    ScriptedPuppet.SendActionSignal(nrn, n"HackingCompleted", 1.0);
    MBAInfo("Netrunner", s"throttled by=\(TDBID.ToStringDEBUG(nrn.GetRecordID())) prof=\(MBAI_NetProfileName(prof)) reason=\(reason) held=\(targetName)");
    return;
  };
  let attempt: ref<MBAI_NetrunnerAttempt> = new MBAI_NetrunnerAttempt();
  attempt.leaned = leaned;
  attempt.pick = pick;
  attempt.targetName = targetName;
  attempt.nativeName = nativeName;
  attempt.profile = prof;
  attempt.cap = cap;
  attempt.now = now;
  nrn.m_mbaiNetrunnerAttempt = attempt;
  wrappedMethod(context, record);
  nrn.m_mbaiNetrunnerAttempt = null;
}

@wrapMethod(AISubActionQuickHack_Record_Implementation)
public final static func Hack(context: ScriptExecutionContext, record: wref<AISubActionQuickHack_Record>) -> Void {
  let nrn: ref<NPCPuppet> = ScriptExecutionContext.GetOwner(context) as NPCPuppet;
  if !MBAI_EnemyEligible(nrn) {
    wrappedMethod(context, record);
    return;
  };
  let attempt: ref<MBAI_NetrunnerAttempt> = nrn.m_mbaiNetrunnerAttempt;
  nrn.m_mbaiNetrunnerAttempt = null;
  if !IsDefined(attempt) {
    wrappedMethod(context, record);
    return;
  };
  if attempt.leaned {
    if MBAI_NetrunnerCast(context, nrn, record, attempt.pick) {
      MBAI_NetrunnerStamp(nrn, attempt.targetName, attempt.now);
      MBAI_SetIntent(nrn, n"NetrunnerCast", n"Netrunner", 4.0, attempt.now);
      MBAInfo("Netrunner", s"steer by=\(TDBID.ToStringDEBUG(nrn.GetRecordID())) prof=\(MBAI_NetProfileName(attempt.profile)) cap=\(attempt.cap) \(attempt.nativeName) -> \(attempt.targetName)");
      return;
    };
  };
  let nativeTarget: wref<GameObject>;
  let nativeDispatched: Bool = AIActionTarget.GetObject(context, record.Target(), nativeTarget);
  wrappedMethod(context, record);
  if nativeDispatched {
    MBAI_NetrunnerStamp(nrn, attempt.nativeName, attempt.now);
    MBAI_SetIntent(nrn, n"NetrunnerCast", n"Netrunner", 4.0, attempt.now);
    MBAInfo("Netrunner", s"cast by=\(TDBID.ToStringDEBUG(nrn.GetRecordID())) prof=\(MBAI_NetProfileName(attempt.profile)) hack=\(attempt.nativeName)");
  };
}

public func MBAI_NetrunnerProfile(aff: gamedataAffiliation) -> MBAI_NetProfile {
  if Equals(aff, gamedataAffiliation.VoodooBoys) {
    return MBAI_NetProfile.Apex;
  };
  if Equals(aff, gamedataAffiliation.NetWatch) || Equals(aff, gamedataAffiliation.NCPD) {
    return MBAI_NetProfile.IceWarden;
  };
  if Equals(aff, gamedataAffiliation.Arasaka) || Equals(aff, gamedataAffiliation.Militech) || Equals(aff, gamedataAffiliation.NUSA) || Equals(aff, gamedataAffiliation.KangTao) || Equals(aff, gamedataAffiliation.Barghest) || Equals(aff, gamedataAffiliation.AfterlifeMercs) || Equals(aff, gamedataAffiliation.UnaffiliatedCorpo) || Equals(aff, gamedataAffiliation.Classified) {
    return MBAI_NetProfile.Corpo;
  };
  if Equals(aff, gamedataAffiliation.Maelstrom) || Equals(aff, gamedataAffiliation.MaelstromAndroid) {
    return MBAI_NetProfile.ChromeButcher;
  };
  if Equals(aff, gamedataAffiliation.TygerClaws) || Equals(aff, gamedataAffiliation.Valentinos) || Equals(aff, gamedataAffiliation.SixthStreet) || Equals(aff, gamedataAffiliation.SixthStreetAndroid) || Equals(aff, gamedataAffiliation.Wraiths) || Equals(aff, gamedataAffiliation.WraithsAndroid) || Equals(aff, gamedataAffiliation.highriders) {
    return MBAI_NetProfile.BladeSupport;
  };
  if Equals(aff, gamedataAffiliation.Scavengers) || Equals(aff, gamedataAffiliation.ScavengersAndroid) || Equals(aff, gamedataAffiliation.crimson_harvest) {
    return MBAI_NetProfile.ScavRig;
  };
  return MBAI_NetProfile.Baseline;
}

public func MBAI_NetProfileName(prof: MBAI_NetProfile) -> String {
  switch prof {
    case MBAI_NetProfile.Apex:
      return "Apex";
    case MBAI_NetProfile.IceWarden:
      return "IceWarden";
    case MBAI_NetProfile.Corpo:
      return "Corpo";
    case MBAI_NetProfile.ChromeButcher:
      return "ChromeButcher";
    case MBAI_NetProfile.BladeSupport:
      return "BladeSupport";
    case MBAI_NetProfile.ScavRig:
      return "ScavRig";
  };
  return "Baseline";
}

public func MBAI_NetrunnerPickHack(nrn: wref<NPCPuppet>, prof: MBAI_NetProfile, out pick: TweakDBID) -> Bool {
  let roll: Float = RandF();
  switch prof {
    case MBAI_NetProfile.Apex:
      if roll < 0.28 {
        pick = t"QuickhackBrainMeltWithoutCDObjectAction";
      } else if roll < 0.52 {
        pick = t"QuickhackPoisonWithoutCDObjectAction";
      } else if roll < 0.74 {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      } else if roll < 0.88 {
        pick = t"QuickhackBurnWithoutCDObjectAction";
      } else {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      };
      return true;
    case MBAI_NetProfile.IceWarden:
      if roll < 0.26 {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      } else if roll < 0.48 {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      } else if roll < 0.66 {
        pick = t"QuickhackWeaponMalfWithoutCDObjectAction";
      } else if roll < 0.82 {
        pick = t"QuickhackBlindWithoutCDObjectAction";
      } else if roll < 0.92 {
        pick = t"QuickhackBrainMeltWithoutCDObjectAction";
      } else {
        pick = t"QuickhackPoisonWithoutCDObjectAction";
      };
      return true;
    case MBAI_NetProfile.Corpo:
      if roll < 0.24 {
        pick = t"QuickhackBlindWithoutCDObjectAction";
      } else if roll < 0.46 {
        pick = t"QuickhackWeaponMalfWithoutCDObjectAction";
      } else if roll < 0.66 {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      } else if roll < 0.84 {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      } else if roll < 0.94 {
        pick = t"QuickhackPoisonWithoutCDObjectAction";
      } else {
        pick = t"QuickhackBrainMeltWithoutCDObjectAction";
      };
      return true;
    case MBAI_NetProfile.ChromeButcher:
      if MBAI_NetrunnerCountMeleeAllies(nrn) >= 2 {
        if roll < 0.5 {
          pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
        } else if roll < 0.78 {
          pick = t"QuickhackLocoMalfWithoutCDObjectAction";
        } else if roll < 0.92 {
          pick = t"QuickhackWeaponMalfWithoutCDObjectAction";
        } else {
          pick = t"QuickhackBlindWithoutCDObjectAction";
        };
        return true;
      };
      if roll < 0.24 {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      } else if roll < 0.46 {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      } else if roll < 0.64 {
        pick = t"QuickhackBurnWithoutCDObjectAction";
      } else if roll < 0.8 {
        pick = t"QuickhackBrainMeltWithoutCDObjectAction";
      } else if roll < 0.92 {
        pick = t"QuickhackPoisonWithoutCDObjectAction";
      } else {
        pick = t"QuickhackLocoMalfWithoutCDObjectAction";
      };
      return true;
    case MBAI_NetProfile.BladeSupport:
      if roll < 0.26 {
        pick = t"QuickhackLocoMalfWithoutCDObjectAction";
      } else if roll < 0.5 {
        pick = t"QuickhackBlindWithoutCDObjectAction";
      } else if roll < 0.74 {
        pick = t"QuickhackWeaponMalfWithoutCDObjectAction";
      } else if roll < 0.94 {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      } else {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      };
      return true;
    case MBAI_NetProfile.ScavRig:
      if roll < 0.3 {
        pick = t"QuickhackCyberwareMalfWithoutCDObjectAction";
      } else if roll < 0.54 {
        pick = t"QuickhackOverloadWithoutCDObjectAction";
      } else if roll < 0.74 {
        pick = t"QuickhackLocoMalfWithoutCDObjectAction";
      } else if roll < 0.88 {
        pick = t"QuickhackBurnWithoutCDObjectAction";
      } else {
        pick = t"QuickhackBlindWithoutCDObjectAction";
      };
      return true;
  };
  return false;
}

public func MBAI_NetrunnerTierCap(rarity: gamedataNPCRarity) -> Int32 {
  if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.Elite) || Equals(rarity, gamedataNPCRarity.MaxTac) || Equals(rarity, gamedataNPCRarity.Officer) {
    return 3;
  };
  if Equals(rarity, gamedataNPCRarity.Rare) {
    return 2;
  };
  if Equals(rarity, gamedataNPCRarity.Normal) {
    return 1;
  };
  return 0;
}

public func MBAI_NetrunnerHackStrength(name: String) -> Int32 {
  if StrContains(name, "Ultimate") {
    return 3;
  };
  if StrContains(name, "BrainMelt") || StrContains(name, "Poison") || StrContains(name, "Overload") {
    return 2;
  };
  if StrContains(name, "Cyberware") || StrContains(name, "Loco") || StrContains(name, "WeaponMalf") {
    return 1;
  };
  return 0;
}

public func MBAI_NetrunnerCapHack(cap: Int32) -> TweakDBID {
  if cap >= 2 {
    return t"QuickhackOverloadWithoutCDObjectAction";
  };
  if cap >= 1 {
    return t"QuickhackCyberwareMalfWithoutCDObjectAction";
  };
  return t"QuickhackBlindWithoutCDObjectAction";
}

public func MBAI_NetrunnerGlobalGap(prof: MBAI_NetProfile) -> Float {
  switch prof {
    case MBAI_NetProfile.Apex:
      return 15.0;
    case MBAI_NetProfile.IceWarden:
      return 18.0;
    case MBAI_NetProfile.Corpo:
      return 28.0;
    case MBAI_NetProfile.ChromeButcher:
      return 24.0;
    case MBAI_NetProfile.BladeSupport:
      return 50.0;
    case MBAI_NetProfile.ScavRig:
      return 34.0;
  };
  return 32.0;
}

public func MBAI_NetrunnerHackIndex(name: String) -> Int32 {
  if StrContains(name, "Ultimate") {
    return 8;
  };
  if StrContains(name, "Blind") {
    return 0;
  };
  if StrContains(name, "Burn") {
    return 1;
  };
  if StrContains(name, "Cyberware") {
    return 2;
  };
  if StrContains(name, "Loco") {
    return 3;
  };
  if StrContains(name, "WeaponMalf") {
    return 4;
  };
  if StrContains(name, "BrainMelt") {
    return 5;
  };
  if StrContains(name, "Poison") {
    return 6;
  };
  if StrContains(name, "Overload") {
    return 7;
  };
  return 0;
}

public func MBAI_NetrunnerHackCD(prof: MBAI_NetProfile, idx: Int32) -> Float {
  switch prof {
    case MBAI_NetProfile.Apex:
      return MBAI_CD_Apex(idx);
    case MBAI_NetProfile.IceWarden:
      return MBAI_CD_IceWarden(idx);
    case MBAI_NetProfile.Corpo:
      return MBAI_CD_Corpo(idx);
    case MBAI_NetProfile.ChromeButcher:
      return MBAI_CD_ChromeButcher(idx);
    case MBAI_NetProfile.BladeSupport:
      return MBAI_CD_BladeSupport(idx);
    case MBAI_NetProfile.ScavRig:
      return MBAI_CD_ScavRig(idx);
  };
  return MBAI_CD_Baseline(idx);
}

public func MBAI_CD_Apex(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 14.0;
    case 1:
      return 12.0;
    case 2:
      return 16.0;
    case 3:
      return 18.0;
    case 4:
      return 26.0;
    case 5:
      return 16.0;
    case 6:
      return 15.0;
    case 7:
      return 15.0;
    case 8:
      return 90.0;
  };
  return 16.0;
}

public func MBAI_CD_IceWarden(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 12.0;
    case 1:
      return 24.0;
    case 2:
      return 14.0;
    case 3:
      return 20.0;
    case 4:
      return 15.0;
    case 5:
      return 22.0;
    case 6:
      return 30.0;
    case 7:
      return 16.0;
    case 8:
      return 95.0;
  };
  return 18.0;
}

public func MBAI_CD_Corpo(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 9.0;
    case 1:
      return 28.0;
    case 2:
      return 17.0;
    case 3:
      return 20.0;
    case 4:
      return 14.0;
    case 5:
      return 38.0;
    case 6:
      return 28.0;
    case 7:
      return 26.0;
    case 8:
      return 115.0;
  };
  return 20.0;
}

public func MBAI_CD_ChromeButcher(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 16.0;
    case 1:
      return 20.0;
    case 2:
      return 15.0;
    case 3:
      return 22.0;
    case 4:
      return 26.0;
    case 5:
      return 30.0;
    case 6:
      return 26.0;
    case 7:
      return 22.0;
    case 8:
      return 150.0;
  };
  return 20.0;
}

public func MBAI_CD_BladeSupport(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 14.0;
    case 1:
      return 40.0;
    case 2:
      return 20.0;
    case 3:
      return 20.0;
    case 4:
      return 20.0;
    case 5:
      return 60.0;
    case 6:
      return 55.0;
    case 7:
      return 45.0;
    case 8:
      return 999.0;
  };
  return 25.0;
}

public func MBAI_CD_ScavRig(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 14.0;
    case 1:
      return 24.0;
    case 2:
      return 14.0;
    case 3:
      return 16.0;
    case 4:
      return 26.0;
    case 5:
      return 999.0;
    case 6:
      return 999.0;
    case 7:
      return 24.0;
    case 8:
      return 999.0;
  };
  return 22.0;
}

public func MBAI_CD_Baseline(idx: Int32) -> Float {
  switch idx {
    case 0:
      return 12.0;
    case 1:
      return 30.0;
    case 2:
      return 20.0;
    case 3:
      return 22.0;
    case 4:
      return 22.0;
    case 5:
      return 42.0;
    case 6:
      return 30.0;
    case 7:
      return 28.0;
    case 8:
      return 120.0;
  };
  return 22.0;
}

public func MBAI_NetrunnerEnsureCD(nrn: ref<NPCPuppet>) -> Void {
  while ArraySize(nrn.m_mbaiHackCD) < 9 {
    ArrayPush(nrn.m_mbaiHackCD, 0.0);
  };
}

public func MBAI_NetrunnerGlobalReady(nrn: wref<NPCPuppet>, prof: MBAI_NetProfile, mult: Float, now: Float) -> Bool {
  return (now - nrn.m_mbaiLastHack) >= MBAI_NetrunnerGlobalGap(prof) * mult * MBAI_TemperamentNetrunnerCadenceMul(nrn) * MBAI_IntentNetrunnerCadenceMul(nrn, now);
}

public func MBAI_NetrunnerHackReady(nrn: wref<NPCPuppet>, prof: MBAI_NetProfile, name: String, mult: Float, now: Float) -> Bool {
  let idx: Int32 = MBAI_NetrunnerHackIndex(name);
  return (now - nrn.m_mbaiHackCD[idx]) >= MBAI_NetrunnerHackCD(prof, idx) * mult * MBAI_TemperamentNetrunnerCadenceMul(nrn) * MBAI_IntentNetrunnerCadenceMul(nrn, now);
}

public func MBAI_NetrunnerStamp(nrn: ref<NPCPuppet>, name: String, now: Float) -> Void {
  nrn.m_mbaiLastHack = now;
  nrn.m_mbaiHackCD[MBAI_NetrunnerHackIndex(name)] = now;
}

public func MBAI_NetrunnerCast(context: ScriptExecutionContext, nrn: wref<NPCPuppet>, record: wref<AISubActionQuickHack_Record>, actionID: TweakDBID) -> Bool {
  let target: wref<GameObject>;
  let action: ref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(actionID);
  if !AIActionTarget.GetObject(context, record.Target(), target) || !IsDefined(action) {
    return false;
  };
  let player: ref<PlayerPuppet> = GetPlayer(nrn.GetGame());
  if IsDefined(player) && StatusEffectSystem.ObjectHasStatusEffect(player, t"StatusEffect.HackReveal") {
    StatusEffectHelper.RemoveStatusEffect(nrn, t"AIQuickHackStatusEffect.HackRevealInterrupted");
  } else {
    StatusEffectHelper.RemoveStatusEffect(nrn, t"AIQuickHackStatusEffect.HackingInterrupted");
  };
  let evt: ref<HackTargetEvent> = new HackTargetEvent();
  evt.targetID = target.GetEntityID();
  evt.netrunnerID = nrn.GetEntityID();
  evt.objectRecord = action;
  target.QueueEvent(evt);
  return true;
}

public func MBAI_NetrunnerCountMeleeAllies(nrn: wref<NPCPuppet>) -> Int32 {
  let nearby: array<ref<NPCPuppet>> = nrn.GetNPCsAroundObject(40.0);
  let count: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(nearby) {
    let a: ref<NPCPuppet> = nearby[i];
    if MBAI_EnemyEligible(a) && a.GetEntityID() != nrn.GetEntityID() && MBAI_SameCombatGroup(nrn, a) && MBAI_ArchetypeIsMelee(MBAI_GetArchetype(a)) {
      count += 1;
    };
    i += 1;
  };
  return count;
}

public func MBAI_NetrunnerUltimateGateMet(nrn: wref<NPCPuppet>) -> Bool {
  let gi: GameInstance = nrn.GetGame();
  let player: ref<GameObject> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
  if !IsDefined(player) {
    return true;
  };
  if Vector4.Distance(nrn.GetWorldPosition(), player.GetWorldPosition()) < 25.0 {
    return false;
  };
  let nearby: array<ref<NPCPuppet>> = nrn.GetNPCsAroundObject(30.0);
  let allies: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(nearby) {
    let a: ref<NPCPuppet> = nearby[i];
    if MBAI_EnemyEligible(a) && a.GetEntityID() != nrn.GetEntityID() && MBAI_SameCombatGroup(nrn, a) {
      allies += 1;
    };
    i += 1;
  };
  return allies >= 3;
}
