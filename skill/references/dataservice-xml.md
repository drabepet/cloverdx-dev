# CloverDX Data Service XML Structure

> Source: CloverDX 7.3.1 docs + TrainingExamples (getCustomers.rjob, getCustomerByID.rjob, uploadFile.rjob)

Data services (`.rjob`) expose a CloverDX graph as a REST endpoint. They share the
same `<Graph>` root as `.grf` files but have `nature="restJob"`. The graph receives
the HTTP request via a RESTJOB_INPUT node and sends the response via RESTJOB_OUTPUT.

---

## Root Element

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="rjob01" licenseCode="CAN_USE_COMMUNITY_EDITION"
       name="getCustomers" nature="restJob">
```

**`nature="restJob"`** is the only structural difference from a regular graph root.

---

## `<Global>` Section for Data Services

Data services extend `<Global>` with endpoint configuration and response status codes.

### EndpointSettings

Defines the HTTP endpoint exposed by this data service:

```xml
<EndpointSettings>
    <UrlPath>/customers</UrlPath>
    <RequestMethod>GET</RequestMethod>
</EndpointSettings>
```

For parametrized URLs (path parameters):
```xml
<EndpointSettings>
    <UrlPath>/customers/{id}</UrlPath>
    <RequestMethod>GET</RequestMethod>
    <RequestParameter location="url_path" name="id" type="string" required="true"
                      description="Customer ID to retrieve"/>
</EndpointSettings>
```

For file upload (POST with form data):
```xml
<EndpointSettings>
    <UrlPath>/upload</UrlPath>
    <RequestMethod>POST</RequestMethod>
    <RequestParameter location="form_data" name="file" type="text_file" required="true"
                      description="File to upload"/>
    <RequestParameter location="query" name="notify" type="boolean" required="false"
                      description="Send email notification after upload"/>
</EndpointSettings>
```

**`<RequestParameter>` attributes:**
| Attribute | Description | Values |
|---|---|---|
| `location` | Where the parameter comes from | `url_path`, `query`, `form_data`, `header` |
| `name` | Parameter name | string |
| `type` | Data type | `string`, `integer`, `boolean`, `text_file`, `binary_file` |
| `required` | Whether the request fails without it | `true` / `false` |
| `description` | Shown in auto-generated API docs | string |

### RestJobResponseStatus

Declares the HTTP response codes this endpoint can return:

```xml
<RestJobResponseStatus>
    <JobStatusGroup responseStatus="200">
        <JobStatus statusCode="FINISHED_OK"/>
    </JobStatusGroup>
    <JobStatusGroup responseStatus="400">
        <JobStatus statusCode="ABORTED"/>
    </JobStatusGroup>
    <JobStatusGroup responseStatus="500">
        <JobStatus statusCode="ERROR"/>
    </JobStatusGroup>
</RestJobResponseStatus>
```

Maps CloverDX job status codes to HTTP status codes:
- `FINISHED_OK` → 200
- `ABORTED` → 400 (client error, e.g., bad input)
- `ERROR` → 500 (server/processing error)

---

## RESTJOB_INPUT Node

Receives the HTTP request and makes it available to the graph:

```xml
<Node id="RESTJOB_INPUT0" type="RESTJOB_INPUT" guiX="24" guiY="100"/>
```

For file uploads, the input reads the uploaded content:
```xml
<Node id="RESTJOB_INPUT0" type="RESTJOB_INPUT"
      fileURL="request:part:file"
      guiX="24" guiY="100"/>
```

`fileURL="request:part:file"` — reads the binary/text content of the form field named `file`.

**Query and path parameters** are accessed inside CTL2 using:
```ctl
getParamValue("id")      // URL path param: /customers/{id}
getParamValue("notify")  // Query param: ?notify=true
```

---

## RESTJOB_OUTPUT Node

Sends the HTTP response:

```xml
<!-- JSON array response -->
<Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
      responseFormat="JSON"
      topLevelArray="true"
      metadataName="true"
      guiX="500" guiY="100"/>
```

```xml
<!-- Single JSON object response with explicit content type -->
<Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
      responseFormat="JSON"
      contentType="application/json"
      guiX="500" guiY="100"/>
```

```xml
<!-- Format controlled by a graph parameter -->
<Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
      responseFormat="${FORMAT}"
      guiX="500" guiY="100"/>
