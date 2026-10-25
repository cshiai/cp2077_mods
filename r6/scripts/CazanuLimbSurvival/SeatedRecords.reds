// Cazanu - private native shooting/aim records for the seated wound controller.
module CazanuLimbSurvival

public class CLS_SeatedCombatTweak extends ScriptableTweak {
  protected cb func OnApply() -> Void {
    TweakDBManager.SetFlat(n"CazanuLimbSurvival.SeatedCombatReady", false);
    if this.Build() {
      TweakDBManager.SetFlat(n"CazanuLimbSurvival.SeatedCombatReady", true);
    }
  }

  private func Clone(name: CName, source: TweakDBID) -> Bool {
    if IsDefined(TweakDBInterface.GetRecord(TDBID.Create(NameToString(name)))) {
      return true;
    }
    return TweakDBManager.CloneRecord(name, source);
  }

  private func MakeShoot(name: CName, id: TweakDBID, slot: TweakDBID) -> Bool {
    let source = TweakDBInterface.GetAISubActionShootWithWeaponRecord(t"ShootActions.DefaultSubActionShootWithWeapon");
    if !IsDefined(source) || source.GetPauseConditionCount() == 0
      || !this.Clone(name, source.GetID()) {
      return false;
    }
    let slots: array<TweakDBID>;
    ArrayPush(slots, slot);
    let ok = TweakDBManager.SetFlat(id + t".weaponSlots", slots);
    ok = TweakDBManager.SetFlat(id + t".target", t"AIActionTarget.CombatTarget") && ok;
    // Native zero means already finished; -1 is the unlimited shot budget.
    // The per-NPC controller still ends this stage after fifteen seconds.
    ok = TweakDBManager.SetFlat(id + t".numberOfShots", -1) && ok;
    ok = TweakDBManager.SetFlat(id + t".maxNumberOfShots", -1) && ok;
    ok = TweakDBManager.SetFlat(id + t".delay", 0.0) && ok;
    ok = TweakDBManager.UpdateRecord(id) && ok;
    let result = TweakDBInterface.GetAISubActionShootWithWeaponRecord(id);
    return ok && IsDefined(result) && result.GetWeaponSlotsCount() == 1
      && Equals(result.GetWeaponSlotsItem(0).GetID(), slot)
      && Equals(result.Target().GetID(), t"AIActionTarget.CombatTarget")
      && result.NumberOfShots() == -1 && result.MaxNumberOfShots() == -1
      && result.GetPauseConditionCount() == source.GetPauseConditionCount();
  }

  private func MakeLook(name: CName, id: TweakDBID, preset: TweakDBID) -> Bool {
    let wounded = TweakDBInterface.GetAIActionRecord(t"ShootActions.WoundedShoot");
    if !IsDefined(wounded) {
      return false;
    }
    let i = 0;
    while i < wounded.GetLookatsCount() {
      let source = wounded.GetLookatsItem(i);
      if IsDefined(source) && IsDefined(source.Preset()) && Equals(source.Preset().GetID(), preset) {
        if !this.Clone(name, source.GetID()) {
          return false;
        }
        // Eligibility is checked against the actual equipped gun and intact
        // hand by this NPC's controller. No standing-wound predicates change.
        let ok = TweakDBManager.SetFlat(id + t".activationCondition", TDBID.None());
        let aimOffset = source.Offset();
        if Equals(id, t"CazanuLimbSurvival.SeatedLookRight") {
          // A small visual lowering relative to the existing chest target.
          // Start from the native source each time; never accumulate offsets.
          aimOffset.Z -= 0.12;
        }
        ok = TweakDBManager.SetFlat(id + t".offset", aimOffset) && ok;
        ok = TweakDBManager.UpdateRecord(id) && ok;
        let result = TweakDBInterface.GetAIActionLookAtDataRecord(id);
        if !ok || !IsDefined(result) { return false; }
        let checkedOffset = result.Offset();
        return IsDefined(result.Target()) && Equals(result.Preset().GetID(), preset)
          && !IsDefined(result.ActivationCondition())
          && checkedOffset.X == aimOffset.X && checkedOffset.Y == aimOffset.Y
          && checkedOffset.Z == aimOffset.Z;
      }
      i += 1;
    }
    return false;
  }

  private func Build() -> Bool {
    let ok = this.MakeShoot(n"CazanuLimbSurvival.SeatedShootRight", t"CazanuLimbSurvival.SeatedShootRight", t"AttachmentSlots.WeaponRight");
    ok = this.MakeShoot(n"CazanuLimbSurvival.SeatedShootLeft", t"CazanuLimbSurvival.SeatedShootLeft", t"AttachmentSlots.WeaponLeft") && ok;
    ok = this.MakeLook(n"CazanuLimbSurvival.SeatedLookRight", t"CazanuLimbSurvival.SeatedLookRight", t"LookatPreset.Corpo_Handgun_Right_Arm_LootAt") && ok;
    ok = this.MakeLook(n"CazanuLimbSurvival.SeatedLookLeft", t"CazanuLimbSurvival.SeatedLookLeft", t"LookatPreset.Corpo_Handgun_Left_Arm_LootAt") && ok;
    ok = this.MakeLook(n"CazanuLimbSurvival.SeatedLookBody", t"CazanuLimbSurvival.SeatedLookBody", t"LookatPreset.Corpo_Handgun_Body_LootAt") && ok;
    return ok;
  }
}
