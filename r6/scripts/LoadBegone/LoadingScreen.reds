module LoadBegone

@if(ModuleExists("LoadBegone.Native"))
import LoadBegone.Native.*

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneRecapScreenOpened(screen: ref<IScriptable>) -> Void {
    RecapScreenOpened(screen);
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneRecapScreenOpened(screen: ref<IScriptable>) -> Void {}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneSetVoiceLanguage(language: CName) -> Void {
    SetVoiceLanguage(language);
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneSetVoiceLanguage(language: CName) -> Void {}

@wrapMethod(InitialLoadingScreenLogicController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    LoadBegoneBlackBackdrop(this.GetRootCompoundWidget());
    LoadBegoneRecapScreenOpened(this);
    return result;
}

func LoadBegoneBlackBackdrop(root: ref<inkCompoundWidget>) -> Void {
    if !IsDefined(root) {
        return;
    }
    // Their tint is style-bound, so recolouring them doesn't stick
    let fader = root.GetWidget(n"Fader");
    if IsDefined(fader) {
        fader.SetVisible(false);
    }
    let glower = root.GetWidget(n"glower");
    if IsDefined(glower) {
        glower.SetVisible(false);
    }
}
