// UniversalIconicWeapons.reds
// Converts all eligible weapons in Cyberpunk 2077 2.50 into true Iconic weapons:
//   1. Sets BaseStats.IsItemIconic = 1.0 & wraps RPGManager.IsItemIconic (Gold Iconic UI, loot beam, Upgrade tab).
//   2. Attaches dynamic n"IconicWeapon" tag (enables weapon mod swapping & blocks accidental scrap/disassemble).
//   3. Converts non-Iconic loot/crafted tier modifiers into the official Iconic upgrade curves
//      (iconic_upgrades_amount_to_quality & iconic_upgrades_amount_to_plus on WasItemUpgraded)
//      so every weapon upgrades cleanly from Tier 1 through Tier 5++ (EffectiveTier = 10).
//   4. Rolls a persistent per-weapon random pool of Iconic stats + special hidden Iconic mechanics
//      across Core Combat, Ranged/Melee Handling, Elemental Infliction, Universal Hidden Mechanics,
//      and Weapon-Evolution Signature Mechanics (Power / Tech / Smart / Blade / Blunt).

module CustomRedscriptSuite.UniversalIconicWeapons

@addField(PlayerPuppet)
private let customRedscriptCraftingInProgress: Bool;

public class UniversalIconicWeaponHelper {

  public final static func IsEligibleItemID(itemID: ItemID) -> Bool {
    if !ItemID.IsValid(itemID) || !RPGManager.IsItemWeapon(itemID) {
      return false;
    };
    let itemType: gamedataItemType = RPGManager.GetItemType(itemID);
    return NotEquals(itemType, gamedataItemType.Wea_Fists)
      && NotEquals(itemType, gamedataItemType.Cyb_StrongArms)
      && NotEquals(itemType, gamedataItemType.Cyb_NanoWires)
      && NotEquals(itemType, gamedataItemType.Cyb_MantisBlades)
      && NotEquals(itemType, gamedataItemType.Cyb_Launcher);
  }

  public final static func IsEligibleWeapon(itemData: wref<gameItemData>) -> Bool {
    if !IsDefined(itemData) {
      return false;
    };
    return UniversalIconicWeaponHelper.IsEligibleItemID(itemData.GetID());
  }

  private final static func AddSavedStat(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    statType: gamedataStatType,
    modType: gameStatModifierType,
    value: Float
  ) -> Void {
    if !IsDefined(statsSystem) || !StatsObjectID.IsDefined(statsId) {
      return;
    }
    let mod: ref<gameStatModifierData> = RPGManager.CreateStatModifier(statType, modType, value);
    if IsDefined(mod) {
      statsSystem.AddSavedModifier(statsId, mod);
    }
  }

