// C2: Lethal Enemy Netrunners (Pure-Redscript Port of Challenging Enemy Netrunners + Enemy Quickhack Fixes)
// Pure Redscript (0 TweakXL / ModSettings dependencies) for Cyberpunk 2077 v2.5:
// 1. Frees enemy Netrunners early (after 2.0s or 20% of upload time) so they keep moving,
//    taking cover, and shooting while their quickhack continues uploading.
// 2. Hides the orange Netrunner link wire and minimap marker once the Netrunner breaks root.
// 3. Cuts enemy Netrunner per-hack and post-hack throttle cooldowns by 50% at runtime.
// 4. Unlocks Weapon Jam and Tier 2 combat quickhacks on Tier 3 Netrunners at runtime,
//    scales MaxTac quickhacks to game difficulty, and fixes linked status effect duplicates.

enum CENRevealMode {
  Shown = 0,
  Hidden = 1,
  WhileRooted = 2,
}

public class CENSettings {
  public let linkLine: CENRevealMode = CENRevealMode.WhileRooted;
  public let minimapMarker: CENRevealMode = CENRevealMode.WhileRooted;
  public let earlyRelease: Bool = true;
  public let rootDuration: Float = 2.0;
  public let rootUploadPercent: Float = 20.0;
  public let proximityCancelsHack: Bool = true;
  public let hitInterruptCount: Int32 = 8;
  public let hitInterruptCountNormal: Int32 = 2;
  public let hitWindow: Float = 5.0;
  public let hackThrottlePercent: Float = 50.0;
  public let hackCooldownPercent: Float = 50.0;
}

public func CEN_ProximityRange() -> Float {
  return 6.0;
}

public func CEN_HeavyHitWeight() -> Int32 {
  return 3;
}

public func CEN_IsRevealActionID(id: TweakDBID) -> Bool {
  return id == t"AIQuickHack.HackReveal"
      || id == t"AIQuickHack.HackRevealPosition"
      || id == t"AIQuickHack.PreventionHackRevealPosition";
}

public func CEN_IsRevealAction(record: wref<AISubActionQuickHack_Record>) -> Bool {
  if !IsDefined(record) {
    return true;
  };
  let result: wref<ObjectAction_Record> = record.ActionResult();
  if !IsDefined(result) {
    return true;
  };
  return CEN_IsRevealActionID(result.GetRecordID());
}

public func CEN_IsInterruptEffect(id: TweakDBID) -> Bool {
  return id == t"AIQuickHackStatusEffect.HackingInterrupted"
      || id == t"AIQuickHackStatusEffect.HackRevealInterrupted";
}

@addField(ScriptedPuppet)
public let m_cenUploading: Bool;

@addField(ScriptedPuppet)
public let m_cenCancelling: Bool;

@addField(ScriptedPuppet)
public let m_cenHitCount: Int32;

@addField(ScriptedPuppet)
public let m_cenHitWindowStart: Float;

@addField(ScriptedPuppet)
public let m_cenHackStart: Float;

@addField(ScriptedPuppet)
public let m_cenUploadTime: Float;

@addMethod(ScriptedPuppet)
public final func CEN_BeginRelease(now: Float) -> Void {
  this.m_cenUploading = true;
  this.m_cenCancelling = false;
  this.m_cenHitCount = 0;
  this.m_cenHitWindowStart = now;
  if Equals((new CENSettings()).linkLine, CENRevealMode.WhileRooted) {
    this.CEN_HideLink();
  };
}

@addMethod(ScriptedPuppet)
public final func CEN_RetireUpload() -> Void {
  this.m_cenUploading = false;
  this.m_cenCancelling = false;
  this.m_cenHitCount = 0;
  this.m_cenHackStart = 0.0;
  this.m_cenUploadTime = 0.0;
}

@addMethod(ScriptedPuppet)
public final func CEN_CancelUpload() -> Void {
  this.m_cenCancelling = true;
  this.m_cenHitCount = 0;
  StatusEffectHelper.ApplyStatusEffect(this, t"AIQuickHackStatusEffect.HackingInterrupted", this.GetEntityID());
}

