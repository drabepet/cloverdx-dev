# CloverDX Metadata Reference

> Source: CloverDX 7.3.1 docs + TrainingExamples + APIWorkshopSandbox real graphs

Metadata defines the **record structure** (schema) for data flowing through edges. Every edge that carries structured data should have metadata assigned. Metadata can live in three places: standalone `.fmt` files, inline inside a graph, or referenced from another edge.

---

## Table of Contents
1. Record types (delimited, fixed, mixed)
2. Field types and attributes
3. Special field attributes
4. Standalone .fmt files
5. Inline metadata in graphs
6. External metadata reference in graphs
7. Edge metadata assignment
8. metadataRef — inheriting metadata between edges
9. Debug attributes on edges
10. Real examples from training graphs
11. Metadata design guidelines

---

## 1. Record Types

### Delimited
Fields separated by a delimiter character.

```xml
<Record type="delimited" fieldDelimiter="\t" recordDelimiter="\n\|\r\n" name="Customer">
  <Field name="id" type="long"/>
  <Field name="fullName" type="string"/>
</Record>
```

| Attribute | Description | Common values |
|---|---|---|
| `type` | Record format | `delimited` |
| `fieldDelimiter` | Field separator | `\t` (tab), `\|` (pipe), `;` (semicolon), `,` (comma) |
| `recordDelimiter` | Row separator | `\n\|\r\n` (LF or CRLF), `\r\n` |
| `skipSourceRows` | Skip header rows | `1` |
| `quotedStrings` | Honour quote chars | `true` / `false` |
| `quoteChar` | Quote character | `"` / `both` (accept both `"` and `'`) |

### Fixed-length
Each field occupies a fixed number of bytes.

```xml
<Record type="fixed" recordDelimiter="\r\n" name="LineItemFixLen">
  <Field name="orderId" size="10" type="long" format="0000000000"/>
  <Field name="orderDatetime" size="19" type="date" format="yyyy-MM-dd HH:mm:ss"/>
  <Field name="productName" size="60" type="string"/>
</Record>
```

| Attribute | Description |
|---|---|
| `type` | `fixed` |
| `size` | Number of characters/bytes for this field (required for every field) |
| `format` | Display/parse format for numbers and dates |

### Mixed
Combination of delimited sections and fixed-length sections in the same record. Less common — used for legacy formats.

---

## 2. Field Types

| CTL type | XML `type` | Notes |
|---|---|---|
| `string` | `string` | Default for most text fields |
| `integer` | `integer` | 32-bit signed (-2,147,483,648 to 2,147,483,647) |
| `long` | `long` | 64-bit signed — use for IDs and large counts |
| `decimal` | `decimal` | Fixed-point; specify `length` and `scale` |
| `number` | `number` | Floating-point (double precision) |
| `date` | `date` | Date and/or time; always specify `format` and `timeZone` |
| `boolean` | `boolean` | `true` / `false` |
| `byte` | `byte` | Binary data |
| `cbyte` | `cbyte` | Compressed binary |
| list | `string` with `containerType="list"` | List field (see below) |

### Decimal precision
```xml
<Field name="unitPrice" type="decimal" length="10" scale="2"/>
<Field name="paidAmount" type="decimal" scale="2"/>
```
- `length` — total significant digits (optional but recommended)
- `scale` — digits after decimal point

### Date format and timezone
```xml
<Field name="accountCreated" type="date" format="yyyy-MM-dd" timeZone="UTC"/>
<Field name="orderDatetime" type="date" format="yyyy-MM-dd HH:mm:ss" timeZone="UTC"/>
<Field name="timestamp" type="date" format="yyyy-MM-dd HH:mm"/>
```
**Always specify `timeZone`** to avoid DST ambiguity — use `UTC` unless you have a specific reason.

Common formats:
| Format string | Example |
|---|---|
| `yyyy-MM-dd` | `2024-03-15` |
| `yyyy-MM-dd HH:mm:ss` | `2024-03-15 14:30:00` |
| `yyyy-MM-dd HH:mm` | `2024-03-15 14:30` |
| `yyyyMMddHHmmss` | `20240315143000` |
| `dd/MM/yyyy` | `15/03/2024` |
| `MM/dd/yyyy HH:mm:ss` | `03/15/2024 14:30:00` |

