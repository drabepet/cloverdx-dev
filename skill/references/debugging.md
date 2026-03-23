# CloverDX Debugging and Diagnostics Reference

## Symptom Triage — Start Here

| Symptom | Likely path | First tool to call |
|---|---|---|
| `OutOfMemoryError` | Infrastructure | `list_performance_logs` → check `swap` |
| ExtSort / ExtHashJoin I/O error | Infrastructure | `df -h` on server → check temp disk |
| Job slow or timed out | Infrastructure | `list_performance_logs` → check `jobs`, `wCPU` |
| Component crash / bad log entry | Logic failure | `retrive_graph_log_get` → find `ERROR` |
| Metadata field type error | Logic failure | `retrive_graph_log_get` → update `.fmt` |
| CTL2 exception | Logic failure | `retrive_graph_log_get` → check null guards |
| Job succeeds but output is wrong | Silent failure | `retrive_graph_log_get` → check record counts |
| Jobflow reports success, data missing | Silent failure | Check `$in.1.status` in outputMapping |
| Cluster remote edge failure | Infrastructure | Check gRPC ports 10500–10600 |
| Worker keeps restarting | Infrastructure | `list_performance_logs` → check `wHeap`, `swap` |

---

## Table of Contents
1. Diagnostic Workflow Overview
2. MCP-Powered Diagnostics
3. Log File Structure
4. Performance Log Analysis
5. Common Failure Patterns
6. Memory and GC Diagnostics
7. Cluster-Specific Issues
8. CTL2 Debugging

---

## 1. Diagnostic Workflow Overview

When investigating a problem, follow this sequence:

1. **Identify the symptom** — failed job, slow execution, unexpected output, server instability
2. **Get the execution record** — run ID, status, duration, error summary
3. **Pull the execution log** — detailed component-level log for the specific run
4. **Correlate with performance data** — heap, CPU, GC at the time of failure
5. **Examine the graph/jobflow** — understand the pipeline that failed
6. **Check server-level logs** — for infrastructure issues beyond the job itself
7. **Reproduce or fix** — apply the fix and verify

---

## 2. MCP-Powered Diagnostics

For input parameters, call sequences, and SQL examples for `execute_database_query`, see `references/mcp-workflows.md`. The sections below describe what each tool *returns* and what to look for.

### Getting execution history — retrieve_tracking_get

Call with a run ID to get the detailed record for one execution:
- Job status (`FINISHED_OK`, `ERROR`, `ABORTED`, `TIMEOUT`)
- Start time, end time, duration — **extract these for scoping `list_performance_logs`**
- Error summary and the component ID that caused failure
- Input/output record counts per component

Call with a graph path (without a specific run ID) to list recent executions. Use this to find a run ID when the user reports a failure but doesn't provide one.

### Pulling execution logs — retrive_graph_log_get

Note: typo in tool name is intentional — that's how it's registered.

**What to look for:**
- `ERROR` entries — direct cause of failure; read these first
- `FATAL` entries — JVM-level or critical infrastructure failures
- `WARN` entries — often precursors (connection retries, slow queries accumulating)
- Component initialization section (top of log) — missing files, bad connections show here
- Record counts per component — find where data was lost (component receives 10k, outputs 0)
- Phase timing — unusually long phases reveal where time was spent

### Server-level log searching — list_server_logs

Use `list_server_logs` with Java regex patterns to search across log entries:
- `pattern: "OutOfMemoryError"` — heap exhaustion events
- `pattern: "FATAL"` — critical server errors
- `pattern: "Connection refused"` — network/database connectivity issues
- `pattern: "deadlock"` — database or thread deadlocks
- `pattern: "(?i)worker.*restart"` — Worker process restarts (case-insensitive)

Appenders to search:
- `SERVER_LOG` — main server operations (most useful)
- `USER_ACTION` — user-triggered events (login, job launch)
- `SERVER_AUDIT_LOG` — security-relevant events

### Performance log analysis — list_performance_logs

Scope to the failure window: use `startTime` from `retrieve_tracking_get`, go ±5 minutes.

Use `list_performance_logs` to retrieve time-series metrics at 3-second intervals:

| Metric | Meaning | Alert Threshold |
|---|---|---|
| `cHeap` | Core JVM heap usage (MB) | >80% of Core Xmx |
| `wHeap` | Worker JVM heap usage (MB) | >80% of Worker Xmx |
| `cCPU` | Core CPU utilization (%) | >50% sustained (Core should be lightweight) |
| `wCPU` | Worker CPU utilization (%) | >90% sustained |
| `cGC` | Core GC time (ms per interval) | >500ms per 3s interval |
| `wGC` | Worker GC time (ms per interval) | >1000ms per 3s interval |
| `jobs` | Currently running jobs | Near max_running_concurrently |
| `jobQueue` | Jobs waiting in queue | Growing continuously |
| `swap` | Swap usage (MB) | Any value > 0 |
| `cFD` / `wFD` | File descriptors open | Approaching OS limit |

**Key diagnostic pattern:** Correlate the timestamp of a job failure with performance
metrics at that moment. If `wHeap` was at maximum and `wGC` was high, the job likely
failed due to memory pressure.

---

## 3. Log File Structure

CloverDX produces several log files:

| Log | Location | Content |
|---|---|---|
| `all.log` | Configurable | Combined server + worker log (default) |
| Performance log | Configurable | 3-second interval metrics |
| Execution logs | Per-run | Component-level detail for each job execution |
| Tomcat logs | catalina.out | Startup, shutdown, deployment events |

Log configuration is in `log4j2.xml` (CloverDX 7.x uses Log4j2).

---

## 4. Performance Log Analysis

The performance log is your most powerful diagnostic tool. It records metrics every
3 seconds, giving you a time-series view of server health.

**Typical diagnostic questions and how to answer them:**

**"Why was this job slow?"**
- Check `wCPU` — was the Worker CPU-bound?
- Check `wHeap` + `wGC` — was it spending time garbage collecting?
- Check `jobs` — were too many jobs running concurrently?
- Check `swap` — any swapping indicates severe memory pressure

**"Why did the Worker restart?"**
- Look for `wHeap` at or near maximum immediately before restart
- Check if `wGC` spiked (long GC pauses indicate heap exhaustion)
- Check if `swap` appeared (OS killed the process)

**"Is the server healthy right now?"**
- `cHeap` < 60% of Core Xmx
- `wHeap` < 70% of Worker Xmx during batch windows
- `cGC` and `wGC` low and stable
- `swap` = 0
- `jobQueue` not growing

---

## 5. Common Failure Patterns

### OutOfMemoryError in Worker

**Symptom:** Job fails with `java.lang.OutOfMemoryError: Java heap space`
**Diagnosis:** `wHeap` at maximum, `wGC` spiking

**Check `swap` first:**
- `swap > 0` → Worker missed its heartbeat to Server Core and killed itself. **Lower heap** (not raise it), add host RAM, or reduce concurrent jobs. Raising heap when swap is non-zero makes things worse.
- `swap = 0` → Heap is genuinely too small. Increase Worker heap: Configuration > Setup > Worker > Maximum heap size, or set `worker.jvmOptions=-Xmx<size>m` in `clover.properties`, or `CLOVER_WORKER_HEAP_SIZE=<size>` for Docker.

**Other fixes (in order):**
1. Use streaming components — avoid loading entire datasets into memory
2. Switch `ExtHashJoin` → `ExtMergeJoin` if the slave is large (the slave is fully in-heap for HashJoin)
3. Reduce concurrent jobs (Configuration > Setup > Worker > Maximum jobs running concurrently)

### Temp disk full

**Symptom:** ExtSort or ExtHashJoin fails with I/O error
**Diagnosis:** Temp volume at 100% utilization
**Fix:** Check disk space first with `df -h` on the server. Worker temp defaults to the system temp directory. Override with `worker.jvmOptions=-Djava.io.tmpdir=/fast/volume` in `clover.properties`. Use gp3 or NVMe instance store for temp volumes.

### Database connection exhaustion

