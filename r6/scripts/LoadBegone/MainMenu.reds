module LoadBegone

@if(ModuleExists("LoadBegone.Native"))
import LoadBegone.Native.*

@addField(UI_SystemDef)
public let LoadBegoneUsed: Bool;

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
func LoadBegoneLog(text: String) -> Void {
    Log(text);
}

@if(!ModuleExists("LoadBegone.Native"))
func LoadBegoneLog(text: String) -> Void {}

@addField(SingleplayerMenuGameController)
private let m_lbTimer: ref<inkAnimProxy>;

@addField(SingleplayerMenuGameController)
private let m_lbViaMenu: Bool;

@addField(SingleplayerMenuGameController)
private let m_lbWaited: Float;

@addField(SingleplayerMenuGameController)
private let m_lbSettled: Bool;

@wrapMethod(SingleplayerMenuGameController)
protected cb func OnSavesForLoadReady(saves: array<String>) -> Bool {
    let result = wrappedMethod(saves);
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
protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.m_lbTimer) {
        this.m_lbTimer.UnregisterFromCallback(inkanimEventType.OnFinish, this, n"OnLoadBegoneDue");
        this.m_lbTimer.Stop();
        this.m_lbTimer = null;
        LoadBegoneReleaseIntro(false);
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
    let root: wref<inkWidget> = this.GetRootWidget();
    if !IsDefined(root) {
        return;
    }
    this.m_lbTimer = root.PlayAnimation(def);
    this.m_lbTimer.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnLoadBegoneDue");
}

@addMethod(SingleplayerMenuGameController)
protected cb func OnLoadBegoneDue(proxy: ref<inkAnimProxy>) -> Bool {
    this.m_lbTimer = null;
    let config = LoadBegoneReadConfig();

    if !this.m_lbViaMenu {
        if config.holdEscForMenu && LoadBegoneEscHeld() {
            LoadBegoneLog("Esc held, going to the main menu");
            LoadBegoneReleaseIntro(false);
            return false;
        }
        if config.skipModWarning && (LoadBegoneIntroUp() || !LoadBegoneHasNative()) {
            LoadBegoneLog("Loading last save");
            this.GetSystemRequestsHandler().LoadLastCheckpoint(false);
            LoadBegoneReleaseIntro(true);
            return true;
        }
        this.m_lbViaMenu = true;
        LoadBegoneReleaseIntro(false);
    }
    if LoadBegoneIntroUp() && this.m_lbWaited < 60.0 {
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
    if this.m_isModded && !config.skipModWarning {
        this.LoadModdedSave(0);
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
