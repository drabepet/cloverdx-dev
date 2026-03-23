# CloverDX MCP — Workflows and Call Sequences

> This file documents *how* to use MCP tools, not just *which* ones exist.
> For tool descriptions and "when to use", see the MCP Tools table in SKILL.md.

---

## Canonical Diagnostic Call Chain

Most debugging sessions follow this sequence. Each step produces the input for the next.

```
1. deployment_current
      ↓ reveals: server version, sandbox home path, Worker heap config
2. retrieve_tracking_get  (needs: runId or graph path to find recent runs)
      ↓ reveals: runId, failure status, error summary, timestamps, record counts
3. retrive_graph_log_get  (needs: runId from step 2)
      ↓ reveals: component-level log, ERROR/FATAL entries, phase timing
4. list_performance_logs  (needs: timestamps from step 2 to scope the window)
      ↓ reveals: wHeap, swap, wGC, wCPU at the moment of failure
5. list_server_logs       (only if step 3 shows infrastructure errors, not graph logic)
```

Never skip step 1. `deployment_current` anchors all subsequent advice to the real environment — Worker heap, version, cluster topology — and reveals the sandbox home path needed for step 2.

---

## Step 1 — deployment_current

No parameters. Call it first in every MCP session.

**Key fields to extract from the response:**

| Field | What it tells you | How to use it |
|---|---|---|
| Server version | Which features and fixes apply | Scope advice to the actual version |
| `sandboxes.home` or sandbox path | Where sandboxes live on the server | Construct paths for `retrieve_sandbox_file` |
| Worker max heap (Xmx) | Ceiling for memory | Interpret `wHeap` numbers as % of this |
| Cluster nodes | Single node or cluster | Cluster issues need different diagnosis |
| Java version | GC defaults, JVM behavior | Java 17 defaults to G1GC |

**After calling it:** Note the Worker heap ceiling and sandbox path. Both are needed in later steps.

---

## Step 2 — Finding a Run ID

`retrieve_tracking_get` and `retrive_graph_log_get` both need a `runId`. How you get it depends on what the user tells you:

**User gives you a run ID directly** → use it immediately.

**User gives you a graph name or path** → call `retrieve_tracking_get` with the graph path to list recent executions, then pick the relevant one. Look for the run with a FAILED/ERROR status and a timestamp matching the reported failure window.

**User says "it failed last night" with no other info** → call `retrieve_tracking_get` with a time range filter covering the previous night. Scan for runs with ERROR or ABORTED status.

**User says "the scheduler job"** → check `deployment_current` output for scheduled job names, then look up by path.

Once you have a `runId`, keep it — both `retrieve_tracking_get` (for the detailed record) and `retrive_graph_log_get` (for the log) need it.

---

## Step 3 — retrieve_tracking_get

**What it returns for a specific run:**
- `status` — FINISHED_OK, ERROR, ABORTED, TIMEOUT
- `startTime` / `endTime` — use these to scope `list_performance_logs`
- `duration` — in milliseconds
- `errorMessage` — first-level error summary (not the full stack trace)
- `errorComponent` — the component ID that caused failure; use this to find the component in the graph XML
- Record counts per component — where data was lost or multiplied

**What it returns when listing recent runs for a graph path:**
- Multiple run records sorted by time
- Each has `runId`, `status`, `startTime`, `duration`

**Key action:** Extract `startTime` and `endTime`. You'll need this 5-minute window for `list_performance_logs`.

---

## Step 4 — retrive_graph_log_get

**Note:** The typo (`retrive` not `retrieve`) is intentional — that's how the tool is registered.

**Input:** `runId` from step 3.

**What to look for in the log:**
```
ERROR  — direct cause of failure; read these first
FATAL  — critical failures, often JVM-level
WARN   — often precursors (connection retries, slow queries building up)
```

