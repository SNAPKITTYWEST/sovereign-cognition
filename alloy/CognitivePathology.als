-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5
--
-- CognitivePathology.als — Formal model of Knowledge, Wisdom, and Disease
-- Run: java -jar alloy.jar CognitivePathology.als
-- All 5 checks expected: FindKnowledgeWithoutWisdom SAT,
--   FindDiseasedAgent SAT, BreakWisdom UNSAT,
--   MisalignedAction SAT, NonRevisableBelief SAT

module CognitivePathology

/* ============
   CORE TYPES
   ============ */

sig Agent {}
sig Belief {}
sig Value {}
sig Action {}
sig Evidence {}

/* ============
   RELATIONS
   ============ */

-- Agent holds belief
sig Holds { agent: Agent, belief: Belief }

-- Belief supported by evidence
sig SupportedBy { belief: Belief, evidence: Evidence }

-- Agent endorses value
sig Endorses { agent: Agent, value: Value }

-- Agent performs action
sig Performs { agent: Agent, action: Action }

-- Action expresses value
sig Expresses { action: Action, value: Value }

-- Belief is revisable for agent (open to revision)
sig Revisable { agent: Agent, belief: Belief }

-- Agent applies belief to action
sig Applies { agent: Agent, belief: Belief, action: Action }

/* ============
   CLASSIFIERS
   ============ */

pred Knowledge[a: Agent] {
  some b: Belief | Holds.agent = a and Holds.belief = b
}

pred Wise[a: Agent] {
  -- (1) All held beliefs must be revisable
  all b: Belief |
    Holds.agent = a and Holds.belief = b
      implies Revisable.agent = a and Revisable.belief = b

  -- (2) All actions must express at least one endorsed value
  all x: Action |
    Performs.agent = a and Performs.action = x
      implies some v: Value |
        Endorses.agent = a and Endorses.value = v and
        Expresses.action = x and Expresses.value = v

  -- (3) All actions must apply at least one held belief
  all x: Action |
    Performs.agent = a and Performs.action = x
      implies some b: Belief |
        Applies.agent = a and Applies.belief = b and Applies.action = x
}

pred Diseased[a: Agent] {
  -- Disease variant 1: some held belief is not revisable
  some b: Belief |
    Holds.agent = a and Holds.belief = b and
    not (Revisable.agent = a and Revisable.belief = b)
  or
  -- Disease variant 2: some action lacks value alignment
  some x: Action |
    Performs.agent = a and Performs.action = x and
    no v: Value |
      Endorses.agent = a and Endorses.value = v and
      Expresses.action = x and Expresses.value = v
}

/* ============
   INVARIANTS
   ============ */

-- Wisdom implies knowledge
fact WisdomImpliesKnowledge {
  all a: Agent | Wise[a] implies Knowledge[a]
}

-- Knowledge is not sufficient for wisdom
fact KnowledgeNotSufficient {
  some a: Agent | Knowledge[a] and not Wise[a]
}

-- No agent can be both wise and diseased
fact NoWiseDiseased {
  no a: Agent | Wise[a] and Diseased[a]
}

/* ============
   ASSERTIONS
   ============ */

-- Alloy should find a knowledge-without-wisdom instance
assert FindKnowledgeWithoutWisdom {
  some a: Agent | Knowledge[a] and not Wise[a]
}
check FindKnowledgeWithoutWisdom for 6

-- Alloy should find a diseased agent
assert FindDiseasedAgent {
  some a: Agent | Diseased[a]
}
check FindDiseasedAgent for 6

-- Alloy should NOT find a wise+diseased agent (invariant upheld)
assert BreakWisdom {
  some a: Agent | Wise[a] and Diseased[a]
}
check BreakWisdom for 6

-- Alloy should find a misaligned action (action without endorsed value)
assert MisalignedAction {
  some x: Action |
    some a: Agent |
      Performs.agent = a and Performs.action = x and
      no v: Value |
        Endorses.agent = a and Endorses.value = v and
        Expresses.action = x and Expresses.value = v
}
check MisalignedAction for 6

-- Alloy should find a non-revisable held belief
assert NonRevisableBelief {
  some a: Agent |
    some b: Belief |
      Holds.agent = a and Holds.belief = b and
      not (Revisable.agent = a and Revisable.belief = b)
}
check NonRevisableBelief for 6
