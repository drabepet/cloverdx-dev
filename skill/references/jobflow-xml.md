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

All jobflow nodes appear inside `<Phase number="0">` (jobflows are always single-phase;
control flow is expressed through LOOP and CONDITION, not phase sequencing).

### EXECUTE_GRAPH — Run a child graph

```xml
<Node id="EXECUTE_LOAD_CUSTOMERS" type="EXECUTE_GRAPH"
      guiX="200" guiY="100"
      graphURL="${GRAPH_DIR}/LoadCustomers.grf"
      stopOnFail="true">
    <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.1.fileUrl = $in.0.url;
    $out.1.truncate = getParamValue("TRUNCATE_TABLE");
    return ALL;
}
    ]]></attr>
    <attr name="outputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.fileUrl = $in.1.fileUrl;
    $out.0.recordCount = $in.3.outputPort_0_totalRecords;
    return ALL;
}
    ]]></attr>
</Node>
```

**Key EXECUTE_GRAPH attributes:**
| Attribute | Description | Default |
|---|---|---|
| `graphURL` | Path to .grf file | required |
| `stopOnFail` | Abort jobflow if child fails | `true` |
| `executionType` | `synchronous` or `asynchronous` | `synchronous` |
| `executorsNumber` | Max concurrent instances (when fed by LIST_FILES) | `1` |
| `redirectErrorOutput` | Capture child's stderr | `false` |
| `executionLabel` | Per-run label in tracking (CTL2 expression) | — |

**inputMapping port convention:**
- `$in.0.*` — record from the jobflow's input edge (e.g., from LIST_FILES or GET_JOB_INPUT)
- `$out.1.*` — parameters passed to the child graph

**outputMapping port convention:**
- `$in.1.*`, `$in.2.*`, `$in.3.*` — child graph output ports
- `$out.0.*` — record accumulated in the jobflow for downstream processing

**Auto-named output fields from child graph:**
When the child graph uses a component with tracking enabled, outputMapping can read
fields like `$in.3.outputPort_0_COMPONENT_ID_totalRecords` (port 3 = tracking metadata).

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

Emits one record per matching file. Feed directly into EXECUTE_GRAPH with
`executorsNumber` for bounded parallelism.

---

## Edges in Jobflows

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
              graphURL="${GRAPH_DIR}/LoadCustomers.grf"
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
              graphURL="${GRAPH_DIR}/LoadOrders.grf"
              stopOnFail="true" guiX="350" guiY="100"/>

        <!-- Step 3: load payments -->
        <Node id="EXEC_PAYMENTS" type="EXECUTE_GRAPH"
              graphURL="${GRAPH_DIR}/LoadPayments.grf"
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
              graphURL="${GRAPH_DIR}/LoadData.grf"
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
          graphURL="${GRAPH_DIR}/LoadPaymentsFile.grf"
          executorsNumber="4"
          stopOnFail="true"
          guiX="250" guiY="100">
        <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.1.fileUrl = $in.0.url;
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
      graphURL="${GRAPH_DIR}/HeavyProcess.grf"
      executionType="asynchronous"
      guiX="200" guiY="100"/>

<!-- MonitorGraph polls until all async jobs complete -->
<Node id="MONITOR0" type="MONITOR_GRAPH"
      monitoringInterval="5000"
      guiX="400" guiY="100"/>

<Edge id="E0" fromNode="EXEC_ASYNC:0" toNode="MONITOR0:0"/>
```

---

## Gotchas

- **`stopOnFail="false"` is required for retry patterns** — otherwise the jobflow aborts on first child failure before the retry logic can run.
- **LOOP always needs a loop-back edge** — the output of the loop body must connect back to LOOP input port 0. Missing this edge causes infinite loop or graph error.
- **Jobflow edges carry no business metadata** — this is normal. Control flow edges just propagate the execution token.
- **ExecuteGraph replaces deprecated RunGraph** — always use EXECUTE_GRAPH (`type="EXECUTE_GRAPH"`), never `type="RUN_GRAPH"`.
- **Dictionary vs GraphParameters for state** — use Dictionary when you need to share data between graphs (parent writes, child reads). Use GraphParameters for configuration values known at design time.
