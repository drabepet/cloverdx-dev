# CloverDX Jobflow XML Structure

> Source: CloverDX 7.3.1 docs + TrainingExamples (09e01 Load online store data, 09e04 Retry job)

Jobflows (`.jbf`) orchestrate graph execution. They share the same `<Graph>` root as `.grf`
files but have `nature="jobflow"`. Jobflow nodes are control-flow constructs (EXECUTE_GRAPH,
LOOP, CONDITION, etc.) rather than data-transformation components.

---

## Root Element

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="xyz123" licenseCode="CAN_USE_COMMUNITY_EDITION"
       name="Load online store data" nature="jobflow">
```

The only difference from a `.grf` root: **`nature="jobflow"`**.

---

## Global Section

Jobflows can have parameters and a dictionary like graphs, but typically have fewer
metadata definitions (jobflows don't read/write records directly — they orchestrate).

```xml
<Global>
    <GraphParameters>
        <GraphParameterFile fileURL="workspace.prm"/>
        <GraphParameter name="RETRY_COUNT" value="3">
            <SingleType name="integer"/>
        </GraphParameter>
    </GraphParameters>
    <Dictionary>
        <Entry id="SHOULD_CONTINUE" input="false" output="false" type="boolean"/>
        <Entry id="ATTEMPT_COUNTER" input="false" output="false" type="integer"/>
    </Dictionary>
</Global>
```

---

## Jobflow Node Types

Jobflow nodes appear inside `<Phase>` blocks. **Phases are available in jobflows but rarely needed** — token flow already provides ordering. Single-phase (`<Phase number="0">`) is the strong convention; multi-phase is allowed but unusual. Control flow is expressed through LOOP and CONDITION, not phase sequencing.

**Execution model:** Components execute one-at-a-time, triggered by tokens — fundamentally different from graphs where all components in a phase stream records concurrently. Default edge type changes to **"Direct fast propagate"** (no buffer, immediate token delivery). **Never use jobflows for data transformation** — a subgraph that takes 10 seconds in a graph can take 7+ minutes in a jobflow due to per-token overhead.

### EXECUTE_GRAPH — Run a child graph

```xml
<Node id="EXECUTE_LOAD_CUSTOMERS" type="EXECUTE_GRAPH"
      guiX="200" guiY="100"
      jobURL="${GRAPH_DIR}/LoadCustomers.grf"
      stopOnFail="true">
    <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.executionLabel = "Loading customers";
    $out.1.fileUrl = $in.0.URL;
    $out.1.truncate = getParamValue("TRUNCATE_TABLE");
    return ALL;
}
    ]]></attr>
    <attr name="outputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.status = $in.1.status;
    $out.0.recordCount = $in.3.outputPort_0_totalRecords;
    return ALL;
}
    ]]></attr>