---

## 3. Special Field Attributes

### `label` — human-readable display name
```xml
<Field name="productName" type="string" label="Product name"/>
<Field name="unitPrice" type="decimal" label="Unit price"/>
```
Shown in Designer column headers. Doesn't affect data processing.

### `eofAsDelimiter` — last field on a line
```xml
<Field name="isActive" type="boolean" eofAsDelimiter="true"/>
```
Marks the last field in a record — the field value ends at end-of-line, not at a delimiter. Use on the last `<Field>` element when the last field has no trailing delimiter.

### `auto_filling` — system-populated fields
```xml
<Field name="inputFileURL" type="string" auto_filling="source_name"/>
<Field name="inutFileRowNo" type="long" auto_filling="source_row_count"/>
```
CloverDX fills these automatically from the reader component:

| Value | Filled with |
|---|---|
| `source_name` | Source file URL/name |
| `source_row_count` | Row number within the source file |
| `global_row_count` | Absolute row number across all files |

Use in error metadata to track which file and row caused a problem.

### `containerType="list"` — list field
```xml
<Field name="value" type="string" containerType="list"/>
```
Field holds a `list[string]`. Used for fields that carry arrays (e.g., StringList.fmt).

### `nullable` — allow null values
By default all fields accept nulls. Set `nullable="false"` to enforce non-null.

### `size` — fixed-length field width
```xml
<Field name="name" type="string" size="11"/>
<Field name="radius" type="decimal" size="6"/>
```
Required for `type="fixed"` records.

---

## 4. Standalone .fmt Files

External metadata files can be shared across many graphs. Defined once, referenced everywhere.

### Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Record type="delimited" fieldDelimiter="\t" recordDelimiter="\n\|\r\n"
        name="Customer" skipSourceRows="1"
        previewAttachmentCharset="UTF-8">
  <Field name="id" type="long"/>
  <Field name="fullName" type="string"/>
  <Field name="email" type="string"/>
  <Field name="accountCreated" type="date" format="yyyy-MM-dd" timeZone="UTC"/>
  <Field name="isActive" type="boolean" eofAsDelimiter="true"/>
</Record>
```

### Real examples from TrainingExamples

**Customer.fmt** — tab-delimited, 11 fields including date with UTC timezone:
```xml
<Record type="delimited" fieldDelimiter="\t" recordDelimiter="\n\|\r\n" name="Customer" skipSourceRows="1">
  <Field name="id" type="long"/>
  <Field name="fullName" type="string"/>
  <Field name="streetAddress" type="string"/>
  <Field name="city" type="string"/>
  <Field name="postalCode" type="string"/>
  <Field name="state" type="string"/>
  <Field name="country" type="string"/>
  <Field name="email" type="string"/>
  <Field name="phone" type="string"/>
  <Field name="accountCreated" type="date" format="yyyy-MM-dd" timeZone="UTC"/>
  <Field name="isActive" type="boolean"/>
</Record>
```

**LineItem.fmt** — pipe-delimited with decimal precision:
```xml
<Record type="delimited" fieldDelimiter="|" recordDelimiter="\n\|\r\n" name="LineItem">
  <Field name="orderId" type="long"/>
  <Field name="orderDatetime" type="date" format="yyyy-MM-dd HH:mm:ss" timeZone="UTC"/>
  <Field name="productCode" type="long"/>
  <Field name="productName" type="string"/>
  <Field name="unitPrice" type="decimal" length="10" scale="2"/>
  <Field name="units" type="decimal" length="10" scale="2"/>
  <Field name="totalPrice" type="decimal" length="10" scale="2"/>
</Record>
```

**LineItemFixLen.fmt** — fixed-length equivalent of above:
```xml
<Record type="fixed" recordDelimiter="\r\n" name="LineItemFixLen">
  <Field name="orderId" type="long" size="10" format="0000000000"/>
  <Field name="orderDatetime" type="date" size="19" format="yyyy-MM-dd HH:mm:ss" timeZone="UTC"/>
  <Field name="productCode" type="long" size="10" format="0000000000"/>
  <Field name="productName" type="string" size="60"/>
  <Field name="unitPrice" type="decimal" size="10" length="10" scale="2"/>
  <Field name="units" type="decimal" size="10" length="10" scale="2"/>
  <Field name="totalPrice" type="decimal" size="10" length="10" scale="2"/>
