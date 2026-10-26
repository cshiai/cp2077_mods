module MuchBetterAI.Core


@if(ModuleExists("ImmersiveShootingAI.Configurations"))
public static func MBAI_ISAIInstalled() -> Bool {
  return true;
}

@if(!ModuleExists("ImmersiveShootingAI.Configurations"))
public static func MBAI_ISAIInstalled() -> Bool {
  return false;
}

public static func MBAI_OwnsSuppressionFire() -> Bool {
  return !MBAI_ISAIInstalled();
}
