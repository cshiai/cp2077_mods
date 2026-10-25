// Q6: Zero-Wait UI Suite (Instant Time Skip + Instant Kiroshi Scanner + Instant Attribute Upgrade)
// Pure Redscript (0 dependencies) for Cyberpunk 2077 v2.5:
// 1. Instant Time Skip: Skips the 5-second radial clock wait animation after TimeSystem advances.
// 2. Instant Kiroshi Scanner: Sets NPC, device, and clue scan duration to 0.0 seconds.
// 3. Instant Attribute Investment: Removes the hold-to-upgrade bar on Attribute buttons.

// --- 1. Instant Time Skip ---
@replaceMethod(TimeskipGameController)
private final func PlayTictocAnimation() -> Void {
  this.m_timeSkipped = true;
}

@wrapMethod(TimeskipGameController)
private final func Apply() -> Void {
  wrappedMethod();
  if this.m_hoursToSkip > 0 {
    if IsDefined(this.m_animProxy) {
      this.m_animProxy.Stop(true);
    };
    if IsDefined(this.m_progressAnimProxy) {
      this.m_progressAnimProxy.Stop(true);
    };
    this.m_timeSkipped = true;
    this.OnCloseAfterFinishing(null);
  };
}

// --- 2. Instant Kiroshi Scanner (0.0s Scan Time) ---
public class IUS_ScannerRequest extends ScriptableSystemRequest {
  public let entityID: EntityID;
}

public class IUS_System extends ScriptableSystem {
  public final static func Get(gi: GameInstance) -> ref<IUS_System> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"IUS_System") as IUS_System;
  }

  private final func OnScannerRequest(request: ref<IUS_ScannerRequest>) -> Void {
    if !IsDefined(request) || !EntityID.IsDefined(request.entityID) {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let obj: ref<GameObject> = GameInstance.FindEntityByID(gi, request.entityID) as GameObject;
    if IsDefined(obj) && obj.IsAttached() {
      let setScannerTime: ref<SetScanningTimeEvent> = new SetScanningTimeEvent();
      setScannerTime.time = 0.0;
      obj.QueueEvent(setScannerTime);
    };
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let res: Bool = wrappedMethod();
  let sys: ref<IUS_System> = IUS_System.Get(this.GetGame());
  if IsDefined(sys) {
    let req: ref<IUS_ScannerRequest> = new IUS_ScannerRequest();
    req.entityID = this.GetEntityID();
    sys.QueueRequest(req);
  };
  return res;
}

@wrapMethod(Device)
protected final func InitializeScanningDataTask(data: ref<ScriptTaskData>) -> Void {
  wrappedMethod(data);
  let sys: ref<IUS_System> = IUS_System.Get(this.GetGame());
  if IsDefined(sys) {
    let req: ref<IUS_ScannerRequest> = new IUS_ScannerRequest();
    req.entityID = this.GetEntityID();
    sys.QueueRequest(req);
  };
}

@replaceMethod(InspectionComponent)
private final func SetTimeToScan(timeVal: Float) -> Void {
  this.m_timeToScan = 0.0;
}

// --- 3. Instant Attribute Investment (0 Hold Delay) ---
@wrapMethod(NewPerksAttributeButtonController)
protected cb func OnAttributeInvestPress(evt: ref<inkPointerEvent>) -> Bool {
  let res: Bool = wrappedMethod(evt);
  if this.m_isPressed && this.m_totalPoints > 0 {
    let holdFinishedEvent: ref<NewPerksTabAttributeInvestHoldFinished> = new NewPerksTabAttributeInvestHoldFinished();
    holdFinishedEvent.attribute = this.m_initData.perkMenuAttribute;
    this.QueueEvent(holdFinishedEvent);
    this.m_isPressed = false;
    this.UpdateCursorData();
    this.UpdateState();
  };
  return res;
}

@wrapMethod(PerksMenuAttributeItemController)
protected cb func OnAttributeItemHold(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"upgrade_attribute") && evt.GetHoldProgress() > 0.0 && !this.m_recentlyPurchased {
    if this.m_data.availableToUpgrade && this.m_dataManager.IsAttributeUpgradeable(this.m_attributeType) {
      this.m_recentlyPurchased = true;
      let upgradeEvent: ref<AttributeUpgradePurchased> = new AttributeUpgradePurchased();
      upgradeEvent.attributeType = this.m_attributeType;
      upgradeEvent.attributeData = this.m_attributeDisplayController.GetAttributeData();
      this.QueueEvent(upgradeEvent);
      this.PlaySound(n"Attributes", n"OnDone");
      return true;
    };
  };
  return wrappedMethod(evt);
}