@addMethod(ScriptedPuppet)
public final func CEN_HideLink() -> Void {
  let bb: ref<IBlackboard> = this.GetAIControllerComponent().GetActionBlackboard();
  if !IsDefined(bb) {
    return;
  };
  let netrunnerID: EntityID = FromVariant<EntityID>(bb.GetVariant(GetAllBlackboardDefs().AIAction.netrunner));
  let targetID: EntityID = FromVariant<EntityID>(bb.GetVariant(GetAllBlackboardDefs().AIAction.netrunnerTarget));
  if !EntityID.IsDefined(netrunnerID) || !EntityID.IsDefined(targetID) {
    return;
  };
  let proxyID: EntityID = FromVariant<EntityID>(bb.GetVariant(GetAllBlackboardDefs().AIAction.netrunnerProxy));
  if EntityID.IsDefined(proxyID) {
    this.GetPS().DrawBetweenEntities(false, false, this.GetFxResourceByKey(n"pingNetworkLink"), netrunnerID, proxyID, false, false);
    this.GetPS().DrawBetweenEntities(false, false, this.GetFxResourceByKey(n"pingNetworkLink"), proxyID, targetID, false, false);
    this.ToggleForcedVisibilityInAnimSystem(n"pingNetworkLink", false, 0.00, netrunnerID);
    this.ToggleForcedVisibilityInAnimSystem(n"pingNetworkLink", false, 0.00, proxyID);
  } else {
    this.GetPS().DrawBetweenEntities(false, false, this.GetFxResourceByKey(n"pingNetworkLink"), netrunnerID, targetID, false, false);
    this.ToggleForcedVisibilityInAnimSystem(n"pingNetworkLink", false, 0.00, netrunnerID);
  };
}

public func CEN_UploadTime(context: ScriptExecutionContext, record: wref<AISubActionQuickHack_Record>, caster: ref<ScriptedPuppet>) -> Float {
  let result: wref<ObjectAction_Record> = record.ActionResult();
  let target: wref<GameObject>;
  if !IsDefined(result) || !AIActionTarget.GetObject(context, record.Target(), target) {
    return 0.0;
  };
  let mods: array<wref<StatModifier_Record>>;
  result.ActivationTime(mods);
  if ArraySize(mods) == 0 {
    return 0.0;
  };
  return RPGManager.CalculateStatModifiers(mods, caster.GetGame(), caster, Cast<StatsObjectID>(target.GetEntityID()), Cast<StatsObjectID>(caster.GetEntityID()));
}

@wrapMethod(AISubActionQuickHack_Record_Implementation)
public final static func Update(context: ScriptExecutionContext, record: wref<AISubActionQuickHack_Record>, const duration: Float) -> AIbehaviorUpdateOutcome {
  let settings: ref<CENSettings> = new CENSettings();
  if !settings.earlyRelease || CEN_IsRevealAction(record) {
    return wrappedMethod(context, record, duration);
  };
  let vanilla: AIbehaviorUpdateOutcome = wrappedMethod(context, record, duration);
  if Equals(vanilla, AIbehaviorUpdateOutcome.SUCCESS) {
    return vanilla;
  };
  let caster: ref<ScriptedPuppet> = ScriptExecutionContext.GetOwner(context) as ScriptedPuppet;
  if !IsDefined(caster) {
    return vanilla;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(caster.GetGame()));
  if caster.m_cenHackStart <= 0.0 {
    caster.m_cenHackStart = now;
    caster.m_cenUploadTime = CEN_UploadTime(context, record, caster);
  };
  if now - caster.m_cenHackStart < MaxF(settings.rootDuration, caster.m_cenUploadTime * settings.rootUploadPercent * 0.01) {
    return vanilla;
  };
  if !caster.m_cenUploading {
    caster.CEN_BeginRelease(now);
  };
  return AIbehaviorUpdateOutcome.SUCCESS;
}

