module MuchBetterAI.Marksmanship

import MuchBetterAI.Logging.*
import MuchBetterAI.Core.*

private static func MBAI_CadenceTierIndex(rarity: gamedataNPCRarity) -> Int32 {
  switch rarity {
    case gamedataNPCRarity.Trash:
    case gamedataNPCRarity.Weak:
      return 0;
    case gamedataNPCRarity.Normal:
      return 1;
    case gamedataNPCRarity.Rare:
      return 2;
    case gamedataNPCRarity.Officer:
      return 3;
    case gamedataNPCRarity.Elite:
      return 4;
    default:
      return -1;
  };
}

private static func MBAI_CadencePackageForIndex(idx: Int32) -> wref<AIPatternsPackage_Record> {
  switch idx {
    case 0:
      return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_TrashWeak");
    case 1:
      return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Normal");
    case 2:
      return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Rare");
    case 3:
      return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Officer");
    default:
      return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Elite");
  };
}

private static func MBAI_ClassCadencePackage(wpn: gamedataItemType) -> wref<AIPatternsPackage_Record> {
  let pkg: wref<AIPatternsPackage_Record>;
  switch wpn {
    case gamedataItemType.Wea_SniperRifle:
    case gamedataItemType.Wea_PrecisionRifle:
      pkg = TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Sniper");
      break;
    case gamedataItemType.Wea_Shotgun:
    case gamedataItemType.Wea_ShotgunDual:
      pkg = TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Shotgun");
      break;
    case gamedataItemType.Wea_LightMachineGun:
    case gamedataItemType.Wea_HeavyMachineGun:
      pkg = TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Heavy");
      break;
    case gamedataItemType.Wea_SubmachineGun:
      pkg = TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_SMG");
      break;
    default:
      break;
  };
  return pkg;
}

private static func MBAI_SuppressiveCadencePackage() -> wref<AIPatternsPackage_Record> {
  return TweakDBInterface.GetAIPatternsPackageRecord(t"MBAI.Cadence_Suppress");
}

@wrapMethod(AIWeapon)
public final static func SelectShootingPatternPackage(weaponOwner: wref<GameObject>, weapon: wref<WeaponObject>, opt records: [wref<AIPatternsPackage_Record>]) -> wref<AIPatternsPackage_Record> {
  let npc: ref<NPCPuppet> = weaponOwner as NPCPuppet;
  if !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
    return wrappedMethod(weaponOwner, weapon, records);
  };
  let weaponRecord: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
  if Equals(weaponRecord.Evolution().Type(), gamedataWeaponEvolution.Smart) {
    return wrappedMethod(weaponOwner, weapon, records);
  };
  if MBAI_ISAIInstalled() {
    return wrappedMethod(weaponOwner, weapon, records);
  };
  let traceCadence: Bool = false;
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  if MBAI_IsSuppressing(npc, now) {
    let suppressive: wref<AIPatternsPackage_Record> = MBAI_SuppressiveCadencePackage();
    if IsDefined(suppressive) {
      if traceCadence {
        MBATrace("Cadence", s"suppressive cadence npc=\(ToString(npc.GetEntityID())) weaponClass=\(ToString(weaponRecord.ItemType().Type()))");
      };
      return suppressive;
    };
  };
  let idx: Int32 = MBAI_CadenceTierIndex(npc.GetNPCRarity());
  if idx < 0 {
    return wrappedMethod(weaponOwner, weapon, records);
  };
  let classPkg: wref<AIPatternsPackage_Record> = MBAI_ClassCadencePackage(weaponRecord.ItemType().Type());
  if IsDefined(classPkg) {
    if traceCadence {
      MBATrace("Cadence", s"class cadence npc=\(ToString(npc.GetEntityID())) weaponClass=\(ToString(weaponRecord.ItemType().Type()))");
    };
    return classPkg;
  };
  let nudge: Float = MBAI_FactionSkillNudge(npc);
  if nudge > 0.0 {
    idx += 1;
  };
  if idx < 0 {
    idx = 0;
  };
  if idx > 4 {
    idx = 4;
  };
  let cadence: wref<AIPatternsPackage_Record> = MBAI_CadencePackageForIndex(idx);
  if !IsDefined(cadence) {
    return wrappedMethod(weaponOwner, weapon, records);
  };
  if traceCadence {
    MBATrace("Cadence", s"tier cadence npc=\(ToString(npc.GetEntityID())) rarity=\(npc.GetNPCRarity()) tier=\(idx) nudge=\(nudge)");
  };
  return cadence;
}

@wrapMethod(AISubActionShootWithWeapon_Record_Implementation)
public final static func QueueFirstShot(weapon: wref<WeaponObject>) -> Void {
  wrappedMethod(weapon);
  let npc: ref<NPCPuppet> = weapon.GetOwner() as NPCPuppet;
  if !MBAI_EnemyEligible(npc) || npc.IsMechanical() {
    return;
  };
  if MBAI_ISAIInstalled() {
    return;
  };
  if MBAI_CadenceTierIndex(npc.GetNPCRarity()) < 0 {
    return;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(npc.GetGame()));
  let mult: Float = MBAI_FactionReactionMult(npc) * MBAI_IntentFirstShotWindup(npc, now);
  if mult == 1.0 {
    return;
  };
  let bb: ref<IBlackboard> = weapon.GetAIBlackboard();
  let base: Float = bb.GetFloat(GetAllBlackboardDefs().AIShooting.nextShotTimeStamp);
  let scaled: Float = ClampF(base * mult, 0.03, 1.1);
  bb.SetFloat(GetAllBlackboardDefs().AIShooting.nextShotTimeStamp, scaled);
  MBATrace("Cadence", s"windup rarity=\(npc.GetNPCRarity()) base=\(base) mult=\(mult) -> \(scaled)");
}
