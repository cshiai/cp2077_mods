module LoadBegone.Native

public native func Log(text: String) -> Void;

public native func IsEscHeld() -> Bool;

public native func IsIntroUp() -> Bool;

public native func HoldIntro() -> Void;
public native func ReleaseIntro(loading: Bool) -> Void;
