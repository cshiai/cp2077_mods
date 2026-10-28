module Phoenicia.BlackChrome

public class BerserkEffector extends ModifyAttackEffector {
  private let game: GameInstance;
  private let rageEffectId: TweakDBID;

  protected func Initialize(record: TweakDBID, game: GameInstance, parentRecord: TweakDBID) -> Void {
    this.game = game;
    this.rageEffectId = t"BlackChrome.BerserkerRage";
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
    if !IsDefined(hitEvent) || !IsDefined(hitEvent.target) || !IsDefined(hitEvent.attackComputed) {
      return;
    };

    let game = this.game;
    if !GameInstance.IsValid(game) && IsDefined(owner) {
      game = owner.GetGame();
    }
    if !GameInstance.IsValid(game) {
      return;
    }
    let maxPlayerHealth: Float;
    let playerEntityId: EntityID = hitEvent.target.GetEntityID();
    let statPools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(game);
    if !IsDefined(statPools) {
      return;
    };
    maxPlayerHealth = statPools.GetStatPoolMaxPointValue(Cast<StatsObjectID>(playerEntityId), gamedataStatPoolType.Health);
    if maxPlayerHealth <= 0.0 {
      return;
    };

    damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    if damage > 0.00 {
      let requiredDamagePerStack: Float = maxPlayerHealth / 40.0;
      let effectStacksFromDamage: Float = damage / requiredDamagePerStack;
      let appliedStacks: Int32 = 0;

      while effectStacksFromDamage >= 1.0 && appliedStacks < 64 {
        StatusEffectHelper.ApplyStatusEffect(hitEvent.target, this.rageEffectId);
        effectStacksFromDamage = effectStacksFromDamage - 1.0;
        appliedStacks += 1;
      }
    };
  }

}