</Record>
```

**Product.fmt** — with `label`, `quotedStrings`, `quoteChar`:
```xml
<Record type="delimited" fieldDelimiter="|" recordDelimiter="\n\|\r\n"
        name="Product" skipSourceRows="1" quotedStrings="true" quoteChar="&quot;">
  <Field name="productName" type="string" label="Product name"/>
  <Field name="productCode" type="long" label="Product code"/>
  <Field name="unitPrice" type="decimal" label="Unit price"/>
  <Field name="supplierName" type="string" label="Supplier"/>
  <Field name="profitMargin" type="decimal" label="Profit margin"/>
</Record>
```

**StateCode.fmt** — with `previewAttachment` and `eofAsDelimiter`:
```xml
<Record type="delimited" fieldDelimiter="\t" recordDelimiter="\n\|\r\n"
        name="StateCode" skipSourceRows="1" quotedStrings="false" quoteChar="both"
        previewAttachment="${LOOKUP_DIR}/USAStateCodes.txt">
  <Field name="name" type="string"/>
  <Field name="code" type="string"/>
  <Field name="type" type="string" eofAsDelimiter="true"/>
</Record>
```

**StringList.fmt** — list container type:
```xml
<Record type="delimited" fieldDelimiter="|" recordDelimiter="\n\|\r\n" name="StringList">
  <Field name="value" type="string" containerType="list"/>
</Record>
```

---

## 5. Inline Metadata in Graphs

Metadata defined directly inside a `.grf` (or `.jbf`, `.rjob`, `.sgrf`) file. No external file needed.

### Basic inline definition
```xml
<Metadata id="Metadata0">
  <Record type="delimited" fieldDelimiter="|" recordDelimiter="\n\|\r\n" name="Planet">
    <Field name="name" type="string"/>
  </Record>
</Metadata>
```

The `id` attribute (`Metadata0`, `Metadata1`, etc.) is how edges reference this metadata.

### Inline with previewAttachment
```xml
<Metadata id="Metadata0" previewAttachment="${DATAIN_DIR}/Customers.csv" previewAttachmentCharset="UTF-8">
  <Record type="delimited" fieldDelimiter="\t" name="Customer"
          previewAttachment="${DATAIN_DIR}/Customers.csv" previewAttachmentCharset="UTF-8"
          skipSourceRows="1">
    <Field name="id" type="long"/>
    ...
  </Record>
</Metadata>
```
`previewAttachment` links to a data file for Designer's data preview feature — doesn't affect runtime.

### Raw string input pattern (all fields as string)
When reading data that needs parsing in CTL2, declare all fields as `string` first:
```xml
<!-- PaymentsInput — raw strings before parsing in Reformat -->
<Metadata id="Metadata0">
  <Record type="delimited" fieldDelimiter=";" name="PaymentsInput" skipSourceRows="1">
    <Field name="paymentId" type="string"/>
    <Field name="orderId" type="string"/>
    <Field name="customerId" type="string"/>
    <Field name="paymentType" type="string"/>
    <Field name="paidAmount" type="string"/>
    <Field name="paymentDate" type="string"/>
  </Record>
</Metadata>
<!-- OrderPayment — typed output after parsing -->
<Metadata fileURL="${META_DIR}/online-store/OrderPayment.fmt" id="Metadata1"/>
```
Edge0 carries raw strings → Reformat parses → Edge1 carries typed data. (From 05e02)

### Error record metadata pattern
```xml
<Metadata id="Metadata2">
  <Record type="delimited" fieldDelimiter=";" name="PaymentsInputError">
    <Field name="recordNo" type="long"/>
    <Field name="fieldName" type="string"/>
    <Field name="originalData" type="string"/>
    <Field name="errorMessage" type="string"/>
    <Field name="fileURL" type="string"/>
  </Record>
