module INCF

public class MissingCorePopupTrigger extends ScriptableSystem {
  private let requested: Bool;
  private let shown: Bool;
  private let isWelcome: Bool;
  private let busyAttempts: Int32;
  private let waitAttempts: Int32;
  private let loadSerial: Int32;

  public static func WaitForGameplayDelay() -> Float { return 0.25; }
  public static func BusyRetryDelay() -> Float { return 1.00; }
  public static func ShowDelay() -> Float { return 4.00; }
  public static func MaxWaitAttempts() -> Int32 { return 240; }
  public static func MaxBusyAttempts() -> Int32 { return 30; }

  public func ResetForLoad() -> Void {
    this.loadSerial += 1;
    this.requested = false;
    this.shown = false;
    this.busyAttempts = 0;
    this.waitAttempts = 0;
  }

  public func IsCurrentLoad(serial: Int32) -> Bool {
    return serial == this.loadSerial;
  }

  public func SetWelcomeMode(value: Bool) -> Void {
    this.isWelcome = value;
  }

  public func RequestAfterGameplayLoad() -> Void {
    if this.requested || this.shown {
      return;
    }

    if this.isWelcome {
      let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
      if IsDefined(qs) && qs.GetFact(n"incf_welcome_popup_shown") == 1 {
        return;
      }
    }

    this.requested = true;
    this.WaitForGameplay();
  }

  public func WaitForGameplay() -> Void {
    if !this.requested || this.shown {
      return;
    }

    let playerSystem: ref<PlayerSystem> = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if !IsDefined(playerSystem) {
      this.ScheduleWait();
      return;
    }

    let player: ref<PlayerPuppet> =
      playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet;

    if !IsDefined(player) {
      this.ScheduleWait();
      return;
    }

    let pos: Vector4 = player.GetWorldPosition();
    if AbsF(pos.Z) < 0.001 {
      this.ScheduleWait();
      return;
    }

    if !this.IsStartupGateReady() {
      this.ScheduleWait();
      return;
    }

    if this.IsTutorialPopupActive() || !this.IsSafeForPopup(player) {
      this.ScheduleWait();
      return;
    }

    this.waitAttempts = 0;
    this.ScheduleShow(MissingCorePopupTrigger.ShowDelay());
  }

  private func IsStartupGateReady() -> Bool {
    let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(qs) {
      return false;
    }

    if qs.GetFact(n"ep1_standalone") == 1 {
      return qs.GetFact(n"q301_00_done") == 1;
    }

    let q101FlowActive: Bool =
      qs.GetFact(n"q101_active") == 1 ||
      qs.GetFact(n"q101_started") == 1 ||
      qs.GetFact(n"q005_done") == 1;

    let q101RecoverySafe: Bool =
      qs.GetFact(n"q101_talking_to_johnny_end") == 1 ||
      qs.GetFact(n"q101_v_room_stanley_start") == 1;

    if q101FlowActive {
      return q101RecoverySafe;
    }

    if qs.GetFact(n"q001_start_wilson_quest") == 1 {
      return true;
    }

    return false;
  }

  private func IsTutorialPopupActive() -> Bool {
    let timeSystem: ref<TimeSystem> = GameInstance.GetTimeSystem(this.GetGameInstance());
    return IsDefined(timeSystem) && timeSystem.IsTimeDilationActive(n"UI_TutorialPopup");
  }

  private func IsSafeForPopup(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }

    if player.IsInCombat() {
      return false;
    }

    let game: GameInstance = this.GetGameInstance();
    let bbSys: ref<BlackboardSystem> = GameInstance.GetBlackboardSystem(game);
    if !IsDefined(bbSys) {
      return false;
    }

    let allDefs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    if !IsDefined(allDefs) {
      return false;
    }

    let uiSystemDef: ref<UI_SystemDef> = allDefs.UI_System;
    let uiSystemBB: ref<IBlackboard> = bbSys.Get(uiSystemDef);
    if IsDefined(uiSystemBB) && uiSystemBB.GetBool(uiSystemDef.IsInMenu) {
      return false;
    }

    let playerSMDef: ref<PlayerStateMachineDef> = allDefs.PlayerStateMachine;
    let playerSMBB: ref<IBlackboard> = bbSys.GetLocalInstanced(player.GetEntityID(), playerSMDef);
    if !IsDefined(playerSMBB) {
      return false;
    }

    let sceneTier: Int32 = playerSMBB.GetInt(playerSMDef.SceneTier);

