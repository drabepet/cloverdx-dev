# CloverDX Transformer Components

> Source: CloverDX 7.3.1 docs + TrainingExamples graphs

---

## Reformat (Map)

The primary record transformation component. Applies CTL2 or Java logic to convert input records to output records. Supports multiple input and output ports.

**Key properties:**
| Property | Description |
|---|---|
| `transform` | Inline CTL2 code |
| `transformURL` | External `.ctl` file reference |

**CTL2 return values:**
- `return ALL;` — send record to all connected output ports
- `return OK;` / `return 0;` — send to port 0
- `return SKIP;` — discard this record
- `return integer N;` — send to port N

**Simple field mapping** (05e01 - Reformat address.grf):
```ctl
function integer transform() {
    $out.0.id = $in.0.id;
    $out.0.name = $in.0.fullName;
    $out.0.addressLine1 = $in.0.streetAddress;
    $out.0.addressLine2 = $in.0.city + ", " + $in.0.state + " " + $in.0.postalCode;
    $out.0.addressLine3 = $in.0.country;
    return ALL;
}
```

**Wildcard copy + override** (16e04 - Payments statistics.grf):
```ctl
function integer transform() {
    $out.0.* = $in.0.*;                          // copy all fields
    $out.0.paymentType = upperCase($in.0.paymentType);  // override one
    return ALL;
}
```

**Skip invalid records** (05e02 - Parse and fix simple payments.grf):
```ctl
function integer transform() {
    if ($in.0.orderId == null) {
        return SKIP;
    }
    // ... transform logic
    return ALL;
}
```

**Multi-format date parsing** (05e02):
```ctl
if (isDate($in.0.paymentDate, "yyyyMMddHHmmss", "en.US", "GMT")) {
    $out.0.paymentDate = extractDate(str2date($in.0.paymentDate, "yyyyMMddHHmmss", "en.US", "GMT"));
} else if (isDate($in.0.paymentDate, "yyyy-MM-dd HH:mm:ss", "en.US", "GMT")) {
    $out.0.paymentDate = extractDate(str2date($in.0.paymentDate, "yyyy-MM-dd HH:mm:ss", "en.US", "GMT"));
} else {
    raiseError("Unknown date format: " + $in.0.paymentDate);
}
```

**Read graph parameters** (07e03):
```ctl
$out.0.baseCurrency = getParamValue("BASE_CURRENCY");
$out.0.targetCurrency = getParamValue("TARGET_CURRENCY");
```

**Hash/anonymize a field** (15e02):
```ctl
$out.0.UID = byte2hex(sha256($in.0.clientIp + $in.0.userAgent));
$out.0.timestamp = date2str($in.0.timestamp, "yyyyMM");
```

**Regex cleanup** (05e02 — strip suffix after dash):
```ctl
string orderIdPrefix = replace($in.0.orderId, "-.*", "");
$out.0.orderId = str2long(orderIdPrefix);
```

---

## ExtFilter

Routes records to port 0 (pass) or port 1 (reject) based on a CTL2 boolean expression. Input is not modified.

**Key properties:**
| Property | Description |
|---|---|
| `filterExpression` | CTL2 expression returning boolean |

**Simple boolean field** (03e01):
```ctl
//#CTL2
$in.0.isActive
```

**Comparison** (05e01):
```ctl
//#CTL2
$in.0.isActive == true
```

**Filter with parameter** (Data service pattern):
```ctl
//#CTL2
num2str($in.0.id) == getParamValue("ID")
```

**Ports:**
- Port 0 = accepted (filter is true)
- Port 1 = rejected (filter is false) — connect to TrashWriter if not needed, but always connect

---

## Normalizer

Expands one input record into multiple output records (wide-to-long). Use for splitting arrays or repeated fields.

**CTL2 interface — three functions:**
- `count()` — returns how many output records to generate
- `transform(integer i)` — called i times with index 0…n-1; populate `$out.0.*`
- `clean()` — reset state between input records (always implement this)

**Example — split comma-separated phones** (10e01 - Data normalization.grf):
```ctl
//#CTL2
string[] phoneNumbers;
clean();

function integer count() {
    phoneNumbers = split($in.0.phone, ",");
    return length(phoneNumbers);
}

function integer transform(integer i) {
    $out.0.customerId = $in.0.id;
    $out.0.order = i;
    $out.0.phone = trim(phoneNumbers[i]);
    return OK;
}

function void clean() {
    clear(phoneNumbers);
}
```

**Gotcha:** `clean()` must reset all global variables — if omitted, state leaks between input groups.

---

## Denormalizer

Merges multiple input records (same group key) into one output record (long-to-wide). **Input MUST be sorted by group key.**

**CTL2 interface — three functions:**
- `append()` — called for each record in the group; accumulate into global variables
- `transform()` — called once per group; write accumulated values to `$out.0.*`
- `clean()` — reset accumulators between groups

**Key property:** `key` — field(s) defining the group boundary (must match sort key)

