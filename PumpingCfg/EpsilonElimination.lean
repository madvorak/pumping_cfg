/-
Copyright (c) 2024 Alexander Loitzl. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Alexander Loitzl
-/

import Mathlib.Computability.ContextFreeGrammar

namespace ContextFreeGrammar

variable {T : Type}
variable {g : ContextFreeGrammar T}

-- *********************************************************************************************** --
-- ************************************** Nullable Symbols *************************************** --
-- *********************************************************************************************** --
variable [DecidableEq g.NT]

-- All lefthand side non-terminals
def generators : Finset g.NT := (g.rules.map (fun r => r.input)).toFinset

lemma in_generators {r : ContextFreeRule T g.NT} (h : r ∈ g.rules) :
  r.input ∈ g.generators := by
  unfold generators
  revert h
  induction g.rules with
  | nil => simp
  | cons hd tl ih =>
    simp at ih ⊢
    rintro (c1 | c2)
    · left
      rw[c1]
    · right
      exact ih c2

-- Fixpoint iteration to compute all nullable variables
-- I can't quite get functional induction to work here :(
-- NOTE If we instead shrink the set of generators the termination argument should
-- be easier. I am not so sure about the correctness proofs

def rule_is_nullable (nullable : Finset g.NT) (r : ContextFreeRule T g.NT) : Bool :=
  let symbol_is_nullable : (Symbol T g.NT) → Bool := fun s =>
    match s with
    | Symbol.terminal _ => False
    | Symbol.nonterminal nt => nt ∈ nullable
  ∀ s ∈ r.output, symbol_is_nullable s

def add_if_nullable (r : ContextFreeRule T g.NT) (nullable : Finset g.NT) : Finset g.NT :=
  if rule_is_nullable nullable r then insert r.input nullable else nullable

--  Single round of fixpoint iteration
--  Add all rules' lefthand variable if all output symbols are in the set of nullable symbols
def add_nullables (nullable : Finset g.NT) : Finset g.NT :=
  g.rules.attach.foldr (fun ⟨r, _⟩ => add_if_nullable r) nullable

-- Lemmas for termination proof
lemma add_if_nullable_subset_generators {r : ContextFreeRule T g.NT} {nullable : Finset g.NT}
  (p : nullable ⊆ g.generators) (hin : r ∈ g.rules) :
  add_if_nullable r nullable ⊆ g.generators := by
  unfold add_if_nullable
  split
  · exact Finset.insert_subset (in_generators hin) p
  · exact p

lemma add_nullables_subset_generators (nullable : Finset g.NT) (p : nullable ⊆ g.generators) :
  add_nullables nullable ⊆ g.generators := by
  unfold add_nullables
  induction g.rules.attach with
  | nil => simp; exact p
  | cons hd tl ih => exact add_if_nullable_subset_generators ih hd.2

lemma add_if_nullable_subset (r : ContextFreeRule T g.NT) (nullable : Finset g.NT) :
  nullable ⊆ (add_if_nullable r nullable) := by
  unfold add_if_nullable
  split <;> simp

lemma nullable_subset_add_nullables (nullable : Finset  g.NT) :
  nullable ⊆ (add_nullables nullable) := by
  unfold add_nullables
  induction g.rules.attach with
  | nil => simp
  | cons hd tl ih =>
    apply subset_trans ih
    apply add_if_nullable_subset hd.1

-- Main Property that guarantees the termination of our fixpoint iteration
lemma generators_limits_nullable (nullable : Finset g.NT) (p : nullable ⊆ g.generators)
  (hneq : nullable ≠ add_nullables nullable) :
  (g.generators).card - (add_nullables nullable).card < (g.generators).card - nullable.card := by
  have h := HasSubset.Subset.ssubset_of_ne (nullable_subset_add_nullables nullable) hneq
  apply Nat.sub_lt_sub_left
  · apply Nat.lt_of_lt_of_le
    · apply Finset.card_lt_card h
    · exact Finset.card_le_card (add_nullables_subset_generators nullable p)
  · apply Finset.card_lt_card h

