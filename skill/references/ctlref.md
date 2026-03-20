# CTL2 Language Reference — Overview

> **Source**: [CloverDX 7.3.1 Documentation](https://doc.cloverdx.com/latest/developer/part6.html)
>
> This is the main entry point for CTL2 (CloverDX Transformation Language) reference.
> Detailed content is split across sub-files to save context. **Load only what you need.**

---

## Quick Summary

CTL2 is a statically-typed, C/Java-like language compiled to Java bytecode at graph initialization.
It's used to define transformations, filters, partitions, and other custom logic in CloverDX components.

**Key characteristics:**
- Statically typed with 13 data types (including `variant` for dynamic typing since 5.6)
- Compiles to JVM bytecode — type errors caught at compile time
- C-like syntax: semicolons, braces, familiar control flow
- Built-in I/O via `$in.0.field` / `$out.0.field` port notation
- 250+ built-in functions across string, date, math, conversion, container, and utility categories
- Import system for reusable `.ctl` files and metadata `.fmt` files
- Error handling via try-catch (5.6+) or OnError functions

---

## Reference Files

| File | Content | Load When |
|------|---------|-----------|
| [`ctl-types-and-syntax.md`](ctl-types-and-syntax.md) | Data types, literals, variables, operators, control flow, error handling, record access, regex | Writing or reviewing any CTL2 code — **start here** |
| [`ctl-string-functions.md`](ctl-string-functions.md) | All 82 string functions: manipulation, search, validation, URL, XML, file paths, phonetic | Working with string data, parsing, formatting, validation |
| [`ctl-date-functions.md`](ctl-date-functions.md) | 18 date functions: createDate, dateAdd, dateDiff, get* accessors, today, zeroDate | Date arithmetic, formatting, timezone handling |
| [`ctl-conversion-functions.md`](ctl-conversion-functions.md) | Type conversions (str↔num, str↔date, byte, hash), JSON/XML/Avro parsing | Type conversion, data format transformation, hashing |
| [`ctl-container-functions.md`](ctl-container-functions.md) | List/map operations, record dynamic field access, sequences, mapping introspection, subgraph | Working with collections, dynamic records, sequences |
| [`ctl-math-misc-functions.md`](ctl-math-misc-functions.md) | Math, random, bit ops, null handling, parameters, logging, evalExpression, HTTP/Data Service, lookups | Math calculations, system interaction, Data API endpoints |

---

## Essential Patterns Quick Reference

### Basic Transformation
```ctl
//#CTL2

function integer transform() {
    $out.0.fullName = $in.0.firstName + " " + $in.0.lastName;
    $out.0.age = $in.0.age;
    $out.0.email = lowerCase(trim($in.0.email));
    return ALL;
}
```

### Null-Safe Field Handling
```ctl
// Using nvl (null coalesce)
$out.0.name = nvl($in.0.name, "UNKNOWN");

// Using nvl2 (conditional null)
$out.0.status = nvl2($in.0.email, "HAS_EMAIL", "NO_EMAIL");

// Using ternary
$out.0.label = isnull($in.0.label) ? "default" : $in.0.label;
```

### Date Operations
```ctl
// Format date to string
$out.0.dateStr = date2str($in.0.created, "yyyy-MM-dd");

// Parse string to date
$out.0.dateVal = str2date($in.0.dateStr, "dd/MM/yyyy");

// Date arithmetic
$out.0.nextWeek = dateAdd(today(), 7, day);
$out.0.daysSince = dateDiff(today(), $in.0.startDate, day);
```

### String Parsing
```ctl
// Split and extract
list[string] parts = split($in.0.fullName, "\\s+");
$out.0.firstName = parts[0];
$out.0.lastName = length(parts) > 1 ? parts[1] : "";

// Regex match
if ($in.0.email ~= ".*@company\\.com") {
    $out.0.isInternal = true;
}
```

### Error Handling
```ctl
try {
    $out.0.amount = str2decimal($in.0.rawAmount);
} catch (CTLException e) {
    printLog(warn, "Parse failed: " + e.message);
    $out.0.amount = 0D;
}
```

### Working with JSON (variant)
```ctl
variant data = parseJson($in.0.jsonString);
$out.0.name = cast(data["name"], string);
$out.0.count = cast(data["items"], list, variant).length(data["items"]);
```

### Lookup Table Access
```ctl
string country = lookup("countryLookup").get($in.0.code).name;
if (isnull(country)) {
    $out.0.country = "UNKNOWN";
} else {
    $out.0.country = country;
}
```

### Graph Parameters
```ctl
string inputDir = getParamValue("DATAIN_DIR");
printLog(info, "Processing from: " + inputDir);
```

---

## Data Type Quick Reference

| Type | Default | Example | Key Notes |
|------|---------|---------|-----------|
| `boolean` | `false` | `true` | |
| `byte` | `null` | `hex2byte("41")` | No literal syntax |
| `cbyte` | `null` | | Compressed byte |
| `date` | `1970-01-01 00:00:00 GMT` | `2024-01-15` | Always timezone-aware |
| `decimal` | `0` | `123.45D` | Use for money. Use `D` suffix! |
| `integer` | `0` | `42` | 32-bit, overflows |
| `long` | `0` | `257L` | 64-bit, use `L` suffix |
| `number` | `0.0` | `3.14` | 64-bit double. NOT for money |
| `string` | `""` | `"hello"` | |
| `list` | `[]` | `[1, 2, 3]` | `string[] x;` or `list[string] x;` |
| `map` | `{}` | `{"a" -> 1}` | `map[string, integer] x;` |
| `variant` | `null` | | Dynamic typing (5.6+) |
| `record` | none | `MyMeta r;` | Based on metadata |

---

## Operator Quick Reference

| Category | Operators |
|----------|-----------|
| Arithmetic | `+` `-` `*` `/` `%` `++` `--` |
| Relational | `>` `>=` `==` `<=` `<` `!=` `~=` (regex match) `?=` (regex contains) |
| Logical | `&&` `\|\|` `!` |
| Assignment | `=` `+=` `-=` `*=` `/=` `%=` |
| Type test | `typeof` |
| Ternary | `? :` |
| Conditional fail | `expr1 : expr2 : expr3` (interpreted mode only) |
