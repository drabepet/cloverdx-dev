# CloverDX Subgraph XML Structure

> Source: CloverDX 7.3.1 docs + TrainingExamples (OrdersReader.sgrf, PaymentsReader.sgrf)

Subgraphs (`.sgrf`) are reusable graph fragments that can be embedded inside other
graphs as a single logical component. They share the same `<Graph>` root but have
`nature="subgraph"`. The subgraph defines its own input and output port interface,
and parent graphs connect to it just like any other component.

---

## Root Element

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="sgrf01" licenseCode="CAN_USE_COMMUNITY_EDITION"
       name="OrdersReader" nature="subgraph">
```

The only difference from a `.grf` root: **`nature="subgraph"`**.

---

## Subgraph Port Declaration (`<Global>`)

Subgraphs declare their ports in `<Global>`. This defines the interface that parent
graphs see when they embed the subgraph as a component.

### Output ports only (most common — subgraph as data source):
```xml
<Global>
    <Metadata fileURL="${META_DIR}/Orders.fmt" id="META_ORDERS"/>
    <GraphParameters>
        <GraphParameterFile fileURL="workspace.prm"/>
        <GraphParameter name="SOURCE_URI" value="${DATAIN_DIR}/orders.csv">
            <ComponentReference referencedComponent="READ_ORDERS"
                                referencedProperty="fileURL"/>
        </GraphParameter>
    </GraphParameters>
    <OutputPorts>
        <SinglePort id="PORT_ORDERS" name="orders" description="Stream of order records"
                    metadata="META_ORDERS" required="true"/>
    </OutputPorts>
</Global>
```

### Output port with `required="false"`:
```xml
<OutputPorts>
    <SinglePort id="PORT_VALID" name="valid" metadata="META_PAYMENTS" required="true"/>
    <SinglePort id="PORT_INVALID" name="invalid" metadata="META_PAYMENTS"
                required="false" keepEdge="true"/>
</OutputPorts>
```

- `required="true"` — parent graph MUST connect this port. Error if unconnected.
- `required="false"` — parent graph MAY leave this port unconnected.
- `keepEdge="true"` — even if the parent doesn't connect this port, keep the internal
  subgraph edge active (data still flows, it just goes nowhere). Useful for optional
  error/reject paths.

### Input and output ports (subgraph as transformer):
```xml
<InputPorts>
    <SinglePort id="PORT_IN" name="input" metadata="META_RAW" required="true"/>
</InputPorts>
<OutputPorts>
    <SinglePort id="PORT_OUT" name="output" metadata="META_CLEAN" required="true"/>
    <SinglePort id="PORT_ERR" name="errors" metadata="META_ERRORS" required="false"/>
</OutputPorts>
```

---

## SUBGRAPH_INPUT and SUBGRAPH_OUTPUT Nodes

These are the internal connection points that map to the declared ports.

### SUBGRAPH_OUTPUT — emits data to the parent graph's port:
```xml
<Node id="SUBGRAPH_OUTPUT0" type="SUBGRAPH_OUTPUT"
      guiX="500" guiY="100"
      outputPortIndex="0"
      guiName="orders output"/>
```

- `outputPortIndex` — which output port (matches declaration order in `<OutputPorts>`)
- Data flowing into this node is what the parent graph receives on that port
- **Always required — no exceptions.** Even write-only subgraphs with no logical output
  must include at least one SUBGRAPH_OUTPUT node. checkConfig returns
  `ERROR: Missing SubgraphOutput component` without it.

**Write-only subgraph pattern** (e.g., subgraph that writes to DB or file):
Use SimpleCopy to fork the stream — one branch to the writer, one to SUBGRAPH_OUTPUT.
Declare the port as `required="false" keepEdge="true"` so parent graphs don't need to
connect it:

```xml
<OutputPorts>
    <SinglePort id="PORT_PASSTHROUGH" name="passthrough" metadata="META_DATA"
                required="false" keepEdge="true"/>
</OutputPorts>
...
<Node id="COPY0" type="SIMPLE_COPY" guiX="200" guiY="100"/>
<Node id="WRITE0" type="DB_OUTPUT_TABLE" ... guiX="400" guiY="50"/>
<Node id="SUBGRAPH_OUTPUT0" type="SUBGRAPH_OUTPUT" outputPortIndex="0" guiX="400" guiY="150"/>

