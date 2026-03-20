# CloverDX Component Reference — Overview

> Source: CloverDX 7.3.1 docs + real graphs from TrainingExamples + APIWorkshopSandbox
> Detailed reference is split across sub-files. **Load only what the task requires.**

---

## Sub-file Index

| File | Components |
|---|---|
| `comp-readers.md` | FlatFileReader, DBInputTable, XMLReader, JSON_READER, XML_EXTRACT, JSON_EXTRACT, SpreadsheetDataReader, HTTP_CONNECTOR, RESTConnector |
| `comp-writers.md` | FlatFileWriter, DBOutputTable, DBExecute, JSONWriter, StructuredDataWriter, EmailSender, TrashWriter |
| `comp-transformers.md` | Reformat/Map, ExtFilter, Normalizer, Denormalizer, Rollup, Aggregate, DataGenerator |
| `comp-joiners.md` | ExtHashJoin, ExtMergeJoin, LookupJoin, ExtXMLWriter (hierarchical join) |
| `comp-sorters-routing.md` | ExtSort, FastSort, Dedup, SimpleCopy, SimpleGather, Partition, ClusterPartition, ClusterSimpleGather, Validator, ProfilerProbe |
| `comp-jobflow.md` | ExecuteGraph, MonitorGraph, ExecuteJobflow, ExecuteScript, Condition, Fail, ListFiles, SetJobOutput, GetJobInput — and all jobflow patterns |
| `comp-dataservices.md` | Data service graph structure (.rjob), GetJobInput, HTTP request/response CTL2 functions, GET/POST/upload/download/variant patterns |
| `comp-subgraphs.md` | SubgraphInput, SubgraphOutput, subgraph design patterns, GraphParameters, ComponentReference |

---

## Quick Component Decision Guide

**Reading data:**
- Flat file / CSV → `FlatFileReader`
- Database → `DBInputTable`
- Excel → `SpreadsheetDataReader`
- XML file → `XML_EXTRACT` (schema-based) or `XMLReader` (DOM)
- JSON file → `JSON_EXTRACT` (schema-based) or `JSON_READER` (DOM)
- REST API → `HTTP_CONNECTOR` → `JSON_EXTRACT` / `FlatFileReader(port:$0.content)`
- OpenAPI-documented REST API → `RESTConnector`

**Writing data:**
- Flat file / CSV → `FlatFileWriter`
- Database → `DBOutputTable`
- JSON → `JSONWriter`
- DDL / raw SQL → `DBExecute`
- Report with header+footer → `StructuredDataWriter`
- Email → `EmailSender`
- Discard → `TrashWriter`

**Transforming:**
- Field mapping / logic → `Reformat`
- Filter records → `ExtFilter`
- One row → many rows → `Normalizer`
- Many rows → one row → `Denormalizer`
- Group + aggregate → `Aggregate`
- Group + aggregate + subtotals → `Denormalizer` + `Rollup`

**Joining:**
- Large driver + small lookup (unsorted) → `ExtHashJoin`
- Both large + sorted → `ExtMergeJoin`
- Reference data from file/DB → `LookupJoin`

**Sorting:**
- Any size dataset → `ExtSort` (disk-based, safe)
- Small dataset, fits in memory → `FastSort`

**Deduplication:**
- Remove duplicates → `Dedup` (requires sorted input)
- Top-N selection → `Dedup(noDupRecord=N)` after sort descending

**Routing:**
- Duplicate to all outputs → `SimpleCopy`
- Merge multiple inputs → `SimpleGather`
- Route to one of N outputs → `Partition`

**Orchestration:**
- Run a graph → `ExecuteGraph`
- Run a sub-jobflow → `ExecuteJobflow`
- Run a shell command → `ExecuteScript`
- Branch on condition → `Condition`

---

## Common Gotchas

| Pattern | Gotcha |
|---|---|
| Aggregate / Denormalizer / Rollup / ExtMergeJoin / Dedup | **Requires sorted input** — always place ExtSort before these |
| ExtHashJoin | Slave (port 1) fully loaded into Worker heap — watch memory for large slaves |
| ExtSort temp disk | Spill files go to Worker temp dir — keep on a separate volume |
| DBOutputTable with FK constraints | Use phases: parent table phase N, child table phase N+1 |
| FlatFileReader error records | Use `dataPolicy=controlled` to route errors to port 1 — always connect port 1 |
| TrashWriter | Always connect unused output ports — dangling ports cause graph validation errors |
| Subgraph parameters | Use `ComponentReference` to auto-sync graph parameters to component properties |

---

## Deprecated — Do Not Use

| Deprecated | Replacement |
|---|---|
| `RunGraph` | `ExecuteGraph` |
| `SystemExecute` | `ExecuteScript` |

Flag these in any graph you're modifying and suggest refactoring.
