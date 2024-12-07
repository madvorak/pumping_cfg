/-
Copyright (c) 2024 Alexander Loitzl. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Alexander Loitzl
-/

import Mathlib.Computability.ContextFreeGrammar
import PumpingCfg.EpsilonElimination

namespace ContextFreeGrammar

variable {T : Type}

section Stuff
variable {NT : Type}

lemma lists {p q x y : List (Symbol T NT)} {v : Symbol T NT} (h: p ++ q = x ++ [v] ++ y) :
  ∃ w z, (y = w ++ z ∧ p = x ++ [v] ++ w ∧ q = z) ∨ (x = w ++ z ∧ p = w ∧ q = z ++ [v] ++ y) := by
  induction p generalizing q x y with
  | nil =>
    use [], x
    right
    simp at h ⊢
    exact h
  | cons hd tl ih =>
    cases x with
    | nil =>
      simp at h ⊢
      use tl, q
      left
      constructor
      rw [h.2]
      exact ⟨⟨h.1, rfl⟩, rfl⟩
    | cons x1 xs =>
      simp at h ⊢
      obtain ⟨h1, h2⟩ := h
      change (tl ++ q = xs ++ ([v] ++ y)) at h2
      rw [← List.append_assoc] at h2
      obtain ⟨m, n, h⟩ := ih h2
      cases h with
      | inl h =>
        obtain ⟨he1, he2, he3⟩ := h
        use m, n
        left
        constructor
        exact he1
        constructor
        constructor
        exact h1
        simp at he2
        exact he2
        exact he3
      | inr h =>
        obtain ⟨he1, he2, he3⟩ := h
        rw[he2, h1, he1]
        use (x1 :: m), n
        right
        constructor
        simp
        constructor
        rfl
        rw [he3]
        simp

variable {g : ContextFreeGrammar.{0,0} T}

lemma DerivesIn.append_split {p q w : List (Symbol T g.NT)} {n : ℕ} (h : g.DerivesIn (p ++ q) w n) :
  ∃ x y m1 m2, w = x ++ y ∧ g.DerivesIn p x m1 ∧ g.DerivesIn q y m2 ∧ n = m1 + m2 := by
  cases n with
  | zero =>
    use p, q, 0, 0
    constructor
    · cases h
      rfl
    · exact ⟨DerivesIn.refl p, DerivesIn.refl q, rfl⟩
  | succ n =>
    obtain ⟨v, hp, hd⟩ := h.head_of_succ
    obtain ⟨r, hrin, hr⟩ := hp
    obtain ⟨p', q', heq, hv⟩ := hr.exists_parts
    obtain ⟨a, b, hc⟩ := lists heq
    cases hc with
    | inl hc =>
      obtain ⟨heq1, heq2, heq3⟩ := hc
      rw[hv, heq1, ← List.append_assoc] at hd
      obtain ⟨x, y, m1, m2, hw, hd1, hd2, hn⟩ := hd.append_split
      use x, y, (m1 + 1), m2
      constructor
      exact hw
      constructor
      apply Produces.trans_derivesIn
      use r
      constructor
      exact hrin
      rw [heq2]
      apply r.rewrites_of_exists_parts
      exact hd1
      constructor
      rwa [heq3]
      rw [hn]
      omega
    | inr hc =>
      obtain ⟨heq1, heq2, heq3⟩ := hc
      rw[hv, heq1, List.append_assoc, List.append_assoc] at hd
      obtain ⟨x, y, m1, m2, hw, hd1, hd2, hn⟩ := hd.append_split
      use x, y, m1, m2 + 1
      constructor
      exact hw
      constructor
      rwa [heq2]
      constructor
      apply Produces.trans_derivesIn
      use r
      constructor
      exact hrin
      rw [heq3]
      apply r.rewrites_of_exists_parts
      rwa [List.append_assoc]
      omega