def add_nullables_iter (nullable : Finset g.NT) (p : nullable ⊆ g.generators) : Finset g.NT :=
  let nullable' := add_nullables nullable
  if nullable = nullable' then
    nullable
  else
    add_nullables_iter nullable' (add_nullables_subset_generators nullable p)
  termination_by ((g.generators).card - nullable.card)
  decreasing_by
    rename_i h
    exact generators_limits_nullable nullable p h

-- Compute all nullable variables of a grammar
def compute_nullables : Finset g.NT :=
  add_nullables_iter ∅ generators.empty_subset

def NullableNonTerminal (v : g.NT) : Prop := g.Derives [Symbol.nonterminal v] []

-- ********************************************************************** --
-- Only If direction of the main correctness theorem of compute_nullables --
-- ********************************************************************** --

-- That's annoying
omit [DecidableEq g.NT] in
lemma all_nullable_nullable (w : List (Symbol T g.NT)) (h: ∀ v ∈ w, g.Derives [v] []) :
  g.Derives w [] := by
  induction w with
  | nil => exact Derives.refl []
  | cons hd tl ih =>
    change g.Derives ([hd] ++ tl) []
    apply Derives.trans
    · apply Derives.append_right
      apply h
      simp
    · simp
      apply ih
      intro v hv
      apply h
      right
      exact hv

lemma rule_is_nullable_correct (nullable : Finset g.NT) (r : ContextFreeRule T g.NT)
  (hrin : r ∈ g.rules) (hin : ∀ v ∈ nullable, NullableNonTerminal v) (hr : rule_is_nullable nullable r) :
  NullableNonTerminal r.input := by
  unfold rule_is_nullable at hr
  unfold NullableNonTerminal
  have h1 : g.Produces [Symbol.nonterminal r.input] r.output := by
    use r
    constructor
    exact hrin
    rw [ContextFreeRule.rewrites_iff]
    use [], []
    simp
  apply Produces.trans_derives h1
  apply all_nullable_nullable
  intro v hvin
  simp at hr
  specialize hr v hvin
  cases v <;> simp at hr
  apply hin _ hr

lemma add_nullables_nullable (nullable : Finset g.NT) (hin : ∀ v ∈ nullable, NullableNonTerminal v) :
  ∀ v ∈ add_nullables nullable, NullableNonTerminal v := by
  unfold add_nullables
  induction g.rules.attach with
  | nil =>
    simp
    apply hin
  | cons hd tl ih =>
    simp
    unfold add_if_nullable
    split
    · simp
      constructor
      · apply rule_is_nullable_correct _ _ hd.2 ih
        rename_i h
        exact h
      · exact ih
    · exact ih

-- Main correctness result of the only if direction
lemma add_nullables_iter_only_nullable (nullable : Finset g.NT) (p : nullable ⊆ g.generators)
  (hin : ∀ v ∈ nullable, NullableNonTerminal v) :
  ∀ v ∈ (add_nullables_iter nullable p), NullableNonTerminal v:= by
  unfold add_nullables_iter
  intro v
  simp
  split
  · tauto
  · have ih := add_nullables_iter_only_nullable (add_nullables nullable) (add_nullables_subset_generators nullable p)
    apply ih
    exact add_nullables_nullable nullable hin
  termination_by ((g.generators).card - nullable.card)
  decreasing_by
    rename_i h
    exact generators_limits_nullable nullable p h

-- ************************
-- If direction starts here
-- ************************

-- NOTE Here, it seems like induction on length of derivation will be needed
-- We'll want to talk about sub-derivations, hence structural induction doesn't work

-- This proof seems semi tedious
omit [DecidableEq g.NT] in
lemma epsilon_left_derives {w u v : List (Symbol T g.NT)}
  (hwe : g.Derives w []) (heq : w = u ++ v) : g.Derives u [] := by
  revert u v
  induction hwe using Relation.ReflTransGen.head_induction_on with
  | refl =>
    simp
    rfl
  | @head u v huv _ ih =>
    intro x y heq
    obtain ⟨r, rin, huv⟩ := huv
    obtain ⟨p, q, h1, h2⟩ := ContextFreeRule.Rewrites.exists_parts huv
    rw[heq, List.append_assoc, List.append_eq_append_iff] at h1
    cases h1 with
    | inl h =>
      obtain ⟨x', hx, _⟩ := h
      apply ih
      rw[h2, hx]
      simp
      rfl
    | inr h =>
      obtain ⟨x', hx, hr⟩ := h
      cases x' with
      | nil =>
        apply ih
        rw[h2, hx]
        simp
        rfl
      | cons h t =>
        obtain ⟨_, _⟩ := hr
        apply Produces.trans_derives
        use r
        constructor
        exact rin
        rw[ContextFreeRule.rewrites_iff]
        use p, t
        constructor
        · simp
          exact hx
        · rfl
        apply ih
        rw[h2]
        simp
        rfl

