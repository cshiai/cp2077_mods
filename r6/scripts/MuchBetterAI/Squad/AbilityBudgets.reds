module MuchBetterAI.Squad

import MuchBetterAI.Fireteam.*

public class MBAI_SquadAbilityBudgetState {
  public let squadName: CName;
  public let fallbackID: EntityID;
  public let lastSeen: Float;
  public let grenadeReadyAt: Float;
  public let propagationWindow: Float;
  public let propagationSpent: Int32;
}

public class MBAI_SquadAbilityBudgetSystem extends ScriptableSystem {
  private let m_groups: array<ref<MBAI_SquadAbilityBudgetState>>;

  public final func GrenadeReady(npc: wref<NPCPuppet>, now: Float) -> Bool {
    let state: ref<MBAI_SquadAbilityBudgetState> = this.GetOrCreate(npc, now);
    return IsDefined(state) && now >= state.grenadeReadyAt;
  }

  public final func SpendGrenade(npc: wref<NPCPuppet>, now: Float) -> Void {
    let state: ref<MBAI_SquadAbilityBudgetState> = this.GetOrCreate(npc, now);
    if IsDefined(state) {
      let group: MBAI_DoctrineGroup = MBAI_GetDoctrineGroup(MBAI_GetAffiliation(npc), npc.GetNPCRarity());
      state.grenadeReadyAt = now + 15.0 / MBAI_DoctrineGrenadeWillingness(group);
    };
  }

  public final func CombatPropagationReady(npc: wref<NPCPuppet>, budget: Int32, now: Float) -> Bool {
    let state: ref<MBAI_SquadAbilityBudgetState> = this.GetOrCreate(npc, now);
    if !IsDefined(state) {
      return false;
    };
    if state.propagationWindow <= 0.0 || now - state.propagationWindow > 6.0 {
      state.propagationWindow = now;
      state.propagationSpent = 0;
    };
    return state.propagationSpent < budget;
  }

  public final func SpendCombatPropagation(npc: wref<NPCPuppet>, now: Float) -> Int32 {
    let state: ref<MBAI_SquadAbilityBudgetState> = this.GetOrCreate(npc, now);
    if !IsDefined(state) {
      return 0;
    };
    state.propagationSpent += 1;
    return state.propagationSpent;
  }

  private final func GetOrCreate(npc: wref<NPCPuppet>, now: Float) -> ref<MBAI_SquadAbilityBudgetState> {
    if !IsDefined(npc) {
      return null;
    };
    this.Prune(now);
    let i: Int32 = 0;
    while i < ArraySize(this.m_groups) {
      let state: ref<MBAI_SquadAbilityBudgetState> = this.m_groups[i];
      if MBAI_CombatGroupMatches(state.squadName, state.fallbackID, npc) {
        state.lastSeen = now;
        return state;
      };
      i += 1;
    };
    let state: ref<MBAI_SquadAbilityBudgetState> = new MBAI_SquadAbilityBudgetState();
    state.squadName = MBAI_CombatGroupSquadName(npc);
    state.fallbackID = npc.GetEntityID();
    state.lastSeen = now;
    ArrayPush(this.m_groups, state);
    return state;
  }

  private final func Prune(now: Float) -> Void {
    let i: Int32 = ArraySize(this.m_groups) - 1;
    while i >= 0 {
      if now - this.m_groups[i].lastSeen > 45.0 {
        ArrayErase(this.m_groups, i);
      };
      i -= 1;
    };
  }
}
