# CloverDX Common Development Patterns

> Derived from TrainingExamples sandbox (119 real graphs, jobflows, subgraphs, data services).
> Each pattern shows the component chain and the key decisions to get right.
>
> **Check here before building from scratch** — if your task matches a pattern below, use it
> as a starting point and adapt. Most common tasks are already solved here.

**Quick index:**
| # | Pattern | Use when |
|---|---|---|
| 1 | CSV → Database Load | Bulk file ingest to a table |
| 2 | Filter and Split Output | Route records by condition |
| 3 | Sort → Aggregate | Group-by + sum/count/avg |
| 4 | Deduplicate | Remove duplicate rows |
| 5 | Enrich with Join | Merge two large datasets |
| 6 | Enrich with Lookup Table | Small reference data enrichment |
| 7 | Normalize | Wide row → many narrow rows |
| 8 | Denormalize | Many rows → one wide row |
| 9 | Rollup | Group + subtotals |
| 10 | REST API Call | Read from external API |
| 11 | Validate Data | Check data quality, route errors |
| 12 | Read/Write XML or JSON | Hierarchical format I/O |
| 13 | Spreadsheet (Excel) | Read/write .xlsx |
| 14 | Email Notification | Send alert after processing |
| 15 | Sequential Jobflow | Ordered ETL pipeline |
| 16 | Jobflow with Stats | Collect record counts across steps |
| 17 | Retry Jobflow | Auto-retry on failure |
| 18 | Parallel File Processing | Fan-out: one graph per file |
| 19 | Reusable Reader Subgraph | Shared input logic |
| 20 | Data Service — GET List | REST API endpoint |

---

## 1. CSV → Database Load

**Example:** `08e03 - Load customers.grf`

```
FlatFileReader → DBOutputTable
```

With optional truncation in phase 0:
```
Phase 0: DBExecute (DELETE FROM table)   [enabled=${TRUNCATE_TABLE}]
Phase 1: FlatFileReader → DBOutputTable
```

Key decisions:
- `dataPolicy="controlled"` on reader to route parse errors to port 1 instead of aborting
- `batchMode="true"` on DBOutputTable for bulk performance
- Use `enabled="${TRUNCATE_TABLE}"` on the DBExecute node — no extra branching needed

---

## 2. Filter and Split Output

**Example:** `03e01 - Read and filter customers.grf`

```
FlatFileReader → ExtFilter → FlatFileWriter (active)
                     ↓ (port 1)
                 FlatFileWriter (inactive)
```

Key decisions:
- Always connect port 1 (rejected records) — even to TrashWriter — or the graph errors
- `filterExpression`: `$in.0.isActive == true`
- To add a reason field to rejects: insert a Reformat before the reject writer

---

## 3. Sort → Aggregate

**Examples:** `03e02 - Aggregation - sorted.grf`, `07e01 - Customer leaderboard.grf`

```
FlatFileReader → ExtSort → Aggregate → FlatFileWriter
```

Unsorted variant (loads all groups into memory):
```
FlatFileReader → Aggregate (sorted=false) → FlatFileWriter
```

Key decisions:
- `sorted=true` on Aggregate requires pre-sorted input but uses O(1) memory — prefer this for large data
- `sorted=false` works on any order but holds all groups in Worker heap
- `aggregateKey` must exactly match the ExtSort `sortKey` fields

---

## 4. Deduplicate

**Example:** `03e03 - Deduplication.grf`

```
FlatFileReader → ExtFilter (remove nulls) → FastSort → Dedup → FlatFileWriter
```

Key decisions:
- Sort before Dedup — Dedup only removes consecutive duplicates
- FastSort is faster than ExtSort for smaller datasets (in-memory, no temp disk)
- Dedup `keyFields` defines what "duplicate" means — often just the ID field

---

## 5. Enrich with Join (Two Large Datasets)

**Example:** `07e01 - Customer leaderboard.grf`, `08e04a - Customer leaderboard - basic db.grf`

```
FlatFileReader (customers) → ExtSort (id) ──→ port 0 ─┐
                                                        ExtMergeJoin → FlatFileWriter
FlatFileReader (payments)  → ExtSort (customerId) → port 1 ─┘
```

Key decisions:
- Both inputs must be sorted on the join key before ExtMergeJoin
- Use `joinType="leftOuter"` to keep customers with no payments
- `joinKey` format: `$id(a)#$customerId(a);`
- **ExtHashJoin vs ExtMergeJoin:** ExtHashJoin skips the sort but loads the entire slave (port 1) into Worker heap. Use it only when the slave is small (rule of thumb: < 500k records / < 500 MB). For anything larger, pay the sort cost and use ExtMergeJoin — heap exhaustion is a worse outcome than sort time.

---

## 6. Enrich with Lookup Table

**Example:** `07e03 - Customer leaderboard USD to EUR.grf`

