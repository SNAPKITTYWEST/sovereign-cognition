-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6
--
-- CognitionCore.als — Core cognition model with classification assertions
-- Mirrors the cognition_core.fut Futhark kernel structure in Alloy.
-- Run: java -jar alloy.jar CognitionCore.als

sig Agent {}
sig Belief {}
sig Evidence {}
sig Value {}
sig Action {}

-- Core relations
sig Holds     { agent: Agent, belief: Belief }
sig SupportedBy { belief: Belief, evidence: Evidence }
sig Endorses  { agent: Agent, value: Value }
sig Performs  { agent: Agent, action: Action }
sig Applies   { agent: Agent, belief: Belief, action: Action }
sig Revisable { agent: Agent, belief: Belief }
sig Expresses { action: Action, value: Value }

-- Knowledge: agent holds at least one belief
pred Knowledge[a: Agent] {
  some b: Belief | Holds.agent = a and Holds.belief = b
}

-- Wisdom: all three conditions
pred Wise[a: Agent] {
  -- (1) All held beliefs revisable
  all b: Belief |
    Holds.agent = a and Holds.belief = b
      implies Revisable.agent = a and Revisable.belief = b

  -- (2) All actions value-aligned
  all x: Action |
    Performs.agent = a and Performs.action = x
      implies some v: Value |
        Endorses.agent = a and Endorses.value = v and
        Expresses.action = x and Expresses.value = v

  -- (3) All actions belief-applied
  all x: Action |
    Performs.agent = a and Performs.action = x
      implies some b: Belief |
        Applies.agent = a and Applies.belief = b and Applies.action = x
}

-- Disease: blocked revision OR misaligned action
pred Diseased[a: Agent] {
  some b: Belief |
    Holds.agent = a and Holds.belief = b and
    not (Revisable.agent = a and Revisable.belief = b)
  or
  some x: Action |
    Performs.agent = a and Performs.action = x and
    no v: Value |
      Endorses.agent = a and Endorses.value = v and
      Expresses.action = x and Expresses.value = v
}

-- Invariants
fact WisdomImpliesKnowledge {
  all a: Agent | Wise[a] implies Knowledge[a]
}

fact DiseaseCompatibleWithKnowledge {
  some a: Agent | Diseased[a] and Knowledge[a]
}

fact NoWiseDiseased {
  no a: Agent | Wise[a] and Diseased[a]
}

fact KnowledgeWithoutWisdomExists {
  some a: Agent | Knowledge[a] and not Wise[a]
}

-- Assertions
assert WiseNotDiseased {
  all a: Agent | Wise[a] implies not Diseased[a]
}
check WiseNotDiseased for 6

assert KnowledgeNotSufficientForWisdom {
  some a: Agent | Knowledge[a] and not Wise[a]
}
check KnowledgeNotSufficientForWisdom for 6

assert DiseaseBlocksWisdom {
  all a: Agent | Diseased[a] implies not Wise[a]
}
check DiseaseBlocksWisdom for 6
