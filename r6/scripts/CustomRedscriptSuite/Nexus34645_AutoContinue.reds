// Nexus 34645 direct-redscript compatibility port (native bridge removed)
// Pure-redscript fallback for the reference AutoContinue.reds behavior.
// The downloaded original declares ACA25* native methods supplied by its DLL;
// those declarations are intentionally omitted here because that DLL is not
// installed in this profile.
module AutoContinueAfterLoading

public class AutoContinueConfig {
  public static func AutoConfirmAfterSave() -> Bool {
    return true;
  }
}

// ---------------------------------------------------------------------------
// Normal loading screen: one guarded synthetic Space press
// ---------------------------------------------------------------------------

@addField(InitialLoadingScreenLogicController)
private let sicDisposed: Bool;

@addField(InitialLoadingScreenLogicController)
private let sicAnimationReady: Bool;

@addField(InitialLoadingScreenLogicController)
private let sicConfirmed: Bool;

@addField(InitialLoadingScreenLogicController)
private let sicTimer: ref<inkCanvas>;

@addField(InitialLoadingScreenLogicController)
private let sicTimerProxy: ref<inkAnimProxy>;

@wrapMethod(InitialLoadingScreenLogicController)
protected cb func OnInitialize() -> Bool {
  this.sicDisposed = false;
  this.sicAnimationReady = false;
  this.sicConfirmed = false;
  let result: Bool = wrappedMethod();
  this.SICStartHeartbeat();
  return result;
}

@wrapMethod(InitialLoadingScreenLogicController)
protected cb func OnAnimReadyForLoadingSkipEvent() -> Bool {
  let result: Bool = wrappedMethod();
  if !this.sicDisposed {
    this.sicAnimationReady = true;
  };
  return result;
}

@addMethod(InitialLoadingScreenLogicController)
private final func SICStartHeartbeat() -> Void {
  let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
  if !IsDefined(root) || this.sicDisposed || !AutoContinueConfig.AutoConfirmAfterSave() {
    return;
  };

  // A zero-size private canvas is cheaper and safer than polling a native
  // widget from a global callback.  It has no visual or layout effect.
  this.sicTimer = new inkCanvas();
  this.sicTimer.SetName(n"SkipIntroAutoContinueHeartbeat");
  this.sicTimer.SetSize(new Vector2(0.00, 0.00));
  this.sicTimer.SetInteractive(false);
  this.sicTimer.Reparent(root);

  let animation: ref<inkAnimDef> = new inkAnimDef();
  let transparency: ref<inkAnimTransparency> = new inkAnimTransparency();
  transparency.SetDuration(0.05);
  transparency.SetStartTransparency(1.00);
  transparency.SetEndTransparency(1.00);
  transparency.SetType(inkanimInterpolationType.Linear);
  transparency.SetMode(inkanimInterpolationMode.EasyIn);
  animation.AddInterpolator(transparency);

  let options: inkAnimOptions;
  options.loopType = inkanimLoopType.Cycle;
  options.loopInfinite = true;
  this.sicTimerProxy = this.sicTimer.PlayAnimationWithOptions(animation, options);
  if IsDefined(this.sicTimerProxy) {
    this.sicTimerProxy.RegisterToCallback(inkanimEventType.OnEndLoop, this, n"SICHeartbeat");
  };
}

@addMethod(InitialLoadingScreenLogicController)
private final func SICPromptIsReady() -> Bool {
  let root: wref<inkWidget> = this.GetRootWidget();
  let prompt: wref<inkWidget> = this.GetWidget(n"inkCanvasWidget7_hide");
  return !this.sicDisposed
    && !this.sicConfirmed
    && this.sicAnimationReady
    && IsDefined(root)
    && root.IsVisible()
    && inkWidgetRef.IsValid(this.progressBarRoot)
    && !inkWidgetRef.IsVisible(this.progressBarRoot)
    && IsDefined(prompt)
    && prompt.IsVisible();
}

@addMethod(InitialLoadingScreenLogicController)
private final func SICQueueSpace() -> Void {
  let keyEvent: ref<inkKeyInputEvent> = new inkKeyInputEvent();
  keyEvent.key = EInputKey.IK_Space;
  keyEvent.action = EInputAction.IACT_Press;
  this.QueueEvent(keyEvent);
}

@addMethod(InitialLoadingScreenLogicController)
protected cb func SICHeartbeat(proxy: ref<inkAnimProxy>) -> Bool {
  if this.sicDisposed {
    return false;
  };
  if this.SICPromptIsReady() {
    this.sicConfirmed = true;
    this.SICQueueSpace();
  };
}

@addMethod(InitialLoadingScreenLogicController)
protected cb func OnUninitialize() -> Bool {
  this.sicDisposed = true;
  this.sicAnimationReady = false;
  if IsDefined(this.sicTimerProxy) {
    this.sicTimerProxy.UnregisterFromCallback(inkanimEventType.OnEndLoop, this, n"SICHeartbeat");
    this.sicTimerProxy.Stop();
    this.sicTimerProxy = null;
  };
  if IsDefined(this.sicTimer) {
    let parent: ref<inkCompoundWidget> = this.sicTimer.GetParentWidget() as inkCompoundWidget;
    if IsDefined(parent) {
      parent.RemoveChild(this.sicTimer);
    };
    this.sicTimer = null;
  };
}
