module MuchBetterAI.Core

public static func MBAI_WeaponBand(distance: Float, weaponType: gamedataItemType) -> Float {
  switch weaponType {
    case gamedataItemType.Wea_Shotgun:
    case gamedataItemType.Wea_ShotgunDual:
      if distance <= 12.0 { return 1.0; };
      if distance <= 18.0 { return 0.70; };
      if distance <= 28.0 { return 0.35; };
      return 0.15;
    case gamedataItemType.Wea_SubmachineGun:
      if distance <= 16.0 { return 1.0; };
      if distance <= 26.0 { return 0.75; };
      if distance <= 38.0 { return 0.45; };
      return 0.25;
    case gamedataItemType.Wea_Handgun:
      if distance < 6.0 { return 0.80; };
      if distance <= 24.0 { return 1.0; };
      if distance <= 36.0 { return 0.70; };
      if distance <= 48.0 { return 0.45; };
      return 0.25;
    case gamedataItemType.Wea_Revolver:
      if distance <= 14.0 { return 1.0; };
      if distance <= 28.0 { return 0.78; };
      if distance <= 42.0 { return 0.45; };
      return 0.25;
    case gamedataItemType.Wea_SniperRifle:
      if distance < 14.0 { return 0.45; };
      if distance <= 28.0 { return 0.70; };
      if distance <= 75.0 { return 1.0; };
      if distance <= 90.0 { return 0.75; };
      return 0.45;
    case gamedataItemType.Wea_PrecisionRifle:
      if distance < 10.0 { return 0.65; };
      if distance <= 18.0 { return 0.85; };
      if distance <= 50.0 { return 1.0; };
      if distance <= 65.0 { return 0.75; };
      return 0.45;
    case gamedataItemType.Wea_LightMachineGun:
      if distance < 8.0 { return 0.75; };
      if distance <= 36.0 { return 1.0; };
      if distance <= 50.0 { return 0.75; };
      return 0.45;
    case gamedataItemType.Wea_HeavyMachineGun:
      if distance < 8.0 { return 0.55; };
      if distance <= 18.0 { return 0.75; };
      if distance <= 55.0 { return 1.0; };
      if distance <= 75.0 { return 0.70; };
      return 0.45;
    case gamedataItemType.Wea_AssaultRifle:
    case gamedataItemType.Wea_Rifle:
      if distance < 8.0 { return 0.80; };
      if distance <= 34.0 { return 1.0; };
      if distance <= 48.0 { return 0.70; };
      if distance <= 60.0 { return 0.45; };
      return 0.30;
    default:
      if distance < 8.0 { return 0.80; };
      if distance <= 30.0 { return 1.0; };
      if distance <= 45.0 { return 0.70; };
      return 0.45;
  };
}
