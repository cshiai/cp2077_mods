module Phoenicia.BlackChrome

public class AegisEffector extends ModifyAttackEffector {

  private let m_chanceToTrigger: Float;

  protected func Initialize(record: TweakDBID, game: GameInstance, parentRecord: TweakDBID) -> Void {
    this.m_chanceToTrigger = TDB.GetFloat(record + t".chanceToTrigger");
  }

  protected func ActionOn(owner: ref<GameObject>) -> Void {
    this.ProcessAction(owner);
  }

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    this.ProcessAction(owner);
  }

  private final func ProcessAction(owner: ref<GameObject>) -> Void {
    let damage: Float;
    let hitEvent: ref<gameHitEvent> = this.GetHitEvent();
    if !IsDefined(hitEvent) || !IsDefined(hitEvent.attackComputed) {
      return;
    };
    damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    if damage <= 0.00 {
      return;
    };
    if RandF() >= ClampF(this.m_chanceToTrigger, 0.0, 1.0) {
      return;
    };
    hitEvent.attackComputed.MultAttackValue(0.00);
    if IsDefined(owner) {
      GameObject.PlaySound(owner, n"w_cyb_nanotech_plates_deflecting");
    };
  }
}
