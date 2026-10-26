module MuchBetterAI.Stealth

@if(ModuleExists("AiTriggerOverhaul"))
import AiTriggerOverhaul.Settings

@if(ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsMovement() -> Bool {
  return Settings.ModIsEnabled();
}

@if(ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsInteraction() -> Bool {
  return Settings.ModIsEnabled();
}

@if(ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsDisposal() -> Bool {
  return Settings.ModIsEnabled();
}

@if(!ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsMovement() -> Bool {
  return false;
}

@if(!ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsInteraction() -> Bool {
  return false;
}

@if(!ModuleExists("AiTriggerOverhaul"))
public func MBAI_Acoustic_ATOOwnsDisposal() -> Bool {
  return false;
}