</Metadata>
```
Error records capture: which row failed, which field, what the raw value was, the error message, and the source file URL.

---

## 6. External Metadata Reference in Graphs

Reference a `.fmt` file from inside a graph — no inline definition needed.

```xml
<Metadata fileURL="${META_DIR}/online-store/Customer.fmt" id="Metadata0"/>
<Metadata fileURL="${META_DIR}/online-store/Order.fmt" id="Metadata1"/>
<Metadata fileURL="${META_DIR}/online-store/LineItem.fmt" id="Metadata2"/>
```

The `id` is still local to the graph. The `fileURL` points to the `.fmt` file — use `${META_DIR}` parameter to keep it portable.

**Benefit:** Change the schema in one `.fmt` file → all graphs using it update automatically. Use for shared, stable schemas (customers, orders, products).

---

## 7. Edge Metadata Assignment

Edges carry data between component ports. The `metadata` attribute specifies which metadata describes the records on that edge.

```xml
<Edge id="Edge0"
      fromNode="FLAT_FILE_READER:0" outPort="Port 0 (output)"
      toNode="REFORMAT:0"           inPort="Port 0 (in)"
      metadata="Metadata0"
      guiRouter="Manhattan" guiBendpoints=""/>
```

### When to assign metadata to an edge
- **Always assign** on the first edge out of a reader (defines the record structure)
- **Always assign** when the schema changes (e.g., after a Reformat transforms the record shape)
- **Optional** when schema is unchanged (e.g., after ExtSort, Dedup — same records flow through)
- **Typically omit** on error/log/rejection ports (port 1 of readers with `dataPolicy=controlled`)

### When edges have no metadata attribute
From real graphs:
- Error/rejection paths (logs, parse errors, rejected records)
- Edges after sort/dedup/filter where schema is identical to an upstream edge
- Control/trigger edges with no data payload
- Final output edges where schema is implicit from input

### Edge port reference format
```xml
fromNode="COMPONENT_ID:portNumber"
toNode="COMPONENT_ID:portNumber"
```
Port numbers are 0-based: `READER:0` is output port 0, `REFORMAT:0` is input port 0.

---

## 8. metadataRef — Inheriting Metadata Between Edges

Instead of repeating a metadata ID, an edge can inherit metadata from another edge using `metadataRef`.

```xml
<!-- Edge8 carries output of Dedup — has no explicit metadata -->
<Edge id="Edge8" fromNode="TAKE_TOP_10:0" outPort="Port 0 (unique)" toNode="DO_THE_CONVERSION:0" .../>

<!-- Edge1 inherits metadata from Edge8 using XPath-like reference -->
<Edge id="Edge1" fromNode="DO_THE_CONVERSION:0" outPort="Port 0 (joined records)"
      toNode="WRITE_CUSTOMER_LEADERBOARD:0"
      metadataRef="#//Edge8" .../>
```

`metadataRef="#//Edge8"` means: "use whatever metadata is on Edge8".

**When to use:** When a component (like LookupJoin) doesn't change the schema and you want to propagate metadata without duplicating the definition. Avoids needing a redundant `<Metadata>` block.

---

## 9. Debug Attributes on Edges

Edges can carry debug hints that control Designer data preview and debugging behavior:

```xml
<Edge debugLastRecords="true" debugSampleData="false" ... metadata="Metadata0" .../>
<Edge debugMode="false" .../>
<Edge debugMode="true" .../>
```

| Attribute | Description |
|---|---|
| `debugMode` | `true` = edge is monitored in debug sessions |
| `debugLastRecords` | Record the last N records flowing through |
| `debugSampleData` | Sample random records for profiling |

These are set by Designer automatically when you toggle edge debugging — you don't usually write them by hand.

---

## 10. Real Graph Metadata Patterns

### Single external metadata, one path (08e03 / 09e01)
```xml
<Metadata fileURL="${META_DIR}/online-store/Customer.fmt" id="Metadata0"/>

<Edge id="Edge0" fromNode="CUSTOMERS_INPUT:0" ... metadata="Metadata0" .../>
<Edge id="Edge1" fromNode="CUSTOMERS_INPUT:1" ... outPort="Port 1 (logs)" toNode="TRASH1:0"/>
<!-- Edge1 has no metadata — it's the error/logs port -->
```

### Raw input → parsed output (05e02 - Parse and fix simple payments)
```xml
<Metadata id="Metadata0">  <!-- all strings — raw input -->
  <Record type="delimited" fieldDelimiter=";" name="PaymentsInput" skipSourceRows="1">
    <Field name="paymentId" type="string"/>
    <Field name="paidAmount" type="string"/>
    ...
  </Record>
