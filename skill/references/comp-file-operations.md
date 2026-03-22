# CloverDX File Operations Components

> Source: CloverDX 7.3.1 docs (doc.cloverdx.com/latest/developer/common-of-file-operations.html)

Five components for file system operations: `ListFiles`, `CopyFiles`, `MoveFiles`,
`DeleteFiles`, `CreateFiles`. All support local paths, FTP, SFTP, S3, Azure Blob,
SMB, HDFS, and sandbox URLs.

**Common behaviour:**
- Input port (0) is optional — can be driven by upstream records or run standalone
- Output port (0) = results; output port (1) = errors (both optional)
- `redirectErrorOutput="true"` sends errors to port 0 instead of port 1
- `stopOnFail="false"` + connected error port = continue on failure, capture errors

---

## ListFiles

Discovers files and directories matching a glob pattern. Emits one record per match.
The primary driver for dynamic file-per-graph jobflow patterns.

```xml
<Node id="LIST_INPUT" type="LIST_FILES"
      fileURL="${DATAIN_DIR}/Payments-*.csv"
      guiName="List Payment Files" guiX="24" guiY="100"/>
```

**Key attributes:**
| Attribute | Description | Default |
|---|---|---|
| `fileURL` | Path or glob pattern | required |
| `recursive` | Descend into subdirectories | `false` |

**Output port 0 fields (case-sensitive):**
| Field | Type | Description |
|---|---|---|
| `URL` | string | Full file URL — use this in downstream `jobURL` / `fileURL` mappings |
| `name` | string | Filename only |
| `size` | long | Size in bytes |
| `lastModified` | date | Last modification timestamp |
| `isFile` | boolean | True if regular file |
| `isDirectory` | boolean | True if directory |
| `canRead` | boolean | Read permission |
| `canWrite` | boolean | Write permission |
| `canExecute` | boolean | Execute permission |
| `isHidden` | boolean | Hidden file |
| `result` | boolean | True if listed successfully |
| `errorMessage` | string | Error message if failed |

> **`URL` is uppercase** — a common source of bugs. `$in.0.URL` not `$in.0.url`.

**Jobflow fan-out pattern:**
```xml
<Node id="LIST_FILES0" type="LIST_FILES"
      fileURL="${DATAIN_DIR}/Payments-*.csv" guiX="24" guiY="100"/>
<Node id="EXEC_LOAD" type="EXECUTE_GRAPH"
      jobURL="${GRAPH_DIR}/LoadPaymentsFile.grf"
      executorsNumber="4" guiX="300" guiY="100">
    <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.executionLabel = "Loading: " + $in.0.URL;
    $out.1.fileUrl = $in.0.URL;
    return ALL;
}
    ]]></attr>
</Node>
<Edge id="E0" fromNode="LIST_FILES0:0" toNode="EXEC_LOAD:0"/>
```

---

## DeleteFiles

Deletes files or directories (optionally recursive). No input edges required.

```xml
<!-- Standalone — delete by pattern -->
<Node id="DELETE_INPUT" type="DELETE_FILES"
      fileURL="${DATAIN_DIR}/input/Payments*.csv"
      guiName="Delete Input Files" guiX="500" guiY="100"/>
```

```xml
<!-- Driven by upstream records -->
<Node id="DELETE_PROCESSED" type="DELETE_FILES" guiX="500" guiY="100">
    <attr name="inputMapping"><![CDATA[
//#CTL2
function integer transform() {
    $out.0.fileURL = $in.0.URL;
    return ALL;
}
    ]]></attr>
</Node>
```

**Key attributes:**
| Attribute | Description | Default |
|---|---|---|
| `fileURL` | File or glob pattern to delete | required (or via inputMapping) |
| `recursive` | Delete directories recursively | `false` |
| `redirectErrorOutput` | Errors → port 0 instead of port 1 | `false` |
| `stopOnFail` | Stop on first error | `true` |

**Input mapping fields:** `fileURL` (string), `recursive` (boolean)

**Output port 0 fields:** `fileURL`, `result` (boolean), `errorMessage`, `stackTrace`

---

## MoveFiles

Moves or renames files and directories.

```xml
<!-- Move processed files to archive -->
<Node id="MOVE_TO_ARCHIVE" type="MOVE_FILES"
      sourceURL="${DATAIN_DIR}/Payments.csv"
      targetURL="${DATAIN_DIR}/archive/"
      overwrite="always"
      guiX="500" guiY="100"/>
```

**Key attributes:**
| Attribute | Description | Default |
|---|---|---|
| `sourceURL` | Source file or glob | required (or via inputMapping) |
| `targetURL` | Destination file or directory | required (or via inputMapping) |
| `overwrite` | `always` / `update` / `never` | `always` |
| `makeParentDirs` | Create missing parent directories | `false` |
| `redirectErrorOutput` | Errors → port 0 | `false` |
| `stopOnFail` | Stop on first error | `true` |

> **Target ending with `/`** — treated as a directory; source is moved *into* it.
> Target without `/` — treated as the new filename (rename).

**Input mapping fields:** `sourceURL`, `targetURL`, `overwrite`, `makeParentDirs`