@wrapMethod(AISubActionQuickHack_Record_Implementation)
public final static func CancelConnection(context: ScriptExecutionContext, record: wref<AISubActionQuickHack_Record>) -> Void {
  let settings: ref<CENSettings> = new CENSettings();
  if settings.earlyRelease && !CEN_IsRevealAction(record) {
    let caster: ref<ScriptedPuppet> = ScriptExecutionContext.GetOwner(context) as ScriptedPuppet;
    if IsDefined(caster) {
      if caster.m_cenUploading {
        ScriptExecutionContext.SetArgumentObject(context, n"NetrunnerProxy", null);
        return;
      };
      if !settings.proximityCancelsHack {
        let player: ref<PlayerPuppet> = GetPlayer(caster.GetGame());
        if IsDefined(player) && Vector4.Distance(player.GetWorldPosition(), caster.GetWorldPosition()) <= CEN_ProximityRange() {
          caster.CEN_BeginRelease(EngineTime.ToFloat(GameInstance.GetSimTime(caster.GetGame())));
          ScriptExecutionContext.SetArgumentObject(context, n"NetrunnerProxy", null);
          return;
        };
      };
      caster.CEN_RetireUpload();
    };
  };
  wrappedMethod(context, record);
}

@wrapMethod(StatusEffectHelper)
public final static func ApplyStatusEffect(target: wref<GameObject>, statusEffectID: TweakDBID, instigatorEntityID: EntityID) -> Bool {
  if CEN_IsInterruptEffect(statusEffectID) {
    let puppet: ref<ScriptedPuppet> = target as ScriptedPuppet;
    if IsDefined(puppet) && puppet.m_cenUploading && !puppet.m_cenCancelling {
      return false;
    };
  };
  return wrappedMethod(target, statusEffectID, instigatorEntityID);
}

@wrapMethod(AISubActionStatusEffect_Record_Implementation)
public final static func ApplyStatusEffect(context: ScriptExecutionContext, record: wref<AISubActionStatusEffect_Record>) -> Void {
  let target: wref<GameObject>;
  if AIActionTarget.GetObject(context, record.Target(), target) {
    let puppet: ref<ScriptedPuppet> = target as ScriptedPuppet;
    if IsDefined(puppet) && puppet.m_cenUploading && !puppet.m_cenCancelling {
      let i: Int32 = 0;
      while i < record.GetStatusEffectsCount() {
        if CEN_IsInterruptEffect(record.GetStatusEffectsItem(i).GetID()) {
          return;
        };
        i += 1;
      };
    };
  };
  wrappedMethod(context, record);
}

@wrapMethod(UploadFromNPCToPlayerListener)
public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
  wrappedMethod(oldValue, newValue, percToPoints);
  let npc: ref<ScriptedPuppet> = this.m_npcPuppet;
  if !IsDefined(npc) || !npc.m_cenUploading {
    return;
  };
  if !this.m_HUDData.active {
    npc.CEN_RetireUpload();
    return;
  };
  if IsDefined(this.m_playerPuppet) {
    let sfx: ref<StatusEffectSystem> = GameInstance.GetStatusEffectSystem(this.m_gameInstance);
    if IsDefined(sfx) && !sfx.HasStatusEffect(this.m_playerPuppet.GetEntityID(), t"AIQuickHackStatusEffect.BeingHacked") {
      StatusEffectHelper.ApplyStatusEffect(this.m_playerPuppet, t"AIQuickHackStatusEffect.BeingHacked", npc.GetEntityID());
    };
  };
}

@wrapMethod(UploadFromNPCToPlayerListener)
protected cb func OnStatPoolMaxValueReached(value: Float) -> Bool {
  if IsDefined(this.m_npcPuppet) {
    this.m_npcPuppet.CEN_RetireUpload();
  };
  return wrappedMethod(value);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !this.m_cenUploading || this.m_cenCancelling {
    return result;
  };
  if !IsDefined(evt.attackData) || !IsDefined(evt.attackData.GetInstigator() as PlayerPuppet) {
    return result;
  };
  let settings: ref<CENSettings> = new CENSettings();
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
  if now - this.m_cenHitWindowStart > settings.hitWindow {
    this.m_cenHitWindowStart = now;
    this.m_cenHitCount = 0;
  };
  let attackType: gamedataAttackType = evt.attackData.GetAttackType();
  if AttackData.IsMelee(attackType) || AttackData.IsWhip(attackType) || AttackData.IsThrown(attackType) {
    this.m_cenHitCount += CEN_HeavyHitWeight();
  } else {
    this.m_cenHitCount += 1;
  };
  let rarity: gamedataNPCRarity = this.GetNPCRarity();
  let limit: Int32 = Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac)
      ? settings.hitInterruptCount
      : settings.hitInterruptCountNormal;
  if this.m_cenHitCount >= limit {
    this.CEN_CancelUpload();
  };
  return result;
}