</Metadata>
<Metadata fileURL="${META_DIR}/online-store/OrderPayment.fmt" id="Metadata1"/>
<!-- Metadata1 has proper types: long, decimal, date -->

<Edge id="Edge0" fromNode="PAYMENTS:0" ... metadata="Metadata0" toNode="PARSE_AND_CONVERT_PAYMENTS:0"/>
<Edge id="Edge1" fromNode="PARSE_AND_CONVERT_PAYMENTS:0" ... metadata="Metadata1" toNode="CLEAN_PAYMENTS:0"/>
```

### Multiple metadata, multi-port reader (11e01 - Parse orders)
```xml
<Metadata fileURL="${META_DIR}/online-store/Order.fmt" id="Metadata0"/>
<Metadata fileURL="${META_DIR}/online-store/Item.fmt" id="Metadata2"/>
<Metadata fileURL="${META_DIR}/online-store/Address.fmt" id="Metadata1"/>

<Edge id="Edge2" fromNode="ORDERS:0" ... metadata="Metadata0" .../> <!-- orders -->
<Edge id="Edge1" fromNode="ORDERS:1" ... metadata="Metadata2" .../> <!-- line items -->
<Edge id="Edge0" fromNode="ORDERS:2" ... metadata="Metadata1" .../> <!-- addresses -->
```
Each output port of the XML_EXTRACT gets its own metadata.

### Mix of external and inline metadata (07e01 - Customer leaderboard)
```xml
<!-- External: reuse stable shared schema -->
<Metadata fileURL="${META_DIR}/online-store/Customer.fmt" id="Metadata0"/>

<!-- Inline: intermediate computation schema, unique to this graph -->
<Metadata id="Metadata1">
  <Record type="delimited" fieldDelimiter="|" name="TotalSpending">
    <Field name="customerId" type="long"/>
    <Field name="paidAmount" type="decimal"/>
  </Record>
</Metadata>

<!-- Inline: output schema with all customer contact fields + totalPaid -->
<Metadata id="Metadata2">
  <Record type="delimited" fieldDelimiter="\t" name="CustomerContact" skipSourceRows="1">
    <Field name="fullName" type="string"/>
    <Field name="email" type="string"/>
    <Field name="phone" type="string"/>
    <Field name="totalPaid" type="decimal"/>
  </Record>
</Metadata>

<!-- Inline: raw input from payments CSV -->
<Metadata id="Metadata3">
  <Record type="delimited" fieldDelimiter=";" name="Payments" skipSourceRows="1">
    <Field name="paymentId" type="integer"/>
    <Field name="orderId" type="string"/>
    <Field name="customerId" type="integer"/>
    <Field name="paymentType" type="string"/>
    <Field name="paidAmount" type="decimal" scale="2"/>
    <Field name="paymentDate" type="string" eofAsDelimiter="true"/>
  </Record>
</Metadata>
```

### Auto-filling fields for traceability (PaymentsReader.sgrf)
```xml
<Metadata id="Metadata0">
  <Record type="delimited" fieldDelimiter=";" name="PaymentsInput" skipSourceRows="1">
    <Field name="paymentId" type="string"/>
    ...
    <Field name="inputFileURL" type="string" auto_filling="source_name"/>
    <Field name="inutFileRowNo" type="long" auto_filling="source_row_count"/>
  </Record>
</Metadata>
```
Reader automatically fills `inputFileURL` and `inutFileRowNo` — no CTL2 needed for source tracking.

### API response metadata with labels (12e02 - Weather forecast)
```xml
<Metadata id="Metadata0">
  <Record type="delimited" fieldDelimiter="\t" name="WeatherMain" recordDelimiter="\r\n">
    <Field name="dt" type="long"/>
    <Field name="date_time" type="date" format="yyyy-MM-dd HH:mm" label="Time"/>
    <Field name="temp" type="decimal" scale="1" label="Temperature"/>
    <Field name="temp_min" type="decimal" scale="1" label="Min temperature"/>
    <Field name="grnd_level" type="decimal" scale="1" label="Ground level pressure"/>
    <Field name="weather_desc" type="string" label="Weather description"/>
    <Field name="cloud_cover" type="number" label="Cloud cover"/>
    <Field name="wind_speed" type="number" label="Wind speed"/>
  </Record>