</Node>
```

**Key EXECUTE_GRAPH attributes:**
| Attribute | Description | Default |
|---|---|---|
| `jobURL` | Path to .grf/.jbf/.sgrf file | required |
| `stopOnFail` | Abort jobflow if child fails | `true` |
| `executionType` | `synchronous` or `asynchronous` | `synchronous` |
| `executorsNumber` | Max concurrent instances (when fed by LIST_FILES) | `1` |
| `redirectErrorOutput` | Route all output (success AND error) to port 0 | `false` |
| `executionLabel` | Per-run label in tracking (CTL2 string expression) | — |

**inputMapping port convention:**
- `$out.0.executionLabel` — label shown in Server tracking UI (string CTL2 expression)
- `$out.1.*` — parameters passed into the child graph (mapped to child's `<GraphParameters>`)
- `$in.0.*` — incoming token data (e.g., from LIST_FILES or GET_JOB_INPUT)

**Note:** The child graph must declare `<GraphParameter>` entries for each field you write to `$out.1.*`. If the parameter doesn't exist in the child's XML, the value is silently ignored.

**outputMapping port convention — the full RunStatus record:**
- `$in.0.*` — pass-through of the original input token
- `$in.1.*` — the RunStatus record (see table below)
- `$in.2.*` — child's output Dictionary entries (fields declared `output="true"`)
- `$in.3.*` — tracking metadata (per-component record counts)

**RunStatus fields (all available on `$in.1.*`):**
| Field | Type | Description |
|---|---|---|
| `runId` | long | Unique execution ID — use with MonitorGraph or KillGraph |
| `originalJobURL` | string | Resolved path to the executed file |
| `status` | string | `FINISHED_OK` · `ERROR` · `ABORTED` · `TIMEOUT` · `RUNNING` (async) · `UNKNOWN` |
| `errMessage` | string | Error message (failed graphs only) |
| `errComponent` | string | Component ID that caused failure |
| `errComponentType` | string | Type string of failing component |
| `startTime` | long | Start timestamp (ms) |
| `endTime` | long | End timestamp (ms, null for async) |
| `duration` | long | Elapsed time in milliseconds |

**`FINISHED_OK` is the correct status string for a successful run.** Use `$in.1.status == "FINISHED_OK"` in outputMapping and downstream EXT_FILTER/CONDITION checks.

**stopOnFail failure modes — understand all three:**

| Configuration | When child fails | Jobflow outcome |
|---|---|---|
| `stopOnFail="true"` (default) | Jobflow aborts immediately | FAIL — no error handling possible |
| `stopOnFail="false"` + error port **connected** | Token routes to port 1 | Continues — you handle failure |
| `stopOnFail="false"` + `redirectErrorOutput="true"` | All output to port 0 | **Silent failure** — check `$in.1.status` downstream or you'll never know |
| `stopOnFail="false"` + **no error port connected** | Java exception propagates | FAIL — same as stopOnFail=true |

**⚠️ Silent failure gotcha:** `redirectErrorOutput="true"` is commonly used in retry patterns, but if downstream logic doesn't check `$in.1.status != "FINISHED_OK"`, all child failures are silently swallowed and the jobflow reports success.

---

### GET_JOB_INPUT — Initialize jobflow state / receive parent parameters

```xml
<Node id="GET_JOB_INPUT0" type="GET_JOB_INPUT" guiX="24" guiY="100">
    <attr name="mapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.shouldContinue = true;
    $out.0.attemptCounter = 0;
    return ALL;
}
    ]]></attr>
</Node>
```

Used to initialize loop state or receive data passed from a parent jobflow.
Always the first node in jobflows that use LOOP or accept input from a parent.

---

### LOOP — Conditional repeat

```xml
<Node id="LOOP0" type="LOOP" guiX="200" guiY="100">
    <attr name="whileCondition"><![CDATA[
//#CTL2
function boolean isTrue() {
    return $in.0.shouldContinue;
}
    ]]></attr>
</Node>
```

- Port 0 (output): enter the loop body
- Port 1 (output): exit the loop — connect to SUCCESS or downstream processing
- The loop's input comes back around from a REFORMAT that updates the loop condition

**LOOP pattern — retry with counter:**
```
GET_JOB_INPUT → LOOP
                  ↓ (port 0: continue)
               EXECUTE_GRAPH (stopOnFail=false)
                  ↓
               REFORMAT (update shouldContinue, increment counter)
                  ↓ (back to LOOP input)
               LOOP
                  ↓ (port 1: exit)
               EXT_FILTER (success/failure branch)
                  → FAIL / SUCCESS
```

---

### FAIL — Explicitly terminate with error

```xml
<Node id="FAIL0" type="FAIL" guiX="600" guiY="200">
    <attr name="errorMessage"><![CDATA[
//#CTL2
function string getMessage() {
    return "Job failed after " + num2str($in.0.attemptCounter) + " attempts.";
}
    ]]></attr>
