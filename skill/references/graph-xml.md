# CloverDX Graph XML Structure

> Source: CloverDX 7.3.1 docs + TrainingExamples (01e01 Planets, 07e01 Customer leaderboard, 09e01 Load customers)

A CloverDX graph (`.grf`) is an XML file. The root element is `<Graph>`. Subgraphs (`.sgrf`)
and data services (`.rjob`) share the same root but with a `nature` attribute — see their
own reference files for the differences.

---

## Graph Root Element

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="dvela" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="wbgPGrRRrW" licenseCode="CAN_USE_COMMUNITY_EDITION"
       name="Customer leaderboard" showComponentDetails="true">
```

**Key root attributes:**
| Attribute | Description |
|---|---|
| `name` | Graph display name |
| `author` | Creator username |
| `created` | Creation timestamp |
| `id` | Unique graph ID (auto-generated) |
| `guiVersion` | Designer version that created/last saved the file |
| `licenseCode` | License tier |
| `nature` | Omit for normal graphs; `"subgraph"` / `"restJob"` / `"jobflow"` for special types |

---

## `<Global>` Section

Everything before the phases. Declared order: Metadata → Connection → GraphParameters → LookupTable → Sequence → Dictionary → RichTextNote.

### Metadata

#### External reference (preferred for reuse):
```xml
<Metadata fileURL="${META_DIR}/Customers.fmt" id="META_CUSTOMERS"/>
```

#### Inline metadata (common for graph-specific schemas):
```xml
<Metadata id="META_PLANETS">
    <Record fieldDelimiter="|" name="planets" recordDelimiter="\n" type="delimited">
        <Field name="id" type="integer"/>
        <Field name="name" type="string"/>
        <Field name="diameter" type="integer"/>
        <Field name="moons" type="integer"/>
        <Field name="comment" type="string"/>
    </Record>
</Metadata>
```

Multiple metadata can appear — one per record structure used in the graph.

### Connection

#### Reference to external .cfg file:
```xml
<Connection dbConfig="${CONN_DIR}/database.cfg" id="CONN_DATABASE" type="JDBC"/>
```

#### Inline JDBC connection (avoid — prefer external .cfg):
```xml
<Connection id="CONN_DB" type="JDBC"
    dbURL="jdbc:postgresql://host:5432/db"
    user="${DB_USER}" password="${DB_PASSWORD}"
    jdbcDriver="org.postgresql.Driver"/>
```

### GraphParameters

Standard parameters — defined in the graph, can be overridden by `workspace.prm`:
```xml
<GraphParameters>
    <GraphParameterFile fileURL="workspace.prm"/>
    <GraphParameter name="TRUNCATE_TABLE" value="false">
        <SingleType name="bool"/>
    </GraphParameter>
    <GraphParameter name="LAST_PROCESSED_ID" value="0">
        <SingleType name="long"/>
    </GraphParameter>
</GraphParameters>
```

**Dynamic parameter with CTL2** — computed at runtime from a Dictionary or external source:
```xml
<GraphParameter name="CUSTOMER_SINCE">
    <DynamicValue code="//#CTL2&#10;function string getValue() {&#10;    return getParamValue(&quot;BASE_DATE&quot;);&#10;}"/>
</GraphParameter>
```

**`<ComponentReference>`** — auto-wires a parameter value into a component property:
```xml
<GraphParameter name="FILE_URL" value="${DATAIN_DIR}/customers.csv">
    <ComponentReference referencedComponent="READ_CUSTOMERS" referencedProperty="fileURL"/>
</GraphParameter>
```
This makes the parameter appear in a dedicated panel in Designer and keeps the property
in sync without editing the Node XML directly.

### Dictionary

Shared key-value store — accessible from any component via CTL2 `getDictionaryValue()` / `setDictionaryValue()`.
```xml
<Dictionary>
    <Entry id="UPLOAD_FILE_NAME" input="false" output="true" type="string"/>
    <Entry id="RECORD_COUNT" input="false" output="true" type="long"/>
</Dictionary>
```
- `input="true"` — value can be set before the graph starts (from parent jobflow)
- `output="true"` — value can be read after the graph ends (by parent jobflow)

### RichTextNote

Design-time annotation displayed as a colored sticky note in Designer. Not executed.
```xml
<RichTextNote backgroundColor="FAF6D1" enabled="true" folded="false"
               guiName="Phase 0 - Lookup" guiX="24" guiY="22" guiWidth="260" guiHeight="76">
    <attr name="text"><![CDATA[h3. Phase 0 — load exchange rate lookup
Load lookup table from CSV file.]]></attr>
</RichTextNote>
```
Uses Confluence-style markup (`h3.`, `*bold*`, `_italic_`).

---

## `<Phase>` Section

Phases execute sequentially. Phase 0 runs first, then phase 1, etc.
Within a phase, all components execute concurrently (driven by data flow).

```xml
<Phase number="0">
    <!-- All nodes and edges for this phase -->