```
FlatFileReader → LookupJoin → Reformat → FlatFileWriter
                      ↑
              LookupTable (exchange rates CSV)
```

Key decisions:
- Lookup table is defined in a `.cfg` file, loaded once at graph start
- `leftOuterJoin="true"` — keep records even when no match found
- Best for small-to-medium reference tables (currency codes, state codes, categories)
- For larger reference data: use ExtHashJoin with the reference as the slave input

---

## 7. Normalize (Wide → Long / Split Arrays)

**Example:** `10e01 - Data normalization.grf`

```
FlatFileReader → Normalizer → FlatFileWriter
```

Use when one input record should become multiple output records (e.g., a customer with
comma-separated phone numbers → one record per phone).

CTL2 pattern:
```ctl
string[] phones;

function integer count() {
    phones = split($in.0.phone, ",");
    return length(phones);
}

function integer transform(integer i) {
    $out.0.customerId = $in.0.id;
    $out.0.phone = trim(phones[i]);
    return OK;
}

function void clean() { clear(phones); }
```

---

## 8. Denormalize (Long → Wide / Aggregate into One Row)

**Example:** `10e02 - Data denormalization.grf`

```
FlatFileReader → ExtSort (groupKey) → Denormalizer → FlatFileWriter
```

Use when multiple records with the same key should collapse into one record
(e.g., one row per customer with all their payment types as separate fields).

Key decisions:
- Input **must be sorted** by the group key before Denormalizer
- Implement `clean()` to reset accumulators between groups — forgetting this causes state bleed

---

## 9. Rollup (Group + Subtotals)

**Example:** `10e03 - Rollup.grf`

```
FlatFileReader → ExtMergeJoin → ExtSort → Rollup → FlatFileWriter
```

Use when you need both detail rows and summary/subtotal rows in the output
(e.g., sales by product with a subtotal row per supplier).

- `updateTransform()` emits detail rows
- `transform()` emits the group summary row
- Input must be sorted by the group key

---

## 10. REST API Call

**Examples:** `12e01 - Sunset and Sunrise Times.grf`, `12e02 - Weather forecast full.grf`

```
HTTPConnector → JSONExtract → Reformat → [FlatFileWriter / EmailSender]
                    ↓ (error port)
               ExtFilter → FAIL
```

Key decisions:
- Check the HTTP status code in an ExtFilter after HTTPConnector — don't assume success
- JSONExtract flattens nested JSON into records; configure `mapping` for your schema
- For APIs with OpenAPI spec: use RESTConnector instead (handles pagination natively)
- For SOAP: use WebServiceClient (see `12e03 - List sandboxes.grf` for login/call/logout pattern)

---

## 11. Validate Data

**Examples:** `16e01 - Validate customers.grf`, `16e02 - Validate payments.grf`

```
FlatFileReader → Validator → FlatFileWriter (valid)
                     ↓ (port 1)
                 FlatFileWriter (invalid + error descriptions)
```

Key decisions:
- Validator adds an error description field to rejected records automatically
- Always write rejects to a separate file/table — don't silently discard
- For complex rules that Validator can't express: use ExtFilter or Reformat with explicit logic

---

## 12. Read and Write XML / JSON

**XML read:** `11e01 - Parse orders.grf`
```
XMLExtract → FlatFileWriter
```

**XML write (hierarchical, sorted):** `11e02b - Order payments report - sorted.grf`
```
FlatFileReader → ExtSort → ExtXMLWriter   (3 sorted input streams → nested XML)
```

**JSON read:** `11e03 - Parse orders JSON.grf`
```
JSONExtract → FlatFileWriter
```

**JSON write:** `11e04 - Write orders JSON.grf`
```
FlatFileReader → JSONWriter
```

Key decisions:
- ExtXMLWriter with `sortedInput="true"` streams efficiently without buffering; requires pre-sorted inputs
- JSONExtract and XMLExtract both support nested paths via mapping configuration
- For simple JSON arrays: JSONWriter is sufficient; for nested structures use StructuredDataWriter

---

## 13. Spreadsheet (Excel) Read/Write

**Example:** `17e01 - Read online shop catalogue.grf`

```
SpreadsheetDataReader → Dedup → SimpleCopy → SpreadsheetDataWriter
```

Key decisions:
- SpreadsheetDataReader reads `.xlsx` files; configure sheet name/index and header row
- Dedup after reading to handle duplicate catalog entries
- SimpleCopy splits the stream when you need both a file output and a DB load in parallel

---

## 14. Email Notification after Processing

**Example:** `13e01 - Weather forecast email.grf`

```
[processing pipeline] → Aggregate → Combine → EmailSender → FlatFileWriter
```

Key decisions:
- EmailSender takes one record per email — use Denormalizer or Combine if you need to
  aggregate multiple records into one email body
- Configure `smtpHost`, `from`, `to` as graph parameters — not hardcoded
- Put EmailSender in a later phase if you want to ensure it only runs after all data is processed