  private final static func EnsureSaberSignaturePackage(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    itemData: ref<gameItemData>
  ) -> Void {
    if !IsDefined(statsSystem) || !StatsObjectID.IsDefined(statsId) || !IsDefined(itemData)
      || !Equals(itemData.GetID().GetTDBID(), t"Items.Saber_DarthVader") {
      return;
    }

    let current: Float = itemData.GetStatValueByType(gamedataStatType.TriggerDismembermentChance);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerDismembermentChance, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.HitDismembermentFactor);
    if current < 3.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitDismembermentFactor, gameStatModifierType.Additive, 3.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.TriggerWoundedChance);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerWoundedChance, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.HitWoundsFactor);
    if current < 3.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitWoundsFactor, gameStatModifierType.Additive, 3.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.AttackSpeed);
    if current < 1.50 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AttackSpeed, gameStatModifierType.AdditiveMultiplier, 1.50);
    }
    current = itemData.GetStatValueByType(gamedataStatType.AttackSpeed);
    if current < 2.50 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AttackSpeed, gameStatModifierType.Additive, 2.50);
    }
    current = itemData.GetStatValueByType(gamedataStatType.BaseMeleeAttackStaminaCost);
    if current > 0.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BaseMeleeAttackStaminaCost, gameStatModifierType.Multiplier, 0.00);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanIgnoreWeaponStaminaPenaties);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanIgnoreWeaponStaminaPenaties, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanWeaponIgnoreArmor);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponIgnoreArmor, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanDealFullDamageToArmored);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanDealFullDamageToArmored, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.BurningApplicationRate);
    if current < 100.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BurningApplicationRate, gameStatModifierType.Additive, 100.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanBurningCriticallyHit);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBurningCriticallyHit, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.ElectrocutedApplicationRate);
    if current < 100.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ElectrocutedApplicationRate, gameStatModifierType.Additive, 100.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.BonusCritChanceVsElectrocutedEnemies);
    if current < 35.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusCritChanceVsElectrocutedEnemies, gameStatModifierType.Additive, 35.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.BleedingApplicationRate);
    if current < 100.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BleedingApplicationRate, gameStatModifierType.Additive, 100.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanBleedingCriticallyHit);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBleedingCriticallyHit, gameStatModifierType.Additive, 1.00 - current);
    }
    current = itemData.GetStatValueByType(gamedataStatType.CanBleedingSlowTarget);
    if current < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBleedingSlowTarget, gameStatModifierType.Additive, 1.00 - current);
    }
  }

  private final static func ApplyCoreOffensiveRoll(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    roll: Int32
  ) -> Void {
    switch roll {
      case 0:
        // +15% to +35% Base Weapon Damage (scales across all upgrade tiers)
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.DPS, gameStatModifierType.AdditiveMultiplier, RandRangeF(0.15, 0.35));
        break;
      case 1:
        // +12% to +28% Critical Hit Chance
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CritChance, gameStatModifierType.Additive, RandRangeF(12.00, 28.00));
        break;
      case 2:
        // +25% to +55% Critical Hit Damage
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CritDamage, gameStatModifierType.Additive, RandRangeF(25.00, 55.00));
        break;
      case 3:
        // +35% to +85% Headshot / Weakspot Damage Multiplier
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HeadshotDamageMultiplier, gameStatModifierType.Additive, RandRangeF(0.35, 0.85));
        break;
      case 4:
        // +20% to +45% Armor Penetration
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ArmorPenetrationBonus, gameStatModifierType.Additive, RandRangeF(20.00, 45.00));
        break;
      case 5:
        // +40% to +90% Stealth Hit Damage Multiplier
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.StealthHitDamageMultiplier, gameStatModifierType.Additive, RandRangeF(0.40, 0.90));
        break;
      case 6:
        // Apex Hunter: +18% to +40% Bonus Damage vs. Bosses and Elites
        let bossBonus: Float = RandRangeF(18.00, 40.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusDamageAgainstBosses, gameStatModifierType.Additive, bossBonus);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusDamageAgainstElites, gameStatModifierType.Additive, bossBonus);
        break;
      default:
        // Opener & Executioner: +18% to +38% Damage to enemies at Full HP and below Half HP
        let execBonus: Float = RandRangeF(18.00, 38.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusPercentDamageToEnemiesAtFullHealth, gameStatModifierType.Additive, execBonus);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusPercentDamageToEnemiesBelowHalfHealth, gameStatModifierType.Additive, execBonus);
        break;
    };
  }

  private final static func ApplyRangedHandlingRoll(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    roll: Int32
  ) -> Void {
    switch roll {
      case 0:
        // Hair-Trigger: 14% to 26% faster Rate of Fire
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CycleTimeBase, gameStatModifierType.Multiplier, RandRangeF(0.74, 0.86));
        break;
      case 1:
        // Snap-Sight: 22% to 40% faster Aim-Down-Sights (ADS) transition speed
        let aimMult: Float = RandRangeF(0.60, 0.78);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AimInTime, gameStatModifierType.Multiplier, aimMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AimOutTime, gameStatModifierType.Multiplier, aimMult);
        break;
      case 2:
        // Speed-Loader: 22% to 40% faster Tactical & Empty Reload Speed
        let reloadMult: Float = RandRangeF(0.60, 0.78);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ReloadTimeBase, gameStatModifierType.Multiplier, reloadMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.EmptyReloadTime, gameStatModifierType.Multiplier, reloadMult);
        break;
      case 3:
        // High-Velocity Barrel: +35% to +80% Effective Firing Range
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.EffectiveRange, gameStatModifierType.AdditiveMultiplier, RandRangeF(0.35, 0.80));
        break;
      case 4:
        // Gyro-Compensator: 40% to 65% Recoil Kick Reduction
        let recoilMult: Float = RandRangeF(0.35, 0.60);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.RecoilKickMin, gameStatModifierType.Multiplier, recoilMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.RecoilKickMax, gameStatModifierType.Multiplier, recoilMult);
        break;
      case 5:
        // Match-Grade Choke: 40% to 65% tighter Hip & ADS Bullet Spread
        let spreadMult: Float = RandRangeF(0.35, 0.60);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadDefaultX, gameStatModifierType.Multiplier, spreadMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadAdsDefaultX, gameStatModifierType.Multiplier, spreadMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadMaxX, gameStatModifierType.Multiplier, spreadMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadAdsMaxX, gameStatModifierType.Multiplier, spreadMult);
        break;
      default:
        // Reflex Target Acquisition: 30% to 50% faster ADS speed & reduced weapon sway
        let adsMult: Float = RandRangeF(0.50, 0.70);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AimInTime, gameStatModifierType.Multiplier, adsMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AimOutTime, gameStatModifierType.Multiplier, adsMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.Sway, gameStatModifierType.Multiplier, adsMult);
        break;
    };
  }

  private final static func ApplyMeleeHandlingRoll(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    roll: Int32
  ) -> Void {
    switch roll {
      case 0:
        // Overclocked Servo Swing: +18% to +38% faster Melee Attack Speed
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.AttackSpeed, gameStatModifierType.AdditiveMultiplier, RandRangeF(0.18, 0.38));
        break;
      case 1:
        // Zero-Drag Grip: 35% to 60% reduced Melee Attack & Block Stamina Cost
        let stamMult: Float = RandRangeF(0.40, 0.65);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BaseMeleeAttackStaminaCost, gameStatModifierType.Multiplier, stamMult);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.StaminaCostToBlock, gameStatModifierType.Multiplier, stamMult);
        break;
      case 2:
        // Relentless Combo Flow: +30% to +60% longer Melee Combo Window
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.MeleeAttackComboDuration, gameStatModifierType.AdditiveMultiplier, RandRangeF(0.30, 0.60));
        break;
      default:
        // Pneumatic Impact: +45% to +90% stronger Knockdown & Physical Impulse
        let impulseBonus: Float = RandRangeF(0.45, 0.90);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.KnockdownImpulse, gameStatModifierType.AdditiveMultiplier, impulseBonus);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.PhysicalImpulse, gameStatModifierType.AdditiveMultiplier, impulseBonus);
        break;
    };
  }

  private final static func ApplyElementalRoll(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    roll: Int32
  ) -> Void {
    let procRate: Float = RandRangeF(15.00, 35.00);
    switch roll {
      case 0:
        // Hemorrhage Inflictor: Bleed Chance + Critical Bleeding + Slow on Bleed
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BleedingApplicationRate, gameStatModifierType.Additive, procRate);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBleedingCriticallyHit, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBleedingSlowTarget, gameStatModifierType.Additive, 1.00);
        break;
      case 1:
        // Thermite Incendiary: Burn Chance + Critical Burning
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BurningApplicationRate, gameStatModifierType.Additive, procRate);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanBurningCriticallyHit, gameStatModifierType.Additive, 1.00);
        break;
      case 2:
        // Corrosive Neurotoxin: Poison Chance + Armor Corrosion + Poison Slow
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.PoisonedApplicationRate, gameStatModifierType.Additive, procRate);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanPoisonLowerArmor, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanPoisonSlow, gameStatModifierType.Additive, 1.00);
        break;
      default:
        // High-Voltage Arc: Electrocute Chance + Bonus Crit Chance vs. Electrocuted Targets
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ElectrocutedApplicationRate, gameStatModifierType.Additive, procRate);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusCritChanceVsElectrocutedEnemies, gameStatModifierType.Additive, RandRangeF(20.00, 35.00));
        break;
    };
  }

  private final static func ApplyHiddenIconicMechanicRoll(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    isRanged: Bool,
    roll: Int32
  ) -> Void {
    switch roll {
      case 0:
        // Hidden Mechanic 1: True Armor-Piercing Core (100% bypasses enemy armor mitigation)
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponIgnoreArmor, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanDealFullDamageToArmored, gameStatModifierType.Additive, 1.00);
        break;
      case 1:
        // Hidden Mechanic 2: Hyper-Velocity Zero Falloff & Deadeye First Shot
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.DamageFalloffDisabled, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadZeroOnFirstShot, gameStatModifierType.Additive, 1.00);
        break;
      case 2:
        // Hidden Mechanic 3: Ghost-Runner Tactical Harness (Reload while sprinting/sliding/vaulting + zero reload slow + no stamina penalties)
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponReloadWhileSprinting, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponReloadWhileSliding, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponReloadWhileVaulting, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.IsNotSlowedDuringReload, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanIgnoreWeaponStaminaPenaties, gameStatModifierType.Additive, 1.00);
        break;
      case 3:
        // Hidden Mechanic 4: Split-Chamber Multishot (Ranged) / Vampiric Bloodbath (Melee)
        if isRanged {
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ProjectilesPerShotBase, gameStatModifierType.Additive, 1.00);
        } else {
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HealOnKillingBleedingTarget, gameStatModifierType.Additive, 25.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanIgnoreWeaponStaminaPenaties, gameStatModifierType.Additive, 1.00);
        };
        break;
      case 4:
        // Hidden Mechanic 5: Executioner Dismemberment Matrix & Stagger
        // Pair HitWoundsFactor + TriggerWoundedChance with HitDismembermentFactor so living limb dismemberment
        // (CazanuLimbSurvival) triggers non-lethally before health is depleted.
        if !isRanged {
          break;
        }
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitDismembermentFactor, gameStatModifierType.Additive, 1.50);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerDismembermentChance, gameStatModifierType.Additive, 0.40);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitWoundsFactor, gameStatModifierType.Additive, 1.50);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerWoundedChance, gameStatModifierType.Additive, 0.40);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanQuickMeleeStagger, gameStatModifierType.Additive, 1.00);
        break;
      default:
        break;
    };
  }

  private final static func ApplyCraftedHiddenMechanic(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID
  ) -> Void {
    // V-crafted weapons get this deterministic hidden package instead of the
    // single random world/purchased roll: 40% dismemberment and full armor
    // bypass.  Cazanu's living-limb path also consumes the wound pair, so keep
    // both pairs together instead of leaving the visible dismemberment stat
    // disconnected from the accumulated wound threshold.
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitDismembermentFactor, gameStatModifierType.Additive, 1.50);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerDismembermentChance, gameStatModifierType.Additive, 0.40);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitWoundsFactor, gameStatModifierType.Additive, 1.50);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerWoundedChance, gameStatModifierType.Additive, 0.40);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanWeaponIgnoreArmor, gameStatModifierType.Additive, 1.00);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanDealFullDamageToArmored, gameStatModifierType.Additive, 1.00);
  }

  private final static func ApplyCraftedWoundBridge(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    itemData: ref<gameItemData>
  ) -> Void {
    if !IsDefined(itemData) || !WeaponObject.IsRanged(itemData.GetID()) {
      return;
    }
    // Marker 4.0 was shipped before the wound pair was added.  Repair only
    // that missing bridge so existing dismemberment/armor rolls are not doubled.
    if itemData.GetStatValueByType(gamedataStatType.HitWoundsFactor) < 1.50 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HitWoundsFactor, gameStatModifierType.Additive, 1.50);
    }
    if itemData.GetStatValueByType(gamedataStatType.TriggerWoundedChance) < 0.40 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TriggerWoundedChance, gameStatModifierType.Additive, 0.40);
    }
  }

  public final static func RepairIconicUpgradeCurvesIfNeeded(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    itemData: ref<gameItemData>
  ) -> Void {
    if !IsDefined(statsSystem) || !StatsObjectID.IsDefined(statsId) || !IsDefined(itemData) {
      return;
    }

    let isSaber: Bool = Equals(itemData.GetID().GetTDBID(), t"Items.Saber_DarthVader");
    if isSaber {
      UniversalIconicWeaponHelper.EnsureSaberSignaturePackage(statsSystem, statsId, itemData);
    }
    let quality: Float = itemData.GetStatValueByType(gamedataStatType.Quality);
    let plus: Float = itemData.GetStatValueByType(gamedataStatType.IsItemPlus);
    let upgrades: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let needsCurveRepair: Bool = isSaber || (UniversalIconicWeaponHelper.IsEligibleWeapon(itemData)
      && upgrades >= 2.00 && plus < 1.00 && quality >= 4.00);
    if !needsCurveRepair {
      return;
    }

    let initialUpgrades: Float = 0.00;
    if upgrades <= 0.00 {
      initialUpgrades = Cast<Float>(RoundF(ClampF(quality * 2.00 + plus, 0.00, 10.00)));
    }

    // Remove both transient and saved copies of the old random/tier curves.
    // The second pass is intentional: older saves can carry one copy in each
    // modifier bucket, while current saves generally use only the saved path.
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.Quality, false);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.Quality, true);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.RandomCurveInput, false);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.RandomCurveInput, true);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.IsItemPlus, false);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.IsItemPlus, true);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.QualityToMaxQualityRatio, false);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.QualityToMaxQualityRatio, true);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.CommonTierFailsafe, false);
    statsSystem.RemoveAllModifiers(statsId, gamedataStatType.CommonTierFailsafe, true);

    if itemData.GetStatValueByType(gamedataStatType.ScalingBlocked) < 1.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ScalingBlocked, gameStatModifierType.Additive, 1.00);
    }
    if initialUpgrades > 0.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, initialUpgrades);
    }

    let qualityCurveMod: ref<gameStatModifierData> = RPGManager.CreateStatModifierUsingCurve(
      gamedataStatType.Quality,
      gameStatModifierType.Additive,
      gamedataStatType.WasItemUpgraded,
      n"quality_curves",
      n"iconic_upgrades_amount_to_quality"
    );
    let plusCurveMod: ref<gameStatModifierData> = RPGManager.CreateStatModifierUsingCurve(
      gamedataStatType.IsItemPlus,
      gameStatModifierType.Additive,
      gamedataStatType.WasItemUpgraded,
      n"quality_curves",
      n"iconic_upgrades_amount_to_plus"
    );
    if IsDefined(qualityCurveMod) {
      statsSystem.AddSavedModifier(statsId, qualityCurveMod);
    }
    if IsDefined(plusCurveMod) {
      statsSystem.AddSavedModifier(statsId, plusCurveMod);
    }

  }

  private final static func ApplyEvolutionSignatureMechanic(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    evolution: gamedataWeaponEvolution
  ) -> Void {
    let subRoll: Int32 = RandRange(0, 2);
    switch evolution {
      case gamedataWeaponEvolution.Power:
        if subRoll == 0 {
          // Power Signature A: Hyper-Ricochet Engine
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.RicochetCount, gameStatModifierType.Additive, 2.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.RicochetChance, gameStatModifierType.Additive, 0.50);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusRicochetDamage, gameStatModifierType.Additive, RandRangeF(25.00, 45.00));
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.BonusRicochetCritChance, gameStatModifierType.Additive, 25.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanSeeRicochetVisuals, gameStatModifierType.Additive, 1.00);
        } else {
          // Power Signature B: High-Caliber Stopping Power
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.KnockdownImpulse, gameStatModifierType.AdditiveMultiplier, 0.50);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SpreadZeroOnFirstShot, gameStatModifierType.Additive, 1.00);
        };
        break;
      case gamedataWeaponEvolution.Tech:
        if subRoll == 0 {
          // Tech Signature A: Overcharged Rail Capacitor
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ChargeTime, gameStatModifierType.Multiplier, 0.65);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ChargeFullMultiplier, gameStatModifierType.Additive, 0.35);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanControlFullyChargedWeapon, gameStatModifierType.Additive, 1.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.TechPierceDamageFactor, gameStatModifierType.Additive, 0.35);
        } else {
          // Tech Signature B: Full-Auto Storm Capacitor
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.FullAutoOnFullCharge, gameStatModifierType.Additive, 1.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ChargeTime, gameStatModifierType.Multiplier, 0.72);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ChargeMaxTimeInChargedState, gameStatModifierType.Additive, 2.50);
        };
        break;
      case gamedataWeaponEvolution.Smart:
        if subRoll == 0 {
          // Smart Signature A: Multi-Target Neural Swarm
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunAdsTimeToLock, gameStatModifierType.Multiplier, 0.50);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunHipTimeToLock, gameStatModifierType.Multiplier, 0.50);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunAdsMaxLockedTargets, gameStatModifierType.Additive, 2.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunHipMaxLockedTargets, gameStatModifierType.Additive, 2.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunTrackMultipleEntitiesInADS, gameStatModifierType.Additive, 1.00);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunKeepTargetsOnAimStateChange, gameStatModifierType.Additive, 1.00);
        } else {
          // Smart Signature B: Hypersonic Seeker Darts
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunPlayerProjectileVelocity, gameStatModifierType.Multiplier, 1.45);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunHitProbabilityMultiplier, gameStatModifierType.Additive, 0.35);
          UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.SmartGunKeepTargetsOnAimStateChange, gameStatModifierType.Additive, 1.00);
        };
        break;
      case gamedataWeaponEvolution.Blade:
      case gamedataWeaponEvolution.Blunt:
        // Melee / Thrown Signature: Magnetic Boomerang Return & Bloodlust
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ThrowRecovery, gameStatModifierType.Multiplier, 0.45);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.CanIgnoreWeaponStaminaPenaties, gameStatModifierType.Additive, 1.00);
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.HealOnKillingBleedingTarget, gameStatModifierType.Additive, 20.00);
        break;
      default:
        break;
    };
  }

  private final static func RollRandomIconicStatPackage(
    statsSystem: ref<StatsSystem>,
    statsId: StatsObjectID,
    itemData: ref<gameItemData>,
    craftedByPlayer: Bool
  ) -> Void {
    let itemId: ItemID = itemData.GetID();
    let isRanged: Bool = WeaponObject.IsRanged(itemId);
    let evolution: gamedataWeaponEvolution = RPGManager.GetWeaponEvolution(itemId);

    // V-crafted weapons use the same modifier package as world-found and
    // purchased weapons.  The previous extra-roll branch made crafted saves
    // diverge from the ordinary Iconic pool and overpowered the result.
    let coreCount: Int32 = 2;
    let core1: Int32 = RandRange(0, 8);
    let core2: Int32 = (core1 + RandRange(1, 8)) % 8;
    UniversalIconicWeaponHelper.ApplyCoreOffensiveRoll(statsSystem, statsId, core1);
    UniversalIconicWeaponHelper.ApplyCoreOffensiveRoll(statsSystem, statsId, core2);
    if coreCount >= 3 {
      let core3: Int32 = (core2 + RandRange(1, 8)) % 8;
      let uniqueCore3: Int32 = core3;
      while uniqueCore3 == core1 || uniqueCore3 == core2 {
        uniqueCore3 = (uniqueCore3 + 1) % 8;
      };
      UniversalIconicWeaponHelper.ApplyCoreOffensiveRoll(statsSystem, statsId, uniqueCore3);
    };

    let handlingCount: Int32 = 2;
    if isRanged {
      let hand1: Int32 = RandRange(0, 7);
      let hand2: Int32 = (hand1 + RandRange(1, 7)) % 7;
      UniversalIconicWeaponHelper.ApplyRangedHandlingRoll(statsSystem, statsId, hand1);
      UniversalIconicWeaponHelper.ApplyRangedHandlingRoll(statsSystem, statsId, hand2);
      if handlingCount >= 3 {
        let hand3: Int32 = (hand2 + RandRange(1, 7)) % 7;
        let uniqueHand3: Int32 = hand3;
        while uniqueHand3 == hand1 || uniqueHand3 == hand2 {
          uniqueHand3 = (uniqueHand3 + 1) % 7;
        };
        UniversalIconicWeaponHelper.ApplyRangedHandlingRoll(statsSystem, statsId, uniqueHand3);
      };
    } else {
      let melee1: Int32 = RandRange(0, 4);
      let melee2: Int32 = (melee1 + RandRange(1, 4)) % 4;
      UniversalIconicWeaponHelper.ApplyMeleeHandlingRoll(statsSystem, statsId, melee1);
      UniversalIconicWeaponHelper.ApplyMeleeHandlingRoll(statsSystem, statsId, melee2);
      if handlingCount >= 3 {
        let melee3: Int32 = (melee2 + RandRange(1, 4)) % 4;
        let uniqueMelee3: Int32 = melee3;
        while uniqueMelee3 == melee1 || uniqueMelee3 == melee2 {
          uniqueMelee3 = (uniqueMelee3 + 1) % 4;
        };
        UniversalIconicWeaponHelper.ApplyMeleeHandlingRoll(statsSystem, statsId, uniqueMelee3);
      };
    };

    let elementalCount: Int32 = 1;
    let elem1: Int32 = RandRange(0, 4);
    UniversalIconicWeaponHelper.ApplyElementalRoll(statsSystem, statsId, elem1);
    if elementalCount >= 2 {
      let elem2: Int32 = (elem1 + RandRange(1, 4)) % 4;
      UniversalIconicWeaponHelper.ApplyElementalRoll(statsSystem, statsId, elem2);
      if elementalCount >= 3 {
        let elem3: Int32 = (elem2 + RandRange(1, 4)) % 4;
        let uniqueElem3: Int32 = elem3;
        while uniqueElem3 == elem1 || uniqueElem3 == elem2 {
          uniqueElem3 = (uniqueElem3 + 1) % 4;
        };
        UniversalIconicWeaponHelper.ApplyElementalRoll(statsSystem, statsId, uniqueElem3);
      };
    };

    if craftedByPlayer && isRanged {
      UniversalIconicWeaponHelper.ApplyCraftedHiddenMechanic(statsSystem, statsId);
    } else if !craftedByPlayer {
      // World/purchased weapons retain one random hidden mechanic.
      let hiddenRoll: Int32 = RandRange(0, 5);
      UniversalIconicWeaponHelper.ApplyHiddenIconicMechanicRoll(statsSystem, statsId, isRanged, hiddenRoll);
    };

    // All promoted weapons retain one weapon-evolution signature.
    UniversalIconicWeaponHelper.ApplyEvolutionSignatureMechanic(statsSystem, statsId, evolution);
  }

  public final static func PromoteWeaponToIconic(game: GameInstance, itemData: ref<gameItemData>) -> Void {
    if !GameInstance.IsValid(game) || !UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
      return;
    };

    let itemRecord: wref<Item_Record> = TweakDBInterface.GetItemRecord(itemData.GetID().GetTDBID());
    let isNativeIconicRecord: Bool = IsDefined(itemRecord) && itemRecord.TagsContains(n"IconicWeapon");

    // Always ensure the runtime dynamic tag n"IconicWeapon" is present (enables mod swapping & blocks scrap/disassemble)
    if !itemData.HasTag(n"IconicWeapon") {
      itemData.SetDynamicTag(n"IconicWeapon");
    };

    let craftedByPlayer: Bool = itemData.GetStatValueByType(gamedataStatType.IsItemCrafted) >= 1.00
      || itemData.HasTag(n"CustomRedscriptCraftedWeapon");
    let craftedRangedByPlayer: Bool = craftedByPlayer && WeaponObject.IsRanged(itemData.GetID());

    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
    if !IsDefined(statsSystem) {
      return;
    }
    let statsId: StatsObjectID = itemData.GetStatsObjectID();
    UniversalIconicWeaponHelper.RepairIconicUpgradeCurvesIfNeeded(statsSystem, statsId, itemData);

    // Older versions stamped the deterministic gun package onto every
    // crafted weapon.  Remove that package from existing non-Saber melee
    // weapons, while leaving the Saber signature package authoritative.
    // Existing crafted weapons promoted by the previous versions receive only
    // the missing deterministic package bridge, without rerolling other rolls.
    let currentMarker: Float = itemData.GetStatValueByType(gamedataStatType.IconicItemUpgraded);
    if craftedByPlayer && !WeaponObject.IsRanged(itemData.GetID())
      && !Equals(itemData.GetID().GetTDBID(), t"Items.Saber_DarthVader") && currentMarker >= 4.00 {
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.HitDismembermentFactor, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.TriggerDismembermentChance, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.HitWoundsFactor, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.TriggerWoundedChance, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.CanWeaponIgnoreArmor, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.CanDealFullDamageToArmored, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.IconicItemUpgraded, true);
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.IconicItemUpgraded, gameStatModifierType.Additive, 1.00);
      return;
    }
    if currentMarker >= 1.00 {
      if craftedRangedByPlayer && currentMarker < 5.00 {
        if currentMarker >= 4.00 {
          UniversalIconicWeaponHelper.ApplyCraftedWoundBridge(statsSystem, statsId, itemData);
        } else {
          UniversalIconicWeaponHelper.ApplyCraftedHiddenMechanic(statsSystem, statsId);
        }
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.IconicItemUpgraded, gameStatModifierType.Additive, 5.00 - currentMarker);
      };
      return;
    };

    // Layer 1: Ensure BaseStats.IsItemIconic = 1.0 is saved on the weapon
    if itemData.GetStatValueByType(gamedataStatType.IsItemIconic) <= 0.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.IsItemIconic, gameStatModifierType.Additive, 1.00);
    };

    // Layer 3: Convert non-Iconic weapon tier modifiers to the official Iconic WasItemUpgraded curves
    if !isNativeIconicRecord {
      let initialQuality: Float = itemData.GetStatValueByType(gamedataStatType.Quality);
      let initialPlus: Float = itemData.GetStatValueByType(gamedataStatType.IsItemPlus);
      let initialUpgrades: Float = Cast<Float>(RoundF(ClampF(initialQuality * 2.00 + initialPlus, 0.00, 10.00)));

      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.Quality, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.RandomCurveInput, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.IsItemPlus, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.QualityToMaxQualityRatio, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.CommonTierFailsafe, true);
      statsSystem.RemoveAllModifiers(statsId, gamedataStatType.WasItemUpgraded, true);

      if itemData.GetStatValueByType(gamedataStatType.ScalingBlocked) < 1.00 {
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.ScalingBlocked, gameStatModifierType.Additive, 1.00);
      };

      if initialUpgrades > 0.00 {
        UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, initialUpgrades);
      };

      let qualityCurveMod: ref<gameStatModifierData> = RPGManager.CreateStatModifierUsingCurve(
        gamedataStatType.Quality,
        gameStatModifierType.Additive,
        gamedataStatType.WasItemUpgraded,
        n"quality_curves",
        n"iconic_upgrades_amount_to_quality"
      );
      let plusCurveMod: ref<gameStatModifierData> = RPGManager.CreateStatModifierUsingCurve(
        gamedataStatType.IsItemPlus,
        gameStatModifierType.Additive,
        gamedataStatType.WasItemUpgraded,
        n"quality_curves",
        n"iconic_upgrades_amount_to_plus"
      );
      statsSystem.AddSavedModifier(statsId, qualityCurveMod);
      statsSystem.AddSavedModifier(statsId, plusCurveMod);
    };

    // Layer 4: Apply the shared world/purchased Iconic modifier package. New
    // crafted weapons use the same pool; existing saved modifiers are not
    // destructively removed because the old rolls were not ownership-marked.
    UniversalIconicWeaponHelper.RollRandomIconicStatPackage(statsSystem, statsId, itemData, craftedByPlayer);

    // Save persistent idempotency marker (1.0 = promoted standard weapon,
    // 2.0 = native Iconic with bonus roll, 5.0 = crafted ranged deterministic
    // hidden package)
    let markerVal: Float = craftedRangedByPlayer ? 5.00 : (isNativeIconicRecord ? 2.00 : 1.00);
    UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.IconicItemUpgraded, gameStatModifierType.Additive, markerVal);
  }

  public final static func PromoteAllPlayerWeapons(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    };
    let game: GameInstance = player.GetGame();
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(game);
    if !IsDefined(ts) {
      return;
    };
    let itemList: array<wref<gameItemData>>;
    ts.GetItemList(player, itemList);
    let i: Int32 = 0;
    let count: Int32 = ArraySize(itemList);
    while i < count {
      let itemData: ref<gameItemData> = itemList[i];
      if IsDefined(itemData) && UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
        UniversalIconicWeaponHelper.PromoteWeaponToIconic(game, itemData);
      };
      i += 1;
    };
  }

  public final static func MaximizeWeaponTier(game: GameInstance, itemData: ref<gameItemData>, opt anticipatedUpgrades: Int32) -> Void {
    if !GameInstance.IsValid(game) || !UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
      return;
    };
    UniversalIconicWeaponHelper.PromoteWeaponToIconic(game, itemData);
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(game);
    if !IsDefined(statsSystem) {
      return;
    };
    let statsId: StatsObjectID = itemData.GetStatsObjectID();
    if !StatsObjectID.IsDefined(statsId) {
      return;
    };
    UniversalIconicWeaponHelper.RepairIconicUpgradeCurvesIfNeeded(statsSystem, statsId, itemData);
    let currentValue: Float = itemData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
    let targetDelta: Float = 10.00 - currentValue - Cast<Float>(Max(0, anticipatedUpgrades));
    if targetDelta > 0.00 {
      UniversalIconicWeaponHelper.AddSavedStat(statsSystem, statsId, gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, targetDelta);
    };
  }
}