</Phase>
<Phase number="1">
    <!-- Runs after phase 0 completes -->
</Phase>
```

Most simple graphs use a single phase (number="0"). Use multiple phases when you need
to guarantee completion order (e.g., load a lookup table before the main processing phase).

---

## `<Node>` (Component)

```xml
<Node guiName="Read Customers" guiX="24" guiY="150" id="READ_CUSTOMERS"
      type="FLAT_FILE_READER"
      fileURL="${DATAIN_DIR}/customers.csv"
      charset="UTF-8"
      dataPolicy="controlled"/>
```

**Universal attributes:**
| Attribute | Description |
|---|---|
| `id` | Unique ID — used in edge `fromNode`/`toNode` references |
| `type` | Component type string (see components.md) |
| `guiX`, `guiY` | Visual position in Designer canvas |
| `guiName` | Optional label shown in Designer (defaults to id if omitted) |
| `enabled` | `enabled` (default), `disabled`, `pass_through`, `wait_for_all` |

**Component-specific properties** appear as additional attributes OR as child `<attr>` elements
with CDATA (used when the value contains XML special characters or is multi-line CTL2):

```xml
<Node id="TRANSFORM_DATA" type="REFORMAT" guiX="300" guiY="150">
    <attr name="transform"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.fullName = $in.0.firstName + " " + $in.0.lastName;
    $out.0.totalPaid = $in.1.paidAmount;
    return ALL;
}
    ]]></attr>
</Node>
```

### Common component `<attr>` properties:
| Attr name | Component | Description |
|---|---|---|
| `transform` | REFORMAT, EXT_HASH_JOIN, etc. | Inline CTL2 transformation |
| `filterExpression` | EXT_FILTER | Inline CTL2 boolean expression |
| `inputMapping` | EXECUTE_GRAPH | CTL2 to pass params to child graph |
| `outputMapping` | EXECUTE_GRAPH | CTL2 to read results from child graph |
| `sqlQuery` | DB_EXECUTE, DB_INPUT_TABLE | SQL statement |
| `mapping` | AGGREGATE | Declarative field=function expressions |

---

## `<Edge>` (Data Flow Connection)

```xml
<Edge fromNode="READ_CUSTOMERS:0" guiBendpoints="" guiRouter="Manhattan"
      id="EDGE0" inPort="Port 0 (in)" metadata="META_CUSTOMERS"
      outPort="Port 0 (output)" toNode="EXT_SORT0:0"/>
```

**Key attributes:**
| Attribute | Description |
|---|---|
| `id` | Unique edge ID |
| `fromNode` | `COMPONENT_ID:portNumber` — output port of source component |
| `toNode` | `COMPONENT_ID:portNumber` — input port of destination component |
| `outPort` | Human-readable port label (optional, cosmetic) |
| `inPort` | Human-readable port label (optional, cosmetic) |
| `metadata` | ID of a `<Metadata>` element defined in `<Global>` |
| `metadataRef` | `#//EdgeN` — inherit metadata from another edge by ID |
| `guiRouter` | `Manhattan` (auto-routing, default) or `Manual` (explicit bendpoints) |
| `guiBendpoints` | Explicit bend coordinates when `guiRouter="Manual"` |
| `debugMode` | `true` — capture edge data for debugging in Designer |

**When `metadata` is omitted:**
- The edge carries no schema (error/control flow paths, or schema passes through unchanged)
- TrashWriter inputs, error outputs, and jobflow control edges typically have no metadata

**metadataRef example** — edge inherits schema from another edge:
```xml
<Edge id="EDGE3" fromNode="EXT_HASH_JOIN0:0" toNode="REFORMAT0:0"
      metadataRef="#//EDGE0" .../>
```

---