**Output port 0 fields:** `sourceURL`, `targetURL`, `resultURL`, `result`, `errorMessage`, `stackTrace`

---

## CopyFiles

Copies files and directories. Same semantics as MoveFiles but source is preserved.

```xml
<Node id="COPY_TO_BACKUP" type="COPY_FILES"
      sourceURL="${DATAIN_DIR}/Customers.csv"
      targetURL="${BACKUP_DIR}/"
      overwrite="update"
      makeParentDirs="true"
      guiX="500" guiY="100"/>
```

**Key attributes:**
| Attribute | Description | Default |
|---|---|---|
| `sourceURL` | Source file or glob | required (or via inputMapping) |
| `targetURL` | Destination file or directory | required (or via inputMapping) |
| `overwrite` | `always` / `update` / `never` | `always` |
| `recursive` | Copy directories recursively | `false` |
| `makeParentDirs` | Create missing parent directories | `false` |
| `redirectErrorOutput` | Errors → port 0 | `false` |
| `stopOnFail` | Stop on first error | `true` |

**Input mapping fields:** `sourceURL`, `targetURL`, `recursive`, `overwrite`, `makeParentDirs`

**Output port 0 fields:** `sourceURL`, `targetURL`, `resultURL`, `result`, `errorMessage`, `stackTrace`

---

## CreateFiles

Creates files or directories. Also sets `lastModified` timestamps.

```xml
<!-- Create output directory before writing -->
<Node id="CREATE_DIR" type="CREATE_FILES"
      fileURL="${DATAOUT_DIR}/output/"
      makeParentDirs="true"
      guiX="24" guiY="100"/>
```

**Key attributes:**
| Attribute | Description | Default |
|---|---|---|
| `fileURL` | Path to create | required (or via inputMapping) |
| `directory` | Create as directory (or use URL ending with `/`) | `false` |
| `makeParentDirs` | Create missing parent directories | `false` |
| `lastModified` | Set modification timestamp | — |
| `redirectErrorOutput` | Errors → port 0 | `false` |
| `stopOnFail` | Stop on first error | `true` |

**Input mapping fields:** `fileURL`, `directory`, `makeParentDirs`, `modifiedDate`

**Output port 0 fields:** `fileURL`, `result`, `errorMessage`, `stackTrace`

---

## URL Formats

All file operations support the same URL schemes:

| Protocol | Format | Example |
|---|---|---|
| Local | `/path/to/file` | `${DATAIN_DIR}/orders.csv` |
| Glob | `/path/*.csv` | `${DATAIN_DIR}/Payments-*.csv` |
| FTP | `ftp://user:pass@host/path` | `ftp://etl:secret@files.example.com/in/` |
| SFTP | `sftp://user:pass@host/path` | — |
| S3 | `s3://key:secret@s3.amazonaws.com/bucket/path` | — |
| Azure Blob | `az-blob://account:key@account.blob.core.windows.net/container/path` | — |
| SMB v2/v3 | `smb2://domain%3Buser:pass@server/share/path` | — |
| HDFS | `hdfs://CONNECTION_ID/path` | — |
| Sandbox | `sandbox://sandboxCode/path/to/file` | — |
| Archive | `zip:(archive.zip)!inner/file.csv` | — |

**Multiple sources:** separate with `;`
```
${DATAIN_DIR}/file1.csv;${DATAIN_DIR}/file2.csv
```

---

## Common Patterns

### Post-load cleanup: delete input after successful load
```xml
<!-- Phase 0: load -->
<Node id="LOAD" type="DB_OUTPUT_TABLE" .../>
<!-- Phase 1: delete source only after phase 0 succeeds -->
<Node id="CLEANUP" type="DELETE_FILES"
      fileURL="${DATAIN_DIR}/Payments.csv" guiX="24" guiY="100"/>
```

### Archive after load: move to dated subfolder
```xml
<Node id="ARCHIVE" type="MOVE_FILES"
      sourceURL="${DATAIN_DIR}/Payments.csv"
      targetURL="${DATAIN_DIR}/archive/2024-01/"
      makeParentDirs="true" guiX="24" guiY="100"/>
```

### Fan-out with cleanup: list → load → delete each file
```
ListFiles → ExecuteGraph(loadFile.grf, executorsNumber=4)
          → [in loadFile.grf, phase 1] DeleteFiles(${FILE_URL})
```
Pass `FILE_URL` as a graph parameter to the child graph so it can delete its own input.

### Error capture on delete
```xml
<Node id="DELETE0" type="DELETE_FILES"
      fileURL="${DATAIN_DIR}/input/*.csv"
      redirectErrorOutput="false"
      stopOnFail="false" guiX="24" guiY="100"/>
<!-- Port 0: success records -->
<Node id="LOG_OK" type="FLAT_FILE_WRITER" fileURL="${LOG_DIR}/deleted.log" .../>
<!-- Port 1: error records -->
<Node id="LOG_ERR" type="FLAT_FILE_WRITER" fileURL="${LOG_DIR}/delete_errors.log" .../>
<Edge fromNode="DELETE0:0" toNode="LOG_OK:0"/>
<Edge fromNode="DELETE0:1" toNode="LOG_ERR:0"/>
```
