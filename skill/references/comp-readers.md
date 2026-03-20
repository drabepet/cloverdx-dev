# CloverDX Reader Components

> Source: CloverDX 7.3.1 docs + TrainingExamples + APIWorkshopSandbox graphs

---

## FlatFileReader (UniversalDataReader)

Reads delimited, fixed-length, or mixed flat files (CSV, TSV, custom separators).

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | File path, supports parameters and zip archives | `${DATAIN_DIR}/Planets.txt` |
| `dataPolicy` | `strict` (fail on error) / `controlled` (route errors to port 1) / `lenient` (skip silently) | `controlled` |
| `charset` | Character encoding | `UTF-8` |
| `skipSourceRows` | Number of header rows to skip | `1` |
| `verbose` | Log parsing details | `true` |

**Ports:** 0 = records, 1 = rejected records (only when `dataPolicy=controlled`)

**Zip archive syntax:** `zip:(${DATAIN_DIR}/Orders.zip)#Orders.csv`
**Wildcard pattern (multiple files):** `${DATAIN_DIR}/Payments-*.csv`
**Read from port (chained):** `port:$0.content:discrete`

**Error handling example** (02e03 - Planets - errors.grf):
- Set `dataPolicy="controlled"` → malformed records go to port 1
- Route port 1 to TrashWriter or FlatFileWriter for error log

---

## DBInputTable

Reads records from a relational database via SQL query.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `dbConnection` | Reference to `.cfg` connection or `clover.properties` entry | `JDBC0` |
| `sqlQuery` | Inline SQL or reference to `.sql` file | `SELECT * FROM customers WHERE active=1` |
| `url` | External SQL file path | `${TRANS_DIR}/sql/query.sql` |
| `fetchSize` | Number of rows fetched per round-trip (tune for performance) | `1000` |
| `incrementalKey` | Field for incremental reads | `updated_at` |

**Connection defined in `.cfg` file** — always reference by ID, never hardcode JDBC strings.

**Example** (08e01 - Database connections.grf):
```
dbConnection: JDBC0
sqlQuery: SELECT id, fullName, email FROM customers
```

**Performance:** Increase `fetchSize` to reduce round-trips. Default is driver-dependent (often 10–100).

---

## XMLReader / JSON_READER (DOM-based)

Parses XML or JSON with XPath/JSONPath-style hierarchical mapping. Produces multiple output ports for nested structures.

**Key properties:**
| Property | Description |
|---|---|
| `fileURL` | Source file or `port:$0.content:discrete` for chained input |
| `charset` | Encoding |
| `implicitMapping` | Auto-map element names to field names |

**Multiple output port mapping** (11e05 - Read orders with DOM.grf):
- Port 0 → Orders (id, customerId, date, itemsCount via `count(items)`)
- Port 1 → Line items (nested under order, `../id` references parent)
- Port 2 → Addresses (nested under order)

**XPath functions available:** `count()`, `../fieldName` (parent traversal), `@attr` (attribute access)

**Reading from HTTP response:**
```
fileURL: port:$0.content:discrete
```
Chain HTTP_CONNECTOR → JSON_READER to parse REST API responses inline.

---

## XML_EXTRACT / JSON_EXTRACT (Schema-based)

Extracts hierarchical data using an XSD schema for validation and mapping. Preferred over DOM reader when XSD exists.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `sourceUri` | File or port reference | `zip:(${DATAIN_DIR}/Orders.zip)#Orders.xml` |
| `schema` | XSD schema file | `${META_DIR}/online-store/Orders.xsd` |

**Field mapping syntax** — uses `xmlFields` with curly-brace notation:
- `{}date` → element named `date`
- `../{}id` → `id` from parent element

**Example** (11e01 - Parse orders.grf):
- Port 0 → Order records (id, customerId, date)
- Port 1 → Line items (`../{}id` references parent order id)
- Port 2 → Addresses

**Reading from port** (12e02 - Weather forecast full.grf):
```
sourceUri: port:$0.content:discrete
schema: ${META_DIR}/weather/weather_json.xsd
```
JSON_EXTRACT with `useParentRecord=true` allows side-by-side field extraction from nested arrays.

---

## SpreadsheetDataReader

Reads Excel files (.xlsx, .xls).

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `fileURL` | Excel file path | `${DATAIN_DIR}/OnlineShopCatalogue.xlsx` |
| `sheetName` / `sheetNumber` | Target sheet | `Sheet1` / `0` |
| `startRow` | First data row (0-based) | `1` (skip header) |
| `mapping` | Auto or explicit column-to-field mapping | |

**Example** (17e01 - Read online shop catalogue.grf):
```
fileURL: ${DATAIN_DIR}/data-generators/OnlineShopCatalogue.xlsx
```
Output fed to SimpleCopy → Dedup to extract unique suppliers from product catalog.

---

## HTTP_CONNECTOR

Makes HTTP/HTTPS requests (GET, POST, PUT, DELETE). Used for REST API consumption.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `url` | Endpoint URL | `https://api.openweathermap.org/data/2.5/forecast` |
| `method` | HTTP method | `GET` / `POST` |
| `addInputFieldsAsParameters` | Pass input record fields as query parameters | `true` |
| `username` / `password` | Basic auth (use encrypted `enc#...` for passwords) | |
| `headerProperties` | Custom HTTP headers | |

**Ports:** 0 = response, 1 = errors (connection failures, timeouts)

**Pattern — API call with query parameters** (12e01 - Sunset and Sunrise Times.grf):
```
url: https://api.sunrisesunset.io/json
addInputFieldsAsParameters: true
```
Input record fields `lat`, `lng` become `?lat=...&lng=...` query string automatically.

**Pattern — authenticated API** (14e03 - Get and parse customers.grf):
```
url: ${URL}
username: ${USERNAME}
password: ${PASSWORD}   ← use enc# prefix for encrypted storage
```

**Pattern — chain with parser:**
```
HTTP_CONNECTOR (port 0) → JSON_EXTRACT
HTTP_CONNECTOR (port 0) → FlatFileReader (port:$0.content:discrete)
```

---

## RESTConnector (6.7+)

Native OpenAPI/Swagger spec integration. Preferred over HTTP_CONNECTOR for documented REST APIs.

**Key properties:**
| Property | Description |
|---|---|
| `apiSpecUrl` | URL to OpenAPI spec (JSON/YAML) |
| `operationId` | Which API operation to call |
| Pagination | Auto-pagination support (offset, cursor, link-header) |
| Response mapping | Auto-maps response schema to output metadata |

**When to use RESTConnector vs HTTP_CONNECTOR:**
- RESTConnector: Public APIs with OpenAPI spec, need auto-pagination or schema mapping
- HTTP_CONNECTOR: Simple calls, private APIs, chaining to JSON_EXTRACT for custom parsing