**Component initialization section** — at the top of the log. If a component fails to initialize (e.g., can't find a metadata file, bad connection string), the error appears here, before any records are processed.

**Record counts section** — each component logs input/output record counts. Compare upstream vs downstream counts to find where data is dropped or rejected. A component that receives 10,000 records and outputs 0 either filtered everything (check ExtFilter port 1) or crashed.

**Phase timing** — each phase start/end is logged. Unusually long phases indicate where time was spent.

**Tip:** If the log is very long, search for `ERROR` first. Then search for the `errorComponent` ID from step 3 to find the relevant context.

---

## Step 5 — list_performance_logs

**Scope the query to the failure window.** Use `startTime` from step 3, go 5 minutes before and 5 minutes after. Wide windows return a lot of irrelevant data.

**Read the metrics in this order:**

1. `swap` — if non-zero at any point near the failure, this is a host RAM problem. See debugging.md Path A.
2. `wHeap` — plot the trend. Steadily rising = memory leak or accumulating state. Spike to ceiling = OOM.
3. `wGC` — high GC time during the failure window confirms heap pressure. >1000ms per 3s interval is severe.
4. `jobs` — how many jobs were running concurrently? Near-maximum suggests the server was overloaded.
5. `jobQueue` — was the queue growing? If yes, the server couldn't process jobs as fast as they arrived.
6. `wCPU` — high CPU with low heap = compute-bound (normal for large sorts). High CPU with high heap = GC thrashing.

**Healthy baseline for comparison:**
- `wHeap` < 70% of Worker Xmx
- `wGC` < 200ms per interval during batch
- `swap` = 0
- `jobQueue` stable or 0

---

## list_server_logs — Regex Patterns

Use when `retrive_graph_log_get` shows an infrastructure error (not a CTL2 or metadata issue) or when the job doesn't appear in tracking at all (suggesting it never started).

**Useful patterns:**
```
"OutOfMemoryError"        — heap exhaustion events
"FATAL"                   — critical server errors
"Connection refused"      — network / database connectivity
"deadlock"                — database deadlocks
"Worker.*restart"         — Worker process restarts
"Could not obtain JDBC"   — connection pool exhaustion
"SocketTimeoutException"  — network timeout
"Cannot create.*thread"   — thread limit hit
```

**Appenders:**
- `SERVER_LOG` — main server operations (most useful)
- `USER_ACTION` — user-triggered events (login, manual job start)
- `SERVER_AUDIT_LOG` — security-relevant events

**Note:** Patterns are Java regex. `.` matches any character; escape with `\.` for literal dots. Case-sensitive by default — use `(?i)` prefix for case-insensitive: `(?i)out of memory`.

---

## retrieve_sandbox_file

**Use when:** You want to confirm the server-side version of a graph or config file, in case local files are out of sync with what's actually running.

**Path format:** The path is typically relative to the sandbox root, e.g., `graph/LoadCustomers.grf` — not an absolute filesystem path. The sandbox name is specified as a separate parameter.

**When to use it proactively:** After `deployment_current` reveals an unexpected server version or config, use `retrieve_sandbox_file` to read `workspace.prm` directly from the server. The server-side `workspace.prm` may have different parameter values than the local copy, especially in multi-environment deployments.

---

## execute_database_query — System DB Queries

Use after `retrieve_database_schema` to understand the available tables. The CloverDX system database records all execution history, making it useful for analysis that `retrieve_tracking_get` (which only fetches individual runs) cannot provide.

**Always call `retrieve_database_schema` first** to get accurate table and column names — they can vary by CloverDX version.

**Useful query patterns** (adapt table/column names to match schema output):

**Recent failures for a specific graph:**
```sql
SELECT run_id, start_time, end_time, status, error_message
FROM execution_record
WHERE graph_url LIKE '%LoadCustomers%'
  AND status != 'FINISHED_OK'
ORDER BY start_time DESC
LIMIT 20;
```

**Failure rate for a graph over the last 30 days:**
```sql
SELECT
    DATE(start_time) AS day,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN status = 'FINISHED_OK' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN status != 'FINISHED_OK' THEN 1 ELSE 0 END) AS failed
FROM execution_record
WHERE graph_url LIKE '%LoadCustomers%'
  AND start_time >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(start_time)
ORDER BY day DESC;
```

**Average and p95 duration for a graph:**
```sql
SELECT
    COUNT(*) AS run_count,
    AVG(duration_ms) AS avg_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_ms,
    MAX(duration_ms) AS max_ms
FROM execution_record
WHERE graph_url LIKE '%LoadCustomers%'
  AND status = 'FINISHED_OK'
  AND start_time >= CURRENT_DATE - INTERVAL '7 days';
```

**What ran during a specific time window (e.g., to investigate a slowdown):**
```sql
SELECT graph_url, status, start_time, duration_ms
FROM execution_record
WHERE start_time BETWEEN '2024-03-15 02:00:00' AND '2024-03-15 04:00:00'
ORDER BY start_time;
```

**Most frequently failing graphs (last 7 days):**
```sql
SELECT
    graph_url,
    COUNT(*) AS failures
FROM execution_record
WHERE status IN ('ERROR', 'ABORTED')
  AND start_time >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY graph_url
ORDER BY failures DESC
LIMIT 10;
```

**Note on SQL dialect:** CloverDX supports PostgreSQL (most common), MySQL, and SQL Server as its system database. `PERCENTILE_CONT` and `INTERVAL` syntax shown above is PostgreSQL. For MySQL use `DATEDIFF` instead of `INTERVAL`. Ask the user or check `deployment_current` output for the system database type if in doubt.

---

## report_support_issue

Use only after you have confirmed a CloverDX bug (not a configuration or user error). Before filing:

1. Verify the issue is reproducible — document exact steps
2. Confirm it's not a known issue for the current version (check release notes)
3. Collect: server version (from `deployment_current`), Java version, OS, the graph/jobflow XML, the full execution log from `retrive_graph_log_get`, and the performance log window from `list_performance_logs`

A support issue without these artifacts will be difficult for CloverDX support to investigate.

---

## Common Session Patterns

### "This job failed — diagnose it"
```
deployment_current
  → note Worker heap ceiling, server version
retrieve_tracking_get (graph path or run ID)
  → extract runId, errorComponent, timestamps
retrive_graph_log_get (runId)
  → find ERROR entries, check component counts
list_performance_logs (start - 5min to end + 5min)
  → check swap, wHeap, wGC
```

### "The server is slow / jobs are taking longer than usual"
```
deployment_current
  → baseline: heap config, cluster size
list_performance_logs (last 2 hours)
  → look for rising wHeap, increasing wGC, growing jobQueue
retrieve_tracking_get (recent run list)
  → compare current duration vs historical average
[if queue growing] → check executor.maxRunningJobs setting
```

### "I can't tell if a graph is running or stuck"
```
deployment_current
  → confirm server is up
retrieve_tracking_get
  → look for runs with status RUNNING + start_time > expected duration
retrive_graph_log_get (if runId available)
  → check last log entry timestamp vs current time
list_performance_logs (last 30 min)
  → if wHeap is high and stable, the job may be stuck in GC
```

### "New deployment — validate the environment"
```
deployment_current
  → verify version matches expected, Worker heap is configured
retrieve_sandbox_file workspace.prm
  → confirm parameter values match the environment (prod vs test)
list_server_logs (pattern: "ERROR|FATAL", last 30 min)
  → check for startup errors
retrieve_tracking_get (most recent runs)
  → verify jobs that should have run did run and succeeded
```
