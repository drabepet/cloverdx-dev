# cloverdx-dev — Claude Skill for CloverDX Development

A Claude Code skill that acts as a CloverDX development co-pilot. It activates when
working inside a CloverDX sandbox or when any CloverDX development task is mentioned.

## What It Does

- Reads, writes, and modifies graph XML (`.grf`), jobflows (`.jbf`), subgraphs (`.sgrf`), and data services (`.rjob`)
- Writes correct CTL2 transformations that compile — not pseudocode
- Understands metadata, connections, parameters, and project conventions
- **Validates every generated file** via `checkConfig` API before presenting it — built-in feedback loop catches errors automatically
- When connected to a CloverDX Server via MCP: pulls live execution logs, performance metrics, and server configuration to ground advice in reality

## Knowledge Base

| Area | Coverage |
|---|---|
| CTL2 | Language reference, all built-in functions (string, date, math, conversion, container) |
| Components | All major component types with real configuration examples |
| Graph XML | `.grf` / `.jbf` / `.sgrf` / `.rjob` structure from real annotated examples |
| Metadata | Record types, field types, `.fmt` files, inline metadata, edge assignment, line-ending inspection |
| Patterns | Common ETL patterns derived from real example graphs |
| Debugging | Symptom triage table, MCP diagnostic call chains, log analysis, performance correlation |
| MCP Workflows | Step-by-step call sequences, SQL examples, field-level extraction guide |
| Architecture | Dual JVM model, memory sizing, AWS/Kubernetes deployment |

## Changelog

**Latest update**
- `mcp-workflows.md` — new reference file: canonical diagnostic call chain, step-by-step MCP call sequences with input parameters and key fields to extract
- `debugging.md` — added symptom triage table (10 symptoms mapped to likely cause and first MCP tool to call); improved per-tool guidance with `FATAL` entries, regex pattern examples, cluster failure patterns
- `SKILL.md` — trimmed inline XML examples to 3-5 line stubs (full examples live in reference files); added metadata decision rule, parameter safety check, CTL2 gotchas (null+string, decimal precision, try/catch, `replace()` regex escaping), jobflow performance warning (~42× slower for data), `stopOnFail` modes, `LIST_FILES` filter requirement
- `jobflow-xml.md` — execution model section, `$in.1.status` RunStatus documentation, `$out.0.executionLabel` + `$out.1.*` shown together
- `comp-jobflow.md` — fixed root element (`<jbf:jobflow>` → `<Graph nature="jobflow">`), `graphURL` → `jobURL`, RunStatus port mapping, async monitoring patterns
- `patterns.md`, `sandbox-discovery.md`, `ctl-types-and-syntax.md` — targeted additions

## Installation

1. Download the latest zip from [Releases](../../releases)
2. In Claude desktop → Settings → Customize → Skills → Import
3. Select the zip file

## MCP Integration

When connected to a CloverDX Server via MCP, the skill uses live tools:

| Tool | Purpose |
|---|---|
| `deployment_current` | Server version, DB, JVM, cluster info |
| `retrieve_tracking_get` | Execution history for specific runs |
| `retrive_graph_log_get` | Raw log for a single graph execution |
| `list_performance_logs` | Worker/Core heap, CPU, GC metrics |
| `retrieve_sandbox_file` | Read files from server-side sandbox |

## Repository Layout

```
skill/
  SKILL.md          — Skill definition, triggers, and workflow instructions
  scripts/
    checkconfig.sh  — Validates a job file via CloverDX checkConfig API
  references/       — 28 focused reference files loaded on demand
    ctlref.md
    ctl-*.md        — CTL2 function reference (6 files)
    components.md
    comp-*.md       — Component reference by category (8 files)
    metadata.md
    graph-xml.md
    jobflow-xml.md
    subgraph-xml.md
    dataservice-xml.md
    patterns.md
    debugging.md
    architecture.md
    sandbox-discovery.md
    mcp-workflows.md
```

## Validation Script

The skill ships with `skill/scripts/checkconfig.sh` — a reusable script that calls the
CloverDX `checkConfig` REST API and prints any issues found:

```bash
bash skill/scripts/checkconfig.sh <sandbox> <path/in/sandbox>
# e.g.
bash skill/scripts/checkconfig.sh MySandbox graph/LoadCustomers.grf
```

Exit codes: `0` = valid, `1` = issues found, `2` = server unreachable.
Defaults to `http://localhost:8083` with `clover/clover` credentials.
Override with `CLOVER_HOST`, `CLOVER_USER`, `CLOVER_PASS` env vars.