</Node>
```

---

### SUCCESS — Explicitly mark successful completion

```xml
<Node id="SUCCESS0" type="SUCCESS" guiX="600" guiY="100"/>
```

Optional — if the jobflow ends without FAIL, it is implicitly successful.
Use SUCCESS explicitly when you have branching (CONDITION or EXT_FILTER) and need
to clearly mark the success path.

---

### EXT_FILTER — Branch on outcome

```xml
<Node id="EXT_FILTER0" type="EXT_FILTER" guiX="450" guiY="150">
    <attr name="filterExpression"><![CDATA[
//#CTL2
$in.0.status == "FINISHED_OK"
    ]]></attr>
</Node>
```

Port 0 = condition true (connect to SUCCESS or next EXECUTE_GRAPH)
Port 1 = condition false (connect to FAIL)

**Common filter on EXECUTE_GRAPH status field:**
```ctl
$in.0.status == "FINISHED_OK"
$in.0.attemptCounter >= getParamValue("RETRY_COUNT")
```

---

### LIST_FILES — Discover files for fan-out execution

```xml
<Node id="LIST_FILES0" type="LIST_FILES"
      fileURL="${DATAIN_DIR}/Payments-*.csv"
      guiX="24" guiY="100"/>
```

Emits one record per matching entry (files **and subdirectories**). Feed into EXECUTE_GRAPH with `executorsNumber` for bounded parallelism.

**Output record schema (field names are case-sensitive):**
| Field | Type | Description |
|---|---|---|
| `URL` | string | Full file URL — use this in `jobURL` / `fileURL` mappings |
| `name` | string | Filename only |
| `size` | long | File size in bytes |
| `lastModified` | date | Last modification timestamp |
| `isFile` | boolean | `true` for regular files |
| `isDirectory` | boolean | `true` for directories |
| `canRead` | boolean | Read permission flag |

**⚠️ Always filter on `isFile`** — LIST_FILES emits directories too. Without a filter, EXECUTE_GRAPH receives directories and fails with confusing errors:
```xml
<Node id="FILTER_FILES" type="EXT_FILTER" guiX="200" guiY="100">
    <attr name="filterExpression"><![CDATA[//#CTL2
$in.0.isFile == true]]></attr>
</Node>
```
Connect LIST_FILES port 1 (rejected) to a TrashWriter.

**⚠️ Output mapping is empty by default** — if you forget to configure inputMapping on EXECUTE_GRAPH, all downstream parameters are blank/null. Always explicitly map `$out.1.fileUrl = $in.0.URL` (or equivalent).

**Parallel vs sequential:** When LIST_FILES emits multiple tokens, EXECUTE_GRAPH processes them **in parallel by default** (each token triggers an independent execution). Set `executorsNumber="1"` to enforce sequential processing. There are no ordering guarantees for parallel execution.

### CONDITION — Boolean branch

Routes a token to port 0 (true) or port 1 (false) based on a CTL2 boolean expression. Identical syntax to EXT_FILTER. Use CONDITION when branching on job outcome (e.g., status check); use EXT_FILTER when filtering record streams within a graph.

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

- Port 0 = condition true → success path
- Port 1 = condition false → error path / FAIL

---

### SET_JOB_OUTPUT — Pass data from child to parent

Writes values from the current graph/jobflow into output dictionary entries so the parent's `outputMapping` can read them via `$in.2.*`.

```xml
<!-- In child graph — write results back to parent -->
<Node id="SET_OUTPUT" type="SET_JOB_OUTPUT" guiX="700" guiY="100">
    <attr name="mapping"><![CDATA[
//#CTL2
function integer transform() {
    setDictionaryValue("recordCount", $in.0.count);
    setDictionaryValue("status", "OK");
    return ALL;
}
    ]]></attr>