    return sceneTier <= 2;
  }

  private func ScheduleWait() -> Void {
    if !this.requested || this.waitAttempts >= MissingCorePopupTrigger.MaxWaitAttempts() {
      this.requested = false;
      return;
    }

    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.requested = false;
      return;
    }

    this.waitAttempts += 1;
    let cb: ref<INCFWaitForGameplayCallback> = new INCFWaitForGameplayCallback();
    cb.sys = this;
    cb.serial = this.loadSerial;
    ds.DelayCallback(cb, MissingCorePopupTrigger.WaitForGameplayDelay(), false);
  }

  private func ScheduleShow(delay: Float) -> Void {
    let ds: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      this.requested = false;
      return;
    }

    let cb: ref<INCFShowPopupCallback> = new INCFShowPopupCallback();
    cb.sys = this;
    cb.serial = this.loadSerial;
    ds.DelayCallback(cb, delay, false);
  }

  public func ShowPopup() -> Void {
    if !this.requested || this.shown {
      return;
    }

    if !this.IsStartupGateReady() {
      this.ScheduleWait();
      return;
    }

    let playerSystem: ref<PlayerSystem> = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if !IsDefined(playerSystem) {
      this.ScheduleWait();
      return;
    }

    let player: ref<PlayerPuppet> =
      playerSystem.GetLocalPlayerControlledGameObject() as PlayerPuppet;

    if !this.IsSafeForPopup(player) {
      this.ScheduleWait();
      return;
    }

    let game: GameInstance = this.GetGameInstance();
    let bbSys: ref<BlackboardSystem> = GameInstance.GetBlackboardSystem(game);
    if !IsDefined(bbSys) {
      this.ScheduleWait();
      return;
    }

    let allDefs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    if !IsDefined(allDefs) {
      this.ScheduleWait();
      return;
    }

    let uiDef: ref<UIGameDataDef> = allDefs.UIGameData;
    if !IsDefined(uiDef) {
      this.ScheduleWait();
      return;
    }

    let uiBB: ref<IBlackboard> = bbSys.Get(uiDef);
    if !IsDefined(uiBB) {
      this.ScheduleWait();
      return;
    }

    let popupBusy: Bool = uiBB.GetBool(uiDef.Popup_IsShown);
    let tutorialBusy: Bool = this.IsTutorialPopupActive();

    if popupBusy || tutorialBusy {
      this.busyAttempts += 1;

      if this.busyAttempts >= MissingCorePopupTrigger.MaxBusyAttempts() {
        this.requested = false;
        return;
      }

      this.ScheduleShow(MissingCorePopupTrigger.BusyRetryDelay());
      return;
    } else {
      this.busyAttempts = 0;
    }

    let data: PopupData;
    let settings: PopupSettings;

    if this.isWelcome {
      data.title = "WELCOME TO IMMERSIVE NIGHT CITY FIXES";
      data.message =
        "Immersive Night City Fixes is active.\n\n" +
        "This mod addresses world anomalies and inconsistencies across Night City, refining interactions, environments, and visual details that can disrupt immersion.\n\n" +
        "All required components are installed and ready.";
    } else {
      data.title = "MISSING REQUIRED FILES - INCF CORE";
      data.message =
        "Night City is a marvel of design… but even the most intricate world contains imperfections.\n\n" +
        "Immersive Night City Fixes was created to address those quirks — the clipping, floating geometry, misplaced props, and subtle world inconsistencies that can pull you out of the experience.\n\n" +
        "This project brings together community reports and careful corrections to restore the intended look and feel of the city. Every patch adds more refined adjustments based on real observations and player feedback.\n\n" +
        "To fully benefit from these fixes, INCF Core module must be installed and active.";
    }

    data.isModal = true;
    let vid: ResourceAsyncRef;
    if this.isWelcome {
      ResourceAsyncRef.SetPath(vid, r"base\\movies\\misc\\pl_highlights\\pl_location.bk2");
    } else {
      ResourceAsyncRef.SetPath(vid, r"base\\movies\\misc\\q003\\loop_2.bk2");
    }
    data.video = vid;
    data.videoType = IntEnum<VideoType>(3);
    settings.closeAtInput = true;
    settings.pauseGame = true;
    settings.fullscreen = true;

    uiBB.SetVariant(uiDef.Popup_Settings, ToVariant(settings));
    uiBB.SetVariant(uiDef.Popup_Data, ToVariant(data));
    uiBB.SignalVariant(uiDef.Popup_Data);

    if this.isWelcome {
      let qs: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
      if IsDefined(qs) {
        qs.SetFact(n"incf_welcome_popup_shown", 1);
      }
    }

    this.shown = true;
    this.requested = false;
  }
}

public class INCFWaitForGameplayCallback extends DelayCallback {
  public let sys: wref<MissingCorePopupTrigger>;
  public let serial: Int32;

  public func Call() -> Void {
    if IsDefined(this.sys) && this.sys.IsCurrentLoad(this.serial) {
      this.sys.WaitForGameplay();
    }
  }
}

public class INCFShowPopupCallback extends DelayCallback {
  public let sys: wref<MissingCorePopupTrigger>;
  public let serial: Int32;

  public func Call() -> Void {
    if IsDefined(this.sys) && this.sys.IsCurrentLoad(this.serial) {
      this.sys.ShowPopup();
    }
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();

  let game: GameInstance = this.GetGame();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(game);
  if !IsDefined(container) {
    return result;
  }

  let coreMarker: ref<ScriptableSystem> =
    container.Get(n"INCFCore.INCFCoreMarker") as ScriptableSystem;

  let sys: ref<MissingCorePopupTrigger> =
    container.Get(n"INCF.MissingCorePopupTrigger") as MissingCorePopupTrigger;

  if IsDefined(sys) {
    sys.ResetForLoad();
    sys.SetWelcomeMode(IsDefined(coreMarker));
    sys.RequestAfterGameplayLoad();
  }

  return result;
}