@replaceMethod(ScriptedPuppet)
protected cb func OnNetworkLinkQuickhackEvent(evt: ref<NetworkLinkQuickhackEvent>) -> Bool {
  let settings: ref<CENSettings> = new CENSettings();
  let statMod: ref<gameStatModifierData>;
  let bb: ref<IBlackboard> = this.GetAIControllerComponent().GetActionBlackboard();
  if IsDefined(bb) {
    bb.SetVariant(GetAllBlackboardDefs().AIAction.netrunner, ToVariant(evt.netrunnerID));
    bb.SetVariant(GetAllBlackboardDefs().AIAction.netrunnerProxy, ToVariant(evt.proxyID));
    bb.SetVariant(GetAllBlackboardDefs().AIAction.netrunnerTarget, ToVariant(evt.targetID));
  };
  if evt.targetID == GetPlayer(this.GetGame()).GetEntityID() {
    this.ToggleForcedVisibilityInAnimSystem(n"pingNetworkLink", true, 0.00, evt.from);
    if NotEquals(settings.linkLine, CENRevealMode.Hidden) {
      this.GetPS().DrawBetweenEntities(true, false, this.GetFxResourceByKey(n"pingNetworkLink"), evt.to, evt.from, false, false, false, false, true);
    };
    if GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(Cast<StatsObjectID>(evt.targetID), gamedataStatType.RevealNetrunnerWhenHacked) > 0.00 {
      this.ForceVisionAppearanceNetrunner(GameInstance.FindEntityByID(this.GetGame(), evt.netrunnerID) as GameObject, evt.netrunnerID, n"EnemyNetrunner", true);
      statMod = RPGManager.CreateStatModifier(gamedataStatType.RevealNetrunnerWhenHacked, gameStatModifierType.Additive, 1.00);
      GameInstance.GetStatsSystem(this.GetGame()).AddModifier(Cast<StatsObjectID>(evt.netrunnerID), statMod);
      if EntityID.IsDefined(evt.proxyID) {
        this.ForceVisionAppearanceNetrunner(GameInstance.FindEntityByID(this.GetGame(), evt.proxyID) as GameObject, evt.netrunnerID, n"EnemyNetrunner", true);
        GameInstance.GetStatsSystem(this.GetGame()).AddModifier(Cast<StatsObjectID>(evt.proxyID), statMod);
      };
    };
  };
}

@wrapMethod(MinimapStealthMappinController)
protected func Update() -> Void {
  wrappedMethod();
  if !this.m_isNetrunner {
    return;
  };
  let mode: CENRevealMode = (new CENSettings()).minimapMarker;
  if Equals(mode, CENRevealMode.Shown) || (Equals(mode, CENRevealMode.WhileRooted) && this.m_isHacking) {
    return;
  };
  this.SetForceHide(true);
  this.m_stealthMappin.SetVisibleOnMinimap(false);
}

@replaceMethod(SensorDevice)
protected cb func OnNetworkLinkQuickhackEvent(evt: ref<NetworkLinkQuickhackEvent>) -> Bool {
  let settings: ref<CENSettings> = new CENSettings();
  let ps: ref<SensorDeviceControllerPS> = this.GetDevicePS();
  if !IsDefined(ps) {
    return false;
  };
  ps.SetNetrunnerID(evt.netrunnerID);
  ps.SetNetrunnerProxyID(evt.proxyID);
  ps.SetNetrunnerTargetID(evt.targetID);
  if NotEquals(settings.linkLine, CENRevealMode.Hidden) {
    ps.DrawBetweenEntities(true, false, this.GetFxResourceByKey(n"pingNetworkLink"), evt.to, evt.from, false, false, false, false);
  };
  this.ToggleForcedVisibilityInAnimSystem(n"pingNetworkLink", true, 0.00, evt.from);
}

