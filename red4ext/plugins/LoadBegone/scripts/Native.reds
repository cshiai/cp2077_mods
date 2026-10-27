module LoadBegone.Native

public native func Log(text: String) -> Void;

public native func IsEscHeld() -> Bool;

public native func IsIntroUp() -> Bool;

public native func HoldIntro() -> Void;
public native func ReleaseIntro(loading: Bool) -> Void;

public native func IsStartScreenBusy() -> Bool;

public native func RecapScreenOpened(screen: ref<IScriptable>) -> Void;
public native func SetVoiceLanguage(language: CName) -> Void;
