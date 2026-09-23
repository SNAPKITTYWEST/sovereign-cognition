-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
--
-- cognition_core.fut — Core Cognition kernel (no bias/emotion/meta)
-- Minimal kernel for classification: Knowledge / Wisdom / Disease
-- Compile: futhark c cognition_core.fut

module Cognition = {

  type agent    = i32
  type belief   = i32
  type evidence = i32
  type value    = i32
  type action   = i32

  type holds    = { agent: agent, belief: belief }
  type supported = { belief: belief, evidence: evidence }
  type endorses = { agent: agent, value: value }
  type performs = { agent: agent, action: action }
  type applies  = { agent: agent, belief: belief, action: action }
  type revisable = { agent: agent, belief: belief }
  type expresses = { action: action, value: value }

  type world = {
    holds:    []holds,
    supported: []supported,
    endorses: []endorses,
    performs: []performs,
    applies:  []applies,
    revisable: []revisable,
    expresses: []expresses
  }

  let knowledge (w: world) (a: agent): bool =
    any (\h -> h.agent == a) w.holds

  let wise (w: world) (a: agent): bool =
    let beliefs = filter (\h -> h.agent == a) w.holds
    let rev_ok =
      all (\h ->
        any (\r -> r.agent == a && r.belief == h.belief) w.revisable
      ) beliefs

    let acts = filter (\p -> p.agent == a) w.performs
    let val_ok =
      all (\p ->
        any (\e ->
          e.action == p.action &&
          any (\en -> en.agent == a && en.value == e.value) w.endorses
        ) w.expresses
      ) acts

    let app_ok =
      all (\p ->
        any (\ap -> ap.agent == a && ap.action == p.action) w.applies
      ) acts

    rev_ok && val_ok && app_ok

  let diseased (w: world) (a: agent): bool =
    let beliefs = filter (\h -> h.agent == a) w.holds
    let bad_belief =
      any (\h ->
        not (any (\r -> r.agent == a && r.belief == h.belief) w.revisable)
      ) beliefs

    let acts = filter (\p -> p.agent == a) w.performs
    let bad_action =
      any (\p ->
        not (any (\e ->
          e.action == p.action &&
          any (\en -> en.agent == a && en.value == e.value) w.endorses
        ) w.expresses)
      ) acts

    bad_belief || bad_action

  -- Returns (agent, knowledge, wisdom, diseased)
  let classify (w: world) (agents: []agent)
      : [](agent, bool, bool, bool) =
    map (\a ->
      ( a
      , knowledge w a
      , wise w a
      , diseased w a
      )
    ) agents

}
