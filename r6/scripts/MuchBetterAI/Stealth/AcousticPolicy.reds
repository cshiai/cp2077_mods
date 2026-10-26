module MuchBetterAI.Stealth

import MuchBetterAI.Core.*
import MuchBetterAI.Logging.*

public enum MBAI_AcousticFamily {
  Movement = 0,
  Interaction = 1,
  Body = 2,
  Combat = 3
}

public enum MBAI_AcousticSeverity {
  Incidental = 0,
  Suspicious = 1,
  Alarming = 2
}

public class MBAI_AcousticCluster {
  public let pos: Vector4;
  public let severity: MBAI_AcousticSeverity;
  public let count: Int32;
  public let expiresAt: Float;
  public let generation: Uint32;
}

public class MBAI_AcousticReceiptCallback extends DelayCallback {
  public let game: GameInstance;
  public let sourceID: EntityID;
  public let sourcePos: Vector4;
  public let stimType: gamedataStimType;
  public let family: MBAI_AcousticFamily;
  public let severity: MBAI_AcousticSeverity;
  public let radius: Float;
  public let serial: Uint32;

  public func Call() -> Void {
    let sys: ref<MBAI_AcousticSystem> = GameInstance.GetScriptableSystemsContainer(this.game).Get(n"MuchBetterAI.Stealth.MBAI_AcousticSystem") as MBAI_AcousticSystem;
    if IsDefined(sys) {
      sys.EvaluateReceipt(this.sourceID, this.sourcePos, this.stimType, this.family, this.severity, this.radius, this.serial);
    };
  }
}

public class MBAI_AcousticSystem extends ScriptableSystem {
  private let m_movement: ref<MBAI_AcousticCluster>;
  private let m_interaction: ref<MBAI_AcousticCluster>;
  private let m_body: ref<MBAI_AcousticCluster>;
  private let m_combat: ref<MBAI_AcousticCluster>;
  private let m_serial: Uint32;

  private func OnAttach() -> Void {
    this.m_movement = new MBAI_AcousticCluster();
    this.m_interaction = new MBAI_AcousticCluster();
    this.m_body = new MBAI_AcousticCluster();
    this.m_combat = new MBAI_AcousticCluster();
    this.m_serial = 0u;
  }

  private final func ClusterJoinDistanceProbe() -> Float { return 3.0; }

  private final func ClusterWindowProbe() -> Float { return 3.0; }

  private final func ReceiptDelayProbe() -> Float { return 0.2; }

  private final func EffectsEnabledProbe() -> Bool { return false; }

  private final func ReceiptProbeEnabled() -> Bool {
    return this.EffectsEnabledProbe();
  }

  private final func Cluster(family: MBAI_AcousticFamily) -> ref<MBAI_AcousticCluster> {
    switch family {
      case MBAI_AcousticFamily.Interaction:
        return this.m_interaction;
      case MBAI_AcousticFamily.Body:
        return this.m_body;
      case MBAI_AcousticFamily.Combat:
        return this.m_combat;
    };
    return this.m_movement;
  }