```

**Key RESTJOB_OUTPUT attributes:**
| Attribute | Description | Values |
|---|---|---|
| `responseFormat` | Output serialization | `JSON`, `XML`, `CSV`, `${FORMAT}` |
| `topLevelArray` | Wrap records in a JSON array at root level | `true` / `false` |
| `metadataName` | Include record name as JSON object wrapper | `true` / `false` |
| `contentType` | Explicit Content-Type header | e.g., `application/json` |

**`topLevelArray="true"` vs `false`:**
- `true` → `[{...}, {...}]` (array of records)
- `false` → `{...}` (single object — use for single-record responses)

---

## Complete GET List Endpoint (getCustomers.rjob)

Pattern: read all customers from DB, return as JSON array.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="rjob_customers" name="getCustomers" nature="restJob">
    <Global>
        <Metadata fileURL="${META_DIR}/Customers.fmt" id="META_CUSTOMERS"/>
        <Connection dbConfig="${CONN_DIR}/database.cfg" id="CONN_DB" type="JDBC"/>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
            <GraphParameter name="FORMAT" value="JSON"/>
        </GraphParameters>
        <EndpointSettings>
            <UrlPath>/customers</UrlPath>
            <RequestMethod>GET</RequestMethod>
        </EndpointSettings>
        <RestJobResponseStatus>
            <JobStatusGroup responseStatus="200">
                <JobStatus statusCode="FINISHED_OK"/>
            </JobStatusGroup>
            <JobStatusGroup responseStatus="500">
                <JobStatus statusCode="ERROR"/>
            </JobStatusGroup>
        </RestJobResponseStatus>
    </Global>

    <Phase number="0">
        <!-- No RESTJOB_INPUT needed for simple GET with no body -->
        <Node id="READ_CUSTOMERS" type="DB_INPUT_TABLE"
              dbConnection="CONN_DB"
              guiX="24" guiY="100">
            <attr name="sqlQuery"><![CDATA[SELECT id, firstName, lastName, email FROM customers ORDER BY lastName]]></attr>
        </Node>

        <Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
              responseFormat="${FORMAT}"
              topLevelArray="true"
              metadataName="true"
              guiX="350" guiY="100"/>

        <Edge id="E0" fromNode="READ_CUSTOMERS:0" toNode="RESTJOB_OUTPUT0:0"
              metadata="META_CUSTOMERS"/>
    </Phase>
</Graph>
```

---

## Complete GET by ID Endpoint (getCustomerByID.rjob)

Pattern: URL path parameter → filter → return single record.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="rjob_customer_by_id" name="getCustomerByID" nature="restJob">
    <Global>
        <Metadata fileURL="${META_DIR}/Customers.fmt" id="META_CUSTOMERS"/>
        <Connection dbConfig="${CONN_DIR}/database.cfg" id="CONN_DB" type="JDBC"/>
        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
        </GraphParameters>
        <EndpointSettings>
            <UrlPath>/customers/{id}</UrlPath>
            <RequestMethod>GET</RequestMethod>
            <RequestParameter location="url_path" name="id" type="string" required="true"
                              description="Customer ID"/>
        </EndpointSettings>
        <RestJobResponseStatus>
            <JobStatusGroup responseStatus="200">
                <JobStatus statusCode="FINISHED_OK"/>
            </JobStatusGroup>
            <JobStatusGroup responseStatus="400">
                <JobStatus statusCode="ABORTED"/>
            </JobStatusGroup>
            <JobStatusGroup responseStatus="500">
                <JobStatus statusCode="ERROR"/>
            </JobStatusGroup>
        </RestJobResponseStatus>
    </Global>

    <Phase number="0">
        <!-- Read all customers (or use parameterized SQL for efficiency) -->
        <Node id="READ_CUSTOMERS" type="DB_INPUT_TABLE"
              dbConnection="CONN_DB"
              guiX="24" guiY="100">
            <attr name="sqlQuery"><![CDATA[SELECT * FROM customers]]></attr>
        </Node>

        <!-- Filter to the requested customer by URL path param -->
        <Node id="FILTER_BY_ID" type="EXT_FILTER" guiX="250" guiY="100">
            <attr name="filterExpression"><![CDATA[
//#CTL2
num2str($in.0.id) == getParamValue("id")
            ]]></attr>
        </Node>

        <!-- Connect rejected records to Trash (not needed) -->
        <Node id="TRASH_UNMATCHED" type="TRASH" guiX="400" guiY="200"/>

        <!-- Single customer record as JSON object -->
        <Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
              responseFormat="JSON"
              contentType="application/json"
              guiX="500" guiY="100"/>

        <Edge id="E0" fromNode="READ_CUSTOMERS:0" toNode="FILTER_BY_ID:0"
              metadata="META_CUSTOMERS"/>
        <Edge id="E1" fromNode="FILTER_BY_ID:0" toNode="RESTJOB_OUTPUT0:0"
              metadata="META_CUSTOMERS"/>
        <Edge id="E2" fromNode="FILTER_BY_ID:1" toNode="TRASH_UNMATCHED:0"
              metadata="META_CUSTOMERS"/>
    </Phase>