</Node>
```

The parent then reads these in outputMapping:
```ctl
$out.0.recordCount = $in.2.recordCount;   // $in.2.* = child's output dictionary
$out.0.childStatus = $in.2.status;
```

**Key rules:**
- Dictionaries are **private** per graph — the parent cannot directly read a child's dictionary
- Only fields declared `output="true"` in the child's `<Dictionary>` are accessible
- Parameters are **one-way** (parent → child only) — use SetJobOutput/Dictionary for child → parent data flow
- SetJobOutput **overwrites** on each call — the last record processed wins

---

### TOKEN_GATHER — Merge token streams

Collects tokens from multiple input ports and routes them through a single output port. Does NOT synchronize or wait — use BARRIER for parallel synchronization.

```xml
<!-- Collect error tokens from multiple sequential branches into one error handler -->
<Node id="GATHER_ERRORS" type="TOKEN_GATHER" guiX="600" guiY="200"/>
```

**TokenGather vs Barrier:**
- **TokenGather** — sequential error collection. Merges token streams from separate branches into one downstream error handler (e.g., send a single failure email after 3 sequential steps).
- **Barrier** — parallel synchronization. Waits for ALL tokens from concurrent branches, evaluates group success/failure (`$status == "FINISHED_OK"`), emits one aggregated result.

---

### SLEEP — Introduce delay

Pauses execution for a configurable time. Used in retry loops to wait before retrying a failed job.

```xml
<Node id="WAIT_BEFORE_RETRY" type="SLEEP"
      delay="30000"
      guiX="500" guiY="200"/>
```

**⚠️ Buffering gotcha:** By default, the outgoing edge may buffer tokens and not deliver them immediately after the delay expires. If token timing matters (e.g., in a retry loop where the next iteration must start promptly), set the outgoing edge type to **"Direct fast propagate"** in the Designer. The `delay` can also be read dynamically from an input field named `delay` (long, milliseconds).

---

Jobflow edges carry status/tracking records, not business data. They often have no
`metadata` attribute — this is normal and correct.

```xml
<!-- Control flow edge — no metadata, just wires the execution sequence -->
<Edge id="E0" fromNode="GET_JOB_INPUT0:0" toNode="LOOP0:0"
      guiRouter="Manhattan" inPort="Port 0 (in)" outPort="Port 0 (out)"/>

<!-- Edge with explicit bendpoints for loop-back routing -->
<Edge id="E_LOOPBACK" fromNode="REFORMAT0:0" toNode="LOOP0:0"
      guiRouter="Manual"
      guiBendpoints="500|200|500|50|200|50"
      inPort="Port 0 (in)" outPort="Port 0 (out)"/>
```

**`guiRouter="Manual"` with `guiBendpoints`** is common for loop-back edges where
the auto-router would produce confusing overlapping lines.
Format: `x1|y1|x2|y2|...` — each pair is a waypoint in the canvas coordinate system.

---

## Complete Sequential Jobflow (09e01 Load online store data)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="jbf01" name="Load online store data" nature="jobflow">
    <Global>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
        </GraphParameters>
    </Global>

    <Phase number="0">
        <!-- Step 1: load customers -->
        <Node id="EXEC_CUSTOMERS" type="EXECUTE_GRAPH"
              jobURL="${GRAPH_DIR}/LoadCustomers.grf"
              stopOnFail="true" guiX="100" guiY="100">
            <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.1.truncate = getParamValue("TRUNCATE_TABLE");
    return ALL;
}
            ]]></attr>
        </Node>

        <!-- Step 2: load orders (runs after customers complete) -->
        <Node id="EXEC_ORDERS" type="EXECUTE_GRAPH"
              jobURL="${GRAPH_DIR}/LoadOrders.grf"
              stopOnFail="true" guiX="350" guiY="100"/>

        <!-- Step 3: load payments -->
        <Node id="EXEC_PAYMENTS" type="EXECUTE_GRAPH"
              jobURL="${GRAPH_DIR}/LoadPayments.grf"
              stopOnFail="true" guiX="600" guiY="100"/>

        <!-- Edges wire execution order -->
        <Edge id="E0" fromNode="EXEC_CUSTOMERS:0" toNode="EXEC_ORDERS:0"
              guiRouter="Manhattan"/>
        <Edge id="E1" fromNode="EXEC_ORDERS:0" toNode="EXEC_PAYMENTS:0"
              guiRouter="Manhattan"/>
    </Phase>
</Graph>
```