<Edge fromNode="SUBGRAPH_INPUT0:0" toNode="COPY0:0" metadata="META_DATA"/>
<Edge fromNode="COPY0:0" toNode="WRITE0:0" metadata="META_DATA"/>
<Edge fromNode="COPY0:1" toNode="SUBGRAPH_OUTPUT0:0" metadata="META_DATA"/>
```

### SUBGRAPH_INPUT — receives data from the parent graph's port:
```xml
<Node id="SUBGRAPH_INPUT0" type="SUBGRAPH_INPUT"
      guiX="24" guiY="100"
      inputPortIndex="0"
      guiName="raw input"/>
```

---

## Complete Read-only Subgraph (OrdersReader.sgrf)

Pattern: subgraph wraps a FlatFileReader and exposes one output port to the parent.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="sgrf_orders" name="OrdersReader" nature="subgraph">
    <Global>
        <Metadata fileURL="${META_DIR}/Orders.fmt" id="META_ORDERS"/>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
            <!-- ComponentReference wires this param directly to the reader's fileURL -->
            <GraphParameter name="SOURCE_URI" value="${DATAIN_DIR}/orders.csv">
                <ComponentReference referencedComponent="READ_ORDERS"
                                    referencedProperty="fileURL"/>
            </GraphParameter>
        </GraphParameters>
        <OutputPorts>
            <SinglePort id="PORT_ORDERS" name="orders" metadata="META_ORDERS"
                        required="true"/>
        </OutputPorts>
    </Global>

    <Phase number="0">
        <Node id="READ_ORDERS" type="FLAT_FILE_READER"
              fileURL="${DATAIN_DIR}/orders.csv"
              charset="UTF-8"
              guiX="24" guiY="100"/>

        <Node id="SUBGRAPH_OUTPUT0" type="SUBGRAPH_OUTPUT"
              outputPortIndex="0"
              guiX="300" guiY="100"/>

        <Edge id="E0" fromNode="READ_ORDERS:0" toNode="SUBGRAPH_OUTPUT0:0"
              metadata="META_ORDERS"/>
    </Phase>
</Graph>
```

When a parent graph embeds `OrdersReader.sgrf`, it sees a component with one output
port labeled "orders" that emits order records.

---

## Subgraph with Error Handling (PaymentsReader.sgrf)

Pattern: reads, validates, splits valid/invalid, and exposes both as optional ports.
The parent may or may not connect the error port.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="sgrf_payments" name="PaymentsReader" nature="subgraph">
    <Global>
        <Metadata fileURL="${META_DIR}/Payments.fmt" id="META_PAYMENTS"/>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
            <GraphParameter name="PAYMENTS_FILE" value="${DATAIN_DIR}/payments.csv">
                <ComponentReference referencedComponent="READ_PAYMENTS"
                                    referencedProperty="fileURL"/>
            </GraphParameter>
        </GraphParameters>
        <!-- Two output ports: valid records (required) and invalid/rejected (optional) -->
        <OutputPorts>
            <SinglePort id="PORT_VALID" name="valid" metadata="META_PAYMENTS"
                        required="true"/>
            <SinglePort id="PORT_INVALID" name="invalid" metadata="META_PAYMENTS"
                        required="false" keepEdge="true"/>
        </OutputPorts>
    </Global>

    <Phase number="0">
        <Node id="READ_PAYMENTS" type="FLAT_FILE_READER"
              fileURL="${DATAIN_DIR}/payments.csv"
              charset="UTF-8"
              dataPolicy="controlled"
              guiX="24" guiY="100"/>

        <!-- Validate: filter out records with null orderId -->
        <Node id="VALIDATE" type="EXT_FILTER" guiX="250" guiY="100">
            <attr name="filterExpression"><![CDATA[
//#CTL2
!isnull($in.0.orderId) && $in.0.paidAmount > 0.0d
            ]]></attr>
        </Node>

        <!-- Port 0 of EXT_FILTER → valid records → parent's "valid" port -->
        <Node id="OUT_VALID" type="SUBGRAPH_OUTPUT"
              outputPortIndex="0" guiX="500" guiY="50"/>

        <!-- Port 1 of EXT_FILTER → invalid records → parent's "invalid" port -->
        <Node id="OUT_INVALID" type="SUBGRAPH_OUTPUT"
              outputPortIndex="1" guiX="500" guiY="200"/>

        <Edge id="E0" fromNode="READ_PAYMENTS:0" toNode="VALIDATE:0"
              metadata="META_PAYMENTS"/>
        <!-- debugMode on edges useful during development -->
        <Edge id="E1" fromNode="VALIDATE:0" toNode="OUT_VALID:0"
              metadata="META_PAYMENTS" debugMode="true"/>
        <Edge id="E2" fromNode="VALIDATE:1" toNode="OUT_INVALID:0"
              metadata="META_PAYMENTS" debugMode="true"/>
    </Phase>
