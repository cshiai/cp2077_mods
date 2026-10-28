module MuchBetterAI.Capability

import MuchBetterAI.Core.*
import MuchBetterAI.Fireteam.*
import MuchBetterAI.Logging.*
import SimpleDroneCompanion.*

public class MBAI_CapabilityAuditEvent extends Event {}

public static func MBAI_CapabilityCatalog() -> array<TweakDBID> {
  let catalog: array<TweakDBID>;
  ArrayPush(catalog, t"Ability.HasBerserk");
  ArrayPush(catalog, t"Ability.CanUseBiohazardGrenades");
  ArrayPush(catalog, t"Ability.CanGuardBreak");
  ArrayPush(catalog, t"Ability.CanCallReinforcements");
  ArrayPush(catalog, t"Ability.HasChargeJump");
  ArrayPush(catalog, t"Ability.CanUseCombatStims");
  ArrayPush(catalog, t"Ability.CanUseEMPGrenades");
  ArrayPush(catalog, t"Ability.CanUseFlashbangGrenades");
  ArrayPush(catalog, t"Ability.CanUseFragGrenades");
  ArrayPush(catalog, t"Ability.HasGlowingTattoos");
  ArrayPush(catalog, t"Ability.CanUseIncendiaryGrenades");
  ArrayPush(catalog, t"Ability.HasKerenzikov");
  ArrayPush(catalog, t"Ability.CanQuickhack");
  ArrayPush(catalog, t"Ability.CanUseOpticalCamo");
  ArrayPush(catalog, t"Ability.CanOverheatQuickHack");
  ArrayPush(catalog, t"Ability.CanResurrectAllies");
  ArrayPush(catalog, t"Ability.HasSandevistan");
  ArrayPush(catalog, t"Ability.HasSandevistanTier1");
  ArrayPush(catalog, t"Ability.HasSandevistanTier2");
  ArrayPush(catalog, t"Ability.HasSandevistanTier3");
  ArrayPush(catalog, t"Ability.CanUseSmokeGrenades");
  ArrayPush(catalog, t"Ability.CanSeeThroughSmoke");
  ArrayPush(catalog, t"Ability.HasSubdermalArmor");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorLow");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorMedium");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorHigh");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorLow_Mechanical");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorMedium_Mechanical");
  ArrayPush(catalog, t"Ability.HasSubdermalArmorHigh_Mechanical");
  ArrayPush(catalog, t"Ability.CanWeaponMalfunctionQuickHack");
  return catalog;
}

public static func MBAI_CapabilityEligible(npc: wref<NPCPuppet>) -> Bool {
  if !IsDefined(npc) || npc.IsCharacterCivilian() || npc.IsCrowd() || npc.IsPlayerCompanion() || SDC_IsCompanion(npc) || GameObject.IsFriendlyTowardsPlayer(npc) || !npc.IsActive() || !npc.IsOnAutonomousAI() || npc.IsPaperdoll() {
    return false;
  };
  let recordID: TweakDBID = npc.GetRecordID();
  let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(recordID);
  if !IsDefined(record) || Equals(recordID, t"Character.Player_Puppet_Menu") || Equals(recordID, t"Character.Player_Puppet_Inventory") || Equals(recordID, t"Character.Silverhand") || Equals(recordID, t"Character.Takemura") || !IsDefined(record.ActionMap()) {
    return false;
  };
  let rarity: gamedataNPCRarity = npc.GetNPCRarity();
  return NotEquals(rarity, gamedataNPCRarity.Boss) && NotEquals(rarity, gamedataNPCRarity.MaxTac);
}

public static func MBAI_PhysicalCapabilityEligible(npc: wref<NPCPuppet>) -> Bool {
  if !MBAI_CapabilityEligible(npc) || npc.IsMechanical() || NPCManager.HasTag(npc.GetRecordID(), n"Cyberpsycho") {
    return false;
  };
  return true;
}

public static func MBAI_CanGuardBreak(npc: wref<NPCPuppet>) -> Bool {
  if GameFileExists("r6/scripts/ENC/BreakHold.reds") || !MBAI_PhysicalCapabilityEligible(npc) {
    return false;
  };
  switch MBAI_GetArchetype(npc) {
    case gamedataArchetypeType.HeavyMeleeT2:
    case gamedataArchetypeType.HeavyMeleeT3:
      return true;
    case gamedataArchetypeType.FastMeleeT2:
    case gamedataArchetypeType.FastMeleeT3:
      switch MBAI_GetAffiliation(npc) {
        case gamedataAffiliation.TygerClaws:
        case gamedataAffiliation.Arasaka:
        case gamedataAffiliation.Valentinos:
        case gamedataAffiliation.Barghest:
          return true;
        default:
          break;
      };
      break;
    default:
      break;
  };
  return false;
}

public static func MBAI_ProvisionCapabilities(npc: ref<NPCPuppet>) -> Void {
  if !MBAI_CanGuardBreak(npc) {
    return;
  };
  let appliedPackages: array<TweakDBID>;
  let glp: ref<GameplayLogicPackageSystem> = GameInstance.GetGameplayLogicPackageSystem(npc.GetGame());
  if !IsDefined(glp) {
    return;
  };
  glp.GetAppliedPackages(npc, appliedPackages);
  MBAI_ApplyCapability(npc, t"Ability.CanGuardBreak", appliedPackages);
}

public static func MBAI_AuditCapabilities(npc: ref<NPCPuppet>) -> Void {
  // Capability diagnostics are intentionally removed from the fixed profile.
  return;
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let evt: ref<MBAI_CapabilityAuditEvent> = new MBAI_CapabilityAuditEvent();
  let delay = GameInstance.GetDelaySystem(this.GetGame());
  if IsDefined(delay) {
    delay.DelayEvent(this, evt, 0.10, false);
  }
  return result;
}

@addMethod(NPCPuppet)
protected cb func OnMBAI_CapabilityAuditEvent(evt: ref<MBAI_CapabilityAuditEvent>) -> Bool {
  MBAI_ProvisionCapabilities(this);
  return true;
}
