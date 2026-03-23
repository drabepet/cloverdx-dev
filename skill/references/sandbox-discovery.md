# CloverDX Sandbox Discovery

> Run this workflow whenever you are first pointed at a CloverDX sandbox directory.
> Ground all subsequent work in the actual project state before writing or modifying anything.

---

## Step 1 — Map the Sandbox

```bash
find . -type f \( \
  -name "*.grf"  -o \
  -name "*.jbf"  -o \
  -name "*.sgrf" -o \
  -name "*.rjob" -o \
  -name "*.fmt"  -o \
  -name "*.ctl"  -o \
  -name "*.cfg"  -o \
  -name "*.prm"  -o \
  -name "*.jar"  \
\) | sort | head -300
```

### File Type Reference

| Extension | Type | Description |
|---|---|---|
| `.grf` | Graph | Individual ETL/transformation job |
| `.jbf` | Jobflow | Orchestration pipeline — runs graphs in sequence/parallel |
| `.sgrf` | Subgraph | Reusable graph fragment embedded in other graphs |
| `.rjob` | Data Service | REST endpoint backed by a graph |
| `.fmt` | Metadata | Standalone record structure definition |
| `.ctl` | CTL2 | External transformation code (imported by graphs) |
| `.cfg` | Config | Database connection, lookup table, or other config definition |
| `.prm` | Parameters | Parameter file (workspace.prm = project-level overrides) |
| `.jar` | Java library | External library used by GenericTransformer or custom components |

---

## Step 2 — Read Key Configuration

Always read these first — they reveal connection strings, parameter defaults, and
environment-specific settings that affect everything else.

**Priority order:**
1. `workspace.prm` — project-level parameter overrides (may differ per environment)
2. `clover.properties` — sandbox-level settings (if present)
3. Any `.cfg` files in `conn/` or `connections/` — database and service connections

**What to look for in workspace.prm:**
```properties
DATAIN_DIR=...        # input data location
DATAOUT_DIR=...       # output data location
DATATMP_DIR=...       # temp/working data
GRAPH_DIR=...         # graphs location
META_DIR=...          # metadata location
TRANS_DIR=...         # CTL2 transformations location
CONN_DIR=...          # connections location
```

Note which parameters use `${secret:...}` references (AWS Secrets Manager) vs
hardcoded values — this tells you how secrets are managed in the project.

---

## Step 3 — Classify the Directory Structure

Typical sandbox layout (naming varies by project):

```
sandbox-name/
├── graph/          or  graphs/         — .grf files
├── jobflow/        or  jobflows/       — .jbf files
├── subgraph/       or  subgraphs/      — .sgrf files
├── dataservice/    or  restjob/        — .rjob files
├── meta/           or  metadata/       — .fmt files
├── trans/          or  transformation/ — .ctl files
├── conn/           or  connections/    — .cfg connection files
├── lookup/                             — .cfg lookup table definitions
├── data-in/        or  datain/         — input data files
├── data-out/       or  dataout/        — output data files
├── data-tmp/       or  datatmp/        — temporary/working files
└── workspace.prm                       — project parameter overrides
```

Not all directories will be present — many projects skip what they don't need.

---

## Step 4 — Sample Key Artifacts

After mapping, read a few representative files to understand project conventions:

1. **One graph** — understand coding style, naming patterns, parameter usage
2. **One jobflow** (if present) — understand orchestration approach
3. **A few `.fmt` files** — understand the data model
4. **A `.cfg` connection file** — understand how DB connections are structured

Look for:
- Naming conventions (e.g., `LOAD_`, `READ_`, `TRANS_` prefixes on component IDs)
- Whether CTL2 is inline or in external `.ctl` files
- Whether metadata is inline in graphs or in standalone `.fmt` files
- How parameters are used (graph-level, workspace.prm, or jobflow-passed)
- Whether subgraphs are used for shared logic

---

## Step 5 — MCP Server Context (if connected)

When connected to a CloverDX Server via MCP, read `references/mcp-workflows.md` for full call sequences and parameter details. Quick discovery sequence:

```
1. deployment_current
      → Server version, Java version, Worker heap config, cluster topology,
        sandbox home path. Always call this first — anchors all subsequent advice.
        Note the Worker Xmx (heap ceiling) and sandbox home path.

2. list_performance_logs (recent window)
      → Baseline load check: is wHeap already high? Any swap? Is jobQueue growing?

3. retrieve_tracking_get (recent runs)
      → Any recent failures? When was the last successful run?
        Note: this also gives you runIds for failed jobs needing diagnosis.

4. retrieve_sandbox_file workspace.prm
      → Verify server-side parameter values match the environment.
        The server copy may differ from local if deployment wasn't synced.
```

Cross-check: if local files differ from server-side files, ask the user which is authoritative before making changes.

**What to note from `deployment_current` output:**
- Server version → scope advice to that version
- Worker heap Xmx → interpret `wHeap` numbers as % of this value
- Sandbox home path → needed for `retrieve_sandbox_file` calls
- Cluster size → 1 node vs multi-node changes diagnosis approach

---

## Step 6 — Report to the User

Present a concise summary before starting any work:

```
Sandbox: [name]
─────────────────────────────────────────────
Graphs:        N  (.grf)
Jobflows:      N  (.jbf)
Subgraphs:     N  (.sgrf)
Data Services: N  (.rjob)
Metadata:      N  (.fmt)
CTL files:     N  (.ctl)
─────────────────────────────────────────────
Parameters:    workspace.prm [found/not found]
Connections:   [list connection IDs found]
─────────────────────────────────────────────
Server:        [version if MCP available]
Recent runs:   [any failures? last run date?]
─────────────────────────────────────────────
Observations:  [deprecated components, missing files,
                anything unusual]
```

Only include sections that have relevant content — skip empty ones.

---

## Quick Checks to Run During Discovery

- **Deprecated components** — search for `type="RUN_GRAPH"` or `type="SYSTEM_EXECUTE"` in `.grf`/`.jbf` files; flag for replacement with `EXECUTE_GRAPH` / `EXECUTE_SCRIPT`
- **Hardcoded credentials** — check `.cfg` and `.prm` for plaintext passwords; should use `${secret:...}` or parameter references
- **Missing metadata** — edges in graphs without a `metadata` attribute on non-error ports may indicate incomplete graphs
- **Unconnected ports** — a graph that was partially built; always validate before modifying