</Graph>
```

**Tip:** For better performance, push the filter into SQL:
```xml
<attr name="sqlQuery"><![CDATA[SELECT * FROM customers WHERE id = ${id}]]></attr>
```
But be careful with SQL injection — only use this with trusted, validated parameters.
Prefer CTL2 filter for user-supplied values or use prepared statements via JDBC.

---

## Complete File Upload Endpoint (uploadFile.rjob)

Pattern: POST with form-data file → save to disk → send confirmation email → respond.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Graph author="clover" created="2023-11-22 12:00:00" guiVersion="5.13.0"
       id="rjob_upload" name="uploadFile" nature="restJob">
    <Global>
        <!-- Stream metadata for binary file transfer -->
        <Metadata id="META_FILE_STREAM">
            <Record name="fileStream" type="fixedlen">
                <Field name="data" type="byte" size="65536"/>
                <Field name="sourceName" type="string" auto_filling="source_name"/>
            </Record>
        </Metadata>
        <!-- Response metadata -->
        <Metadata id="META_RESPONSE">
            <Record name="response" type="delimited">
                <Field name="message" type="string"/>
                <Field name="fileName" type="string"/>
            </Record>
        </Metadata>

        <GraphParameters>
            <GraphParameterFile fileURL="workspace.prm"/>
            <GraphParameter name="UPLOAD_DIR" value="${DATAOUT_DIR}/uploads"/>
        </GraphParameters>

        <!-- Dictionary to pass filename from phase 0 to phase 5 -->
        <Dictionary>
            <Entry id="UPLOADED_FILE_NAME" input="false" output="true" type="string"/>
        </Dictionary>

        <EndpointSettings>
            <UrlPath>/upload</UrlPath>
            <RequestMethod>POST</RequestMethod>
            <RequestParameter location="form_data" name="file" type="text_file"
                              required="true" description="File to upload"/>
        </EndpointSettings>
        <RestJobResponseStatus>
            <JobStatusGroup responseStatus="200">
                <JobStatus statusCode="FINISHED_OK"/>
            </JobStatusGroup>
            <JobStatusGroup responseStatus="400">
                <JobStatus statusCode="ABORTED"/>
            </JobStatusGroup>
            <JobStatusGroup responseStatus="500">
                <JobStatus statusCode="ERROR"/>
            </JobStatusGroup>
        </RestJobResponseStatus>
    </Global>

    <!-- Phase 0: receive and save the uploaded file -->
    <Phase number="0">
        <!-- fileURL="request:part:file" reads the uploaded file bytes -->
        <Node id="RESTJOB_INPUT0" type="RESTJOB_INPUT"
              fileURL="request:part:file"
              guiX="24" guiY="100"/>

        <!-- Write received bytes to disk; ${DATAIN_DIR}/* means use original filename -->
        <Node id="WRITE_FILE" type="FLAT_FILE_WRITER"
              fileURL="${UPLOAD_DIR}/${UPLOADED_FILE_NAME}"
              guiX="250" guiY="100"/>

        <!-- Capture the original filename into Dictionary for use in phase 5 -->
        <Node id="CAPTURE_NAME" type="REFORMAT" guiX="150" guiY="100">
            <attr name="transform"><![CDATA[
//#CTL2
function integer transform() {
    setDictionaryValue("UPLOADED_FILE_NAME", $in.0.sourceName);
    $out.0.* = $in.0.*;
    return ALL;
}
            ]]></attr>
        </Node>

        <Edge id="E0" fromNode="RESTJOB_INPUT0:0" toNode="CAPTURE_NAME:0"
              metadata="META_FILE_STREAM"/>
        <Edge id="E1" fromNode="CAPTURE_NAME:0" toNode="WRITE_FILE:0"
              metadata="META_FILE_STREAM"/>
    </Phase>

    <!-- Phase 5: send confirmation email and HTTP response -->
    <!-- (Phase numbering gap is valid; phases 1-4 unused) -->
    <Phase number="5">
        <!-- DataGenerator emits one trigger record to kick off response -->
        <Node id="GEN_RESPONSE" type="DATA_GENERATOR"
              recordCount="1"
              guiX="24" guiY="200">
            <attr name="transform"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.message = "File uploaded successfully";
    $out.0.fileName = getDictionaryValue("UPLOADED_FILE_NAME");
    return ALL;
}
            ]]></attr>
        </Node>

        <!-- Optional: send notification email -->
        <Node id="SEND_EMAIL" type="EMAIL_SENDER"
              smtpHost="${SMTP_HOST}"
              from="noreply@company.com"
              to="${NOTIFY_EMAIL}"
              subject="File uploaded: ${UPLOADED_FILE_NAME}"
              guiX="250" guiY="200"/>

        <!-- Send HTTP 200 response with upload confirmation -->
        <Node id="RESTJOB_OUTPUT0" type="RESTJOB_OUTPUT"
              responseFormat="JSON"
              contentType="application/json"
              guiX="500" guiY="200"/>

        <Edge id="E2" fromNode="GEN_RESPONSE:0" toNode="SEND_EMAIL:0"
              metadata="META_RESPONSE"/>
        <Edge id="E3" fromNode="SEND_EMAIL:0" toNode="RESTJOB_OUTPUT0:0"
              metadata="META_RESPONSE"/>
    </Phase>
</Graph>
```

