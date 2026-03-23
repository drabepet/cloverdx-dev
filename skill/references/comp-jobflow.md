# CloverDX Jobflow Components

> Source: CloverDX 7.3.1 docs + TrainingExamples jobflows (09e0x series)

Jobflows orchestrate graph execution. File extension: `.jbf`. Root element: `<Graph nature="jobflow">` (same `<Graph>` root as `.grf` files — only the `nature` attribute differs).

**Execution model:** Token-based sequential control flow. Components execute one at a time, triggered by tokens — unlike graphs where all components in a phase stream records concurrently. Default edge type is "Direct fast propagate" (no buffering). **Never use jobflows for data transformation** — a subgraph processing records inside a jobflow runs ~42x slower than the same subgraph inside a graph. Keep data processing in graphs; use jobflows exclusively for orchestration.

---

## ExecuteGraph

Runs a child graph. Replaces deprecated `RunGraph` (removed in v7.0).

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `jobURL` | Path to .grf/.jbf/.sgrf file | `${GRAPH_DIR}/loadPayments.grf` |
| `inputMapping` | CTL2 to pass parameters to child graph | see below |
| `outputMapping` | CTL2 to extract results from child graph | see below |
| `stopOnFail` | Abort jobflow if child fails | `false` (for retry/conditional patterns) |
| `executionType` | `synchronous` (default) or `asynchronous` | |
| `executorsNumber` | Max concurrent instances (when multiple tokens arrive) | `4` |
| `redirectErrorOutput` | Route all output incl. failures to port 0 | `false` |
| `executionLabel` | Label for tracking/logging | `"Loading: " + $in.0.URL` |

**inputMapping — pass parameters to child graph:**
```ctl
function integer transform() {
    $out.0.executionLabel = "Loading: " + $in.0.URL;  // tracking label
    $out.1.fileUrl = $in.0.URL;      // child's GraphParameter
    $out.1.truncate = getParamValue("TRUNCATE_TABLE");
    return ALL;
}
```
`$out.1.*` maps to child's `<GraphParameter>` entries. If the child doesn't declare a parameter, the mapping is silently ignored.

**outputMapping — read results from child graph:**
```ctl
function integer transform() {
    $out.0.status = $in.1.status;    // $in.1.* = RunStatus record
    $out.0.error = $in.1.errMessage;
    $out.0.recordCount = $in.3.outputPort_0_totalRecords;
    return ALL;
}
```

**Output port mapping:**
- `$in.0.*` — original input token (pass-through)
- `$in.1.*` — **RunStatus record** (status, errMessage, errComponent, runId, duration, etc.)
- `$in.2.*` — child's output Dictionary entries (`output="true"` fields only)
- `$in.3.*` — tracking metadata (per-component record counts)

**Key RunStatus fields:** `status` (`FINISHED_OK` / `ERROR` / `ABORTED` / `TIMEOUT`), `errMessage`, `errComponent`, `runId`, `duration`. See `jobflow-xml.md` for the full field table.

**⚠️ stopOnFail failure modes:**
- `stopOnFail="true"` (default) — first failure aborts the jobflow immediately
- `stopOnFail="false"` + error port connected — failed token routes to port 1; you handle it
- `stopOnFail="false"` + `redirectErrorOutput="true"` — **silent failure**: all output goes to port 0; always check `$in.1.status` downstream
- `stopOnFail="false"` + no error port connected — Java exception aborts the jobflow anyway

---

## MonitorGraph

Polls an asynchronous job until it completes. Used with `ExecuteGraph(executionType=asynchronous)`.

**Key properties:**
| Property | Description |
|---|---|
| `monitoringInterval` | Polling interval in milliseconds |

**Input:** `runId` from async ExecuteGraph output
**Output:** Final RunStatus record when job completes

---

## ExecuteJobflow

Runs a sub-jobflow. Same `inputMapping` / `outputMapping` / `stopOnFail` semantics as ExecuteGraph.

---

## ExecuteScript

Runs a shell command. Replaces deprecated `SystemExecute`.

**Key properties:**
| Property | Description |
|---|---|
| `command` | Shell command to execute |
| `interpreter` | Shell interpreter (bash, sh, etc.) |
| `outputEncoding` | Encoding of stdout capture |

---

## Condition (if/else branching)

Routes a token to port 0 (true) or port 1 (false) based on a boolean CTL2 expression. Identical syntax to EXT_FILTER but operates on jobflow tokens, not record streams.

**Pattern — branch on previous job success:**
```xml
<Node id="CHECK_OK" type="CONDITION" guiX="400" guiY="150">
    <attr name="condition"><![CDATA[
//#CTL2
function boolean isTrue() {
    return $in.0.status == "FINISHED_OK";
}
    ]]></attr>
</Node>
```
Port 0 = true → continue / SUCCESS
Port 1 = false → FAIL or error handling

---

## Fail