**Example — aggregate payment stats per customer** (10e02 - Data denormalization.grf):
```ctl
//#CTL2
long currentCustomerId;
map[string, integer] paymentCounts;
map[string, decimal] paymentAmounts;
clean();

function integer append() {
    currentCustomerId = $in.0.customerId;
    paymentCounts[$in.0.paymentType] = paymentCounts[$in.0.paymentType] + 1;
    paymentAmounts[$in.0.paymentType] = paymentAmounts[$in.0.paymentType] + $in.0.paidAmount;
    return OK;
}

function integer transform() {
    $out.0.customerId = currentCustomerId;
    $out.0.cashCount = paymentCounts["CASH"];
    $out.0.cardCount = paymentCounts["CARD"];
    $out.0.cashAmount = paymentAmounts["CASH"];
    $out.0.cardAmount = paymentAmounts["CARD"];
    // calculate preferred payment type
    foreach (string pt : ["CASH", "CARD"]) {
        $out.0.totalPaymentCount += paymentCounts[pt];
    }
    return OK;
}

function void clean() {
    paymentCounts["CASH"] = 0;
    paymentCounts["CARD"] = 0;
    paymentAmounts["CASH"] = 0.0d;
    paymentAmounts["CARD"] = 0.0d;
}
```

---

## Rollup

Like Denormalizer but also emits summary/subtotal rows in addition to group rows. Requires sorted input.

**CTL2 interface:**
- `initGroup(accumulator)` — initialize accumulator for a new group
- `updateGroup(accumulator)` → bool — called for each record; return true to also call `updateTransform()`
- `updateTransform(counter, accumulator)` — emit detail output per record (return SKIP to suppress)
- `finishGroup(accumulator)` → bool — finalize metrics; return true to call `transform()`
- `transform(counter, accumulator)` — emit summary row for the whole group

**Example** (10e03 - Rollup.grf — profit margin by year/supplier with subtotals):
```ctl
function void initGroup(ProfitMarginReport acc) {
    acc.* = $in.0.*;
    acc.totalItemsSold = 0;
    acc.totalAmount = 0.0d;
    acc.netProfit = 0.0d;
}

function boolean updateGroup(ProfitMarginReport acc) {
    acc.totalItemsSold += $in.0.totalItemsSold;
    acc.totalAmount += $in.0.totalAmount;
    acc.netProfit += $in.0.netProfit;
    return true;   // true → also call updateTransform()
}

function integer updateTransform(integer counter, ProfitMarginReport acc) {
    if (counter == 1) return SKIP;   // skip first detail (avoid duplicate)
    $out.0.* = $in.0.*;
    return 0;
}

function boolean finishGroup(ProfitMarginReport acc) {
    acc.profitPercent = decimal2double(round(acc.netProfit / (acc.totalAmount / 100.0d), 2));
    acc.profitMarginCategory = "ALL";   // mark as subtotal row
    return true;
}

function integer transform(integer counter, ProfitMarginReport acc) {
    if (counter == 1) return SKIP;
    $out.0.* = acc.*;
    return 0;
}
```

**Use with Denormalizer:** Feed Denormalizer output into Rollup for detail groups + summary rows.

---

## Aggregate

Groups and aggregates records using a declarative mapping (no CTL2 needed for standard ops).

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `aggregateKey` | Grouping field(s) | `state` / `customerId` |
| `mapping` | Field=function expressions | see below |
| `sorted` | `true` = streaming (sorted input required), `false` = in-memory | `true` |

**Mapping functions:** `count()`, `sum($field)`, `min($field)`, `max($field)`, `avg($field)`, `countunique($field)`, `first($field)`, `last($field)`

**Example — customers per state** (03e02):
```
aggregateKey: state
mapping: $state:=$state; $customerCount:=count(); $oldest:=min($accountCreated); $newest:=max($accountCreated);
sorted: true    ← requires EXT_SORT before this component
```

**Example — sum payments per customer** (07e01):
```
aggregateKey: customerId
mapping: $customerId:=$customerId; $paidAmount:=sum($paidAmount);
```

**Example — count unique visitors** (15e02):
```
aggregateKey: timestamp
mapping: $timestamp:=$timestamp; $visits:=countunique($UID);
sorted: false
```

**sorted=true vs sorted=false:**
- `sorted=true` — streams through data, O(1) memory, requires pre-sorted input
- `sorted=false` — keeps all groups in memory, works on any input order

**Boolean key fields become strings in output** — when aggregating on a boolean field
(e.g., `isActive`), the Aggregate component outputs the key as a string (`"true"` /
`"false"`), not as a boolean. Define the output metadata with the key field as
`type="string"` to avoid type mismatch errors downstream.

**Mapping must not start with a newline after `<![CDATA[`** — a leading newline causes
a parse error. Always write the mapping on the same line as the CDATA open:

```xml
<!-- Correct -->
<attr name="mapping"><![CDATA[$state:=$state;$count:=count();]]></attr>

<!-- Wrong — leading newline causes parse error -->
<attr name="mapping"><![CDATA[
$state:=$state;
$count:=count();
]]></attr>
```

---

## DataGenerator

Generates synthetic records without any input. Used for initializing sequences, creating test data, or emitting a single trigger record.

**Key properties:**
| Property | Description |
|---|---|
| `recordCount` | Number of records to generate |
| `randomSeed` | Seed for reproducible random data |
| `generate` | CTL2 to populate generated records |

> **`generate` not `transform`** — using `<attr name="transform">` produces a
> "No generator specified" warning and generates empty records.

```xml
<Node id="DATA_GEN" type="DATA_GENERATOR" recordCount="1" guiX="24" guiY="100">
    <attr name="generate"><![CDATA[
//#CTL2
function integer generate() {
    $out.0.requestId = getParamValue("ID");
    $out.0.timestamp = today();
    return ALL;
}
    ]]></attr>
</Node>
```

Commonly used in data services to emit a single "start" record or build a response body.
