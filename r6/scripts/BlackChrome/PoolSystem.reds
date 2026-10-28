module Phoenicia.BlackChrome

public class PoolSystem extends ScriptableSystem {
    private let player: wref<PlayerPuppet>;

    private let delaySystem: ref<DelaySystem>;
    private let statSystem: ref<StatsSystem>;
    private let statusEffectSystem: ref<StatusEffectSystem>;
    private let statPoolsSystem: ref<StatPoolsSystem>;
    private let aegisActiveType: gamedataStatType;
    private let aegisRamCostType: gamedataStatType;
    private let juiceTankEquippedType: gamedataStatType;
    private let juiceTankDamagedType: gamedataStatType;
    private let juiceTankRegenType: gamedataStatType;
    private let delayID: DelayID;


    public static func GetInstance(gameInstance: GameInstance) -> ref<PoolSystem> {
        let system: ref<PoolSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"Phoenicia.BlackChrome.PoolSystem") as PoolSystem;
        return system;
    }

    private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
        let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());

        if IsDefined(player) { 
            if IsDefined(this.delaySystem) {
                this.delaySystem.CancelDelay(this.delayID);
            };
            this.player = player;
            this.statSystem = GameInstance.GetStatsSystem(this.player.GetGame());
            this.delaySystem = GameInstance.GetDelaySystem(this.player.GetGame());
            this.statusEffectSystem = GameInstance.GetStatusEffectSystem(this.player.GetGame());
            this.statPoolsSystem = GameInstance.GetStatPoolsSystem(this.player.GetGame());
            this.aegisActiveType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"AegisActive"));
            this.aegisRamCostType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"AegisRamCost"));
            this.juiceTankEquippedType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"JuiceTankEquipped"));
            this.juiceTankDamagedType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"JuiceTankDamaged"));
            this.juiceTankRegenType = IntEnum<gamedataStatType>(EnumValueFromName(n"gamedataStatType", n"JuiceTankRegen"));

            this.SetUpNextCallback();
        } else {
            this.OnPlayerDetach(null);
        }
    }

    private final func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
        if IsDefined(this.delaySystem) {
            this.delaySystem.CancelDelay(this.delayID);
        };
        this.delayID = GetInvalidDelayID();
        this.player = null;
        this.statSystem = null;
        this.delaySystem = null;
        this.statusEffectSystem = null;
        this.statPoolsSystem = null;
    }

    private func OnAttach() -> Void {
        this.delayID = GetInvalidDelayID();
    }

    private func OnDetach() -> Void {
        this.OnPlayerDetach(null);
    }

    private func SetUpNextCallback() {
        if !IsDefined(this.player) || !IsDefined(this.statSystem) || !IsDefined(this.delaySystem) {
            return;
        };
        let playerID: StatsObjectID = Cast<StatsObjectID>(this.player.GetEntityID());
        let aegisActive: Float = this.statSystem.GetStatValue(playerID, this.aegisActiveType);

        if (aegisActive > 0.0) {
            let aegisRamCost: Float = this.statSystem.GetStatValue(playerID, this.aegisRamCostType);
            aegisRamCost = MaxF(aegisRamCost, 0.0);
            if IsDefined(this.statPoolsSystem) {
                this.statPoolsSystem.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Memory, -aegisRamCost, this.player, false, false);
            };
        }

        let juiceTankEquipped: Float = this.statSystem.GetStatValue(playerID, this.juiceTankEquippedType);
        let juiceTankDamaged: Float = this.statSystem.GetStatValue(playerID, this.juiceTankDamagedType);

        if (juiceTankEquipped > 0.0 && juiceTankDamaged < 1.0) {
            let juiceTankHealing: Float = this.statSystem.GetStatValue(playerID, this.juiceTankRegenType);
            juiceTankHealing = MaxF(juiceTankHealing, 0.0);

            if IsDefined(this.statPoolsSystem) {
                this.statPoolsSystem.RequestChangingStatPoolValue(playerID, gamedataStatPoolType.Health, juiceTankHealing, this.player, false, false);
            };

        }

        this.delayID = this.delaySystem.DelayCallback(BlackChromePoolSystemCallback.Create(this), 1.0, false);
    }
}

public class BlackChromePoolSystemCallback extends DelayCallback {
  private let system: wref<PoolSystem>;

  public static func Create(system: ref<PoolSystem>) -> ref<BlackChromePoolSystemCallback> {
    let self: ref<BlackChromePoolSystemCallback> = new BlackChromePoolSystemCallback();
    self.system = system;
    return self;
  }

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.SetUpNextCallback();
    };
  }
}
