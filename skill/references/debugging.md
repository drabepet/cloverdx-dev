# CloverDX Debugging and Diagnostics Reference

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

### Getting execution history

Use `retrieve_tracking_get` with a run ID to get:
- Job status (COMPLETED, FAILED, ABORTED, RUNNING)
- Start time, end time, duration
- Error summary (if failed)
- Node that executed it (in cluster)
- Input/output record counts

### Pulling execution logs

Use `retrive_graph_log_get` (note: typo in tool name is intentional — that's how it's
registered) to get the raw text log for a specific execution.

**What to look for:**
- `ERROR` entries — direct cause of failure
- `WARN` entries — often precursors to failure (e.g., connection retries)
- Component initialization messages — confirm all components started correctly
- Record counts per component — identify where data was lost or blocked
- Timing per phase — identify slow components

### Server-level log searching

Use `list_server_logs` with regex patterns to search across log entries:
- `pattern: "OutOfMemoryError"` — heap exhaustion events
- `pattern: "FATAL"` — critical server errors
- `pattern: "Connection refused"` — network/database connectivity issues
- `pattern: "deadlock"` — database or thread deadlocks

Appenders to search:
- `SERVER_LOG` — main server operations
- `USER_ACTION` — user-triggered events (login, job launch)
- `SERVER_AUDIT_LOG` — security-relevant events

### Performance log analysis

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
**Fixes (in order of preference):**
1. Use streaming components (avoid loading entire dataset into memory)
2. Increase `worker.maxHeapSize` (respect the 75% rule — see architecture.md)
3. Reduce concurrent jobs via `executor.max_running_concurrently`
4. For ExtSort/ExtHashJoin: ensure temp disk is on a separate, fast volume

### Temp disk full

**Symptom:** ExtSort or ExtHashJoin fails with I/O error
**Diagnosis:** Temp volume at 100% utilization
**Fix:** Separate temp volume from sandboxes. Use gp3 or NVMe instance store for temp.

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

### Null pointer in CTL2

**Symptom:** `NullPointerException` in a Reformat or Map component
**Diagnosis:** Input field is null and CTL2 code doesn't handle it
**Fix:** Add null checks: `if (isnull($in.0.fieldName)) { ... }`

### Remote Edge failure in cluster

**Symptom:** Data transfer between cluster nodes fails
**Diagnosis:** gRPC ports 10500-10600 blocked in security groups
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
- **Frequent full GC** — heap too small for the workload. Increase `worker.maxHeapSize`.
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