lemma DerivesIn.three_split {p q r w : List (Symbol T g.NT)} {n : ℕ} (h : g.DerivesIn (p ++ q ++ r) w n) :
  ∃ x y z m1 m2 m3, w = x ++ y ++ z ∧ g.DerivesIn p x m1 ∧ g.DerivesIn q y m2
    ∧ g.DerivesIn r z m3 ∧ n = m1 + m2 + m3 := by
  obtain ⟨x', z, m1', m3, hw2, hd1', hd3, hn2⟩ := h.append_split
  obtain ⟨x, y, m1, m2, hw1, hd1, hd2, hn1⟩ := hd1'.append_split
  use x, y, z, m1, m2, m3
  constructor
  rw [hw2, hw1]
  constructor
  exact hd1
  constructor
  exact hd2
  constructor
  exact hd3
  rw [hn2, hn1]

lemma Produces.rule {v : g.NT } {w : List (Symbol T g.NT)} (h : g.Produces [Symbol.nonterminal v] w) :
  ContextFreeRule.mk v w ∈ g.rules := by
  obtain ⟨r, hrin, hr⟩ := h
  cases hr
  simp
  exact hrin
  contradiction

end Stuff

section UnitPairs

variable {g : ContextFreeGrammar.{0,0} T}
variable [DecidableEq g.NT]

abbrev unitRule (v1 v2 : g.NT) : ContextFreeRule T g.NT := ContextFreeRule.mk v1 [Symbol.nonterminal v2]

inductive UnitPair : g.NT → g.NT → Prop where
  | refl (v : g.NT) (h : v ∈ g.generators): UnitPair v v
  | trans {v1 v2 v3 : g.NT} (hr : unitRule v1 v2 ∈ g.rules)
         (hu : UnitPair v2 v3): UnitPair v1 v3

@[refl]
lemma UnitPair.rfl {v1 : g.NT} {h : v1 ∈ generators} : UnitPair v1 v1 := UnitPair.refl v1 h

lemma UnitPair.derives {v1 v2 : g.NT} (h : UnitPair v1 v2) :
  g.Derives [Symbol.nonterminal v1] [Symbol.nonterminal v2] := by
  induction h with
  | refl => rfl
  | trans hr _ ih =>
    apply Produces.trans_derives
    constructor
    constructor
    exact hr
    unfold unitRule
    constructor
    exact ih

abbrev NonUnit {N : Type} (w : List (Symbol T N)) :=
  match w with
  | [Symbol.nonterminal _] => False
  | _ => True

