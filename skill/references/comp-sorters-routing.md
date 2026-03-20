# CloverDX Sorters and Routing Components

> Source: CloverDX 7.3.1 docs + TrainingExamples graphs

---

## Sort Key Syntax

All sort/dedup components use the same key format:
```
fieldName(a)           ← ascending
fieldName(d)           ← descending
field1(a);field2(d)    ← multi-key
```

---

## ExtSort

External (disk-based) sort. Handles datasets larger than available memory by spilling to disk.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `sortKey` | Fields and direction | `totalPaid(d)` / `state(a)` |
| `sortInMemory` | Force in-memory sort (faster but limited by heap) | `false` |
| `bufferCapacity` | Records to hold in memory before spilling | |

**Temp disk:** Spill files go to the Worker temp directory. Keep temp on a separate volume from sandboxes (see architecture.md).

**Common sort patterns from examples:**

Sort before aggregation (required for sorted mode):
```
sortKey: state(a)        → feeds Aggregate(sorted=true)
sortKey: customerId(a)   → feeds Aggregate(aggregateKey=customerId)
```

Sort before merge join (required):
```
sortKey: id(a)           → port 0 of ExtMergeJoin
sortKey: customerId(a)   → port 1 of ExtMergeJoin
```

Sort before dedup/top-N (07e01 - Customer leaderboard):
```
sortKey: totalPaid(d)    → descending → Dedup(noDupRecord=10) = top-10 filter
```

Multi-field sort for hierarchical output (11e02b):
```
sortKey: id(a)                          → customers port
sortKey: customerId(a);id(a)            → orders port
sortKey: customerId(a);orderId(a)       → payments port
```

---

## FastSort

In-memory sort. Faster than ExtSort but limited to datasets that fit in Worker heap.

**Use when:** Dataset is small and you know it fits in memory.
**Avoid when:** Dataset size is unpredictable — use ExtSort instead.

Same `sortKey` syntax as ExtSort.

**Example** (03e03 - Deduplication.grf):
```
sortKey: fullName(a);streetAddress(a);city(a);postalCode(a);state(a);country(a)
```
FastSort used here because active customers subset fits in memory.

---

## Dedup

Removes or separates duplicate records. **Input must be sorted** on the dedup key.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `dedupKey` | Fields defining a "duplicate" | `fullName(a);streetAddress(a)` |
| `keep` | Which record to keep: `first` / `last` / `unique` | `first` |
| `noDupRecord` | Max records to output (top-N mode) | `10` |

**Ports:**
- Port 0 = unique records (first occurrence)
- Port 1 = duplicate records

**Standard dedup** (03e03 - Deduplication.grf):
```
dedupKey: fullName(a);streetAddress(a);city(a);postalCode(a);state(a);country(a)
```
Port 0 → unique customers, Port 1 → duplicates (for audit/logging).

**Top-N pattern** (07e01 - Customer leaderboard):
```
# No dedupKey — Dedup acts as "take first N" limiter
noDupRecord: 10
```
After sorting `totalPaid(d)` descending, Dedup(noDupRecord=10) efficiently picks top 10 without a full scan.

---

## SimpleCopy

Copies every record to **all** connected output ports simultaneously. Used to fork a stream into parallel branches.

**No configuration needed.**

**Patterns:**
- Split data for two different writers (e.g., write to DB and to CSV simultaneously)
- Feed data to both a transformer and a stats probe
- Duplicate a stream for different downstream processing paths

```
FlatFileReader → SimpleCopy → port 0 → ExtHashJoin
                           → port 1 → Dedup (unique suppliers)
```
(17e01 - Read online shop catalogue.grf)

---

## SimpleGather

Merges multiple input streams into one output stream. **No ordering guarantee** — records interleave as they arrive.

**No configuration needed.**

**Use when:** Order doesn't matter and you just need to unify streams.
**Avoid when:** You need ordered output — use ExtSort after gathering.

```
error port 0 ─┐
error port 1 ──→ SimpleGather → FlatFileWriter (error log)
error port 2 ─┘
```

---

## Partition

Routes each record to one of N output ports based on CTL2 logic. The CTL2 function returns the port number (0, 1, 2, ...).

**Key properties:**
| Property | Description |
|---|---|
| `transform` | CTL2 returning integer port number |
| `partitionMode` | `keyHash` / `roundRobin` / `ranges` / `ctlFunction` |

**CTL2 partition by month for parallel processing** (15e02 - Partition visitors.grf):
```ctl
//#CTL2
integer WORKER_COUNT = str2integer("${WORKER_COUNT}");

function integer getOutputPort() {
    return getMonth($in.0.timestamp) % WORKER_COUNT;
}
```
Records for month 1 → port 1, month 2 → port 2, etc. Enables parallel Worker processing.

**Round-robin** (no transform needed):
```
partitionMode: roundRobin
```
Distributes records evenly across all output ports.

**Hash-based** (deterministic partitioning on a field):
```
partitionMode: keyHash
partitionKey: customerId
```

---

## ClusterPartition / ClusterSimpleGather

Cluster-aware variants of Partition and SimpleGather. Used in multi-Worker graphs.

**ClusterPartition** (15e02 - Partition visitors.grf):
- Phase 0: Distributes partitioned data to Worker nodes
- Same CTL2 `getOutputPort()` logic as Partition
- Each partition goes to a separate Worker for parallel processing

**ClusterSimpleGather** (15e02):
- Phase 10: Reassembles results from all Workers into a single stream
- No configuration — automatically collects from all input partitions

**Two-phase parallel pattern:**
```
Phase 0:  Reader → Reformat → ClusterPartition → [Workers process in parallel]
Phase 10: ClusterSimpleGather → Aggregate → Sort → Writer
```

---

## Validator

Validates records against configurable rules. Routes valid records to port 0, invalid to port 1.

**Key properties:**
| Property | Description |
|---|---|
| `rules` | XML-embedded validation rules |
| `errorMapping` | CTL2 to enrich invalid records with context |

**Built-in rule types:** `stringLength`, `isNumber`, `isDate`, `notNull`, `regex`, `copyAllByName`

**Example** (16e01 - Validate customers.grf):
Rules: `fullName` max 20 chars, `postalCode` must be integer, `streetAddress` max 25 chars.

```ctl
// errorMapping: enrich invalid records with original field values
function integer transform() {
    $out.1.* = $in.1.*;          // validation error metadata
    $out.1.id = $in.0.id;        // original record fields for traceability
    $out.1.fullName = $in.0.fullName;
    return ALL;
}
```

Invalid records on port 1 include: field name, rule violated, original value, error message.

---

## ProfilerProbe

Profiles data in-flight — computes statistics (min, max, avg, frequency distributions) without stopping the pipeline. Records pass through on port 0; stats appear on port 1.

**Key properties:** Configure which fields to profile and which metrics to compute.

**Example** (16e04 - Payments statistics.grf):
```ctl
// outputMapping: extract computed stats
function integer transform() {
    $out.1.paidAmount__min = $in.1.paidAmount__min;
    $out.1.paidAmount__avg = $in.1.paidAmount__avg;
    $out.1.paidAmount__max = $in.1.paidAmount__max;
    $out.1.paidAmount__sum = $in.1.paidAmount__sum;
    $out.1.paymentType__freq_histogram = $in.1.paymentType__freq_histogram;
    return ALL;
}
```

**Note:** `processingMode="debug_only"` — stats only computed during debug runs, not production execution. Use for profiling without prod overhead.