</Graph>
```

---

## Using a Subgraph in a Parent Graph

In the parent `.grf`, a subgraph is referenced as a Node with `type="SUBGRAPH"` and
`jobURL` pointing to the `.sgrf` file:

```xml
<Node id="ORDERS_READER" type="SUBGRAPH"
      jobURL="${GRAPH_DIR}/subgraph/OrdersReader.sgrf"
      guiX="24" guiY="100"/>

<!-- Connect the subgraph's output port 0 to downstream processing -->
<Edge id="E0" fromNode="ORDERS_READER:0" toNode="PROCESS_ORDERS:0"
      metadata="META_ORDERS"/>
```

> **`jobURL` not `subgraphURL`** — the server only accepts `jobURL`. Using `subgraphURL`
> will cause a validation error.

Parameters declared in the subgraph's `<GraphParameters>` appear in the parent's
component parameter panel when you select the subgraph node in Designer.

---

## ComponentReference — Auto-Wiring Parameters

`<ComponentReference>` links a graph parameter directly to a component property.
When the parameter value changes (e.g., overridden in workspace.prm or passed from
the parent), the component property updates automatically.

```xml
<GraphParameter name="SOURCE_URI" value="${DATAIN_DIR}/customers.csv">
    <ComponentReference referencedComponent="READ_CUSTOMERS"
                        referencedProperty="fileURL"/>
</GraphParameter>
```

This is especially powerful in subgraphs because:
- The parent sees `SOURCE_URI` as a visible parameter on the subgraph component
- The parent can override it per-instance without editing the subgraph XML
- Designer shows it in the dedicated "Parameters" panel

---

## Subgraph Icon

Subgraphs can have a custom icon shown in Designer:

```xml
<Graph ... >
    <!-- Icon attributes on the root element -->
    <!-- Usually set by Designer, not hand-edited -->
</Graph>
```

In practice, Designer manages icon paths automatically. Don't hand-edit them.

---

## Subgraph vs. Inline Graph Parameters

| Scenario | Use |
|---|---|
| Parameter shared across all instances | Default value in `<GraphParameter>` |
| Parameter overridden per parent instance | `<ComponentReference>` on the parameter |
| Parameter computed from parent dictionary | Dynamic param with CTL2 `getValue()` |
| Fixed internal constant | Hardcode in the node attribute, no parameter needed |

---

## Gotchas

- **`keepEdge="true"` on optional ports** — without this, if a parent doesn't connect an optional output port, the internal edge is removed and data silently disappears. Add `keepEdge="true"` when you want the internal logic to run even if the parent ignores the output.
- **SUBGRAPH_OUTPUT port index must match declaration order** — `outputPortIndex="0"` maps to the first `<SinglePort>` in `<OutputPorts>`. Mismatches cause metadata errors.
- **Subgraph metadata must match parent expectations** — the parent assigns edges to subgraph ports; if the metadata doesn't match, CloverDX reports a type mismatch error at graph validation.
- **External CTL in subgraphs** — CTL2 inside a subgraph uses the same `${TRANS_DIR}` paths as regular graphs; make sure the subgraph has access to the shared trans directory.
- **Debugging subgraph internals** — `debugMode="true"` on edges inside the subgraph lets you capture edge data when running the parent graph in debug mode.