// --- Runtime Cooldown Scaling (50% Faster Enemy Netrunner Hack Cooldowns) ---
public static func CEN_IsNetrunnerHackCooldown(cdName: CName) -> Bool {
  return Equals(cdName, n"HackOverheat")
      || Equals(cdName, n"HackOverload")
      || Equals(cdName, n"HackLocomotion")
      || Equals(cdName, n"HackCyberware")
      || Equals(cdName, n"HackWeaponMalfunction")
      || Equals(cdName, n"HackWeaponJam")
      || Equals(cdName, n"HackBlind")
      || Equals(cdName, n"HackDeath")
      || Equals(cdName, n"HackBuffCamo")
      || Equals(cdName, n"HackBuffICE")
      || Equals(cdName, n"HackRevealPosition")
      || Equals(cdName, n"HackAppliedCooldown")
      || Equals(cdName, n"HackAppliedT3Cooldown");
}

@wrapMethod(AIActionHelper)
public final static func StartCooldown(self: ref<GameObject>, record: wref<AIActionCooldown_Record>) -> Int32 {
  let res: Int32 = wrappedMethod(self, record);
  if res >= 0 && IsDefined(self) && IsDefined(record) {
    let cdName: CName = record.Name();
    if IsNameValid(cdName) && CEN_IsNetrunnerHackCooldown(cdName) && record.Duration() > 0.0 {
      let scaledDuration: Float = record.Duration() * 0.50;
      GameObject.RemoveCooldown(self, cdName);
      return AIActionHelper.StartCooldown(self, cdName, scaledDuration);
    };
  };
  return res;
}

// --- Runtime Ability Fixes (Weapon Jam + Tier 3 Netrunner Combat Hacks) ---
@wrapMethod(AIActionHelper)
public final static func CheckAbility(const object: wref<GameObject>, ability: wref<GameplayAbility_Record>) -> Bool {
  if IsDefined(object) && IsDefined(ability) {
    let abilityID: TweakDBID = ability.GetID();
    // Fix vanilla bug where nobody is granted CanJamWeaponQuickHack: map to CanWeaponMalfunctionQuickHack
    if abilityID == t"Ability.CanJamWeaponQuickHack" {
      let malfRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanWeaponMalfunctionQuickHack");
      if IsDefined(malfRec) && wrappedMethod(object, malfRec) {
        return true;
      };
    };
    // Grant Tier 3 Netrunners access to Tier 2 combat quickhacks (Overload, Blind, Weapon Malfunction)
    if abilityID == t"Ability.CanOverloadQuickHack"
    || abilityID == t"Ability.CanBlindQuickHack"
    || abilityID == t"Ability.CanWeaponMalfunctionQuickHack" {
      let netrunnerRec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsNetrunnerArchetype");
      let tier3Rec: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsTier3Archetype");
      if IsDefined(netrunnerRec) && IsDefined(tier3Rec) && wrappedMethod(object, netrunnerRec) && wrappedMethod(object, tier3Rec) {
        return true;
      };
    };
  };
  return wrappedMethod(object, ability);
}

