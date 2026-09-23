-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7
--
-- Integrity.als — Seven integrity invariants for agent coherence
-- Models personal integrity as formal Alloy predicates.
-- Run: java -jar alloy.jar Integrity.als
--
-- Invariants:
--   1. Unity of inner value and outer action
--   2. Non-contradiction of values
--   3. Continuity of identity across time
--   4. Sincerity (expressed beliefs must be held)
--   5. Authentic choice (deliberated actions are not coerced)
--   6. Integration (every integrated part maps to an endorsed value)
--   7. Responsibility (every performed action is accepted)

sig Agent {}
sig Value {}
sig Belief {}
sig Action {}
sig Expression {}
sig Time {}

sig Endorsement        { agent: Agent, value: Value }
sig Believes           { agent: Agent, belief: Belief }
sig Performs           { agent: Agent, action: Action, time: Time }
sig Expresses          { agent: Agent, expr: Expression, time: Time }
sig ActionReason       { action: Action, reason: Belief }
sig Negates            { v: Value, nv: Value }
sig Mapping            { a: Agent, t1: Time, t2: Time, v1: Value, v2: Value }
sig Coerced            { action: Action }
sig Deliberated        { agent: Agent, choice: Action }
sig AcceptsConsequences { agent: Agent, action: Action }
sig Integrated         { agent: Agent, part: Value }

/* ─── INVARIANT 1: Unity of Inner Value and Outer Action ─────────────────── */

fact Unity {
  all p: Performs |
    some v: Value |
      Endorsement.agent = p.agent and Endorsement.value = v and
      ActionReason.action = p.action
}

assert BreakUnity {
  some p: Performs |
    no v: Value |
      Endorsement.agent = p.agent and Endorsement.value = v
}
check BreakUnity for 6

/* ─── INVARIANT 2: Non-Contradiction of Values ───────────────────────────── */

fact NonContradiction {
  no a: Agent |
    some v, nv: Value |
      Negates.v = v and Negates.nv = nv and
      Endorsement.agent = a and Endorsement.value = v and
      Endorsement.agent = a and Endorsement.value = nv
}

assert Contradiction {
  some a: Agent |
    some v, nv: Value |
      Negates.v = v and Negates.nv = nv and
      Endorsement.agent = a and Endorsement.value = v and
      Endorsement.agent = a and Endorsement.value = nv
}
check Contradiction for 6

/* ─── INVARIANT 3: Continuity of Identity ───────────────────────────────── */

fact Continuity {
  all m: Mapping |
    (Endorsement.agent = m.a and Endorsement.value = m.v1)
      implies (some v2: Value |
        Endorsement.agent = m.a and Endorsement.value = v2 and v2 = m.v2)
}

assert BreakContinuity {
  some m: Mapping |
    (Endorsement.agent = m.a and Endorsement.value = m.v1)
      and no v2: Value |
        Endorsement.agent = m.a and Endorsement.value = v2 and v2 = m.v2
}
check BreakContinuity for 6

/* ─── INVARIANT 4: Sincerity ─────────────────────────────────────────────── */

fact Sincerity {
  all e: Expresses |
    some b: Belief |
      Believes.agent = e.agent and Believes.belief = b and
      e.expr in b
}

assert Insincere {
  some e: Expresses |
    no b: Belief |
      Believes.agent = e.agent and Believes.belief = b and
      e.expr in b
}
check Insincere for 6

/* ─── INVARIANT 5: Authentic Choice ─────────────────────────────────────── */

fact AuthenticChoice {
  all d: Deliberated |
    not (some c: Action |
      Coerced.action = c and Deliberated.choice = c)
}

assert InauthenticChoice {
  some d: Deliberated |
    some c: Action |
      Deliberated.choice = c and Coerced.action = c
}
check InauthenticChoice for 6

/* ─── INVARIANT 6: Integration ───────────────────────────────────────────── */

fact Integration {
  all a: Agent |
    all p: Value |
      Integrated.agent = a and Integrated.part = p
        implies some v: Value |
          Endorsement.agent = a and Endorsement.value = v
}

assert Fragmented {
  some a: Agent |
    some p: Value |
      Integrated.agent = a and Integrated.part = p and
      no v: Value |
        Endorsement.agent = a and Endorsement.value = v
}
check Fragmented for 6

/* ─── INVARIANT 7: Responsibility ────────────────────────────────────────── */

fact Responsibility {
  all p: Performs |
    some ac: AcceptsConsequences |
      ac.agent = p.agent and ac.action = p.action
}

assert Irresponsible {
  some p: Performs |
    no ac: AcceptsConsequences |
      ac.agent = p.agent and ac.action = p.action
}
check Irresponsible for 6

/* ─── COMBINED INTEGRITY PREDICATE ──────────────────────────────────────── */

-- An agent has full integrity if all 7 conditions hold simultaneously.
-- (Unity + NonContradiction + Continuity encoded as facts above;
--  Sincerity + AuthenticChoice + Integration + Responsibility as facts above.)

pred FullIntegrity[a: Agent] {
  -- Value-aligned actions
  all p: Performs |
    p.agent = a implies some v: Value |
      Endorsement.agent = a and Endorsement.value = v and
      ActionReason.action = p.action
  -- No contradictory values
  no v, nv: Value |
    Negates.v = v and Negates.nv = nv and
    Endorsement.agent = a and Endorsement.value = v and
    Endorsement.agent = a and Endorsement.value = nv
  -- All actions accepted
  all p: Performs |
    p.agent = a implies some ac: AcceptsConsequences |
      ac.agent = a and ac.action = p.action
}

assert FullIntegrityExists {
  some a: Agent | FullIntegrity[a]
}
check FullIntegrityExists for 6