---

## Complete Retry Loop Jobflow (09e04 Retry job)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="jbf04" name="Retry job" nature="jobflow">
    <Global>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
            <GraphParameter name="RETRY_COUNT" value="3">
                <SingleType name="integer"/>
            </GraphParameter>
        </GraphParameters>
    </Global>

    <Phase number="0">
        <!-- Initialize state -->
        <Node id="INIT" type="GET_JOB_INPUT" guiX="24" guiY="150">
            <attr name="mapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.shouldContinue = true;
    $out.0.attemptCounter = 0;
    $out.0.status = "";
    return ALL;
}
            ]]></attr>
        </Node>

        <!-- Loop while shouldContinue == true -->
        <Node id="LOOP0" type="LOOP" guiX="200" guiY="150">
            <attr name="whileCondition"><![CDATA[
//#CTL2
function boolean isTrue() {
    return $in.0.shouldContinue;
}
            ]]></attr>
        </Node>

        <!-- Run the actual job — don't abort jobflow on child failure -->
        <Node id="EXEC_JOB" type="EXECUTE_GRAPH"
              jobURL="${GRAPH_DIR}/LoadData.grf"
              stopOnFail="false"
              redirectErrorOutput="true"
              guiX="380" guiY="100"/>

        <!-- Update loop state based on outcome -->
        <Node id="UPDATE_STATE" type="REFORMAT" guiX="550" guiY="100">
            <attr name="transform"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.status = $in.0.status;
    $out.0.attemptCounter = $in.0.attemptCounter + 1;
    // Stop if succeeded or exhausted retries
    $out.0.shouldContinue =
        ($in.0.status != "FINISHED_OK") &&
        ($in.0.attemptCounter + 1 < str2integer(getParamValue("RETRY_COUNT")));
    return ALL;
}
            ]]></attr>
        </Node>

        <!-- After loop exits: branch on final status -->
        <Node id="CHECK_STATUS" type="EXT_FILTER" guiX="380" guiY="300">
            <attr name="filterExpression"><![CDATA[
//#CTL2
$in.0.status == "FINISHED_OK"
            ]]></attr>
        </Node>

        <Node id="SUCCESS0" type="SUCCESS" guiX="600" guiY="250"/>
        <Node id="FAIL0" type="FAIL" guiX="600" guiY="350">
            <attr name="errorMessage"><![CDATA[
//#CTL2
function string getMessage() {
    return "Failed after " + num2str($in.0.attemptCounter) + " attempts. Last status: " + $in.0.status;
}
            ]]></attr>
        </Node>

        <!-- Sequential wiring -->
        <Edge id="E0" fromNode="INIT:0" toNode="LOOP0:0" guiRouter="Manhattan"/>
        <Edge id="E1" fromNode="LOOP0:0" toNode="EXEC_JOB:0" guiRouter="Manhattan"/>
        <Edge id="E2" fromNode="EXEC_JOB:0" toNode="UPDATE_STATE:0" guiRouter="Manhattan"/>
        <!-- Loop-back edge — manual routing for clarity -->
        <Edge id="E3" fromNode="UPDATE_STATE:0" toNode="LOOP0:0"
              guiRouter="Manual" guiBendpoints="620|100|620|50|200|50"/>
        <!-- Loop exit (port 1) → final check -->
        <Edge id="E4" fromNode="LOOP0:1" toNode="CHECK_STATUS:0" guiRouter="Manhattan"/>
        <Edge id="E5" fromNode="CHECK_STATUS:0" toNode="SUCCESS0:0" guiRouter="Manhattan"/>
        <Edge id="E6" fromNode="CHECK_STATUS:1" toNode="FAIL0:0" guiRouter="Manhattan"/>
    </Phase>
