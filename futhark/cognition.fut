-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:3f1a2b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a
--
-- cognition.fut — Full Cognition kernel with bias, emotion, meta-beliefs
-- Parallel agent classification: Knowledge / Wisdom / Disease
-- Compile: futhark opencl cognition.fut  (or futhark c for CPU)

module Cognition = {

  -- Core IDs
  type agent    = i32
  type belief   = i32
  type evidence = i32
  type value    = i32
  type action   = i32

  -- Cognitive biases
  type bias =
    | Confirmation
    | Overconfidence
    | Anchoring
    | Availability

  -- Emotional states
  type emotion =
    | Calm
    | Fear
    | Anger
    | Joy
    | Shame

  -- Meta-beliefs (beliefs about beliefs)
  type meta_belief = { subject: belief, about_revision: bool }

  -- Core relations
  type holds    = { agent: agent, belief: belief }
  type supported = { belief: belief, evidence: evidence }
  type endorses = { agent: agent, value: value }
  type performs = { agent: agent, action: action }
  type applies  = { agent: agent, belief: belief, action: action }
  type revisable = { agent: agent, belief: belief }
  type expresses = { action: action, value: value }

  -- Extended relations
  type has_bias   = { agent: agent, bias: bias }
  type has_emotion = { agent: agent, emotion: emotion }
  type has_meta   = { agent: agent, meta: meta_belief }

  type world = {
    holds:    []holds,
    supported: []supported,
    endorses: []endorses,
    performs: []performs,
    applies:  []applies,
    revisable: []revisable,
    expresses: []expresses,
    biases:   []has_bias,
    emotions: []has_emotion,
    metas:    []has_meta
  }

  -- ── Classifiers ───────────────────────────────────────────────────────────

  -- Knowledge: agent holds at least one belief
  let knowledge (w: world) (a: agent): bool =
    any (\h -> h.agent == a) w.holds

  -- Wisdom: openness to revision + value alignment + applied beliefs
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

  -- Disease: blocked revision or value-misaligned action
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

  -- Bias influence: count of bias entries for agent
  let bias_score (w: world) (a: agent): f32 =
    f32.i32 (length (filter (\b -> b.agent == a) w.biases))

  -- Emotion influence: count of emotion entries for agent
  let emotion_score (w: world) (a: agent): f32 =
    f32.i32 (length (filter (\e -> e.agent == a) w.emotions))

  -- ── Parallel classification ────────────────────────────────────────────────

  -- Returns (agent, knowledge, wisdom, diseased, bias_score, emotion_score)
  let classify (w: world) (agents: []agent)
      : [](agent, bool, bool, bool, f32, f32) =
    map (\a ->
      ( a
      , knowledge w a
      , wise w a
      , diseased w a
      , bias_score w a
      , emotion_score w a
      )
    ) agents

  -- ── Deterministic world generator ─────────────────────────────────────────

  let random_world (n_agents: i32) (n_beliefs: i32) (n_actions: i32): world =
    let agents  = iota n_agents
    let beliefs = iota n_beliefs
    let actions = iota n_actions

    let holds =
      map (\i ->
        { agent  = agents[i % n_agents]
        , belief = beliefs[i % n_beliefs] }
      ) (iota (n_agents * 2))

    let performs =
      map (\i ->
        { agent  = agents[i % n_agents]
        , action = actions[i % n_actions] }
      ) (iota (n_agents * 2))

    let endorses =
      map (\i ->
        { agent = agents[i % n_agents]
        , value = i32.i32 (i % 4) }
      ) (iota (n_agents * 2))

    let revisable =
      map (\h -> { agent = h.agent, belief = h.belief }) holds

    let applies =
      map (\p ->
        { agent  = p.agent
        , belief = beliefs[p.action % n_beliefs]
        , action = p.action }
      ) performs

    let expresses =
      map (\p ->
        { action = p.action
        , value  = i32.i32 (p.action % 4) }
      ) performs

    let biases =
      map (\a -> { agent = a, bias = Confirmation }) agents

    let emotions =
      map (\a -> { agent = a, emotion = Calm }) agents

    let metas =
      map (\h ->
        { agent = h.agent
        , meta  = { subject = h.belief, about_revision = true } }
      ) holds

    { holds     = holds
    , supported = []supported
    , endorses  = endorses
    , performs  = performs
    , applies   = applies
    , revisable = revisable
    , expresses = expresses
    , biases    = biases
    , emotions  = emotions
    , metas     = metas
    }

}
