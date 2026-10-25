module CazanuLimbSurvival

// Add only an empty holder before normal component initialization. The seated
// animation resource is requested later, for an eligible injured NPC only.
public class SeatedComponentService extends ScriptableService {
  private let cls_registered: Bool;
  private let cls_loggedAdded: Bool;
  private let cls_loggedMissingRecord: Bool;

  private cb func OnLoad() -> Void {
    if this.cls_registered { return; }
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Entity/Extract", this, n"OnNPCExtract")
      .AddTarget(EntityTarget.Type(n"NPCPuppet"));
    this.cls_registered = true;
    if Diagnostics.Enabled() {
      Diagnostics.Write("SEATED component_service_registered");
    }
  }

  private cb func OnNPCExtract(evt: ref<EntityBuilderEvent>) -> Void {
    let builder = evt.GetEntityBuilder();
    if !IsDefined(builder) || !builder.HasEntity() { return; }
    let template = builder.GetTemplate();
    if !IsDefined(template) || !IsDefined(template.GetEntity() as NPCPuppet) { return; }
    // Puppet.GetRecordID is assigned only during entity initialization. The
    // builder already carries the actual spawn record at this earlier stage.
    let record = TweakDBInterface.GetCharacterRecord(builder.GetRecordID());
    if !IsDefined(record) || !IsDefined(record.CharacterType()) {
      if Diagnostics.Enabled() && !this.cls_loggedMissingRecord {
        this.cls_loggedMissingRecord = true;
        Diagnostics.Write("SEATED component_skipped_missing_record");
      }
      return;
    }
    if NotEquals(record.CharacterType().Type(), gamedataNPCType.Human) { return; }
    if NPCFilter.MechanicalRecord(record.GetID()) { return; }
    let components = template.GetComponents();
    let i = 0;
    while i < ArraySize(components) {
      if IsDefined(components[i]) && Equals(components[i].name, n"CLS_SeatedWorkspot") {
        return;
      }
      i += 1;
    }
    let component = new WorkspotResourceComponent();
    component.name = n"CLS_SeatedWorkspot";
    template.AddComponent(component);
    if Diagnostics.Enabled() && !this.cls_loggedAdded {
      this.cls_loggedAdded = true;
      Diagnostics.Write("SEATED component_added_before_initialization");
    }
  }
}
