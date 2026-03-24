# CloverDX Data Service Components

> Source: CloverDX 7.3.1 docs + APIWorkshopSandbox + TrainingExamples .rjob files

Data services expose graphs as REST endpoints. File extension: `.rjob`. Graphs receive HTTP request data on input ports and send responses on output ports.

---

## Core Structure

Every data service graph has this skeleton:
```
[optional: GetJobInput] → [processing graph logic] → [optional output logic]
```
The HTTP endpoint is declared via annotations on the graph's input/output nodes, not as separate components.

**Endpoint declaration** (on the graph node):
```xml
<RequestParameter name="FORMAT" location="url_path" hint="JSON|CSV|XML"/>
<RequestParameter name="ID" location="query"/>
<RequestMethod name="GET"/>
<UrlPath>/myEndpoint/{FORMAT}</UrlPath>
```

---

## GetJobInput

Reads HTTP request parameters and body into the graph. Also validates required parameters.

**Accesses parameters via CTL2:**
```ctl
string id = getParamValue("ID");             // URL path or query param
string body = getRequestBody();              // raw request body
string header = getRequestHeader("Accept");  // HTTP header
string method = getRequestMethod();          // GET, POST, etc.
```

**Raise error on missing required param:**
```ctl
if (id == null || isBlank(id)) {
    raiseError("Required parameter 'ID' is missing");
}
```

---

## Pattern: Simple GET — query and return data

**Example:** `getCustomers.rjob`, `getPayments.rjob`

```
GetJobInput
  → FlatFileReader (reads data file)
  → [optional ExtFilter to apply param-based filtering]
  → [RESTJOB_OUTPUT node with responseFormat]
```

**Filter by URL parameter:**
```ctl
//#CTL2
num2str($in.0.id) == getParamValue("ID")
```

**Dynamic response format** (`getCustomers.rjob`):
```
URL: /getCustomers/{FORMAT}
RequestParameter: name="FORMAT", location="url_path"
RESTJOB_OUTPUT: responseFormat="${FORMAT}"
```
Client calls `/getCustomers/JSON` or `/getCustomers/CSV` — same graph, different serialization.

---

## Pattern: Parameterized GET by ID

**Example:** `getCustomerByID.rjob` (APIWorkshopSandbox)

```
GetJobInput → FlatFileReader → ExtFilter(id == getParamValue("ID")) → output
```

URL path: `/getCustomerByID/{ID}`

---

## Pattern: POST with file upload (multipart form)

**Example:** `uploadFile.rjob`

```
RequestParameter: location="form_data", name="file", type="text_file"
FlatFileReader: fileURL="request:part:file"    ← reads multipart file stream
Reformat: getRequestPartFilename("file")        ← extract original filename
```

**Get original filename:**
```ctl
string fileName = getRequestPartFilename("file");
```

**Auto-fill source filename into metadata:**
```
Metadata field: fileName with auto_filling="source_name"
```

---

## Pattern: File download

**Example:** `downloadFile.rjob`

```
GetJobInput (validate fileName param)
→ RESTJOB_OUTPUT: responseFormat="FILE"
                  fileURL="${DATATMP_DIR}/${fileName}"
                  ContentType="text/csv"
```

URL: `/downloadFile/{fileName}`

The output node streams the file directly — no data processing needed.

---

## Pattern: Conditional response with variant type

**Example:** `variantExample.rjob`

```
GetJobInput
  → Reformat: check mode param, conditionally set fileURL in variant field
  → FlatFileReader: fileURL from variant field
  → Dedup(noDupRecord=10)
  → record2map() conversion → RESTJOB_OUTPUT (JSON variant)
```

**variant type for dynamic structure:**
```ctl
variant result = record2map($in.0);    // convert record to map → serializes as JSON object
$out.0.data = result;
```

---

## Pattern: Trigger a graph run (POST → ExecuteGraph)

**Example:** `14e01 - Marketing Data on Demand.rjob`

```
GetJobInput → ExecuteGraph(marketingGraph.grf, inputMapping from request params)
            → RESTJOB_OUTPUT (status response)
```

The data service acts as a webhook/trigger — receives a POST, fires a graph, returns success/failure.

---

## HTTP Request CTL2 Functions

| Function | Returns |
|---|---|
| `getParamValue("name")` | URL path or query parameter value (alias, works everywhere) |
| `getRequestParameter("name")` | Canonical form — use this inside `GET_JOB_INPUT` mapping blocks |
| `getRequestBody()` | Raw request body string |
| `getRequestHeader("name")` | HTTP header value |
| `getRequestMethod()` | `"GET"`, `"POST"`, etc. |
| `getRequestContentType()` | Content-Type header |
| `getRequestClientIPAddress()` | Client IP |
| `getRequestPartFilename("name")` | Filename from multipart upload |
| `getRequestParameters()` | All parameters as map |
| `getRequestHeaders()` | All headers as map |

## HTTP Response CTL2 Functions

| Function | Purpose |
|---|---|
| `setResponseStatus(200)` | Set HTTP status code |
| `setResponseHeader("name", "value")` | Set response header |
| `setResponseContentType("application/json")` | Set Content-Type |
| `setResponseBody(string)` | Set raw response body |
| `setResponseEncoding("UTF-8")` | Set encoding |

---

## Deploying Data Services

Creating a `.rjob` file is not enough — it must be **published** via the CloverDX Server GUI before it becomes accessible as an HTTP endpoint.

**Publishing steps:**
1. Deploy/save the `.rjob` file to the sandbox (via Designer or file copy)
2. In CloverDX Server web UI: **Data Services → Publish New Job**
3. Select the sandbox, then select the `.rjob` file
4. Click Publish — the endpoint becomes active immediately

**Endpoint URL format:**
```
http://localhost:8083/clover/data-service/<url-path>
```

> **⚠️ No sandbox name in the URL** — the sandbox is selected at publish time; it does
> NOT appear in the endpoint URL. The URL comes entirely from the `<UrlPath>` in the
> `.rjob` file.

```bash
# WRONG — sandbox name is not part of the URL
curl http://localhost:8083/clover/data-service/mySandbox/customers

# CORRECT — URL path is exactly what you put in <UrlPath>
curl -u clover:clover http://localhost:8083/clover/data-service/customers
```

**Execution history logging** — disabled by default per data service. To enable:
Data Services → select the service → Configuration tab → enable "Save job execution record".
Without this, failed runs produce no server-side log.

---

## Server-Side SQL Filtering (preferred over CTL2 ExtFilter)

For `DB_INPUT_TABLE` inside a `.rjob`, URL path/query parameters declared in
`<EndpointSettings>` can be referenced directly in SQL:

```xml
<attr name="sqlQuery"><![CDATA[
SELECT * FROM customers WHERE id = ${customerId}
]]></attr>
```

This pushes filtering to the database — far more efficient than reading all rows and
applying CTL2 `ExtFilter`. Only use this for trusted/validated parameters; for
user-supplied values that could contain injection characters, use CTL2 post-filter instead.

---

## Security Notes

- Passwords in `.rjob` parameters: always use `enc#` prefix for encrypted storage
- OAuth2 token: use `getOAuth2Token("tokenName")` in CTL2
- Never hardcode credentials in graph XML
- CORS must be configured at the server level (CloverDX Server admin)