---

## 15. Sequential Jobflow (ETL Pipeline)

**Example:** `09e01 - Load online store data.jbf`

```
ExecuteGraph (LoadCustomers) → ExecuteGraph (LoadOrders) → ExecuteGraph (LoadPayments)
```

Key decisions:
- `stopOnFail="true"` (default) — abort the jobflow if any step fails
- Pass parameters to child graphs via `inputMapping` CTL2 on each ExecuteGraph
- Read results from child graphs (record counts, status) via `outputMapping`

---

## 16. Jobflow with Stats Collection

**Examples:** `09e02 - Load and collect stats.jbf`, `09e03 - Load and collect stats dictionary.jbf`

**Via outputMapping (port-based):**
```
ExecuteGraph → Reformat (accumulate stats) → ... → FlatFileWriter (report)
```
Child graph writes stats to `SetJobOutput`; parent reads via `$in.3.outputPort_0_totalRecords`.

**Via Dictionary:**
```
ExecuteGraph (child sets dictionary values) → [parent reads getDictionaryValue()]
```
Child uses `setDictionaryValue("KEY", value)` in CTL2; parent jobflow reads with `getDictionaryValue("KEY")`.

Use Dictionary when stats need to cross phase boundaries or be passed up to a parent jobflow.

---

## 17. Retry Jobflow

**Example:** `09e04 - Retry job.jbf`

```
GetJobInput (init counter) → Loop (while shouldContinue)
                                  ↓ (port 0: enter loop)
                             ExecuteGraph (stopOnFail=false)
                                  ↓
                             Reformat (update counter, set shouldContinue=false when done)
                                  ↓ (back to Loop input)
                             Loop (port 1: exit) → ExtFilter → SUCCESS / FAIL
```

Key decisions:
- `stopOnFail="false"` on ExecuteGraph — essential, or the jobflow aborts before retry logic runs
- Loop-back edge needs `guiRouter="Manual"` with explicit bendpoints to route cleanly
- Cap retries with a counter: `$in.0.status != "FINISHED_OK" && $in.0.counter < maxRetries`

---

## 18. Parallel File Processing (Fan-out)

**Examples:** `09e05a - Count visitors.jbf`, `09e05b - Count visitors async.jbf`

**Synchronous (bounded concurrency):**
```
ListFiles (*.csv) → EXT_FILTER (isFile == true) → ExecuteGraph (executorsNumber=4)
                                                        inputMapping: $out.1.fileUrl = $in.0.URL
```

**Asynchronous (fire and monitor):**
```
ListFiles → EXT_FILTER (isFile == true) → ExecuteGraph (executionType=asynchronous) → MonitorGraph
```

Key decisions:
- **Always filter on `isFile == true` immediately after ListFiles** — it emits directories too; passing a directory to ExecuteGraph produces a confusing error with no reference to the real cause. Connect ListFiles port 1 (rejected entries) to a TrashWriter.
- `executorsNumber` limits concurrent child graphs — prevents heap exhaustion
- Async pattern fires all jobs immediately then waits; sync pattern keeps a sliding window of N concurrent
- In inputMapping, `$in.0.URL` (uppercase) is the full file path — not `$in.0.url` (lowercase)
- **Child graph must declare the parameter** that inputMapping writes to (`$out.1.fileUrl`) — silently ignored if absent

---

## 19. Reusable Reader Subgraph

**Examples:** `PaymentsReader.sgrf`, `OrdersReader.sgrf`, `PaymentsSortedReader.sgrf`

```
[subgraph] FlatFileReader → (optional Reformat/Sort/Dedup) → SubgraphOutput (port 0)
```

Used in parent graph as a single node:
```
PaymentsReader (subgraph) → ExtHashJoin → FlatFileWriter
```

Key decisions:
- Declare `<OutputPorts>` in `<Global>` with metadata — this is the interface the parent sees
- Use `<ComponentReference>` to expose the file path as a parameter the parent can override
- Add `required="false" keepEdge="true"` on an optional error output port so internal flow
  still runs even if the parent doesn't connect that port

---

## 20. Data Service — GET List

**Example:** `getCustomers.rjob`, `getAllCustomers.rjob`

```
DBInputTable (SELECT * FROM ...) → RestJobOutput (responseFormat=JSON, topLevelArray=true)
```

**GET by ID with URL path param:**
```
DBInputTable → ExtFilter ($in.0.id == getParamValue("id")) → RestJobOutput
                   ↓ (port 1)
               Trash
```

Key decisions:
- `topLevelArray="true"` returns a JSON array; zero records returns `[]` not an error
- Path parameters declared in `<EndpointSettings><RequestParameter location="url_path">` are
  accessible via `getParamValue("paramName")` in CTL2
- For better performance: push filtering into SQL WHERE clause rather than post-filter in CTL2
  (but only with safe, validated values to avoid SQL injection)
