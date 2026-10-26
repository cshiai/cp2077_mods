// Nexus 34645 startup-only compatibility helper (AutoContinue removed).
// Pure-redscript portion of the supplied v1.3.0 file.  Its ACA25 native
// tracing/masking bridge is omitted because the reference DLL is not installed.
module Nexus34645Startup

@replaceMethod(EngagementScreenGameController)
protected cb func OnInitialize() -> Bool {
  this.m_requestHandler = this.GetSystemRequestsHandler();
  this.m_requestHandler.RegisterToCallback(n"OnAdditionalContentDataReloadProgressCallback", this, n"OnAdditionalContentDataReloadProgress");
  this.m_requestHandler.RegisterToCallback(n"OnToggleBreachingCallback", this, n"OnToggleBreachingCallback");
  this.m_progressBarController = inkWidgetRef.GetController(this.m_progressBar) as LoadingScreenProgressBarController;
  inkWidgetRef.SetVisible(this.m_progressBar, false);
  inkWidgetRef.SetVisible(this.m_breachingWidget, false);
  return true;
}

@replaceMethod(InitializeUserScreenGameController)
protected cb func OnInitialize() -> Bool {
  this.m_requestHandler = this.GetSystemRequestsHandler();
  this.m_requestHandler.RegisterToCallback(n"OnAdditionalContentDataReloadProgressCallback", this, n"OnAdditionalContentDataReloadProgress");
  this.m_progressBarController = inkWidgetRef.GetController(this.m_progressBar) as LoadingScreenProgressBarController;
  inkWidgetRef.SetVisible(this.m_progressBar, false);
  return true;
}