-- This proof seems too tedious
omit [DecidableEq g.NT] in
lemma epsilon_right_derives {w u v : List (Symbol T g.NT)}
  (hwe : g.Derives w []) (heq : w = u ++ v) : g.Derives v [] := by
  revert u v
  induction hwe using Relation.ReflTransGen.head_induction_on with
  | refl =>
    simp
    rfl
  | @head u v huv _ ih =>
    intro x y heq
    obtain ⟨r, rin, huv⟩ := huv
    obtain ⟨p, q, h1, h2⟩ := ContextFreeRule.Rewrites.exists_parts huv
    rw[heq, List.append_assoc, List.append_eq_append_iff] at h1
    cases h1 with
    | inl h =>
      obtain ⟨y', h1 , hy⟩ := h
      apply Produces.trans_derives
      use r
      constructor
      exact rin
      rw[ContextFreeRule.rewrites_iff]
      use y', q
      constructor
      · simp
        exact hy
      · rfl
      apply ih
      rw[h2,h1]
      simp
      rfl
    | inr h =>
      obtain ⟨q', hx, hq⟩ := h
      cases q' with
      | nil =>
        simp at hq
        apply Produces.trans_derives
        use r
        constructor
        exact rin
        rw[ContextFreeRule.rewrites_iff]
        use [], q
        constructor
        · simp
          tauto
        · rfl
        simp
        apply ih
        rw[h2]
        simp
        rfl
      | cons h t =>
        obtain ⟨_,_⟩ := hq
        apply ih
        rw[h2]
        simp
        rw[← List.append_assoc, ← List.append_assoc]

omit [DecidableEq g.NT] in
lemma epsilon_split_derives {w u v: List (Symbol T g.NT)}
  (hwe : g.Derives (w ++ u ++v) []) : g.Derives u [] := by
  apply epsilon_right_derives
  apply epsilon_left_derives
  exact hwe
  rw[List.append_assoc]
  rfl

-- Main correctness theorem of computing all nullable symbols --
lemma compute_nullables_iff (v : g.NT) :
  v ∈ compute_nullables ↔ NullableNonTerminal v := by
  constructor
  · intro h
    apply add_nullables_iter_only_nullable Finset.empty
    tauto
    exact h
  · sorry

-- *********************************************************************************************** --
-- ************************************* Epsilon Elimination ************************************* --
-- *********************************************************************************************** --

def nonterminalProp (s : Symbol T g.NT) (P : g.NT → Prop) :=
  match s with
  | Symbol.terminal _ => False
  | Symbol.nonterminal n => P n

def remove_nullable (nullable : Finset g.NT) (s: (Symbol T g.NT)) (acc : List (List (Symbol T g.NT))) :=
  match s with
  | Symbol.nonterminal n => (if n ∈ nullable then acc else []) ++ acc.map (fun x => s :: x)
  | Symbol.terminal _ => acc.map (fun x => s :: x)

def remove_nullable_rule (nullable : Finset g.NT) (r: ContextFreeRule T g.NT) : (List (ContextFreeRule T g.NT)) :=
  let fltrmap : List (Symbol T g.NT) → Option (ContextFreeRule T g.NT)
    | [] => Option.none
    | h :: t => ContextFreeRule.mk r.input (h :: t)
  (r.output.foldr (remove_nullable nullable) [[]]).filterMap fltrmap

def remove_nullables (nullable : Finset g.NT) : List (ContextFreeRule T g.NT) :=
  (g.rules.map (remove_nullable_rule nullable)).join

def eliminate_empty : ContextFreeGrammar T :=
  ContextFreeGrammar.mk g.NT g.initial (remove_nullables compute_nullables)

theorem eliminate_empty_correct :
  g.language = (@eliminate_empty T g).language \ {[]} := by sorry

end ContextFreeGrammar
