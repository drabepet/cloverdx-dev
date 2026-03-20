# CloverDX Subgraph Components

> Source: CloverDX 7.3.1 docs + TrainingExamples subgraphs (OrdersReader, PaymentsReader, AggregateCustomers, QueryWeather)

Subgraphs are reusable graph components. Extension: `.sgrf`. They appear in the component palette and can be placed inside regular graphs like any other component.

---

## SubgraphInput

Defines an input port on the subgraph — receives data from the parent graph.

**Key properties:**
| Property | Description |
|---|---|
| Port name | Label shown on the component in parent graph |
| Metadata | Record type expected on this port |

Port 0 is typically a control/parameter port carrying config values from the parent.

**Example** (PaymentsReader.sgrf):
```
SubgraphInput port 0: receives INPUT_FILE_URL, NUM_SOURCE_RECORDS, SKIP_SOURCE_ROWS
```
Parent passes these as a record; subgraph reads them with `getParamValue()` or field access.

---

## SubgraphOutput

Defines an output port on the subgraph — sends data back to the parent graph.

**Key properties:**
| Property | Description |
|---|---|
| Port name | Label shown on the component in parent graph |
| Metadata | Record type emitted on this port |
| `required` | Whether parent must connect this port |
| `keepEdge` | Keep edge even when port has no data |

**Multiple output ports** (OrdersReader.sgrf):
```
Port 0: Order records
Port 1: Line item records
Port 2: Address records
```
Parent connects whichever ports it needs; unused ports can be left unconnected if `required=false`.

---

## Subgraph Structure Patterns

### Reader subgraph with error port (PaymentsReader.sgrf)

```
SubgraphInput (params)
  → FlatFileReader (fileURL from param, dataPolicy=controlled)
  → [REFORMAT: parse + validate fields]
  → port 0: valid records          → SubgraphOutput port 0
  → port 1: parse errors ─┐
                           SimpleGather → SubgraphOutput port 1 (errors)
  → [field mapping errors]─┘
```

**Error handling pattern:**
```ctl
// transformOnError — automatically routes to port 1 on any field conversion error
function integer transformOnError(string errorMessage, string stackTrace) {
    $out.1.recordNo = $in.0.recordNo;
    $out.1.errorMessage = errorMessage;
    $out.1.originalData = $in.0.rawLine;
    return 1;   // port 1 = error port
}
```

### Hierarchical XML/JSON reader subgraph (OrdersReader.sgrf)

```
SubgraphInput (control)
  → XML_EXTRACT (Orders.xml, Orders.xsd)
  → port 0: Order records    → SubgraphOutput port 0
  → port 1: Line items       → SubgraphOutput port 1
  → port 2: Addresses        → SubgraphOutput port 2
```

Uses external `.fmt` metadata files shared with other graphs:
```
Metadata fileURL: ${META_DIR}/online-store/Order.fmt
```

### HTTP API subgraph (QueryWeather.sgrf)

```
SubgraphInput (city, apiKey)
  → HTTP_CONNECTOR (api.openweathermap.org)
  → [port 0: response] → JSON_EXTRACT
    → [port 0: status check] → Reformat (validate cod==200)
    → [port 0: weather records] → Reformat (Kelvin→Celsius) → SubgraphOutput port 0
    → [port 1: API error]       → Concatenate ─→ SubgraphOutput port 1 (errors)
  → [port 1: HTTP error]                    ─┘
```

Multi-layer error handling:
1. HTTP errors (connection fail, timeout) → port 1 of HTTP_CONNECTOR
2. API errors (bad API key, city not found) → parsed from response JSON (cod field)
3. Both consolidated via Concatenate → single error output port

---

## Graph Parameters with ComponentReference

Subgraphs expose parameters to the parent graph via `GraphParameters`. `ComponentReference` wires a parameter directly to a component property so it syncs automatically.

**Example** (PaymentsReader.sgrf):
```xml
<GraphParameter name="INPUT_FILE_URL" value="${DATAIN_DIR}/Payments-*.csv">
    <ComponentReference referencedComponent="FLAT_FILE_READER"
                        referencedProperty="fileURL"/>
</GraphParameter>
```
When parent sets `INPUT_FILE_URL`, the FlatFileReader's `fileURL` updates automatically — no CTL2 mapping needed.

---

## Using Subgraphs in Parent Graphs

**Example** (06e01 - Aggregation with subgraph.grf):
```
AggregateCustomers subgraph
  → port 0: customer aggregation results
  → used exactly like any built-in component
```

**Example** (06e02 - Reading payments with subgraph.grf):
```
PaymentsReader subgraph
  → port 0: valid payment records → DBOutputTable
  → port 1: error records         → FlatFileWriter (error log)
```

Parent graph treats subgraph errors the same as it would a reader's error port — maximum reuse.

---

## Subgraph Design Guidelines

1. **Single responsibility** — one subgraph = one well-defined operation (read X, call API Y, validate Z)
2. **Error ports** — always expose an error port (port 1); parent decides what to do with errors
3. **Parameterize everything variable** — file paths, API keys, record counts via GraphParameters
4. **Reuse shared metadata** — reference `.fmt` files instead of inline definitions
5. **Don't assume phase** — subgraphs run in the caller's phase; avoid phase-dependent logic inside
6. **Keep it simple** — if a subgraph needs its own complex orchestration, consider a jobflow instead