  public final func Record(source: ref<GameObject>, sourcePos: Vector4, stimType: gamedataStimType, family: MBAI_AcousticFamily, severity: MBAI_AcousticSeverity, radius: Float) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    let cluster: ref<MBAI_AcousticCluster> = this.Cluster(family);
    let active: Bool = cluster.count > 0 && now <= cluster.expiresAt;
    let joins: Bool = active && Vector4.Distance(cluster.pos, sourcePos) <= this.ClusterJoinDistanceProbe();
    if joins {
      cluster.pos = sourcePos;
      cluster.count += 1;
      cluster.expiresAt = now + this.ClusterWindowProbe();
      if EnumInt(severity) > EnumInt(cluster.severity) {
        cluster.severity = severity;
      };
    } else {
      if active && EnumInt(severity) < EnumInt(cluster.severity) {
        return;
      };
      cluster.pos = sourcePos;
      cluster.severity = severity;
      cluster.count = 1;
      cluster.expiresAt = now + this.ClusterWindowProbe();
    };
    this.m_serial += 1u;
    cluster.generation = this.m_serial;
    if !joins || EnumInt(severity) < EnumInt(MBAI_AcousticSeverity.Suspicious) {
      return;
    };
    if !this.ReceiptProbeEnabled() {
      return;
    };
    let cb: ref<MBAI_AcousticReceiptCallback> = new MBAI_AcousticReceiptCallback();
    cb.game = this.GetGameInstance();
    cb.sourceID = source.GetEntityID();
    cb.sourcePos = sourcePos;
    cb.stimType = stimType;
    cb.family = family;
    cb.severity = severity;
    cb.radius = radius;
    cb.serial = this.m_serial;
    GameInstance.GetDelaySystem(cb.game).DelayCallback(cb, this.ReceiptDelayProbe(), false);
  }

  public final func EvaluateReceipt(sourceID: EntityID, sourcePos: Vector4, stimType: gamedataStimType, family: MBAI_AcousticFamily, severity: MBAI_AcousticSeverity, radius: Float, serial: Uint32) -> Void {
    if serial != this.Cluster(family).generation || !MBAI_Acoustic_Enabled(family) || !this.ReceiptProbeEnabled() {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let source: wref<GameObject> = GameInstance.FindEntityByID(gi, sourceID) as GameObject;
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(source) || !IsDefined(player) {
      return;
    };
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let traceProbe: Bool = false;
    let queryRadius: Float = radius + Vector4.Distance(source.GetWorldPosition(), sourcePos);
    let npcs: array<ref<NPCPuppet>> = source.GetNPCsAroundObject(queryRadius);
    let responders: Int32 = 0;
    let n: Int32 = 0;
    while n < ArraySize(npcs) && responders < 2 {
      let npc: ref<NPCPuppet> = npcs[n];
      if MBAI_PlayerAlertCanReceiveMovement(npc, player) && !MBAI_DeviceInvestigationOwnsMovement(npc) && Vector4.Distance(npc.GetWorldPosition(), sourcePos) <= radius {
        let state: gamedataNPCHighLevelState = npc.GetHighLevelStateFromBlackboard();
        let investigating: Bool = npc.IsInvestigating();
        let alerted: Bool = Equals(state, gamedataNPCHighLevelState.Alerted);
        if NotEquals(state, gamedataNPCHighLevelState.Combat) && (investigating || alerted) && MBAI_IsOrderAvailable(npc, n"Search", now) && !MBAI_IntentBlocksCommand(npc, n"Search", now) {
          let reaction: ref<ReactionManagerComponent> = npc.GetStimReactionComponent();
          if IsDefined(reaction) {
            let cache: array<ref<StimEventTaskData>> = reaction.GetStimuliCache();
            if traceProbe {
              MBATrace("Acoustics", s"cache npc=\(ToString(npc.GetEntityID())) size=\(ArraySize(cache))");
            };
            let i: Int32 = ArraySize(cache) - 1;
            let inspected: Int32 = 0;
            let matched: Bool = false;
            while i >= 0 && inspected < 4 && !matched {
              let evt: ref<StimuliEvent> = cache[i].cachedEvt;
              if IsDefined(evt) {
                let sourceMatch: Bool = IsDefined(evt.sourceObject) && evt.sourceObject.GetEntityID() == sourceID;
                let typeMatch: Bool = Equals(evt.GetStimType(), stimType);
                let delta: Float = Vector4.Distance(evt.sourcePosition, sourcePos);
                let posMatch: Bool = delta <= 1.0;
                let stateName: String = investigating ? "Investigating" : "Alerted";
                if traceProbe {
                  MBATrace("Acoustics", s"receipt source=\(sourceMatch) type=\(typeMatch) pos=\(posMatch) state=\(stateName)");
                  MBATrace("Acoustics", s"receipt delta=\(delta) npc=\(ToString(npc.GetEntityID()))");
                };
                matched = sourceMatch && typeMatch && posMatch;
              };
              inspected += 1;
              i -= 1;
            };
            if matched {
              responders += 1;
              if Equals(severity, MBAI_AcousticSeverity.Alarming) && traceProbe && this.EffectsEnabledProbe() {
                MBAI_RaiseAlert(npc, 20.0);
              };
              if traceProbe && this.EffectsEnabledProbe() {
                MBAI_Search_MoveToWithContext(npc, sourcePos, "AcousticRepeat");
              };
            };
          };
        };
      };
      n += 1;
    };
  }
}

public func MBAI_Acoustic_Record(source: ref<GameObject>, sourcePos: Vector4, stimType: gamedataStimType, family: MBAI_AcousticFamily, severity: MBAI_AcousticSeverity, radius: Float) -> Void {
  if !IsDefined(source) || !MBAI_Acoustic_Enabled(family) {
    return;
  };
  let sys: ref<MBAI_AcousticSystem> = GameInstance.GetScriptableSystemsContainer(source.GetGame()).Get(n"MuchBetterAI.Stealth.MBAI_AcousticSystem") as MBAI_AcousticSystem;
  if IsDefined(sys) {
    sys.Record(source, sourcePos, stimType, family, severity, radius);
  };
}

public func MBAI_Acoustic_Scale(family: MBAI_AcousticFamily) -> Float {
  switch family {
    case MBAI_AcousticFamily.Interaction:
      return 1.0;
    case MBAI_AcousticFamily.Body:
      return 1.0;
    case MBAI_AcousticFamily.Combat:
      return 1.0;
  };
  return 1.0;
}

public func MBAI_Acoustic_Enabled(family: MBAI_AcousticFamily) -> Bool {
  switch family {
    case MBAI_AcousticFamily.Interaction:
      return true;
    case MBAI_AcousticFamily.Body:
      return true;
    case MBAI_AcousticFamily.Combat:
      return true;
  };
  return true;
}
