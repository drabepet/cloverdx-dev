# cloverdx-dev — Claude Skill

A Claude Code skill that turns Claude into a CloverDX development co-pilot.
It activates when working inside a CloverDX sandbox or when any CloverDX development
task is mentioned, and provides deep knowledge of graphs, CTL2, components, metadata,
and server operations.

## What It Covers

| Area | Files |
|---|---|
| **CTL2 language** | `ctlref.md` + 6 focused sub-files (types, strings, dates, conversions, containers, math) |
| **Components** | `components.md` + 8 sub-files (readers, writers, transformers, joiners, sorters, jobflow, data services, subgraphs) |
| **Metadata** | `metadata.md` — record types, field types, .fmt files, inline metadata, edge assignment |
| **Graph XML** | `graph-xml.md` — .grf structure with real annotated examples |
| **Jobflow XML** | `jobflow-xml.md` — .jbf structure, LOOP/RETRY/fan-out patterns |
| **Subgraph XML** | `subgraph-xml.md` — .sgrf structure, port declaration, ComponentReference |
| **Data Service XML** | `dataservice-xml.md` — .rjob structure, GET/POST/upload patterns |
| **Patterns** | `patterns.md` — 20 common ETL patterns from real examples |
| **Debugging** | `debugging.md` — MCP diagnostic workflows, log analysis |
| **Architecture** | `architecture.md` — dual JVM model, memory sizing, AWS deployment |

## Installation

1. Download the latest zip from [Releases](../../releases)
2. In Claude desktop → Settings → Customize → Skills → Import
3. Select the zip file

## MCP Integration

When connected to a CloverDX Server via MCP, the skill uses live tools to:
- Inspect server version and configuration (`deployment_current`)
- Read execution history and logs (`retrieve_tracking_get`, `retrive_graph_log_get`)
- Query performance metrics (`list_performance_logs`)
- Read server-side sandbox files (`retrieve_sandbox_file`)

## Development

Reference files are in `references/`. Each file is focused and self-contained —
the skill loads only what the current task requires to stay within context limits.

To update the skill after editing files, package as a zip and re-import:
```bash
zip -r cloverdx-dev-skill.zip skill/
```