lemma DerivesIn.unitPair_prefix {w : List T} {w' : List (Symbol T g.NT)} {v : g.NT} {n : ℕ}
  (h: g.DerivesIn w' (List.map Symbol.terminal w) n) (hv : v ∈ g.generators) (heq : [Symbol.nonterminal v] = w') :
  ∃ u x m, UnitPair v u ∧ g.Produces [Symbol.nonterminal u] x ∧ NonUnit x ∧ m ≤ n
       ∧ g.DerivesIn x (List.map Symbol.terminal w) m := by
  induction h using DerivesIn.induction_refl_head generalizing v with
  | refl =>
    cases w <;> simp at heq
  | @head n w'' v' hp hd ih =>
    by_cases h' : NonUnit v'
    · use v, v', n
      constructor
      exact @UnitPair.rfl _ _ _ v hv
      rw [heq]
      repeat first | assumption | omega | constructor
    · unfold NonUnit at h'
      match v' with
      | [Symbol.nonterminal v'] =>
        have h' : v' ∈ generators := by
          cases n with
          | zero => cases w <;> cases hd
          | succ n =>
            obtain ⟨w', hp, _⟩ := hd.head_of_succ
            apply nonterminal_in_generators
            apply hp.rule
            rfl
        obtain ⟨v'', w', m, h1, h2, h3, h4, h5⟩ := @ih v' h' rfl
        use v'', w', m
        constructor
        · constructor
          · unfold unitRule
            rw [←heq] at hp
            exact hp.rule
          · exact h1
        · repeat first | assumption | omega | constructor
      | [Symbol.terminal _] => simp at h'
      | [] => simp at h'
      | _ :: _ :: _ => simp at h'

end UnitPairs

-- *********************************************************************************************** --
-- ****************************************** Unit Pairs ***************************************** --
-- *********************************************************************************************** --

section ComputeUnitPairs

variable {g : ContextFreeGrammar.{0,0} T}
variable [DecidableEq g.NT]

noncomputable def generators_prod_diag : Finset (g.NT × g.NT) :=
  (g.rules.toList.map (fun r => (r.input, r.input))).toFinset

lemma generators_prod_diag_subset : g.generators_prod_diag ⊆ g.generators ×ˢ g.generators := by
  unfold generators_prod_diag generators
  cases g.rules.toList with
  | nil => simp
  | cons hd tl =>
    simp
    intro p h
    simp at h
    cases h with
    | inl h =>
      rw [Finset.mem_product, h]
      simp
    | inr h =>
      obtain ⟨p', hpin, heq⟩ := h
      repeat rw [←heq]
      simp
      right
      use p'

lemma generators_prod_diag_unitPairs {p : g.NT × g.NT} (h : p ∈ g.generators_prod_diag) : UnitPair p.1 p.2  := by
  unfold generators_prod_diag at h
  revert h
  cases heq : g.rules.toList with
  | nil => tauto
  | cons hd tl =>
    simp
    intro h
    cases h with
    | inl h =>
      rw [h]
      simp
      constructor
      apply input_in_generators
      rw [←Finset.mem_toList, heq]
      exact List.mem_cons_self hd tl
    | inr h =>
      obtain ⟨v, hin, hv2⟩ := h
      rw [← hv2]
      simp
      constructor
      apply input_in_generators
      rw [←Finset.mem_toList, heq]
      exact List.mem_cons_of_mem hd hin

def collect_unitPair (input output : g.NT) (pair : g.NT × g.NT) (pairs : Finset (g.NT × g.NT)) : Finset (g.NT × g.NT) :=
  if output = pair.1 then insert (input, pair.2) pairs else pairs

def collect_unitPairs (r : ContextFreeRule T g.NT) (pairs : List (g.NT × g.NT)) : Finset (g.NT × g.NT) :=
  match r.output with
  | [Symbol.nonterminal v] => pairs.foldr (collect_unitPair r.input v) {}
  | _ => {}

lemma rec_collect_unitPairs_unitPairs {input output : g.NT} {p : g.NT × g.NT} {pairs : List (g.NT × g.NT)}
  {collection : Finset (g.NT × g.NT)} (h : p ∈ pairs.foldr (collect_unitPair input output) collection) :
  p ∈ collection ∨ ∃ v, (output, v) ∈ pairs ∧ p = (input, v) := by
  revert collection
  induction pairs with
  | nil =>
    intro collection h
    left
    assumption
  | cons hd tl ih =>
    intro collection
    unfold collect_unitPair
    simp
    split <;> (rename_i heq; intro h)
    · simp at h
      cases h with
      | inl h =>
        right
        use hd.2
        constructor
        left
        rw [heq]
        rw[h]
      | inr h =>
        specialize ih h
        cases ih with
        | inl h' => left; assumption
        | inr h' =>
          obtain ⟨v, hv1, hv2⟩ := h'
          right
          use v
          rw [hv2]
          constructor
          right
          assumption
          rfl
    · specialize ih h
      cases ih with
      | inl h' => left; assumption
      | inr h' =>
        obtain ⟨v, hv1, hv2⟩ := h'
        right
        use v
        rw [hv2]
        constructor
        right
        assumption
        rfl

lemma collect_unitPairs_unitPair {r : ContextFreeRule T g.NT} (pairs : List (g.NT × g.NT)) (hrin : r ∈ g.rules)
  (h : ∀ p ∈ pairs, UnitPair p.1 p.2) : ∀ p ∈ collect_unitPairs r pairs, UnitPair p.1 p.2 := by
  intro p h'
  unfold collect_unitPairs at h'
  match heq : r.output with
  | [Symbol.nonterminal v] =>
    rw[heq] at h'
    simp at h'
    have h'' := rec_collect_unitPairs_unitPairs h'
    cases h'' <;> rename_i h''
    contradiction
    obtain ⟨v', h1, h2⟩ := h''
    constructor
    unfold unitRule
    rw [← heq, h2]
    exact hrin
    apply h at h1
    rw [h2]
    exact h1
  | [] =>
    rw[heq] at h'
    simp at h'
  | [Symbol.terminal _ ] =>
    rw[heq] at h'
    simp at h'
  | x :: y :: tl =>
    rw[heq] at h'
    simp at h'

--  Single round of fixpoint iteration
--  Add all rules' lefthand variable if all output symbols are in the set of nullable symbols
noncomputable def add_unitPairs (pairs : Finset (g.NT × g.NT)) : Finset (g.NT × g.NT) :=
  g.rules.toList.attach.foldr (fun r p => collect_unitPairs r pairs.toList ∪ p) pairs

lemma collect_unitPairs_subset_generators_prod {r : ContextFreeRule T g.NT} (pairs : Finset (g.NT × g.NT))
  (hp : pairs ⊆ g.generators ×ˢ g.generators) (hrin : r ∈ g.rules):
  collect_unitPairs r pairs.toList ⊆ g.generators ×ˢ g.generators := by
  unfold collect_unitPairs
  intro p h
  match heq : r.output with
  | [Symbol.nonterminal v] =>
    rw [heq] at h
    simp at h
    obtain h' := rec_collect_unitPairs_unitPairs h
    cases h'
    contradiction
    simp
    rename_i h'
    obtain ⟨v', hin, hp2⟩ := h'
    rw [hp2]
    simp
    constructor
    · exact input_in_generators hrin
    · rw [Finset.mem_toList] at hin
      specialize hp hin
      simp at hp
      exact hp.2
  | [] =>
    rw [heq] at h
    simp at h
  | [Symbol.terminal _] =>
    rw [heq] at h
    simp at h
  | x :: y :: tl =>
    rw [heq] at h
    simp at h

lemma add_unitPairs_subset_generators_prod (pairs : Finset (g.NT × g.NT)) (p : pairs ⊆ g.generators ×ˢ g.generators) :
  add_unitPairs pairs ⊆ g.generators ×ˢ g.generators := by
  unfold add_unitPairs
  induction g.rules.toList.attach with
  | nil => exact p
  | cons hd tl ih =>
    simp at ih ⊢
    apply Finset.union_subset
    · apply collect_unitPairs_subset_generators_prod
      exact p
      exact Finset.mem_toList.1 hd.2
    · exact ih

lemma add_unitPairs_grows (pairs : Finset (g.NT × g.NT)) :
  pairs ⊆ (add_unitPairs pairs) := by
  unfold add_unitPairs
  induction g.rules.toList.attach with
  | nil =>
    simp
  | cons hd tl ih =>
    apply subset_trans ih
    simp

-- Proof of our termination measure shrinking
lemma generators_prod_limits_unitPairs (pairs : Finset (g.NT × g.NT)) (p : pairs ⊆ g.generators ×ˢ g.generators)
  (hneq : pairs ≠ add_unitPairs pairs) :
  (g.generators ×ˢ g.generators).card - (add_unitPairs pairs).card < (g.generators ×ˢ g.generators).card - pairs.card := by
   have h := HasSubset.Subset.ssubset_of_ne (add_unitPairs_grows pairs) hneq
   apply Nat.sub_lt_sub_left
   · apply Nat.lt_of_lt_of_le
     · apply Finset.card_lt_card h
     · exact Finset.card_le_card (add_unitPairs_subset_generators_prod pairs p)
   · apply Finset.card_lt_card h

noncomputable def add_unitPairs_iter (pairs : Finset (g.NT × g.NT)) (p : pairs ⊆ g.generators ×ˢ g.generators)
  : Finset (g.NT × g.NT) :=
  let pairs' := add_unitPairs pairs
  if  pairs = pairs' then
    pairs
  else
    add_unitPairs_iter pairs' (add_unitPairs_subset_generators_prod pairs p)
  termination_by ((g.generators ×ˢ g.generators).card - pairs.card)
  decreasing_by
    rename_i h
    exact generators_prod_limits_unitPairs pairs p h


-- Compute all nullable variables of a grammar
noncomputable def compute_unitPairs : Finset (g.NT × g.NT) :=
  add_unitPairs_iter g.generators_prod_diag generators_prod_diag_subset

-- ********************************************************************** --
-- Only If direction of the main correctness theorem of compute_unitPairs --
-- ********************************************************************** --

lemma add_unitPairs_unitPairs (pairs : Finset (g.NT × g.NT)) (hin : ∀ p ∈ pairs, UnitPair p.1 p.2) :
  ∀ p ∈ add_unitPairs pairs, UnitPair p.1 p.2 := by
  unfold add_unitPairs
  induction g.rules.toList.attach with
  | nil =>
    intro p
    simp
    exact hin p
  | cons hd tl ih =>
    intro p h
    simp at h
    cases h with
    | inl h =>
      apply collect_unitPairs_unitPair pairs.toList
      exact Finset.mem_toList.1 hd.2
      intro p hin'
      apply hin
      rwa[←Finset.mem_toList]
      exact h
    | inr h =>
      apply ih
      simp
      exact h

-- Main correctness result of the only if direction
lemma add_unitPair_iter_only_unitPairs (pairs : Finset (g.NT × g.NT))
  (h : pairs ⊆ g.generators ×ˢ g.generators) (hin : ∀ p ∈ pairs, UnitPair p.1 p.2) :
  ∀ p ∈ (add_unitPairs_iter pairs h), UnitPair p.1 p.2 := by
  unfold add_unitPairs_iter
  intro p
  simp
  split
  · tauto
  · apply add_unitPair_iter_only_unitPairs (add_unitPairs pairs)
          (add_unitPairs_subset_generators_prod pairs h)
    exact add_unitPairs_unitPairs pairs hin
  termination_by ((g.generators ×ˢ g.generators).card - pairs.card)
  decreasing_by
    rename_i h'
    exact generators_prod_limits_unitPairs pairs h h'

-- ***************************************************************** --
-- If direction of the main correctness theorem of compute_unitPairs --
-- ***************************************************************** --

lemma add_unitPairs_add_unitPairs_iter (pairs: Finset (g.NT × g.NT)) (p : pairs ⊆ generators ×ˢ generators) :
  add_unitPairs_iter pairs p = add_unitPairs (add_unitPairs_iter pairs p) := by
  unfold add_unitPairs_iter
  simp
  split <;> rename_i h
  · exact h
  · apply add_unitPairs_add_unitPairs_iter
  termination_by ((g.generators ×ˢ g.generators).card - pairs.card)
  decreasing_by
    rename_i h'
    exact generators_prod_limits_unitPairs pairs p h'

lemma add_unitPairs_iter_grows {pairs : Finset (g.NT × g.NT)} {h : pairs ⊆ g.generators ×ˢ g.generators} :
  pairs ⊆ (add_unitPairs_iter pairs h) := by
  unfold add_unitPairs_iter
  intro p h'
  simp
  split
  · exact h'
  · apply add_unitPairs_iter_grows
    apply add_unitPairs_grows
    exact h'
  termination_by ((g.generators ×ˢ g.generators).card - pairs.card)
  decreasing_by
    rename_i h'
    exact generators_prod_limits_unitPairs pairs h h'

lemma in_collect_unitPairs {pairs : List (g.NT × g.NT)} {v1 v2 v3 : g.NT} (h : (v2, v3) ∈ pairs) :
  (v1, v3) ∈ collect_unitPairs (unitRule v1 v2) pairs := by
  unfold collect_unitPairs
  simp
  induction pairs with
  | nil => contradiction
  | cons hd tl ih =>
    simp at h ⊢
    unfold collect_unitPair
    cases h with
    | inl h =>
      rw [← h]
      simp
    | inr h =>
      split
      · simp
        right
        exact ih h
      · exact ih h

lemma in_add_unitPairs {pairs : Finset (g.NT × g.NT)} {v1 v2 v3 : g.NT} (hpin : (v2, v3) ∈ pairs)
  (hrin : ContextFreeRule.mk v1 [Symbol.nonterminal v2] ∈ g.rules) :
  (v1, v3) ∈ add_unitPairs pairs := by
  unfold add_unitPairs
  have h := List.mem_attach g.rules.toList ⟨_, Finset.mem_toList.2 hrin⟩
  revert h v2 pairs
  induction g.rules.toList.attach with
  | nil =>
    intro pairs v2 _ hrin h
    contradiction
  | cons r t ih =>
    intro pairs v2 hpin hrin h
    cases h <;> simp at ih ⊢
    · left
      rw [← Finset.mem_toList] at hpin
      exact in_collect_unitPairs hpin
    · rename_i h
      right
      apply ih hpin hrin h

lemma unitPair_in_add_unitPairs_iter {pairs : Finset (g.NT × g.NT)} {u v : g.NT}
  (h1 : pairs ⊆ g.generators ×ˢ g.generators) (h2 : generators_prod_diag ⊆ pairs) (h3 : UnitPair u v) :
  (u, v) ∈ add_unitPairs_iter pairs h1 := by
  induction h3 with
  | refl v hin =>
    apply Finset.mem_of_subset add_unitPairs_iter_grows
    apply Finset.mem_of_subset h2
    unfold generators at hin
    unfold generators_prod_diag
    rw [List.mem_toFinset, List.mem_map] at hin ⊢
    obtain ⟨r, hrin, hr⟩ := hin
    use r
    rw [hr]
    exact ⟨hrin, rfl⟩
  | @trans v1 v2 v3 hur hp ih =>
    rw [add_unitPairs_add_unitPairs_iter]
    apply in_add_unitPairs ih hur

-- Main correctness theorem of computing all unit pairs --
lemma compute_unitPairs_iff {u v : g.NT} :
  (u,v) ∈ compute_unitPairs ↔ UnitPair u v := by
  constructor
  · intro h
    change (UnitPair (u,v).1 (u,v).2)
    apply add_unitPair_iter_only_unitPairs g.generators_prod_diag generators_prod_diag_subset
    intro p hp
    exact generators_prod_diag_unitPairs hp
    exact h
  · intro h
    unfold compute_unitPairs
    apply unitPair_in_add_unitPairs_iter
    rfl
    exact h

end ComputeUnitPairs

-- *********************************************************************************************** --
-- ************************************ Unit Rule Elimination ************************************ --
-- *********************************************************************************************** --

section EliminateUnitRules

variable {g : ContextFreeGrammar T}
variable [DecidableEq g.NT]

noncomputable def nonUnit_rules (p : g.NT × g.NT) : List (ContextFreeRule T g.NT) :=
  let fltrMp (r : ContextFreeRule T g.NT) : Option (ContextFreeRule T g.NT) :=
    if r.input = p.2 then
      match r.output with
      | [Symbol.nonterminal _] => none
      | o => ContextFreeRule.mk p.1 o
    else none
  g.rules.toList.filterMap fltrMp

noncomputable def remove_unitRules [DecidableEq T] (pairs : Finset (g.NT × g.NT)) :=
  ((pairs.toList).map nonUnit_rules).flatten.toFinset

noncomputable def eliminate_unitRules [DecidableEq T] (g : ContextFreeGrammar T) [DecidableEq g.NT] :=
  ContextFreeGrammar.mk g.NT g.initial (remove_unitRules compute_unitPairs)

-- ************************************************************************ --
-- Only If direction of the main correctness theorem of eliminate_unitRules --
-- ************************************************************************ --

-- -- First we prove that the grammar cannot derive empty (Given the input non-empty)
lemma nonUnit_rules_stuff {p : g.NT × g.NT} {r : ContextFreeRule T g.NT} (h : r ∈ nonUnit_rules p) :
  r.input = p.1 ∧ ∃ r' ∈ g.rules, r.output = r'.output ∧ r'.input = p.2 := by
  revert h
  unfold nonUnit_rules
  simp
  intro r' hrin' hr'
  split <;> simp ; rename_i w u heq
  intro hr
  rw [← hr]
  simp
  use r'

lemma remove_unitRules_stuff [DecidableEq T] {pairs : Finset (g.NT × g.NT)} {r : ContextFreeRule T g.NT}
  (h : r ∈ remove_unitRules pairs) :
    ∃ p r', p ∈ pairs ∧ r' ∈ g.rules ∧ r.input = p.1 ∧ r.output = r'.output ∧ r'.input = p.2 := by
    unfold remove_unitRules at h
    simp at h
    obtain ⟨_, ⟨⟨u,v, hpin, rfl⟩, hrin⟩⟩ := h
    obtain ⟨h1, ⟨r', hrin', ho, hi⟩⟩ := nonUnit_rules_stuff hrin
    use (u, v), r'

lemma eliminate_unitRules_implies [DecidableEq T] {v w : List (Symbol T g.NT)}
  (h : g.eliminate_unitRules.Derives v w) : g.Derives v w := by
  induction h using Relation.ReflTransGen.head_induction_on with
  | refl => rfl
  | @head v u hp _ ih =>
    obtain ⟨r, hrin, hr⟩ := hp
    unfold eliminate_unitRules at hrin
    obtain ⟨⟨p1,p2⟩, r', hpin, hrin', heq1, heq2, heq3⟩ := remove_unitRules_stuff hrin
    simp at heq1 heq3
    rw [r.rewrites_iff] at hr
    obtain ⟨p, q, hv, hu⟩ := hr
    rw [hv]
    apply Derives.trans
    · apply Derives.append_right
      apply Derives.append_left
      apply Derives.trans_produces
      rewrite [compute_unitPairs_iff] at hpin
      rewrite [heq1]
      apply hpin.derives
      rw [← heq3]
      exact rewrites_produces hrin'
    · rwa [← heq2, ←hu]

-- ******************************************************************* --
-- If direction of the main correctness theorem of eliminate_unitPairs --
-- ******************************************************************* --

lemma nonUnit_rules_correct {u v : g.NT} {w : List (Symbol T g.NT)}
  (h : {input := u, output := w} ∈ g.rules) (h2 : NonUnit w) :
  {input := v, output := w} ∈ nonUnit_rules (v, u) := by
  unfold nonUnit_rules
  simp
  use ContextFreeRule.mk u w
  simp
  constructor
  exact h
  unfold NonUnit at h2
  match h' : w with
  | [Symbol.nonterminal v] => simp at h2
  | [Symbol.terminal _] => rfl
  | [] => rfl
  | _ :: _ :: _ => simp

lemma remove_unitRules_correct [DecidableEq T] {u v : g.NT} {w : List (Symbol T g.NT)}
  {pairs : Finset (g.NT × g.NT)} (h : {input := v, output := w} ∈ g.rules) (h2 : NonUnit w)
  (h3 : (u, v) ∈ pairs) : {input := u, output := w} ∈ remove_unitRules pairs := by
  unfold remove_unitRules
  simp
  use nonUnit_rules (u, v)
  constructor
  · use u, v
  · exact nonUnit_rules_correct h h2

lemma eliminate_unitRules_produces [DecidableEq T] {u v : g.NT} {w : List (Symbol T g.NT)}
  (h1 : UnitPair u v) (h2 : g.Produces [Symbol.nonterminal v] w)
  (h3 : NonUnit w) : g.eliminate_unitRules.Produces [Symbol.nonterminal u] w := by
  unfold eliminate_unitRules Produces
  simp
  constructor
  constructor
  exact remove_unitRules_correct h2.rule h3 ((compute_unitPairs_iff).2 h1)
  nth_rewrite 2 [← w.append_nil]
  constructor

lemma nonUnit_rules_nonUnit {r : ContextFreeRule T g.NT} (h1 : r ∈ g.rules) (h2 : NonUnit r.output) :
  r ∈ nonUnit_rules (r.input, r.input) := by
  unfold nonUnit_rules
  simp
  use r
  constructor
  exact h1
  simp
  unfold NonUnit at h2
  match h : r.output with
  | [Symbol.nonterminal v] => rw [h] at h2; simp at h2
  | [Symbol.terminal _] => simp; rw [← h]
  | [] => simp; rw [← h]
  | _ :: _ :: _ => simp; rw [← h]

lemma nonUnit_in_eliminate_unitRules [DecidableEq T] {r : ContextFreeRule T g.NT} (h : r ∈ g.rules)
  (h' : NonUnit r.output) : (r ∈ g.eliminate_unitRules.rules) := by
  unfold eliminate_unitRules
  simp
  unfold remove_unitRules
  simp
  use (nonUnit_rules (r.input, r.input))
  constructor
  · use r.input, r.input
    constructor
    · rw [compute_unitPairs_iff]
      apply UnitPair.rfl
      exact nonterminal_in_generators h rfl
    · rfl
  · exact nonUnit_rules_nonUnit h h'

lemma implies_eliminate_unitRules [DecidableEq T] {w : List (Symbol T g.NT)} {s : List T} {n : ℕ}
  (h : g.DerivesIn w (List.map Symbol.terminal s) n) :
  g.eliminate_unitRules.Derives w (List.map Symbol.terminal s):= by
  cases n with
  | zero =>
    cases h
    rfl
  | succ n =>
    obtain ⟨u, hp, hd⟩ := h.head_of_succ
    obtain ⟨r, hrin, hr⟩ := hp
    obtain ⟨p,q, hw, hu⟩ := hr.exists_parts
    by_cases h' : NonUnit r.output
    · apply Produces.trans_derives
      use r
      exact ⟨nonUnit_in_eliminate_unitRules hrin h', hr⟩
      exact implies_eliminate_unitRules hd
    · unfold NonUnit at h'
      match h : r.output with
      | [Symbol.nonterminal v] =>
        rw [h] at hu
        rw [hu] at hd
        obtain ⟨s1', s2', s3', m1, m2, m3, hs, hd1, hd2, hd3, hn⟩ := hd.three_split
        obtain ⟨s', s3, hs', hs'', hs3⟩ := List.map_eq_append_iff.1 hs
        obtain ⟨s1, s2, hs''', hs1, hs2⟩ := List.map_eq_append_iff.1 hs''
        rw [← hs1] at hd1
        rw [← hs2] at hd2
        rw [← hs3] at hd3
        rw [hs, hw, ←hs1, ←hs2, ←hs3]
        apply Derives.append_left_trans
        apply implies_eliminate_unitRules hd3
        apply Derives.append_left_trans
        have h' : v ∈ generators := by
          cases m2 with
          | zero => cases s2 <;> cases hd2
          | succ n =>
            obtain ⟨w', hp, _⟩ := hd2.head_of_succ
            apply nonterminal_in_generators
            apply hp.rule
            rfl
        obtain ⟨u, w', m2', hvu, hp, hw', _, hd2'⟩ := hd2.unitPair_prefix h' rfl
        apply Produces.trans_derives
        · apply eliminate_unitRules_produces _ hp hw'
          apply UnitPair.trans
          unfold unitRule
          rwa [← h]
          exact hvu
        · exact implies_eliminate_unitRules hd2'
        exact implies_eliminate_unitRules hd1
      | [Symbol.terminal _] => rw [h] at h'; simp at h'
      | [] => rw [h] at h'; simp at h'
      | _ :: _ :: _ => rw [h] at h'; simp at h'

-- Main correctness theorem of eliminate_unitRules
theorem eliminate_unitRules_correct [DecidableEq T] :
  g.language = g.eliminate_unitRules.language := by
  unfold language Generates
  have h' : g.eliminate_unitRules.initial = g.initial := by unfold eliminate_unitRules; rfl
  apply Set.eq_of_subset_of_subset
  · intro w h
    simp at h ⊢
    have h' : g.eliminate_unitRules.initial = g.initial := by unfold eliminate_unitRules; rfl
    rw [h']
    obtain ⟨n, h⟩ := (derives_iff_derivesIn _ _ _).1 h
    exact implies_eliminate_unitRules h
  · intro w h
    simp at h ⊢
    rw [←h']
    exact eliminate_unitRules_implies h

end EliminateUnitRules

end ContextFreeGrammar
