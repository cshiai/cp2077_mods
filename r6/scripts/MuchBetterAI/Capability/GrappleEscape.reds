module MuchBetterAI.Capability

import MuchBetterAI.Logging.*

public static func MBAI_GrappleEscapeEligible(target: wref<NPCPuppet>, player: wref<PlayerPuppet>) -> Bool {
  if !IsDefined(target) || !IsDefined(player) || NotEquals(GameObject.GetAttitudeTowards(target, player), EAIAttitude.AIA_Hostile) || target.IsMechanical() || target.IsCharacterCivilian() || target.IsCrowd() || target.IsPlayerCompanion() || NPCManager.HasTag(target.GetRecordID(), n"Cyberpsycho") || NPCManager.HasTag(target.GetRecordID(), n"MiniBoss") || NPCManager.HasTag(target.GetRecordID(), n"q305_maxtac") || NPCManager.HasTag(target.GetRecordID(), n"MaxTac_Prevention") {
    return false;
  };
  let rarity: gamedataNPCRarity = target.GetNPCRarity();
  return NotEquals(rarity, gamedataNPCRarity.Boss) && NotEquals(rarity, gamedataNPCRarity.MaxTac);
}

public static func MBAI_GrappleEscapeHasGorillaArms(player: wref<PlayerPuppet>) -> Bool {
  if !IsDefined(player) {
    return false;
  };
  let arms: ItemID = EquipmentSystem.GetData(player).GetActiveMeleeWare();
  return ItemID.IsValid(arms) && WeaponObject.IsOfType(arms, gamedataItemType.Cyb_StrongArms);
}

public static func MBAI_GrappleEscapeGorillaFinite(rarity: gamedataNPCRarity) -> Bool {
  switch rarity {
    case gamedataNPCRarity.Rare:
    case gamedataNPCRarity.Officer:
    case gamedataNPCRarity.Elite:
      return true;
    default:
      return false;
  };
}

@wrapMethod(GrappleStandEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  stateContext.SetPermanentBoolParameter(n"MBAIGrappleEscapeOwned", false, true);
  wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(GrappleStandDecisions)
protected final const func ToGrappleStruggle(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player: wref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  let target: wref<NPCPuppet> = IsDefined(this.stateMachineInitData) ? this.stateMachineInitData.target as NPCPuppet : null;
  if !MBAI_GrappleEscapeEligible(target, player) {
    return wrappedMethod(stateContext, scriptInterface);
  };
  let rarity: gamedataNPCRarity = target.GetNPCRarity();
  let holdTime: Float;
  switch rarity {
    case gamedataNPCRarity.Trash:
    case gamedataNPCRarity.Weak:
      holdTime = 3.0;
      break;
    case gamedataNPCRarity.Normal:
      holdTime = 2.0;
      break;
    case gamedataNPCRarity.Rare:
    case gamedataNPCRarity.Officer:
      holdTime = 1.0;
      break;
    case gamedataNPCRarity.Elite:
      holdTime = 0.0;
      break;
    default:
      holdTime = -1.0;
      break;
  };
  if holdTime < 0.0 {
    return wrappedMethod(stateContext, scriptInterface);
  };
  if this.IsDeepEnoughToSwim(scriptInterface) {
    stateContext.SetPermanentBoolParameter(n"MBAIGrappleEscapeOwned", true, true);
    return true;
  };
  let gorillaArms: Bool = MBAI_GrappleEscapeHasGorillaArms(player);
  if gorillaArms && !MBAI_GrappleEscapeGorillaFinite(rarity) {
    return false;
  };
  if gorillaArms && MBAI_GrappleEscapeGorillaFinite(rarity) {
    let body: Float = ClampF(scriptInterface.GetStatsSystem().GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.Strength), 1.0, 20.0);
    holdTime += 1.0 + (body - 1.0) * 0.1;
  };
  if this.GetInStateTime() < holdTime || scriptInterface.GetPhotoModeSystem().IsPhotoModeActive() || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"GrappleNoBreakFree") {
    return false;
  };
  MBADebug("GrappleEscape", s"struggle rarity=\(rarity) gorilla=\(gorillaArms) hold=\(holdTime)");
  stateContext.SetPermanentBoolParameter(n"MBAIGrappleEscapeOwned", true, true);
  return true;
}

@wrapMethod(GrappleStandDecisions)
protected final const func IsBreakingFreeAllowed(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player: wref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  let target: wref<NPCPuppet> = IsDefined(this.stateMachineInitData) ? this.stateMachineInitData.target as NPCPuppet : null;
  if !MBAI_GrappleEscapeEligible(target, player) {
    return wrappedMethod(stateContext, scriptInterface);
  };
  if scriptInterface.GetPhotoModeSystem().IsPhotoModeActive() {
    return false;
  };
  if MBAI_GrappleEscapeHasGorillaArms(player) {
    return false;
  };
  return !StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"GrappleNoBreakFree");
}

@wrapMethod(GrappleBreakFreeDecisions)
protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if !stateContext.GetBoolParameter(n"MBAIGrappleEscapeOwned", true) {
    return wrappedMethod(stateContext, scriptInterface);
  };
  if Equals(this.GetTakedownAction(stateContext), ETakedownActionType.GrappleFailed) {
    return true;
  };
  if this.IsDeepEnoughToSwim(scriptInterface) && this.GetInStateTime() >= 0.60 {
    return true;
  };
  if this.GetInStateTime() >= this.GetStaticFloatParameterDefault("stateDuration", 4.50) {
    MBADebug("GrappleEscape", "break free");
    return true;
  };
  return false;
}