---

## CTL2 Functions for Data Services

Inside any CTL2 expression in a `.rjob` file, these HTTP-specific functions are available:

```ctl
// Read URL path parameter (/customers/{id})
string customerId = getParamValue("id");

// Read query string parameter (?format=json)
string format = getParamValue("format");

// Read request header
string authHeader = getRequestHeader("Authorization");

// Set response header
setResponseHeader("X-Request-Id", "12345");

// Access Dictionary for cross-phase data sharing
string fileName = getDictionaryValue("UPLOADED_FILE_NAME");
setDictionaryValue("RECORD_COUNT", num2str(count));
```

`getParamValue()` works for both URL path params and query params — CloverDX merges them.

---

## `auto_filling` Field Attribute for File Uploads

When reading uploaded file content via `RESTJOB_INPUT`, the metadata stream record
can use `auto_filling` to capture metadata about the upload:

```xml
<Field name="sourceName" type="string" auto_filling="source_name"/>
<Field name="sourceSize" type="long" auto_filling="source_size"/>
```

- `source_name` — original filename from the client (`Content-Disposition` header)
- `source_size` — byte size of the uploaded content

These are auto-populated by CloverDX; no CTL2 assignment needed.

---

## Request Parameter Location Reference

| `location` | Where it comes from | Example URL |
|---|---|---|
| `url_path` | Path segment: `/customers/{id}` | `GET /customers/42` |
| `query` | Query string | `GET /customers?active=true` |
| `header` | HTTP request header | `Authorization: Bearer token` |
| `form_data` | Multipart form body | `POST /upload` with file part |

---

## Common Patterns

### Return empty array when no records match:
```xml
<!-- RESTJOB_OUTPUT with topLevelArray=true returns [] automatically if no records flow in -->
<Node id="OUT" type="RESTJOB_OUTPUT" responseFormat="JSON" topLevelArray="true"/>
```

### Return 404 for missing resource:
```ctl
// In a Reformat after filter — check if anything matched
if ($in.0.matchCount == 0) {
    raiseError("Not found");  // triggers ABORTED status → 400 or 404
}
```

### Paginated response with query params:
```ctl
integer pageNum = str2integer(getParamValue("page"));
integer pageSize = str2integer(getParamValue("size"));
integer offset = pageNum * pageSize;
// Then use LIMIT/OFFSET in SQL or skip records in CTL2
```

---

## Gotchas

- **Simple GETs don't need RESTJOB_INPUT** — only needed when you need to read the request body or uploaded file content. Path and query params are always available via `getParamValue()`.
- **Multi-phase data services** — use Dictionary to pass data between phases (e.g., capture filename in phase 0, use in phase 5 for the response). Phase numbering gaps are fine.
- **`topLevelArray="true"` is required for empty results** — without it, zero records produces no output body. With it, zero records produces `[]`.
- **Content-Type must be set explicitly for non-JSON formats** — CloverDX doesn't always infer it. Set `contentType="application/json"` or `contentType="text/csv"` on RESTJOB_OUTPUT.
- **CORS** — must be configured at the CloverDX Server level, not in the `.rjob` file. Edit server settings if cross-origin requests fail.
- **SQL injection risk** — never interpolate `getParamValue()` values directly into SQL strings. Use parameterized queries or CTL2 post-filter (as shown in getCustomerByID example).
- **Phase ordering in data services** — phase 0 runs before phase 5. This is intentional: receive/store in phase 0, then respond in phase 5 after processing completes.