// Mark the item returned by crafting so it follows the shared Iconic package
// after vanilla has finished initializing its crafted state.
@wrapMethod(CraftingSystem)
private final func CraftItem(target: wref<GameObject>, itemRecord: ref<Item_Record>, amount: Int32, opt ammoBulletAmount: Int32) -> wref<gameItemData> {
  let crafter: ref<PlayerPuppet> = target as PlayerPuppet;
  if IsDefined(crafter) {
    crafter.customRedscriptCraftingInProgress = true;
  };
  let craftedItem: wref<gameItemData> = wrappedMethod(target, itemRecord, amount, ammoBulletAmount);
  if IsDefined(craftedItem) && UniversalIconicWeaponHelper.IsEligibleWeapon(craftedItem) {
    craftedItem.SetDynamicTag(n"CustomRedscriptCraftedWeapon");
    // CraftItem returns after vanilla MarkItemAsCrafted(), so promote here
    // after the item is fully initialized.
    UniversalIconicWeaponHelper.PromoteWeaponToIconic(this.GetGameInstance(), craftedItem);
  };
  if IsDefined(crafter) {
    crafter.customRedscriptCraftingInProgress = false;
  };
  return craftedItem;
}

// 1. Treat all eligible weapons as Iconic in UI, loot containers, scanner, vendors, and Upgrade screen filters
@wrapMethod(RPGManager)
public final static func IsItemIconic(itemData: wref<gameItemData>) -> Bool {
  if wrappedMethod(itemData) {
    return true;
  };
  return UniversalIconicWeaponHelper.IsEligibleWeapon(itemData);
}

