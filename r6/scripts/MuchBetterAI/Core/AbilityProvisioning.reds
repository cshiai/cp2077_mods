module MuchBetterAI.Core

import MuchBetterAI.Logging.*

public static func MBAI_CapabilityPackagePresent(appliedPackages: array<TweakDBID>, abilityID: TweakDBID) -> Bool {
  let ability: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(abilityID);
  if !IsDefined(ability) {
    return false;
  };
  let package: wref<GameplayLogicPackage_Record> = ability.AbilityPackage();
  return IsDefined(package) && ArrayContains(appliedPackages, package.GetID());
}

public static func MBAI_ApplyCapability(npc: ref<NPCPuppet>, abilityID: TweakDBID, appliedPackages: array<TweakDBID>) -> Void {
  if !TDBID.IsValid(abilityID) || MBAI_CapabilityPackagePresent(appliedPackages, abilityID) {
    return;
  };
  let ability: wref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(abilityID);
  if !IsDefined(ability) {
    return;
  };
  let package: wref<GameplayLogicPackage_Record> = ability.AbilityPackage();
  if !IsDefined(package) {
    return;
  };
  RPGManager.ApplyGLP(npc, npc, package);
  MBAInfo("Capability", s"assigned entity=\(ToString(npc.GetEntityID())) record=\(TDBID.ToStringDEBUG(npc.GetRecordID())) ability=\(TDBID.ToStringDEBUG(abilityID)) package=\(TDBID.ToStringDEBUG(package.GetID()))");
}
