module LoadBegone

public enum LoadBegoneCheckpoints {
    Vanilla = 0,
    Custom = 1,
    Bypass = 2,
}

// Fixed source profile.  The upstream menu/user.ini surface is not
// shipped in this collection; edit these values in Git and recompile.
public class LoadBegoneConfig {
    public let enabled: Bool = true;

    public let holdEscForMenu: Bool = true;

    public let delay: Float = 0.0;

    public let skipPrompts: Bool = true;

    public let skipModWarning: Bool = true;

    public let skipStartScreen: Bool = true;

    public let checkpoints: LoadBegoneCheckpoints = LoadBegoneCheckpoints.Bypass;

    public let checkpointSpeed: Float = 4.0;

    public let disableSpeedLimit: Bool = true;
}

public func LoadBegoneReadConfig() -> ref<LoadBegoneConfig> {
    return new LoadBegoneConfig();
}