</Metadata>
```
API response metadata: `number` (double) for sensor readings, `decimal` for financial/precision values. Labels improve readability in Designer.

---

## 11. Metadata Design Guidelines

**Use external .fmt files when:**
- Schema is shared across multiple graphs (Customer, Order, Product)
- Schema is stable and unlikely to change often
- You want a single source of truth for record structure

**Use inline metadata when:**
- Schema is unique to this graph (intermediate computation result)
- Schema is a temporary shape (raw string input before parsing)
- Error record structure specific to this graph's validation logic

**Naming conventions:**
- `.fmt` file names: PascalCase matching the entity (`Customer.fmt`, `OrderPayment.fmt`)
- Inline Record `name`: PascalCase, descriptive (`PaymentsInput`, `TotalSpending`, `CustomerContact`)
- Metadata `id`: sequential (`Metadata0`, `Metadata1`) — assigned automatically by Designer

**Always do:**
- Specify `timeZone="UTC"` on all date fields
- Specify `format` on date fields
- Specify `length` and `scale` on decimal fields where precision matters
- Use `eofAsDelimiter="true"` on the last field of delimited records when there is no trailing delimiter
- Use `skipSourceRows="1"` for files with header rows
- Add `auto_filling="source_name"` in error metadata to track origin file

**Raw-input pattern:**
Read all fields as `string` in input metadata → Reformat validates + parses → typed output metadata. This avoids reader parse errors blocking the whole pipeline — you handle bad data explicitly in CTL2.

**PostgreSQL type mapping — use the correct CloverDX type:**

| PostgreSQL type | CloverDX metadata type |
|---|---|
| `integer`, `serial` | `type="integer"` |
| `bigint`, `bigserial` | **`type="long"`** — NOT integer! |
| `numeric(p,s)` | `type="decimal" length="p" scale="s"` |
| `real`, `double precision` | `type="number"` |
| `varchar`, `text` | `type="string"` |
| `boolean` | `type="boolean"` |
| `timestamp`, `timestamptz` | `type="date" format="yyyy-MM-dd HH:mm:ss"` |
| `date` | `type="date" format="yyyy-MM-dd"` |
| `bytea` | `type="byte"` |

> **⚠️ `bigint`/`bigserial` must be `type="long"`** — using `type="integer"` causes silent
> overflow failures at runtime that only manifest when data is actually returned (empty
> queries return HTTP 200, but queries with data return HTTP 500).

**Inline metadata always needs delimiters — even for DB-only use:**

All `type="delimited"` metadata requires `fieldDelimiter` and `recordDelimiter` on the
`<Record>` element, even when the metadata is used exclusively for DB operations
(`DB_OUTPUT_TABLE`, `DB_INPUT_TABLE`) and no file is ever read or written. This is a
CloverDX engine requirement. Also add `eofAsDelimiter="true"` on the last field.

```xml
<!-- Correct — delimiters present even though this metadata is only used for DB output -->
<Metadata id="META_CUSTOMER_REPORT">
  <Record type="delimited" fieldDelimiter="," recordDelimiter="\n" name="CustomerReport">
    <Field name="id" type="long"/>
    <Field name="name" type="string"/>
    <Field name="total" type="decimal" length="12" scale="2" eofAsDelimiter="true"/>
  </Record>
</Metadata>
```

**Never do:**
- Use generic field names (`field1`, `field2`) — always use business names
- Skip `timeZone` on date fields — leads to DST-related data corruption
- Omit `scale` on decimal fields used in financial calculations
- Use `type="integer"` for PostgreSQL `bigint`/`bigserial` columns
- Omit `fieldDelimiter`/`recordDelimiter` on delimited metadata used for DB components

**Always inspect line endings before setting `recordDelimiter`:**

```bash
od -c yourfile.csv | head -5
# \n only   → Unix LF     → recordDelimiter="\n"
# \r \n     → Windows CRLF → recordDelimiter="\r\n"
# both      → mixed        → recordDelimiter="\n|\r\n"
```

Do not default to `\n|\r\n` for all files — use the exact delimiter that matches the
source. Using `\n|\r\n` on a pure LF file works but is imprecise; using `\n` on a CRLF
file leaves `\r` as a trailing character on every string field.
