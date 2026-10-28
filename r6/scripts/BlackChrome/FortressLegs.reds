module Phoenicia.BlackChrome

public class FortressLegsEffector extends ModifyAttackEffector {

  protected func Initialize(record: TweakDBID, game: GameInstance, parentRecord: TweakDBID) -> Void {
  }

  protected func ActionOn(owner: ref<GameObject>) -> Void {
    this.ProcessAction(owner);
  }

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    this.ProcessAction(owner);
  }

  private final func ProcessAction(owner: ref<GameObject>) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let damage: Float;
    let hitEvent: ref<gameHitEvent> = this.GetHitEvent();
    if !IsDefined(player) || !IsDefined(hitEvent) || !IsDefined(hitEvent.attackComputed) {
      return;
    };
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(player.GetGame());
    if !IsDefined(statsSystem) {
      return;
    };

    let frontalReduction = statsSystem.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"BorgDamageReductionFront"))); 
    let sideReduction = statsSystem.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"BorgDamageReductionSide"))); 

    damage = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    if damage <= 0.00 {
      return;
    };
    let hitDirectionInt: Int32 = GameObject.GetAttackAngleInInt(hitEvent);

    if (hitDirectionInt != 2) {
      if (hitDirectionInt == 3 || hitDirectionInt == 1) {
        hitEvent.attackComputed.MultAttackValue(ClampF(sideReduction, 0.0, 1.0));
      } else {
        hitEvent.attackComputed.MultAttackValue(ClampF(frontalReduction, 0.0, 1.0));
      }
    } 
    
  }
}