</Graph>
```

---

## Parallel File Processing (Fan-out Pattern)

```xml
<Phase number="0">
    <Node id="LIST_FILES0" type="LIST_FILES"
          fileURL="${DATAIN_DIR}/Payments-*.csv"
          guiX="24" guiY="100"/>

    <!-- executorsNumber=4 → up to 4 child graphs run concurrently -->
    <Node id="EXEC_LOAD" type="EXECUTE_GRAPH"
          jobURL="${GRAPH_DIR}/LoadPaymentsFile.grf"
          executorsNumber="4"
          stopOnFail="true"
          guiX="250" guiY="100">
        <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.1.fileUrl = $in.0.URL;
    return ALL;
}
        ]]></attr>
    </Node>

    <Edge id="E0" fromNode="LIST_FILES0:0" toNode="EXEC_LOAD:0"
          guiRouter="Manhattan"/>
</Phase>
```

---

## Async Execution Pattern

```xml
<!-- Fire-and-forget: launch all child graphs without waiting -->
<Node id="EXEC_ASYNC" type="EXECUTE_GRAPH"
      jobURL="${GRAPH_DIR}/HeavyProcess.grf"
      executionType="asynchronous"
      guiX="200" guiY="100"/>

<!-- MonitorGraph polls until all async jobs complete -->
<Node id="MONITOR0" type="MONITOR_GRAPH"
      monitoringInterval="5000"
      guiX="400" guiY="100"/>

<Edge id="E0" fromNode="EXEC_ASYNC:0" toNode="MONITOR0:0"/>
```

---

## Gotchas and Common Mistakes

**`stopOnFail="false"` is required for retry patterns** — otherwise the jobflow aborts on first child failure before retry logic can run.

**LOOP always needs a loop-back edge** — output of the loop body must connect back to LOOP input port 0. Missing this edge causes an error or infinite hang.

**Silent failure with `redirectErrorOutput="true"`** — all output routes to port 0, including failures. If downstream logic doesn't check `$in.1.status != "FINISHED_OK"`, all child failures are silently swallowed and the jobflow reports success.

**`stopOnFail="false"` + no error port = same as `stopOnFail="true"`** — if EXECUTE_GRAPH's error port (port 1) is left unconnected, Java exception propagation aborts the jobflow regardless of the setting. Always connect port 1 to a FAIL, TOKEN_GATHER, or TrashWriter.

**LIST_FILES emits directories** — always filter on `isFile == true` immediately after LIST_FILES.

**LIST_FILES output mapping is empty by default** — child graph parameters are blank unless you explicitly map them in inputMapping.

**Parallel is the default with multiple tokens** — when LIST_FILES emits N tokens, EXECUTE_GRAPH runs N instances in parallel. Set `executorsNumber="1"` to enforce sequential. With `stopOnFail="true"` and `executorsNumber > 1`, a failure aborts all in-flight instances immediately (not just future ones).

**Child graph parameters are silently ignored if undeclared** — `$out.1.myParam` in inputMapping has no effect if the child graph doesn't declare `<GraphParameter name="myParam">`. No error is thrown.

**Parameters are one-way (parent → child only)** — child graphs cannot modify parent parameters. Use SetJobOutput + Dictionary output entries for child → parent data flow.

**Async orphan gotcha** — async ExecuteGraph children are killed when the parent finishes unless `executeDaemon="true"`. Don't use async without pairing with MonitorGraph or this attribute.

**`max_running_concurrently` deadlock** — if a job gets stuck (e.g., waiting on a lost DB socket with Linux default TCP keepalive of 7200s), it blocks all subsequent scheduled runs. Mitigation: use JNDI connections, reduce `tcp_keepalive_time`, or implement a server-side watchdog.

**ExecuteGraph replaces deprecated RunGraph** — always use `type="EXECUTE_GRAPH"`, never `type="RUN_GRAPH"`. RunGraph was removed in v7.0.

**Jobflows can now run in Designer (v7.3+)** — older docs say Server is required. Since v7.3, jobflows run in both Designer and Server.

**Jobflow edges carry no business metadata** — control flow edges propagate execution tokens, not records. No `metadata` attribute on edges is normal and correct.
