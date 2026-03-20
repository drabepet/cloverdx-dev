# CloverDX Writer Components

> Source: CloverDX 7.3.1 docs + TrainingExamples graphs

---

## FlatFileWriter (UniversalDataWriter)

Writes delimited flat files (CSV, TSV, custom separators).

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | Output path or port reference | `${DATAOUT_DIR}/result.csv` |
| `charset` | Encoding | `UTF-8` |
| `append` | Append to existing file | `false` |
| `outputFieldNames` | Write header row | `true` |
| `excludeFields` | Semicolon-separated list of fields to omit | `cloud_cover;isToday` |
| `makeDirs` | Create output directory if missing | `true` |

**Write to port (pass data downstream as string):**
```
fileURL: port:$0.value:discrete
```
Used in 13e01 to pass formatted weather text to EmailSender.

**Exclude fields example** (13e01 - Weather forecast email.grf):
```
outputFieldNames: true
excludeFields: cloud_cover;isToday;dateOnly;temp_min;temp_max
```

---

## DBOutputTable

Writes records to a relational database table. The workhorse for DB loading.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `dbConnection` | Connection reference | `JDBC0` |
| `dbTable` | Target table name | `customers` |
| `cloverFields` / `dbFields` | Field name mapping (when names differ) | |
| `fieldMap` | Inline mapping: `$sourceField:=targetColumn` | `$orderId:=order_id;$qty:=quantity` |
| `batchMode` | Enable batch inserts (much faster) | `true` |
| `batchSize` | Records per batch | `${BATCH_SIZE}` |
| `commit` | Records per commit (controls transaction size) | `${COMMIT_SIZE}` |
| `action` | `INSERT` / `UPDATE` / `INSERT_UPDATE` / `DELETE` | `INSERT` |

**Ports:** 0 = input records, 1 = rejected/error records

**Always parameterize batchSize and commit:**
```
batchSize: ${BATCH_SIZE}
commit: ${COMMIT_SIZE}
```
Default batch size is driver-dependent. For Postgres/MySQL, 1000–10000 is typical.

**Field mapping when column names differ** (08e03 - Load orders.grf):
```
fieldMap: $id:=id;$customer_id:=customer_id;$orderId:=order_id
```

**Get auto-generated IDs back** (08e03 - Load orders.grf):
```
batchMode: false
url: ${TRANS_DIR}/sql/${DATABASE}/order_addresses-insert.sql   ← SQL with RETURNING clause
```
Port 1 outputs auto-generated keys for downstream FK resolution.

**Phase ordering for FK constraints** (08e03):
- Phase 0: Load parent tables (customers, products)
- Phase 1: Load orders (FK → customers)
- Phase 2: Load line_items (FK → orders)

---

## DBExecute

Executes raw SQL (DDL or DML). No data ports — statement-based only.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `dbConnection` | Connection reference | `JDBC0` |
| `sqlQuery` | Inline SQL statement | `DELETE FROM payments;` |
| `url` | External SQL file | `${TRANS_DIR}/sql/${DATABASE}/drop.sql` |
| `sqlStatementDelimiter` | Separator between statements | `${__STATEMENT_DELIMITER}` |
| `printStatements` | Log executed SQL | `true` |
| `enabled` | Conditional execution via parameter | `${__TRUNCATE_TABLE_ENABLED}` |

**Conditional truncation pattern** (09e01, 09e02):
```
Phase 0:
  DBExecute: DELETE FROM payments;
             enabled: ${__TRUNCATE_TABLE_ENABLED}
Phase 1:
  DBOutputTable: INSERT into payments
```
The `enabled` attribute lets you skip truncation without changing the graph.

**Multi-dialect SQL** (08e02 - Recreate database tables.grf):
```
url: ${TRANS_DIR}/sql/${DATABASE}/all_online_store-create.sql
sqlStatementDelimiter: ${__STATEMENT_DELIMITER}
```
`${DATABASE}` selects the correct SQL dialect (mssql/mysql/postgresql/oracle).

---

## JSONWriter

Writes hierarchical nested JSON from multiple input ports.

**Key properties:**
| Property | Description |
|---|---|
| `fileURL` | Output file |
| `charset` | Encoding |
| `makeDirs` | Create missing directories |
| `mapping` | XML-based mapping defining JSON nesting |

**Ports:** Multiple input ports (0=root records, 1=nested child, 2=nested grandchild, ...)

**Hierarchical nesting** (11e04 - Write orders JSON.grf):
```
Port 0: Order records       → root array "orders"
Port 1: Line items          → nested under order (clover:key="orderId" clover:parentKey="id")
Port 2: Addresses           → nested under order (clover:key="orderId" clover:parentKey="id")
```
The `key`/`parentKey` attributes define how child records join to their parent.

---

## StructuredDataWriter (StructureWriter)

Writes text files with separate header, body, and footer sections — each from a different input port.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | Output file | `${DATAOUT_DIR}/productList.txt` |
| `mask` | Template for body rows | `$Product_name\|$Unit_price\n` |
| `header` | Template for header (written once) | `minPrice: $minPrice maxPrice: $maxPrice\n` |
| `footer` | Template for footer (written once) | `count: $count` |
| `makeDirs` | Create dirs | `true` |

**Ports:**
- Port 0 = body rows (written for each record)
- Port 1 = header data (first record used, then written once at top)
- Port 2 = footer data (written once at bottom)

**Example** (11e07 - StructureDataWriter.grf):
```
mask:   $Product_name|$Product_code|$Unit_price|$Supplier|$Margin\n
header: minPrice: $minPrice maxprice: $maxPrice avgPrice: $avgPrice avgMargin: $avgMargin\n
footer: count: $count
```
Header/footer come from aggregate components (Rollup/Denormalizer); body comes from detail records.

---

## EmailSender

Sends email with dynamic subject and body built from input record fields.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `smtpServer` | SMTP server hostname | `mail.example.com` |
| `connSecurity` | `NONE` / `SSL` / `STARTTLS` | `STARTTLS` |
| `message` | Newline-separated From/To/Subject/MessageBody | see below |

**Message format** (13e01 - Weather forecast email.grf):
```
From=weather@cloveretl.com
To=${MESSAGE_TO}
Subject=$emailSubject
MessageBody=$emailBody
```
`$fieldName` interpolates from input record. Use upstream Reformat to build subject/body strings.

**Pattern:** FlatFileWriter (port:$0.value) → build email text → EmailSender

---

## TrashWriter

Discards records. Zero configuration. Use as sink for:
- Error ports you don't want to log
- Unwanted output ports that must be connected

```
<!-- Always connect unused output ports to TrashWriter, not left dangling -->
```