## Complete Minimal Graph (01e01 Planets)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-01-01 00:00:00" guiVersion="5.13.0"
       id="wbgPGrRRrW" licenseCode="CAN_USE_COMMUNITY_EDITION" name="Planets">
    <Global>
        <Metadata id="META_PLANETS">
            <Record fieldDelimiter="|" name="planets" recordDelimiter="\n" type="delimited">
                <Field name="id" type="integer"/>
                <Field name="name" type="string"/>
                <Field name="diameter" type="integer"/>
                <Field name="moons" type="integer"/>
                <Field name="comment" type="string"/>
            </Record>
        </Metadata>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
        </GraphParameters>
    </Global>

    <Phase number="0">
        <Node guiX="24" guiY="150" id="FLAT_FILE_READER0" type="FLAT_FILE_READER"
              fileURL="${DATAIN_DIR}/planets.csv"/>
        <Node guiX="300" guiY="150" id="FLAT_FILE_WRITER0" type="FLAT_FILE_WRITER"
              fileURL="${DATAOUT_DIR}/planets_out.csv" charset="UTF-8"/>
        <Edge id="EDGE0" fromNode="FLAT_FILE_READER0:0" toNode="FLAT_FILE_WRITER0:0"
              metadata="META_PLANETS" guiRouter="Manhattan" outPort="Port 0 (output)"
              inPort="Port 0 (in)"/>
    </Phase>
</Graph>
```

---

## Multi-Phase Graph with DB Connection (09e01 Load customers)

Pattern: phase 0 optionally truncates a table, phase 1 loads data.

```xml
<Global>
    <Metadata fileURL="${META_DIR}/Customers.fmt" id="META_CUSTOMERS"/>
    <Connection dbConfig="${CONN_DIR}/database.cfg" id="CONN_DATABASE" type="JDBC"/>
    <GraphParameters>
        <GraphParameterFile fileURL="workspace.prm"/>
        <GraphParameter name="TRUNCATE_TABLE" value="false">
            <SingleType name="bool"/>
        </GraphParameter>
        <GraphParameter name="INPUT_FILE" value="${DATAIN_DIR}/customers.csv">
            <ComponentReference referencedComponent="READ_CUSTOMERS"
                                referencedProperty="fileURL"/>
        </GraphParameter>
    </GraphParameters>
</Global>

<Phase number="0">
    <!-- Enabled only when TRUNCATE_TABLE=true -->
    <Node id="DB_EXECUTE_TRUNCATE" type="DB_EXECUTE"
          enabled="${TRUNCATE_TABLE}"
          dbConnection="CONN_DATABASE"
          guiX="24" guiY="50">
        <attr name="sqlQuery"><![CDATA[DELETE FROM customers]]></attr>
    </Node>
</Phase>

<Phase number="1">
    <Node id="READ_CUSTOMERS" type="FLAT_FILE_READER"
          fileURL="${DATAIN_DIR}/customers.csv"
          guiX="24" guiY="150"/>
    <Node id="WRITE_CUSTOMERS" type="DB_OUTPUT_TABLE"
          dbConnection="CONN_DATABASE"
          dbTable="customers"
          batchMode="true"
          guiX="300" guiY="150"/>
    <Edge id="EDGE0" fromNode="READ_CUSTOMERS:0" toNode="WRITE_CUSTOMERS:0"
          metadata="META_CUSTOMERS"/>
</Phase>
```

---

## Complex Single-Phase Graph with Joins (07e01 Customer leaderboard)

Multiple metadata, external CTL reference, join + sort pipeline:

```xml
<Global>
    <!-- Mix of inline and external metadata -->
    <Metadata fileURL="${META_DIR}/Customers.fmt" id="META_CUSTOMERS"/>
    <Metadata fileURL="${META_DIR}/Payments.fmt" id="META_PAYMENTS"/>
    <Metadata id="META_LEADERBOARD">
        <Record name="leaderboard" type="delimited" ...>
            <Field name="rank" type="integer"/>
            <Field name="fullName" type="string"/>
            <Field name="totalPaid" type="decimal" length="15" scale="2"/>
        </Record>
    </Metadata>

    <GraphParameters>
        <GraphParameterFile fileURL="workspace.prm"/>
        <GraphParameter name="BASE_CURRENCY" value="USD"/>
    </GraphParameters>

    <RichTextNote backgroundColor="FAF6D1" enabled="true" folded="false"
                  guiName="Join logic" guiX="24" guiY="22" guiWidth="300" guiHeight="60">
        <attr name="text"><![CDATA[h3. Join customers with payment totals
Aggregate payments per customer, then join with customer details.]]></attr>
    </RichTextNote>
</Global>