@wrapMethod(RPGManager)
public final static func IsItemIconic(itemData: InnerItemData) -> Bool {
  if wrappedMethod(itemData) {
    return true;
  };
  return UniversalIconicWeaponHelper.IsEligibleItemID(InnerItemData.GetItemID(itemData));
}

// UIInventoryItem caches its iconic result when the UI object is created.
// Re-check eligibility here so vendor selling logic sees the promoted state.
@wrapMethod(UIInventoryItem)
public final func IsIconic() -> Bool {
  if wrappedMethod() {
    return true;
  };
  return UniversalIconicWeaponHelper.IsEligibleWeapon(this.GetItemData());
}

// Iconic weapons are already protected from accidental disassembly and the
// profile intentionally uses instant vendor selling. Bypass only the iconic
// sale confirmation; equipped-item and other vendor confirmations remain
// vanilla.
@wrapMethod(FullscreenVendorGameController)
private func OpenConfirmationPopup(itemData: wref<UIInventoryItem>, quantity: Int32, actionType: QuantityPickerActionType, opt type: VendorConfirmationPopupType) -> Void {
  if Equals(actionType, QuantityPickerActionType.Sell)
    && Equals(type, VendorConfirmationPopupType.Default)
    && IsDefined(itemData)
    && itemData.IsIconic() {
    this.SellItem(itemData.GetRealItemData(), quantity);
    return;
  }
  wrappedMethod(itemData, quantity, actionType, type);
}

