# SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
# CLONE_GATE:AES256:c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4
#
# runtime_core.cr — Core Crystal runtime (no bias/emotion/meta extensions)
# Minimal bridge to the Futhark cognition_core binary.
# Compile: crystal build crystal/runtime_core.cr -o cognition_core

require "json"
require "process"

struct Holds
  getter agent : Int32
  getter belief : Int32

  def initialize(@agent, @belief)
  end
end

struct Supported
  getter belief : Int32
  getter evidence : Int32

  def initialize(@belief, @evidence)
  end
end

struct Endorses
  getter agent : Int32
  getter value : Int32

  def initialize(@agent, @value)
  end
end

struct Performs
  getter agent : Int32
  getter action : Int32

  def initialize(@agent, @action)
  end
end

struct Applies
  getter agent : Int32
  getter belief : Int32
  getter action : Int32

  def initialize(@agent, @belief, @action)
  end
end

struct Revisable
  getter agent : Int32
  getter belief : Int32

  def initialize(@agent, @belief)
  end
end

struct Expresses
  getter action : Int32
  getter value : Int32

  def initialize(@action, @value)
  end
end

struct World
  getter holds : Array(Holds)
  getter supported : Array(Supported)
  getter endorses : Array(Endorses)
  getter performs : Array(Performs)
  getter applies : Array(Applies)
  getter revisable : Array(Revisable)
  getter expresses : Array(Expresses)

  def initialize(@holds, @supported, @endorses, @performs, @applies, @revisable, @expresses)
  end
end

class CognitionRuntime
  def initialize(@futhark_path : String)
  end

  def classify(world : World, agents : Array(Int32))
    payload = {
      holds:     world.holds.map { |h| {agent: h.agent, belief: h.belief} },
      supported: world.supported.map { |s| {belief: s.belief, evidence: s.evidence} },
      endorses:  world.endorses.map { |e| {agent: e.agent, value: e.value} },
      performs:  world.performs.map { |p| {agent: p.agent, action: p.action} },
      applies:   world.applies.map { |a| {agent: a.agent, belief: a.belief, action: a.action} },
      revisable: world.revisable.map { |r| {agent: r.agent, belief: r.belief} },
      expresses: world.expresses.map { |e| {action: e.action, value: e.value} },
      agents:    agents,
    }.to_json

    io = IO::Memory.new
    io.puts payload
    io.rewind

    output = String.build do |buf|
      Process.run(@futhark_path, input: io, output: buf)
    end

    JSON.parse(output)
  end
end

# ── Example usage ─────────────────────────────────────────────────────────────

world = World.new(
  holds:     [Holds.new(0, 0), Holds.new(1, 1)],
  supported: [] of Supported,
  endorses:  [Endorses.new(0, 0), Endorses.new(1, 1)],
  performs:  [Performs.new(0, 0), Performs.new(1, 1)],
  applies:   [Applies.new(0, 0, 0), Applies.new(1, 1, 1)],
  revisable: [Revisable.new(0, 0), Revisable.new(1, 1)],
  expresses: [Expresses.new(0, 0), Expresses.new(1, 1)]
)

runtime = CognitionRuntime.new("./cognition_core_futhark_binary")
result  = runtime.classify(world, [0, 1, 2])
puts result.to_json