**Symptom:** `DBInputTable` or `DBOutputTable` hangs or times out
**Diagnosis:** Connection pool at maximum, queries queued
**Fixes:**
1. Optimize the SQL query (add indexes, reduce result set)
2. Tune Hibernate connection pool settings
3. Use PgBouncer as connection pooler for PostgreSQL
4. Reduce concurrent jobs that hit the same database

### Metadata mismatch

**Symptom:** Job fails with field type or field count errors at runtime
**Diagnosis:** Source schema changed but `.fmt` file was not updated
**Fix:** Update the `.fmt` metadata to match the current source schema.
Check all graphs that reference the same `.fmt` — they may all need updating.

### Null field in CTL2 — silent data corruption

**Symptom:** `"null"` appearing in output strings, or unexpected `NullPointerException`
**Diagnosis:** Nullable field used in string concatenation or arithmetic without null check
**Key behaviour:** `null + " suffix"` produces `"null suffix"` — no crash, silent corruption. `null += " suffix"` produces `" suffix"` (compound assign treats null as empty string). These behave differently.
**Fix:** Add null checks (`isnull()`) before using nullable fields in string operations. Use `nvl($in.0.field, default)` for compact null-coalescing.

### Remote Edge failure in cluster

**Symptom:** Data transfer between cluster nodes fails
**Diagnosis:** gRPC ports 10500–10600 blocked in security groups
**Fix:** Open these ports between all cluster nodes

---

## 6. Memory and GC Diagnostics

### Understanding Worker heap behavior

Worker heap follows a sawtooth pattern: memory grows as data is processed, then drops
during GC. Healthy behavior shows regular, quick GC cycles with heap recovering to a
low baseline.

**Unhealthy patterns:**
- **Steadily rising baseline** — memory leak or accumulating state. Check for components
  that buffer data (HashJoin, Rollup with large groups, lookup tables).
- **Frequent full GC** — heap too small for the workload. Increase Worker heap via Configuration → Setup → Worker, or `worker.jvmOptions=-Xmx<size>m`.
- **GC taking >30% of elapsed time** — severe pressure. Either reduce workload or
  increase memory.

### GC tuning

CloverDX 7.x runs on Java 17, which defaults to G1GC. For most workloads, default
settings are fine. If tuning is needed:
- `-XX:MaxGCPauseMillis=200` (default) — increase for throughput, decrease for latency
- `-XX:G1HeapRegionSize` — auto-sized, rarely needs manual setting
- Consider `-XX:+UseZGC` for very large heaps (>32GB) where pause time matters

---

## 7. Cluster-Specific Issues

### Split-brain

**Symptom:** Nodes run independently, duplicate job executions
**Diagnosis:** JGroups port 7800 blocked or network partition
**Fix:** Verify network connectivity between all nodes on port 7800

### Unbalanced load

**Symptom:** One node overloaded while others are idle
**Diagnosis:** Load balancer weights misconfigured
**Fix:** Adjust `cluster.lb.cpu.weight` and `cluster.lb.memory.weight`

### Sandbox sync delays

**Symptom:** Recent file changes not visible on all nodes
**Diagnosis:** Shared storage (EFS/NFS) latency
**Fix:** Check storage latency metrics; consider switching to faster storage tier

---

## 8. CTL2 Debugging

### Common CTL2 errors

| Error | Cause | Fix |
|---|---|---|
| `Cannot convert X to Y` | Type mismatch in assignment | Use explicit conversion: `str2integer()`, `date2str()`, etc. |
| `NullPointerException` | Null field access | Check with `isnull()` before access |
| `ArrayIndexOutOfBoundsException` | List/map index error | Check `length()` before accessing by index |
| `ParseException` in date conversion | Date format mismatch | Verify format string matches actual data |
| `Division by zero` | Denominator is 0 | Add zero check before division |

### Debugging techniques

1. **Use the `printLog()` function** — writes to the execution log. Use it to trace
   values at runtime: `printLog(info, "Field value: " + $in.0.fieldName);`
2. **Check component error ports** — many components have an error output port that
   captures rejected records with error descriptions.
3. **Test CTL2 incrementally** — start with a simple passthrough, add logic step by step,
   verify each addition.
4. **Check type coercion** — CTL2 is strict about types. `"123" + 1` is not `124` — you
   need `str2integer("123") + 1`.