// 2. Block disassembling/scrapping on all eligible weapons (identical to vanilla Iconic protection)
@wrapMethod(CraftingSystem)
public final const func CanItemBeDisassembled(itemData: wref<gameItemData>) -> Bool {
  if UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
    return false;
  };
  return wrappedMethod(itemData);
}

// 3. Promote newly looted/crafted/purchased weapons when added to player inventory
@wrapMethod(PlayerPuppet)
private final func SetIconicWeaponsTier(itemData: ref<gameItemData>) -> Void {
  if UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
    let itemRecord: wref<Item_Record> = TweakDBInterface.GetItemRecord(itemData.GetID().GetTDBID());
    let isNativeIconicRecord: Bool = IsDefined(itemRecord) && itemRecord.TagsContains(n"IconicWeapon");
    if this.customRedscriptCraftingInProgress {
      // GiveItem fires this callback before vanilla marks the item crafted.
      // Tag it but defer promotion until CraftItem returns.
      itemData.SetDynamicTag(n"CustomRedscriptCraftedWeapon");
      if isNativeIconicRecord {
        wrappedMethod(itemData);
      };
      return;
    };
    if isNativeIconicRecord {
      wrappedMethod(itemData);
    };
    UniversalIconicWeaponHelper.PromoteWeaponToIconic(this.GetGame(), itemData);
    return;
  };
  wrappedMethod(itemData);
}

