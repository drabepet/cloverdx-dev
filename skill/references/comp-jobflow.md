# CloverDX Jobflow Components

> Source: CloverDX 7.3.1 docs + TrainingExamples jobflows (09e0x series)

Jobflows orchestrate graph execution. File extension: `.jbf`. Root element: `<jbf:jobflow>`.

---

## ExecuteGraph

Runs a child graph. Replaces deprecated `RunGraph`.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `jobURL` | Path to .grf/.jbf/.sgrf file | `${GRAPH_DIR}/loadPayments.grf` |
| `inputMapping` | CTL2 to pass parameters to child graph | see below |
| `outputMapping` | CTL2 to extract results from child graph | see below |
| `stopOnFail` | Abort jobflow if child fails | `false` (for retry/conditional patterns) |
| `executionType` | `synchronous` (default) or `asynchronous` | |
| `executorsNumber` | Max concurrent instances (when in a loop) | `4` |
| `executionLabel` | Label for tracking/logging | `${fileUrl}` |

**inputMapping — pass parameters to child graph:**
```ctl
// $out.1.* = child graph input port
function integer transform() {
    $out.1.fileUrl = $in.0.URL;           // file discovered by LIST_FILES
    $out.1.truncate = getParamValue("TRUNCATE_TABLE");
    return ALL;
}
```

**outputMapping — read results from child graph:**
```ctl
// $in.1.*, $in.2.*, $in.3.* = child graph output ports
function integer transform() {
    $out.0.fileUrl = $in.1.fileUrl;
    $out.0.validCount = $in.3.outputPort_0_CUSTOMERS_INPUT_totalRecords;
    $out.0.invalidCount = $in.3.outputPort_1_CUSTOMERS_INPUT_totalRecords;
    return ALL;
}
```

**Async execution + monitoring** (09e05b, 09e06b):
```
executionType: asynchronous
→ returns immediately with runId
→ pair with MONITOR_GRAPH to wait for completion
```

---

## MonitorGraph

Polls an asynchronous job until it completes. Used with `ExecuteGraph(executionType=asynchronous)`.

**Key properties:**
| Property | Description |
|---|---|
| `monitoringInterval` | Polling interval in milliseconds |

**Input:** `runId` from async ExecuteGraph output
**Output:** Final status record when job completes

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

Routes execution based on a boolean expression evaluated against input data or job outcome.

**Ports:**
- Port 0 = true branch
- Port 1 = false branch

**Pattern — branch on previous job success:**
```
ExecuteGraph → Condition(status == "FINISHED_OK") → port 0: continue
                                                  → port 1: Fail
```

---

## Fail

Explicitly terminates the jobflow with an error message.

**Key properties:**
| Property | Description |
|---|---|
| `errorMessage` | Message written to job log | `"Load failed after ${RETRY_COUNT} retries"` |

---

## ListFiles

Discovers files matching a glob pattern and emits one record per file. Used to drive dynamic file-per-graph patterns.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | Glob pattern | `${DATAIN_DIR}/Payments-*.csv` |

**Output fields:** `URL` (uppercase), `name`, `size`, `lastModified`, `isFile`, `isDirectory`, `canRead`, etc.
See `references/comp-file-operations.md` for full field list and patterns.

**Pattern — process each file with a separate graph run** (09e05a):
```
ListFiles(Payments-*.csv) → ExecuteGraph(loadPayments.grf)
                             inputMapping: $out.1.fileUrl = $in.0.URL
```

---

## SetJobOutput / GetJobInput

Pass data between parent and child jobflows.

- **GetJobInput** — reads parameters/data passed from the parent jobflow into the current one
- **SetJobOutput** — writes output data back to the parent jobflow

---

## Jobflow Patterns

### Sequential load with optional truncation

```
Phase 0: DBExecute(DELETE FROM table) [enabled=${TRUNCATE_TABLE}]
Phase 1: DBOutputTable(INSERT)
```
Use graph parameter `TRUNCATE_TABLE=true/false` to control phase 0 at runtime.

### Parallel file processing (09e05a)
```
ListFiles → ExecuteGraph(executorsNumber=4)
```
Up to 4 child graphs run concurrently. Good for independent file-per-graph loads.

### Async parallel + monitor (09e05b / 09e06b)
```
ListFiles → ExecuteGraph(executionType=asynchronous) → MonitorGraph
```
Fire-and-forget pattern. MonitorGraph polls until all async jobs finish.

### Retry loop (09e04)
```
GetJobInput(initialize counter=0, shouldContinue=true)
  → LOOP(while shouldContinue)
    → ExecuteGraph(stopOnFail=false)
    → Reformat: check status, increment counter
      if status=FINISHED_OK OR counter>=RETRY_COUNT → shouldContinue=false
      else → shouldContinue=true (loop again)
  → Condition(success/failure)
```
Key: `stopOnFail=false` on ExecuteGraph lets the loop control failure handling. Counter prevents infinite retry.

### Dictionary-based stats collection (09e02, 09e03)
```
ExecuteGraph → outputMapping reads from child dictionary:
    $out.0.cashCount = $in.2.transactionTypes["CASH"]
```
Child graph writes stats to its dictionary; parent reads them in outputMapping.

### Sync vs Async comparison

| Pattern | When to use |
|---|---|
| Synchronous (default) | Small job counts, order matters, simpler error handling |
| Async + MonitorGraph | Many parallel jobs, want non-blocking dispatch |
| executorsNumber | Bounded parallelism (e.g., max 4 concurrent) |
