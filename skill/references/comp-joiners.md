# CloverDX Joiner Components

> Source: CloverDX 7.3.1 docs + TrainingExamples graphs

---

## Join Key Syntax

All join components use the same key format:
```
$leftField(a)#$rightField(a);$leftField2(a)#$rightField2(a)
```
- `(a)` = ascending, `(d)` = descending
- `#` separates left and right field names
- `;` separates multiple key fields
- When left and right field names are the same: `$field(a)` (no `#` needed)

---

## ExtHashJoin

Hash-based join. Does **not** require sorted input. Loads the entire slave (right) input into a hash table in memory.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `joinKey` | Join fields (left#right format) | `$id(a)#$customerId(a);` |
| `joinType` | `inner` / `leftOuter` / `fullOuter` | `inner` |
| `transform` | CTL2 mapping of joined record | |
| `slaveOverrideKey` | Override slave sort key | |

**Ports:**
- Port 0 = driver (master) — streams through
- Port 1 = slave (lookup) — fully loaded into memory

**Memory impact:** Slave input lives entirely in Worker heap. For large lookups, use ExtMergeJoin instead.

**Example — join customers with payment totals** (07e01 - Customer leaderboard.grf):
```
joinKey: $id(a)#$customerId(a);
joinType: inner
```
```ctl
function integer transform() {
    $out.0.fullName = $in.0.fullName;
    $out.0.email = $in.0.email;
    $out.0.phone = $in.0.phone;
    $out.0.totalPaid = $in.1.paidAmount;   // $in.1 = slave record
    return ALL;
}
```

**When to use:** Slave dataset fits in memory (< a few million records). Driver can be any size.

---

## ExtMergeJoin

Sort-merge join. Both inputs **must be pre-sorted** by join key. Lower memory footprint than hash join.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `joinKey` | Join fields (left#right format) | `$id(a)#$customerId(a);` |
| `joinType` | `inner` / `leftOuter` / `fullOuter` | `inner` |
| `transform` | CTL2 mapping | |

**Both inputs must be sorted — always precede with ExtSort:**
```
ExtSort (id asc) ──→ port 0 ─┐
                              ExtMergeJoin
ExtSort (customerId asc) ──→ port 1 ─┘
```

**Example — merge line items with product catalog** (10e03 - Rollup.grf):
```
joinKey: $productCode(a)#$productCode(a);
joinType: inner
```
```ctl
function integer transform() {
    $out.0.orderDatetime = $in.0.orderDatetime;
    $out.0.yearMonth = date2str($in.0.orderDatetime, "yyyy-MM");
    $out.0.productCode = $in.0.productCode;
    $out.0.supplierName = $in.1.supplierName;
    $out.0.profitMargin = $in.1.profitMargin;
    $out.0.profitMarginCategory = getProfitMarginCategory($in.1.profitMargin);
    return ALL;
}

function string getProfitMarginCategory(decimal profitMargin) {
    if (profitMargin <= 5.0D) return "Low";
    if (profitMargin <= 15.0D) return "Medium";
    return "High";
}
```

**When to use:** Both datasets are large, both already sorted, or memory is constrained.

---

## LookupJoin

Joins a data stream against a lookup table (pre-loaded from file or database). The lookup table stays in memory for fast random access — no sort required.

**Key properties:**
| Property | Description | Example |
|---|---|---|
| `joinKey` | Fields to look up in the lookup table | `baseCurrency;targetCurrency` |
| `lookupTable` | Reference to lookup table definition (`.cfg` file) | `LookupTable0` |
| `leftOuterJoin` | Keep records with no lookup match | `true` |
| `transform` | CTL2 mapping | |

**Example — currency conversion** (07e03 - Customer leaderboard USD to EUR.grf):
```
joinKey: baseCurrency;targetCurrency
lookupTable: LkpExchangeRateByBaseAndTarget
leftOuterJoin: true
```
```ctl
function integer transform() {
    $out.0.* = $in.0.*;
    $out.0.totalPaid = $in.0.totalPaid * $in.1.rate;   // $in.1 = lookup record
    return ALL;
}
```

**Lookup table defined in** `lookup/LkpExchangeRateByBaseAndTarget.cfg` — loaded from CSV at graph start.

**leftOuterJoin=true:** Records with no match in lookup still pass through (useful for reference enrichment where match is optional).

**When to use:** Small-to-medium reference/dimension tables (exchange rates, state codes, product categories). Not suitable for large tables — use ExtHashJoin instead.

---

## ExtXMLWriter (Hierarchical join for XML output)

Not a joiner per se, but joins multiple sorted input streams into a nested XML file.

**Key properties:**
| Property | Description |
|---|---|
| `sortedInput` | `true` (streaming) or `false` (buffers everything) |
| `sortKeys` | Declares expected sort order per port |
| Mapping | XML template with `clover:inPort`, `clover:key`, `clover:parentKey` |

**Nesting pattern** (11e02b - Order payments report - sorted.grf):
```xml
<customers>
  <customer id="$0.id" clover:inPort="0">
    <order id="$1.id" clover:inPort="1" clover:key="customerId" clover:parentKey="id">
      <payment clover:inPort="2" clover:key="orderId" clover:parentKey="id"/>
    </order>
  </customer>
</customers>
```
- `clover:key` = field on child record matching parent
- `clover:parentKey` = field on parent record being matched

**sortedInput="true"** requires all ports sorted — but streams without buffering (memory-efficient).
**sortedInput="false"** buffers entire input — use only for small datasets.

---

## Join Pattern Summary

| Situation | Component | Requirement |
|---|---|---|
| Large driver + small lookup | ExtHashJoin | Slave fits in memory |
| Both large, sort available | ExtMergeJoin | Both sorted on join key |
| Reference data from file/DB | LookupJoin | Lookup table pre-defined |
| Nested XML/JSON output | ExtXMLWriter / JSONWriter | Sorted input (recommended) |