<Phase number="0">
    <Node id="READ_CUSTOMERS" type="FLAT_FILE_READER"
          fileURL="${DATAIN_DIR}/customers.csv" guiX="24" guiY="100"/>
    <Node id="READ_PAYMENTS" type="FLAT_FILE_READER"
          fileURL="${DATAIN_DIR}/payments.csv" guiX="24" guiY="250"/>

    <!-- Aggregate payments per customer -->
    <Node id="AGG_PAYMENTS" type="AGGREGATE"
          aggregateKey="customerId"
          sorted="false"
          guiX="250" guiY="250">
        <attr name="mapping"><![CDATA[
$customerId:=$customerId;
$paidAmount:=sum($paidAmount);
        ]]></attr>
    </Node>

    <!-- Sort customers for merge join -->
    <Node id="SORT_CUSTOMERS" type="EXT_SORT"
          sortKey="id(a)" guiX="250" guiY="100"/>
    <Node id="SORT_PAYMENTS_AGG" type="EXT_SORT"
          sortKey="customerId(a)" guiX="450" guiY="250"/>

    <!-- Join customers (port 0) with payment totals (port 1) -->
    <Node id="JOIN" type="EXT_MERGE_JOIN"
          joinKey="$id(a)#$customerId(a);"
          joinType="leftOuter"
          guiX="550" guiY="150">
        <attr name="transform"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.fullName = $in.0.firstName + " " + $in.0.lastName;
    $out.0.email = $in.0.email;
    $out.0.totalPaid = isnull($in.1.paidAmount) ? 0.0d : $in.1.paidAmount;
    return ALL;
}
        ]]></attr>
    </Node>

    <!-- Sort descending by total paid for ranking -->
    <Node id="SORT_LEADERBOARD" type="EXT_SORT"
          sortKey="totalPaid(d)" guiX="750" guiY="150"/>

    <Node id="WRITE_OUTPUT" type="FLAT_FILE_WRITER"
          fileURL="${DATAOUT_DIR}/leaderboard.csv" guiX="950" guiY="150"/>

    <!-- Edges -->
    <Edge id="E0" fromNode="READ_CUSTOMERS:0" toNode="SORT_CUSTOMERS:0"
          metadata="META_CUSTOMERS"/>
    <Edge id="E1" fromNode="READ_PAYMENTS:0" toNode="AGG_PAYMENTS:0"
          metadata="META_PAYMENTS"/>
    <Edge id="E2" fromNode="SORT_CUSTOMERS:0" toNode="JOIN:0"
          metadata="META_CUSTOMERS"/>
    <Edge id="E3" fromNode="AGG_PAYMENTS:0" toNode="SORT_PAYMENTS_AGG:0"
          metadataRef="#//E1"/>
    <Edge id="E4" fromNode="SORT_PAYMENTS_AGG:0" toNode="JOIN:1"
          metadataRef="#//E1"/>
    <Edge id="E5" fromNode="JOIN:0" toNode="SORT_LEADERBOARD:0"
          metadata="META_LEADERBOARD"/>
    <Edge id="E6" fromNode="SORT_LEADERBOARD:0" toNode="WRITE_OUTPUT:0"
          metadataRef="#//E5"/>
</Phase>
```

---

## Node `enabled` Attribute — Conditional Components

```xml
<!-- Only runs when TRUNCATE_TABLE graph parameter is true -->
<Node id="TRUNCATE" type="DB_EXECUTE" enabled="${TRUNCATE_TABLE}" .../>

<!-- Always runs (default) -->
<Node id="LOAD" type="DB_OUTPUT_TABLE" enabled="enabled" .../>

<!-- Never runs (design-time disable) -->
<Node id="DEBUG_WRITER" type="FLAT_FILE_WRITER" enabled="disabled" .../>
```

Values: `enabled` | `disabled` | `pass_through` | `wait_for_all`

---

## Port Numbering Quick Reference

| Component | Port 0 | Port 1 | Port 2+ |
|---|---|---|---|
| FlatFileReader, DBInputTable | output | — | — |
| FlatFileWriter, DBOutputTable | input | — | — |
| Reformat | output | optional output | — |
| ExtFilter | pass (true) | reject (false) | — |
| ExtHashJoin | driver input | slave input | — |
| ExtHashJoin output | joined | unmatched (outer) | — |
| ExtMergeJoin | left (driver) | right (slave) | — |
| TrashWriter | input | — | — |

---

## Common Gotchas

- **Always connect all output ports** — an unconnected output port causes a graph error. If you don't need the reject path of ExtFilter or error output of a writer, connect it to TrashWriter.
- **metadataRef vs metadata** — use `metadataRef="#//EDGE_ID"` to inherit schema from another edge; use `metadata="META_ID"` to assign a named metadata directly. Don't mix both on the same edge.
- **guiX/guiY matter for readability** — leave space: readers at x=24, transformers at x=300+, writers at x=700+. Y spacing of 150 between parallel streams works well.
- **External CTL reference:** `transformURL="${TRANS_DIR}/myTransform.ctl"` — the .ctl file must be committed alongside the .grf.
- **Phase gaps are valid** — phases 0 and 5 with nothing in between is fine; gaps don't cause errors.
