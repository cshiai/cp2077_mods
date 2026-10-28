module Phoenicia.BlackChrome.CyberDeckHelpers

public func IsCyberdeckEquipped(owner: ref<GameObject>) -> Bool {
  if !IsDefined(owner) {
    return false;
  };
  let data = EquipmentSystem.GetData(owner);
  return IsDefined(data) && ItemID.IsValid(data.FindItemInEquipAreaByTag(n"Cyberdeck", gamedataEquipmentArea.SystemReplacementCW));
}

public func IsAuxCyberdeckEquipped(owner: ref<GameObject>) -> Bool {
  if !IsDefined(owner) {
    return false;
  };
  let data = EquipmentSystem.GetData(owner);
  return IsDefined(data) && ItemID.IsValid(data.FindItemInEquipAreaByTag(n"BlackChrome.AuxCyberdeck", gamedataEquipmentArea.FrontalCortexCW));
}

public func IsAegis(owner: ref<GameObject>) -> Bool {
  if !IsDefined(owner) {
    return false;
  };
  let data = EquipmentSystem.GetData(owner);
  return IsDefined(data) && ItemID.IsValid(data.FindItemInEquipAreaByTag(n"BlackChrome.AegisCyberware", gamedataEquipmentArea.IntegumentarySystemCW));
}
