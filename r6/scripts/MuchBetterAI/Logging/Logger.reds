module MuchBetterAI.Logging


public enum MBALogLevel {
  ERROR = 0,
  WARNING = 1,
  INFO = 2,
  DEBUG = 3,
  TRACE = 4
}

public class LoggerStateSystem extends ScriptableSystem {
  private let m_lastLogMessage: String;
  private let m_lastLogContext: String;
  private let m_lastLogLevel: MBALogLevel;
  private let m_lastLogTimestamp: Float;
  private let m_duplicateCount: Int32;

  private func OnAttach() {
    this.m_lastLogMessage = "";
    this.m_lastLogContext = "";
    this.m_lastLogLevel = MBALogLevel.ERROR;
    this.m_lastLogTimestamp = 0.0;
    this.m_duplicateCount = 0;
  }

  public func GetLastMessage() -> String { return this.m_lastLogMessage; }
  public func GetLastContext() -> String { return this.m_lastLogContext; }
  public func GetLastLevel() -> MBALogLevel { return this.m_lastLogLevel; }
  public func GetLastTimestamp() -> Float { return this.m_lastLogTimestamp; }
  public func GetDuplicateCount() -> Int32 { return this.m_duplicateCount; }
  public func SetLastMessage(msg: String) { this.m_lastLogMessage = msg; }
  public func SetLastContext(ctx: String) { this.m_lastLogContext = ctx; }
  public func SetLastLevel(level: MBALogLevel) { this.m_lastLogLevel = level; }
  public func SetLastTimestamp(time: Float) { this.m_lastLogTimestamp = time; }
  public func SetDuplicateCount(count: Int32) { this.m_duplicateCount = count; }
  public func IncrementDuplicateCount() { this.m_duplicateCount += 1; }
}

private static func GetCurrentLogLevel() -> MBALogLevel {
  // Logging is intentionally fixed; there is no runtime settings/config
  // surface in the CET-free profile.  Errors remain available without
  // flooding the log during ordinary combat.
  return MBALogLevel.ERROR;
}

public static func MBAError(context: String, message: String) -> Void {
  LogWithLevel(MBALogLevel.ERROR, context, message);
}
public static func MBAWarn(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(MBALogLevel.WARNING) {
    LogWithLevel(MBALogLevel.WARNING, context, message);
  }
}
public static func MBAInfo(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(MBALogLevel.INFO) {
    LogWithLevel(MBALogLevel.INFO, context, message);
  }
}
public static func MBADebug(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(MBALogLevel.DEBUG) {
    LogWithLevel(MBALogLevel.DEBUG, context, message);
  }
}
public static func MBATrace(context: String, message: String) -> Void {
  if EnumInt(GetCurrentLogLevel()) >= EnumInt(MBALogLevel.TRACE) {
    LogWithLevel(MBALogLevel.TRACE, context, message);
  }
}

private static func LogWithLevel(level: MBALogLevel, context: String, message: String) -> Void {
  let gameInstance: GameInstance = GetGameInstance();
  let loggerState: ref<LoggerStateSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"MuchBetterAI.Logging.LoggerStateSystem") as LoggerStateSystem;
  if !IsDefined(loggerState) {
    ModLog(n"MuchBetterAI", GetLevelPrefix(level) + " [" + context + "] " + message);
    return;
  }
  let currentTime: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gameInstance));
  let timeSinceLastLog: Float = currentTime - loggerState.GetLastTimestamp();
  if timeSinceLastLog < 5.0 && Equals(loggerState.GetLastContext(), context) && Equals(loggerState.GetLastMessage(), message) && Equals(loggerState.GetLastLevel(), level) {
    loggerState.IncrementDuplicateCount();
    return;
  }
  if loggerState.GetDuplicateCount() > 0 {
    if EnumInt(GetCurrentLogLevel()) >= EnumInt(loggerState.GetLastLevel()) {
      ModLog(n"MuchBetterAI", GetLevelPrefix(loggerState.GetLastLevel()) + " [" + loggerState.GetLastContext() + "] -> Previous message repeated " + ToString(loggerState.GetDuplicateCount()) + " times");
    };
    loggerState.SetDuplicateCount(0);
  }
  ModLog(n"MuchBetterAI", GetLevelPrefix(level) + " [" + context + "] " + message);
  loggerState.SetLastMessage(message);
  loggerState.SetLastContext(context);
  loggerState.SetLastLevel(level);
  loggerState.SetLastTimestamp(currentTime);
}

private static func GetLevelPrefix(level: MBALogLevel) -> String {
  switch level {
    case MBALogLevel.ERROR:   return "[ERROR]  ";
    case MBALogLevel.WARNING: return "[WARN]   ";
    case MBALogLevel.INFO:    return "[INFO]   ";
    case MBALogLevel.DEBUG:   return "[DEBUG]  ";
    case MBALogLevel.TRACE:   return "[TRACE]  ";
  }
  return "[UNKNOWN]";
}