// --- MaxTac Hack Scaling & Linked Status Effect Deduplication ---
public func EQF_DifficultyHack(id: TweakDBID, difficulty: gameDifficulty) -> TweakDBID {
  let hacks: array<TweakDBID> = [
    t"AIQuickHack.HackOverheat", t"AIQuickHack.HackOverheat_Hard", t"AIQuickHack.HackOverheat_VeryHard",
    t"AIQuickHack.HackOverload", t"AIQuickHack.HackOverload_Hard", t"AIQuickHack.HackOverload_VeryHard",
    t"AIQuickHack.HackLocomotion", t"AIQuickHack.HackLocomotion_Hard", t"AIQuickHack.HackLocomotion_VeryHard",
    t"AIQuickHack.HackCyberware", t"AIQuickHack.HackCyberware_Hard", t"AIQuickHack.HackCyberware_VeryHard",
    t"AIQuickHack.HackWeaponMalfunction", t"AIQuickHack.HackWeaponMalfunction_Hard", t"AIQuickHack.HackWeaponMalfunction_VeryHard",
    t"AIQuickHack.HackWeaponJam", t"AIQuickHack.HackWeaponJam", t"AIQuickHack.HackWeaponJam_VeryHard",
    t"AIQuickHack.HackBlind", t"AIQuickHack.HackBlind_Hard", t"AIQuickHack.HackBlind_VeryHard",
    t"AIQuickHack.HackDeath", t"AIQuickHack.HackDeath_Hard", t"AIQuickHack.HackDeath_VeryHard"
  ];
  let index: Int32 = ArrayFindFirst(hacks, id);
  let tier: Int32 = 0;
  if id == t"AIQuickHack.HackDeath_MaxTac" {
    index = 21;
  };
  if index < 0 || index % 3 != 0 {
    return TDBID.None();
  };
  if Equals(difficulty, gameDifficulty.Hard) {
    tier = 1;
  } else {
    if Equals(difficulty, gameDifficulty.VeryHard) {
      tier = 2;
    };
  };
  return hacks[index + tier];
}

@wrapMethod(ScriptedPuppet)
protected cb func OnHackTargetEvent(evt: ref<HackTargetEvent>) -> Bool {
  let netrunner: ref<ScriptedPuppet>;
  let swapped: TweakDBID;
  if IsDefined(evt.objectRecord) {
    netrunner = GameInstance.FindEntityByID(this.GetGame(), evt.netrunnerID) as ScriptedPuppet;
    if IsDefined(netrunner) && AIActionHelper.CheckAbility(netrunner, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.IsAVMaxTac")) {
      swapped = EQF_DifficultyHack(evt.objectRecord.GetID(), GameInstance.GetStatsDataSystem(this.GetGame()).GetDifficulty());
      if TDBID.IsValid(swapped) && IsDefined(TweakDBInterface.GetObjectActionRecord(swapped)) {
        evt.objectRecord = TweakDBInterface.GetObjectActionRecord(swapped);
      };
    };
  };
  return wrappedMethod(evt);
}

@wrapMethod(ScriptedPuppet)
public final func AddLinkedStatusEffect(netrunner: EntityID, target: EntityID, opt actionEffects: array<wref<ObjectActionEffect_Record>>) -> Void {
  let netrunners: array<EntityID>;
  let effects: array<TweakDBID>;
  let i: Int32 = 0;
  wrappedMethod(netrunner, target, actionEffects);
  while i < ArraySize(this.m_linkedStatusEffect.netrunnerIDs) {
    if !ArrayContains(netrunners, this.m_linkedStatusEffect.netrunnerIDs[i]) {
      ArrayPush(netrunners, this.m_linkedStatusEffect.netrunnerIDs[i]);
    };
    i += 1;
  };
  i = 0;
  while i < ArraySize(this.m_linkedStatusEffect.statusEffectList) {
    if TDBID.IsValid(this.m_linkedStatusEffect.statusEffectList[i]) && !ArrayContains(effects, this.m_linkedStatusEffect.statusEffectList[i]) {
      ArrayPush(effects, this.m_linkedStatusEffect.statusEffectList[i]);
    };
    i += 1;
  };
  this.m_linkedStatusEffect.netrunnerIDs = netrunners;
  this.m_linkedStatusEffect.statusEffectList = effects;
}

@wrapMethod(AIActionHelper)
public final static func UpdateLinkedStatusEffects(owner: wref<GameObject>, linkedStatusEffect: script_ref<LinkedStatusEffect>) -> Void {
  if ArraySize(Deref(linkedStatusEffect).netrunnerIDs) == 0 {
    wrappedMethod(owner, linkedStatusEffect);
  };
}
