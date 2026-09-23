# SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
# CLONE_GATE:AES256:b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3
#
# runtime.cr — Full Crystal runtime: Futhark bridge + CLI + Metrics + Alloy export
# Compile: crystal build crystal/runtime.cr -o cognition
# Run:     ./cognition classify -a 10 -b 5 -x 5

require "json"
require "option_parser"
require "process"

# ── Data types ────────────────────────────────────────────────────────────────

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

struct Bias
  getter agent : Int32
  getter kind : String

  def initialize(@agent, @kind)
  end
end

struct Emotion
  getter agent : Int32
  getter kind : String

  def initialize(@agent, @kind)
  end
end

struct MetaBelief
  getter agent : Int32
  getter subject : Int32
  getter about_revision : Bool

  def initialize(@agent, @subject, @about_revision)
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
  getter biases : Array(Bias)
  getter emotions : Array(Emotion)
  getter metas : Array(MetaBelief)

  def initialize(
    @holds, @supported, @endorses, @performs,
    @applies, @revisable, @expresses,
    @biases, @emotions, @metas
  )
  end
end

# ── Futhark bridge ────────────────────────────────────────────────────────────

class CognitionRuntime
  def initialize(@futhark_path : String)
  end

  def classify(world : World, agents : Array(Int32))
    payload = {
      holds: world.holds.map { |h| {agent: h.agent, belief: h.belief} },
      supported: world.supported.map { |s| {belief: s.belief, evidence: s.evidence} },
      endorses: world.endorses.map { |e| {agent: e.agent, value: e.value} },
      performs: world.performs.map { |p| {agent: p.agent, action: p.action} },
      applies: world.applies.map { |a| {agent: a.agent, belief: a.belief, action: a.action} },
      revisable: world.revisable.map { |r| {agent: r.agent, belief: r.belief} },
      expresses: world.expresses.map { |e| {action: e.action, value: e.value} },
      biases: world.biases.map { |b| {agent: b.agent, bias: b.kind} },
      emotions: world.emotions.map { |e| {agent: e.agent, emotion: e.kind} },
      metas: world.metas.map { |m| {agent: m.agent, subject: m.subject, about_revision: m.about_revision} },
      agents: agents,
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

# ── Scenario generators ───────────────────────────────────────────────────────

module Scenario
  BIAS_KINDS    = %w[confirmation overconfidence anchoring availability]
  EMOTION_KINDS = %w[calm fear anger joy shame]

  def self.random_world(n_agents : Int32, n_beliefs : Int32, n_actions : Int32) : World
    agents  = (0...n_agents).to_a
    beliefs = (0...n_beliefs).to_a
    actions = (0...n_actions).to_a

    holds = agents.flat_map do |a|
      beliefs.sample(2).map { |b| Holds.new(a, b) }
    end

    performs = agents.flat_map do |a|
      actions.sample(2).map { |x| Performs.new(a, x) }
    end

    endorses = agents.flat_map do |a|
      [Endorses.new(a, rand(0..3))]
    end

    revisable = holds.map { |h| Revisable.new(h.agent, h.belief) }

    applies = performs.map do |p|
      b = beliefs.sample
      Applies.new(p.agent, b, p.action)
    end

    expresses = performs.map do |p|
      Expresses.new(p.action, rand(0..3))
    end

    biases    = agents.map { |a| Bias.new(a, BIAS_KINDS.sample) }
    emotions  = agents.map { |a| Emotion.new(a, EMOTION_KINDS.sample) }
    metas     = holds.map  { |h| MetaBelief.new(h.agent, h.belief, true) }

    World.new(
      holds: holds,
      supported: [] of Supported,
      endorses: endorses,
      performs: performs,
      applies: applies,
      revisable: revisable,
      expresses: expresses,
      biases: biases,
      emotions: emotions,
      metas: metas
    )
  end
end

# ── Metrics / output ──────────────────────────────────────────────────────────

module Metrics
  alias Summary = Array(NamedTuple(
    agent: Int32, knowledge: Bool, wisdom: Bool,
    diseased: Bool, bias_score: Float64, emotion_score: Float64))

  def self.parse(classification : JSON::Any) : Summary
    classification.as_a.map do |row|
      {
        agent:         row[0].as_i,
        knowledge:     row[1].as_bool,
        wisdom:        row[2].as_bool,
        diseased:      row[3].as_bool,
        bias_score:    row[4].as_f,
        emotion_score: row[5].as_f,
      }
    end
  end

  def self.to_json(summary : Summary) : String
    summary.to_json
  end

  def self.to_svg(summary : Summary) : String
    max_agent = summary.map(&.[:agent]).max? || 0
    width  = 900
    height = 450
    scale_x = max_agent == 0 ? 40.0 : (width - 40).to_f / (max_agent + 1)

    String.build do |s|
      s << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" )
      s << %(style="background:#111;font-family:monospace">\n)
      s << %(<text x="10" y="20" fill="#aaa" font-size="12">● wisdom  ● disease  ● knowledge-only</text>\n)

      summary.each do |row|
        x     = 20 + (row[:agent] * scale_x).to_i
        color = if row[:wisdom]   then "lime"
                elsif row[:diseased] then "red"
                elsif row[:knowledge] then "gold"
                else "gray"
                end
        y = 120 + (row[:emotion_score] * 15).to_i
        s << %(<circle cx="#{x}" cy="#{y}" r="8" fill="#{color}" opacity="0.85"/>\n)
        s << %(<text x="#{x - 4}" y="#{y + 20}" fill="#ccc" font-size="9">#{row[:agent]}</text>\n)
      end
      s << %(</svg>\n)
    end
  end

  def self.print_table(summary : Summary)
    puts "%-6s %-10s %-8s %-10s %-11s %-13s" % [
      "agent", "knowledge", "wisdom", "diseased", "bias_score", "emotion_score"
    ]
    puts "-" * 62
    summary.each do |row|
      puts "%-6d %-10s %-8s %-10s %-11.1f %-13.1f" % [
        row[:agent],
        row[:knowledge].to_s,
        row[:wisdom].to_s,
        row[:diseased].to_s,
        row[:bias_score],
        row[:emotion_score],
      ]
    end
  end
end

# ── Alloy export ──────────────────────────────────────────────────────────────

module AlloyExport
  def self.world_to_alloy(world : World) : String
    String.build do |s|
      s << "-- Auto-generated Alloy instance from sovereign-cognition runtime\n"
      s << "-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0\n\n"
      s << "module CognitionInstance\n\n"
      s << "open CognitivePathology\n\n"

      # Enumerate atoms
      agent_ids  = world.holds.map(&.agent).uniq.sort
      belief_ids = world.holds.map(&.belief).uniq.sort

      s << "-- Agent atoms\n"
      agent_ids.each { |a| s << "one sig Agent#{a} extends Agent {}\n" }
      s << "\n-- Belief atoms\n"
      belief_ids.each { |b| s << "one sig Belief#{b} extends Belief {}\n" }
      s << "\n"

      s << "-- Holds facts\n"
      world.holds.each do |h|
        s << "fact { some h: Holds | h.agent = Agent#{h.agent} and h.belief = Belief#{h.belief} }\n"
      end
      s << "\n"

      s << "-- Revisable facts\n"
      world.revisable.each do |r|
        s << "fact { some rv: Revisable | rv.agent = Agent#{r.agent} and rv.belief = Belief#{r.belief} }\n"
      end
    end
  end
end

# ── CLI ───────────────────────────────────────────────────────────────────────

class CLI
  def initialize(@runtime : CognitionRuntime)
  end

  def run
    command   = ""
    n_agents  = 10
    n_beliefs = 5
    n_actions = 5
    iterations = 10

    OptionParser.parse do |parser|
      parser.banner = "Usage: cognition <command> [options]"
      parser.on("classify",       "Classify agents in a random world")  { command = "classify" }
      parser.on("simulate",       "Run N iterations of random worlds")   { command = "simulate" }
      parser.on("export-alloy",   "Export world as Alloy instance")      { command = "export-alloy" }
      parser.on("render-diagram", "Render SVG diagram of classification") { command = "render-diagram" }
      parser.on("-a N", "--agents=N",     "Number of agents (default 10)")   { |v| n_agents = v.to_i }
      parser.on("-b N", "--beliefs=N",    "Number of beliefs (default 5)")   { |v| n_beliefs = v.to_i }
      parser.on("-x N", "--actions=N",    "Number of actions (default 5)")   { |v| n_actions = v.to_i }
      parser.on("-n N", "--iterations=N", "Simulation iterations (default 10)") { |v| iterations = v.to_i }
      parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
    end

    agents = (0...n_agents).to_a

    case command
    when "classify"
      world = Scenario.random_world(n_agents, n_beliefs, n_actions)
      c     = @runtime.classify(world, agents)
      s     = Metrics.parse(c)
      Metrics.print_table(s)

    when "simulate"
      iterations.times do |i|
        w = Scenario.random_world(n_agents, n_beliefs, n_actions)
        c = @runtime.classify(w, agents)
        s = Metrics.parse(c)
        puts "--- iteration #{i + 1} ---"
        Metrics.print_table(s)
      end

    when "export-alloy"
      world = Scenario.random_world(n_agents, n_beliefs, n_actions)
      puts AlloyExport.world_to_alloy(world)

    when "render-diagram"
      world = Scenario.random_world(n_agents, n_beliefs, n_actions)
      c     = @runtime.classify(world, agents)
      s     = Metrics.parse(c)
      puts Metrics.to_svg(s)

    else
      STDERR.puts "No command. Use: classify | simulate | export-alloy | render-diagram"
      exit 1
    end
  end
end

# ── Entry point ───────────────────────────────────────────────────────────────

runtime = CognitionRuntime.new("./cognition_futhark_binary")
CLI.new(runtime).run
