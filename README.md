# sovereign-cognition

[![License: AGPL-3.0-or-later OR Apache-2.0](https://img.shields.io/badge/license-AGPL--3.0--or--later%20OR%20Apache--2.0-blue.svg)](LICENSE-AGPL)
[![Crystal](https://img.shields.io/badge/Crystal-1.10%2B-black.svg)](https://crystal-lang.org/)
[![Futhark](https://img.shields.io/badge/Futhark-0.24%2B-orange.svg)](https://futhark-lang.org/)
[![Alloy](https://img.shields.io/badge/Alloy-6.0%2B-yellow.svg)](https://alloytools.org/)
[![CLONE_GATE](https://img.shields.io/badge/CLONE__GATE-AES256-black.svg)]()

> Parallel agent cognition classification: **Knowledge / Wisdom / Disease** — GPU-accelerated Futhark kernel, Crystal runtime + CLI, Alloy formal verification, SVG rendering, Alloy export.

---

## What it does

Classifies agents in a relational world model across three dimensions:

- **Knowledge** — holds at least one belief
- **Wisdom** — beliefs are revisable + actions align with endorsed values + actions apply held beliefs
- **Disease** — holds non-revisable beliefs OR performs value-misaligned actions

The classification runs in parallel over all agents via a **Futhark kernel** (compiles to OpenCL/CUDA/C). The **Crystal runtime** bridges JSON ↔ the Futhark binary, generates random worlds, renders SVG lattice diagrams, and exports Alloy instances. The **Alloy models** formally verify the invariants with a bounded SAT solver.

---

## Repository layout

```
sovereign-cognition/
├── futhark/
│   ├── cognition.fut       # Full kernel: bias, emotion, meta-belief extensions
│   └── cognition_core.fut  # Core kernel: knowledge / wisdom / disease only
├── crystal/
│   ├── runtime.cr          # Full runtime: CLI, Scenario, Metrics, SVG, AlloyExport
│   └── runtime_core.cr     # Core runtime: minimal Futhark bridge
├── alloy/
│   ├── CognitivePathology.als  # Main model: Knowledge/Wise/Diseased + 5 checks
│   ├── CognitionCore.als       # Core model: 3 classification checks
│   └── Integrity.als           # 7 integrity invariants: Unity→Responsibility
└── shard.yml
```

---

## Futhark kernels

### `cognition.fut` — Full kernel

Types: `agent`, `belief`, `evidence`, `value`, `action`, `bias` (Confirmation/Overconfidence/Anchoring/Availability), `emotion` (Calm/Fear/Anger/Joy/Shame), `meta_belief`.

```futhark
let classify (w: world) (agents: []agent)
    : [](agent, bool, bool, bool, f32, f32) =
  map (\a -> (a, knowledge w a, wise w a, diseased w a,
              bias_score w a, emotion_score w a)) agents
```

Returns `(agent_id, knowledge, wisdom, diseased, bias_score, emotion_score)` per agent.

### `cognition_core.fut` — Core kernel

Minimal version without bias/emotion/meta. Returns `(agent, knowledge, wisdom, diseased)`.

**Build:**
```bash
futhark opencl futhark/cognition.fut      # GPU
futhark c      futhark/cognition_core.fut # CPU fallback
```

---

## Crystal runtime

### `runtime.cr` — Full CLI

```bash
crystal build crystal/runtime.cr -o cognition

./cognition classify       -a 20 -b 8 -x 6   # classify 20 agents
./cognition simulate       -a 10 -n 5         # 5 random world iterations
./cognition export-alloy   -a 5               # export Alloy instance
./cognition render-diagram -a 15 > out.svg    # SVG lattice diagram
```

**Scenario generator** (`Scenario.random_world`): produces random `World` with agents, beliefs, actions, endorsed values, revisable beliefs, applied beliefs, and value-expressive actions. Randomly assigns biases and emotional states from the full vocabulary.

**Metrics output:** table (stdout), JSON, SVG lattice (agents on x-axis, colour: lime=wise, red=diseased, gold=knowledge-only, grey=none).

**Alloy export:** emits a valid Alloy instance file (`CognitionInstance.als`) for any generated world, listing `one sig AgentN extends Agent {}` atoms and the corresponding `Holds`/`Revisable` facts.

### `runtime_core.cr` — Minimal bridge

Bare `CognitionRuntime` + typed `World` struct. Drop-in for embedding in larger Crystal projects.

---

## Alloy formal models

### `CognitivePathology.als`

Full model with `module CognitivePathology`. Five bounded checks (scope 6):

| Assert | Expected | Meaning |
|--------|----------|---------|
| `FindKnowledgeWithoutWisdom` | SAT | Knowledge ≠ wisdom — instances exist |
| `FindDiseasedAgent` | SAT | Disease instances exist |
| `BreakWisdom` | **UNSAT** | No wise+diseased agent — invariant holds |
| `MisalignedAction` | SAT | Value-misaligned actions exist |
| `NonRevisableBelief` | SAT | Non-revisable held beliefs exist |

### `CognitionCore.als`

Three checks mirroring the Futhark `cognition_core.fut` structure:

| Assert | Expected |
|--------|----------|
| `WiseNotDiseased` | UNSAT |
| `KnowledgeNotSufficientForWisdom` | SAT |
| `DiseaseBlocksWisdom` | UNSAT |

### `Integrity.als`

Seven integrity invariants as Alloy facts + one assertion each:

| # | Invariant | Assert |
|---|-----------|--------|
| 1 | Unity — actions align with endorsed values | `BreakUnity` |
| 2 | Non-Contradiction — no agent endorses a value and its negation | `Contradiction` |
| 3 | Continuity — value identity persists across time mappings | `BreakContinuity` |
| 4 | Sincerity — expressed beliefs are held beliefs | `Insincere` |
| 5 | Authentic Choice — deliberated actions are not coerced | `InauthenticChoice` |
| 6 | Integration — every integrated part maps to an endorsed value | `Fragmented` |
| 7 | Responsibility — every performed action is accepted | `Irresponsible` |

`FullIntegrity[a]` predicate combines invariants 1, 2, 7 into a single per-agent check.

**Run all Alloy checks:**
```bash
java -jar alloy6.jar alloy/CognitivePathology.als
java -jar alloy6.jar alloy/CognitionCore.als
java -jar alloy6.jar alloy/Integrity.als
```

---

## Full pipeline

```
random_world()
    │
    ▼
CognitionRuntime.classify(world, agents)   ← Crystal → JSON → Futhark binary
    │
    ▼
classify() in Futhark kernel               ← parallel map over agents
    │ (agent, knowledge, wisdom, diseased, bias_score, emotion_score)
    ▼
Metrics.parse / to_json / to_svg           ← Crystal post-processing
    │
    ├── stdout table
    ├── JSON export
    ├── SVG diagram
    └── Alloy instance export
            │
            ▼
        AlloyExport.world_to_alloy()       ← feed to CognitionCore.als
```

---

## License

AGPL-3.0-or-later OR Apache-2.0 — all files carry SPDX + CLONE_GATE:AES256 headers.