// 4. Prevent non-Iconic IsItemPlus lock & non-Iconic retro-rescalers from touching weapons
@wrapMethod(PlayerPuppet)
private final func LockItemPlusOnNonIconicWeapons(itemData: ref<gameItemData>) -> Void {
  if UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
    return;
  };
  wrappedMethod(itemData);
}

@wrapMethod(PlayerPuppet)
private final func RetroRescaleNonIconicWeapons(itemData: ref<gameItemData>) -> Void {
  if UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
    UniversalIconicWeaponHelper.PromoteWeaponToIconic(this.GetGame(), itemData);
    return;
  };
  wrappedMethod(itemData);
}

@wrapMethod(Stash)
public final static func RetroScaleNonIconicWeaponsInStash(stashObj: ref<GameObject>, itemData: ref<gameItemData>) -> Void {
  if IsDefined(stashObj) && UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
    UniversalIconicWeaponHelper.PromoteWeaponToIconic(stashObj.GetGame(), itemData);
    return;
  };
  wrappedMethod(stashObj, itemData);
}

// 5. Promote all existing inventory weapons on spawn / save load
@wrapMethod(PlayerPuppet)
protected cb func OnMakePlayerVisibleAfterSpawn(evt: ref<EndGracePeriodAfterSpawn>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  UniversalIconicWeaponHelper.PromoteAllPlayerWeapons(this);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnUnifyIconicsUpgradeCountWithEffectiveTierEvent(evt: ref<UnifyIconicsUpgradeCountWithEffectiveTierEvent>) -> Bool {
  UniversalIconicWeaponHelper.PromoteAllPlayerWeapons(this);
  return wrappedMethod(evt);
}

// 6. Ensure weapon is promoted right before any CraftingSystem.UpgradeItem execution
@wrapMethod(CraftingSystem)
private final func UpgradeItem(owner: wref<GameObject>, itemID: ItemID) -> Void {
  if IsDefined(owner) {
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    if IsDefined(ts) {
      let itemData: wref<gameItemData> = ts.GetItemData(owner, itemID);
      if IsDefined(itemData) && UniversalIconicWeaponHelper.IsEligibleWeapon(itemData) {
        UniversalIconicWeaponHelper.PromoteWeaponToIconic(this.GetGameInstance(), itemData);
      };
    };
  };
  wrappedMethod(owner, itemID);
}