Explicitly terminates the jobflow with an error message.

**Key properties:**
| Property | Description |
|---|---|
| `errorMessage` | CTL2 `getMessage()` function returning error string |

---

## ListFiles

Discovers files matching a glob pattern and emits one record per entry (files **and subdirectories**). Used to drive dynamic file-per-graph patterns.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | Glob pattern | `${DATAIN_DIR}/Payments-*.csv` |

**Output fields:** `URL` (uppercase), `name`, `size`, `lastModified`, `isFile`, `isDirectory`, `canRead`

**⚠️ Always filter on `isFile == true`** immediately after LIST_FILES — directories are included in output and will crash EXECUTE_GRAPH if not filtered out.

**Pattern — process each file with a separate graph run:**
```
ListFiles(Payments-*.csv)
  → EXT_FILTER(isFile == true)     ← REQUIRED
  → ExecuteGraph(loadPayments.grf)
    inputMapping: $out.1.fileUrl = $in.0.URL
```

---

## SetJobOutput / GetJobInput

Pass data between parent and child jobflows via the Dictionary.

- **GetJobInput** — initializes loop state or reads parameters passed from a parent jobflow into the current one. Always the first node in jobflows that use LOOP.
- **SetJobOutput** — writes output data to the current graph's Dictionary so the parent can read it via `$in.2.*` in outputMapping.

**Data flow rules:**
- Parameters flow **parent → child only** (via inputMapping `$out.1.*`)
- Dictionary output flows **child → parent** (via SetJobOutput + outputMapping `$in.2.*`)
- Dictionary entries must be declared `output="true"` in the child's `<Dictionary>` to be readable by the parent
- Only the values from the **last record** processed by SetJobOutput are available to the parent

---

## TokenGather

Merges token streams from multiple input ports into one output port. Does NOT synchronize or wait.

**Use case:** Collect error tokens from separate sequential branches into a single error handler (e.g., one failure email at the end of a chain).

**TokenGather vs Barrier:**
- **TokenGather** — sequential merge. Use when collecting tokens from independent sequential branches.
- **Barrier** — parallel synchronization. Use when waiting for all concurrent branches to finish before continuing.

---

## Sleep

Pauses token execution for a configurable delay (milliseconds). Used in retry loops.

**⚠️ Buffering gotcha:** Tokens may not deliver immediately after the delay if the outgoing edge is buffered. Set the edge to **"Direct fast propagate"** in the Designer for timing-sensitive retry patterns. The `delay` attribute can also be read from an input field named `delay` (long type).

---

## Jobflow Patterns

### Sequential load with error handling

```
EXEC_STEP1 → EXEC_STEP2 → EXEC_STEP3
```
Each step has `stopOnFail="true"`. Any failure aborts the chain immediately with a clear error message pointing to the failing step.

### Sequential load with shared error handling (TokenGather)

```
EXEC_STEP1 → ok → EXEC_STEP2 → ok → EXEC_STEP3 → ok → SUCCESS
             ↓                  ↓                  ↓
           FAIL             FAIL              FAIL
             ↓                  ↓                  ↓
              ← ← ← TOKEN_GATHER ← ← ← ← ← ← ← ←
                         ↓
                   EMAIL_FAILURE
```

### Parallel file processing
```
ListFiles(*.csv) → EXT_FILTER(isFile) → ExecuteGraph(executorsNumber=4)
```
Up to 4 child graphs run concurrently. Always filter on `isFile` first.

### Async parallel + monitor
```
ListFiles → EXT_FILTER(isFile) → ExecuteGraph(executionType=asynchronous) → MonitorGraph
```
Fire-and-forget dispatch; MonitorGraph polls until all async jobs finish.

### Retry loop
```
GetJobInput(counter=0, shouldContinue=true)
  → LOOP(while shouldContinue)
    → ExecuteGraph(stopOnFail=false, redirectErrorOutput=true)
    → Reformat: check $in.1.status, increment counter
      if status==FINISHED_OK OR counter>=RETRY_COUNT → shouldContinue=false
    → (loop-back edge, Manual routing)
  → Condition($in.0.status == "FINISHED_OK")
    → SUCCESS / FAIL
```
Add Sleep before the loop-back edge with "Direct fast propagate" edge for clean retry timing.

### Dictionary-based stats collection
```
Child graph: DBInputTable → Aggregate → SetJobOutput (writes count to Dictionary)
Parent jobflow: ExecuteGraph → outputMapping: $out.0.count = $in.2.recordCount
```
Child graph writes stats to its Dictionary; parent reads them via `$in.2.*` in outputMapping.

### Sync vs Async comparison

| Pattern | When to use |
|---|---|
| Synchronous (default) | Small job counts, order matters, simpler error handling |
| Async + MonitorGraph | Many parallel jobs, want non-blocking dispatch |
| `executorsNumber > 1` | Bounded parallelism (e.g., max 4 concurrent file loads) |
