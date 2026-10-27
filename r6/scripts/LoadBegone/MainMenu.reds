module LoadBegone

@if(ModuleExists("LoadBegone.Native"))
import LoadBegone.Native.*

@addField(UI_SystemDef)
public let LoadBegoneUsed: Bool;

@addField(UI_SystemDef)
public let LoadBegoneHiding: Bool;

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneEscHeld() -> Bool {
    return IsEscHeld();
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneEscHeld() -> Bool {
    return false;
}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneIntroUp() -> Bool {
    return IsIntroUp();
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneIntroUp() -> Bool {
    return false;
}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneHasNative() -> Bool {
    return true;
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneHasNative() -> Bool {
    return false;
}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneHoldIntro() -> Void {
    HoldIntro();
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneHoldIntro() -> Void {}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneReleaseIntro(loading: Bool) -> Void {
    ReleaseIntro(loading);
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneReleaseIntro(loading: Bool) -> Void {}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneStartScreenBusy() -> Bool {
    return IsStartScreenBusy();
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneStartScreenBusy() -> Bool {
    return false;
}

@if(ModuleExists("LoadBegone.Native"))
func LoadBegoneLog(text: String) -> Void {
    Log(text);
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneLog(text: String) -> Void {}

func LoadBegoneBlackLayer(root: ref<inkCompoundWidget>, name: CName) -> ref<inkRectangle> {
    let black = new inkRectangle();
    black.SetName(name);
    black.SetAnchor(inkEAnchor.Fill);
    black.SetTintColor(new HDRColor(0.0, 0.0, 0.0, 1.0));
    black.SetOpacity(1.0);
    black.Reparent(root);
    return black;
}

func LoadBegoneBlackout(root: ref<inkCompoundWidget>) -> Void {
    if !IsDefined(root) || IsDefined(root.GetWidget(n"LoadBegoneBlackTop")) {
        return;
    }
    root.SetOpacity(1.0);
    // Both ends of the child list, since which one draws on top isn't settled
    root.ReorderChild(LoadBegoneBlackLayer(root, n"LoadBegoneBlackBottom"), 0);
    LoadBegoneBlackLayer(root, n"LoadBegoneBlackTop");
}

func LoadBegoneBlackoutIfHiding(root: ref<inkCompoundWidget>) -> Void {
    if GetAllBlackboardDefs().UI_System.LoadBegoneHiding {
        LoadBegoneBlackout(root);
    }
}

func LoadBegoneLightsOn(root: ref<inkCompoundWidget>) -> Void {
    if !IsDefined(root) {
        return;
    }
    let top = root.GetWidget(n"LoadBegoneBlackTop");
    if IsDefined(top) {
        root.RemoveChild(top);
    }
    let bottom = root.GetWidget(n"LoadBegoneBlackBottom");
    if IsDefined(bottom) {
        root.RemoveChild(bottom);
    }
}

@addField(SingleplayerMenuGameController)
private let m_lbTimer: ref<inkAnimProxy>;

@addField(SingleplayerMenuGameController)
private let m_lbViaMenu: Bool;

@addField(SingleplayerMenuGameController)
private let m_lbWaited: Float;

@addField(SingleplayerMenuGameController)
private let m_lbSettled: Bool;

@addField(SingleplayerMenuGameController)
private let m_lbRecapId: Uint64;

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnSavesForLoadReady(saves: array<String>) -> Bool {
    let result = wrappedMethod(saves);
    let voice = this.GetSystemRequestsHandler().GetUserSettings().GetVar(n"/language", n"VoiceOver") as ConfigVarListName;
    if IsDefined(voice) {
        LoadBegoneSetVoiceLanguage(voice.GetValue());
    }
    let defs = GetAllBlackboardDefs().UI_System;
    if !defs.LoadBegoneUsed {
        defs.LoadBegoneUsed = true;
        let config = LoadBegoneReadConfig();
        if config.skipModWarning {
            this.LoadBegoneDisableModVerification();
        }
        if config.enabled && this.m_savesCount > 0 {
            LoadBegoneHoldIntro();
            this.LoadBegoneSchedule(MaxF(config.delay, 1.0 / 60.0));
        }
    }
    return result;
}

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    LoadBegoneBlackoutIfHiding(this.GetRootCompoundWidget());
    return result;
}

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnSaveMetadataReady(info: ref<SaveMetadataInfo>) -> Bool {
    if info.saveIndex == 0 && info.isValid {
        this.m_lbRecapId = info.initialLoadingScreenID;
    }
    return wrappedMethod(info);
}

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.m_lbTimer) {
        this.m_lbTimer.UnregisterFromCallback(inkanimEventType.OnFinish, this, n"OnLoadBegoneDue");
        this.m_lbTimer.Stop();
        this.m_lbTimer = null;
        LoadBegoneReleaseIntro(false);
        GetAllBlackboardDefs().UI_System.LoadBegoneUsed = false;
    }
    return wrappedMethod();
}

@addMethod(SingleplayerMenuGameController)
private final func LoadBegoneSchedule(seconds: Float) -> Void {
    let wait = new inkAnimTextValueProgress();
    wait.SetStartProgress(0.0);
    wait.SetEndProgress(0.0);
    wait.SetDuration(seconds);
    let def = new inkAnimDef();
    def.AddInterpolator(wait);
    this.m_lbTimer = this.GetRootWidget().PlayAnimation(def);
    this.m_lbTimer.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnLoadBegoneDue");
}

@addMethod(SingleplayerMenuGameController)
protected cb func OnLoadBegoneDue(proxy: ref<inkAnimProxy>) -> Bool {
    this.m_lbTimer = null;
    let config = LoadBegoneReadConfig();
    let playRecaps = !config.skipRecapVideos;

    if !this.m_lbViaMenu {
        if config.holdEscForMenu && LoadBegoneEscHeld() {
            LoadBegoneLog("Esc held, going to the main menu");
            GetAllBlackboardDefs().UI_System.LoadBegoneHiding = false;
            LoadBegoneLightsOn(this.GetRootCompoundWidget());
            LoadBegoneReleaseIntro(false);
            return false;
        }
        if config.skipModWarning && !playRecaps && (LoadBegoneIntroUp() || !LoadBegoneHasNative()) {
            LoadBegoneLog("Loading last save");
            this.GetSystemRequestsHandler().LoadLastCheckpoint(false);
            LoadBegoneReleaseIntro(true);
            return true;
        }
        this.m_lbViaMenu = true;
        if playRecaps {
            GetAllBlackboardDefs().UI_System.LoadBegoneHiding = true;
            LoadBegoneBlackout(this.GetRootCompoundWidget());
        }
        LoadBegoneReleaseIntro(false);
    }
    if (LoadBegoneIntroUp() || (playRecaps && LoadBegoneStartScreenBusy())) && this.m_lbWaited < 60.0 {
        this.m_lbWaited += 0.1;
        this.LoadBegoneSchedule(0.1);
        return false;
    }
    // Any sooner crashes the menu's HUD controllers
    if !this.m_lbSettled {
        this.m_lbSettled = true;
        this.LoadBegoneSchedule(1.0);
        return false;
    }
    LoadBegoneLog("Loading last save");
    GetAllBlackboardDefs().UI_System.LoadBegoneHiding = false;
    if this.m_isModded && !config.skipModWarning {
        LoadBegoneLightsOn(this.GetRootCompoundWidget());
        this.LoadModdedSave(0);
    } else if playRecaps && this.m_lbRecapId != 0ul {
        this.PreSpawnInitialLoadingScreen(this.m_lbRecapId);
        this.LoadSaveInGame(0);
    } else {
        this.GetSystemRequestsHandler().LoadLastCheckpoint(false);
    }
    return true;
}

@addMethod(SingleplayerMenuGameController)
private final func LoadBegoneDisableModVerification() -> Void {
    let setting = this.GetSystemRequestsHandler().GetUserSettings().GetVar(n"/gameplay/misc", n"EnableModVerification") as ConfigVarBool;
    if IsDefined(setting) && setting.GetValue() {
        setting.SetValue(false);
        LoadBegoneLog("Mod verification turned off");
    }
}

@wrapMethod(InitializeUserScreenGameController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    LoadBegoneBlackoutIfHiding(this.GetRootCompoundWidget());
    return result;
}

@wrapMethod(EngagementScreenGameController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    LoadBegoneBlackoutIfHiding(this.GetRootCompoundWidget());
    return result;
}

@wrapMethod(gameuiPreGameMenuGameController)
protected cb func OnInitialize() -> Bool {
    let result = wrappedMethod();
    LoadBegoneBlackoutIfHiding(this.GetRootCompoundWidget());
    return result;
}
