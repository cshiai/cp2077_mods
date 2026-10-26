module MuchBetterAI.Stealth


public class MBAI_CorpseLOS {
  private static final func BuildOcclusionFilter() -> QueryFilter {
    let filter: QueryFilter;
    QueryFilter.AddGroup(filter, n"Terrain");
    QueryFilter.AddGroup(filter, n"Static");
    QueryFilter.AddGroup(filter, n"Destructible");
    QueryFilter.AddGroup(filter, n"Dynamic");
    QueryFilter.AddGroup(filter, n"Collider");
    return filter;
  }

  private static final func SegmentVisible(sqs: ref<SpatialQueriesSystem>, start: Vector4, finish: Vector4) -> Bool {
    let delta: Vector4 = finish - start;
    let length: Float = Vector4.Length(delta);
    if length <= 0.10 {
      return true;
    };
    if length > 60.0 {
      return true;
    };
    let endPoint: Vector4 = finish - Vector4.Normalize(delta) * 0.20;
    let hit: TraceResult;
    return !sqs.SyncRaycastByQueryFilter(start, endPoint, MBAI_CorpseLOS.BuildOcclusionFilter(), hit);
  }

  public static final func RayClearBetween(gi: GameInstance, from: Vector4, to: Vector4) -> Bool {
    let sqs: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(gi);
    if !IsDefined(sqs) {
      return true;
    };
    let eye: Vector4 = from;
    eye.Z += 1.65;
    let center: Vector4 = to;
    center.Z += 0.85;
    return MBAI_CorpseLOS.SegmentVisible(sqs, eye, center);
  }

  public static final func HasAnyLOS(owner: wref<GameObject>, targetPos: Vector4) -> Bool {
    if !IsDefined(owner) {
      return true;
    };
    let gi: GameInstance = owner.GetGame();
    let sqs: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(gi);
    if !IsDefined(sqs) {
      return true;
    };
    let eye: Vector4 = owner.GetWorldPosition();
    eye.Z += 1.65;
    let center: Vector4 = targetPos;
    center.Z += 0.85;
    if MBAI_CorpseLOS.SegmentVisible(sqs, eye, center) {
      return true;
    };
    let lower: Vector4 = targetPos;
    lower.Z += 0.15;
    return MBAI_CorpseLOS.SegmentVisible(sqs, eye, lower);
  }

  public static final func ResolveBodyPosition(stimEvent: ref<StimuliEvent>, out position: Vector4) -> Bool {
    position = stimEvent.sourcePosition;
    if !Vector4.IsZero(position) {
      return true;
    };
    let corpse: ref<GameObject> = stimEvent.sourceObject as GameObject;
    if !IsDefined(corpse) {
      return false;
    };
    position = corpse.GetWorldPosition();
    return !Vector4.IsZero(position);
  }
}

@wrapMethod(ReactionManagerComponent)
private final func ShouldStimBeProcessed(stimEvent: ref<StimuliEvent>, delayed: Bool) -> Bool {
  let accepted: Bool = wrappedMethod(stimEvent, delayed);
  if !accepted || !Equals(stimEvent.GetStimType(), gamedataStimType.DeadBody) {
    return accepted;
  };
  let owner: ref<GameObject> = this.GetOwner() as GameObject;
  if !IsDefined(owner) {
    return accepted;
  };
  let corpsePos: Vector4;
  if !MBAI_CorpseLOS.ResolveBodyPosition(stimEvent, corpsePos) {
    return accepted;
  };
  if !MBAI_CorpseLOS.HasAnyLOS(owner, corpsePos) {
    return false;
  };
  return accepted;
}

@wrapMethod(ReactionManagerComponent)
protected cb func OnBodyInvestigated(evt: ref<BodyInvestigatedEvent>) -> Bool {
  wrappedMethod(evt);
  let reaction: ref<AIReactionData> = this.GetActiveReactionData();
  if !IsDefined(reaction) || !Equals(reaction.reactionBehaviorName, gamedataOutput.BodyInvestigate) || !Equals(reaction.stimType, gamedataStimType.DeadBody) {
    return false;
  };
  let body: ref<GameObject> = reaction.stimEventData.source;
  if !IsDefined(body) {
    return false;
  };
  let bodyPos: Vector4 = body.GetWorldPosition();
  if Vector4.IsZero(bodyPos) {
    return false;
  };
  let observer: ref<NPCPuppet> = this.GetOwner() as NPCPuppet;
  if !IsDefined(observer) {
    return false;
  };
  MBAI_BodyAlert_Register(observer, bodyPos);
}
