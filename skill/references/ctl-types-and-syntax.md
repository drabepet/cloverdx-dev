# CTL2 Types, Syntax & Language Reference

> Source: [CloverDX 7.3.1 — Language Reference](https://doc.cloverdx.com/latest/developer/language-reference-ctl2.html)

---

## Program Structure

Every CTL2 program starts with `//#CTL2` (or `//#CTL2:COMPILE` for compiled mode).

```
//#CTL2
ImportStatements      // must come first
VariableDeclarations  // must be declared before use
FunctionDeclarations  // must be declared before use
Statements
Mappings
```

Variables and functions can be interspersed but must always be declared before first use.

---

## Comments

```ctl
// End-of-line comment
integer count = 0; // inline comment

/* Multi-line
   comment */
```

---

## Import

```ctl
import "trans/utils.ctl";           // double quotes (escapes processed)
import 'trans/utils.ctl';           // single quotes (only \' escaped)
import "${FUNCTION_DIR}/utils.ctl"; // graph parameter in path
```

**Metadata import** (since 5.6):
```ctl
import metadata "${META_DIR}/OrderItem.fmt";
import metadata "${META_DIR}/Person.fmt" Customer;  // rename
```
Imported metadata scope is limited to the current CTL script.

---

## Data Types

| Type | Default | Declaration | Key Notes |
|------|---------|-------------|-----------|
| `boolean` | `false` | `boolean b = true;` | |
| `byte` | `null` | `byte b = hex2byte("41");` | No literal syntax — use conversion functions |
| `cbyte` | `null` | `cbyte c;` | Compressed byte |
| `date` | `1970-01-01 00:00:00 GMT` | `date d = str2date("2024-01-15","yyyy-MM-dd");` | Always timezone-aware |
| `decimal` | `0` | `decimal d = 4.56D;` | Fixed-point. Use `D` suffix! Up to 32 significant digits. Default metadata: length=12, scale=2. **Use for money** |
| `integer` | `0` | `integer i = 42;` | 32-bit signed: -2147483648 to 2147483647. **Overflows silently!** Auto-converts to long/double/decimal |
| `long` | `0` | `long l = 257L;` | 64-bit signed. Use `L` suffix. Auto-converts to double/decimal |
| `number` | `0.0` | `double d = 3.14;` | 64-bit floating point. Alias: `double`. **NOT for money** |
| `string` | `""` | `string s = "hello";` | Unicode text |
| `list` | `[]` | `string[] x;` or `list[string] x;` | Indexed from 0. Since 5.6: nested lists/maps. Assigning beyond length fills gaps with null |
| `map` | `{}` | `map[string, integer] m;` | Since 5.6: values can be any type; keys must be primitive. Literal: `{"a" -> 1}` |
| `variant` | `null` | `variant v;` | Dynamic typing (since 5.6). Use `typeof`, `cast()`, `getType()`. Since 5.11: supported in records |
| `record` | none | `MetadataName r;` | Structure based on metadata. Indexed by int or string |

### Type Conversion Rules
- `integer` → `long` → `number(double)` → `decimal` (automatic widening)
- `long` → `double` may lose precision
- Use `D` suffix for decimal literals: `123.56D` not `123.56` (avoids double→decimal precision loss)

---

## Literals

| Type | Syntax | Example |
|------|--------|---------|
| integer | `[0-9]+` | `95623` |
| long | `[0-9]+L` | `257L` |
| hex integer | `0x[0-9A-F]+` | `0xA7B0` |
| octal integer | `0[0-7]*` | `0644` |
| double | digits with `.` | `456.123` |
| decimal | digits with `.` + `D` | `123.456D` |
| string (double-quoted) | `"text"` | `"hello\tworld\n"` — escapes: `\n \r \t \\ \" \b` |
| string (single-quoted) | `'text'` | `'hello\tworld'` — only `\'` escaped |
| string (multi-line) | `"""text"""` | `"""no escapes"""` |
| list | `[elements]` | `[10, 16, 31]` or `[]` |
| map | `{key -> value}` | `{"a" -> 1, "b" -> 2}` or `{}` |
| date | `yyyy-MM-dd` | `2024-01-15` |
| datetime | `yyyy-MM-dd HH:mm:ss` | `2024-01-15 18:55:00` |

---

## Variables and Constants

```ctl
// Declaration then assignment
integer a;
a = 27;

// Declaration with assignment
integer b = 32;

// Constants — protected from reassignment (mutations via functions like clear() NOT checked)
const integer MAX = 100;
const string[] LIST = ["a", "b", "c"];
MAX = 11;           // compile error
LIST[0] = "x";      // compile error
clear(LIST);         // NOT checked — succeeds at runtime
```

---

## Operators

### Arithmetic

| Op | Description | Notes |
|----|-------------|-------|
| `+` | Addition / string concat / list concat / map merge | `concat()` is faster than `+` for strings. String must be first operand for auto-conversion: `"val: " + 123` |
| `-` | Subtraction / unary minus | |
| `*` | Multiplication | Auto-conversion between numeric types |
| `/` | Division | Integer division by zero → exception. Double division by zero → `Infinity` |
| `%` | Modulus | Works with floating-point too |
| `++` | Increment | Prefix: modify first. Postfix: use first. Cannot apply to literals, record fields, map/list values |
| `--` | Decrement | Same rules as `++` |

### Relational

| Op | Alternative | Description |
|----|-------------|-------------|
| `>` | `.gt.` | Greater than (numeric, date, string) |
| `>=` | `=>` `.ge.` | Greater or equal |
| `<` | `.lt.` | Less than |
| `<=` | `=<` `.le.` | Less or equal |
| `==` | `.eq.` | Equal (any type) |
| `!=` | `<>` `.ne.` | Not equal |
| `~=` | `.regex.` | Full regex match: `"bookcase" ~= ".*book.*"` → true |
| `?=` | | Contains regex: `"miredo" ?= "redo"` → true |
| `typeof` | | Type test: `value typeof integer` → boolean. Returns false for null |

### Logical

| Op | Alternative | Description |
|----|-------------|-------------|
| `&&` | `and` | Logical AND |
| `\|\|` | `or` | Logical OR |
| `!` | `not` | Logical NOT |

### Assignment

| Op | Description | Notes |
|----|-------------|-------|
| `=` | Assignment | Deep copy for mutable types (list, map, record, date) since 3.3 |
| `+=` | Add-assign | Also: string concat, list concat, map union. If left is null, uses default (0, "", [], {}) |
| `-=` | Subtract-assign | |
| `*=` | Multiply-assign | |
| `/=` | Divide-assign | |
| `%=` | Modulus-assign | |

### Ternary

```ctl
a = condition ? valueIfTrue : valueIfFalse;
a = c < d ? c : d;  // min(c, d)
```

### Null + string — silent data corruption gotcha

CTL2 does **not** throw a NullPointerException when you concatenate null with a string using `+`. Instead it silently coerces null to the string `"null"`:

```ctl
string s = null;
s = s + " suffix";   // s == "null suffix"  ← silent corruption, not an error
```

This differs from `+=` (compound assign), which treats a null left-hand side as an empty string:
```ctl
string s = null;
s += " suffix";      // s == " suffix"  ← null treated as ""
```

And from `concat()`, which also coerces null to `"null"`:
```ctl
concat("a", null, "b")              // → "anullb"
concatWithSeparator(",", "a", null, "b")  // → "a,b"  ← null omitted!
```

**Rule:** always `isnull()`-check nullable string fields before using `+` or `concat()`. The real risk is not a crash — it's `"null"` appearing in your output data.

### Decimal division — precision gotcha

Dividing by a double literal uses floating-point arithmetic even when the result is assigned to a decimal:

```ctl
decimal result = $in.0.amount / 100.0;   // ← uses double arithmetic, may lose precision
decimal result = $in.0.amount / 100.0D;  // ← correct: forces decimal arithmetic
```

Always use the `D` suffix on decimal literals in arithmetic expressions.

### Conditional Fail (interpreted mode only)

```ctl
// Evaluates left to right, uses first success
integer count = getCachedValue() : refreshAndGet() : defaultValue;
```

---

## Control Flow

### if / else
```ctl
if (condition) {
    // ...
} else if (other) {
    // ...
} else {
    // ...
}
```

### switch
```ctl
switch (response) {
    case "yes":
    case "ok":
        a = 1;
        break;       // without break, falls through!
    case "no":
        a = 0;
        break;
    default:
        a = -1;
}
```
Literals must be unique.

### for
```ctl
for (integer i = 0; i < limit; i++) {
    // Initialization, Condition, Iteration — all optional
}
```

### while / do-while
```ctl
while (condition) { }       // may execute 0 times
do { } while (condition);   // executes at least once
```

### foreach
```ctl
// List iteration
foreach (string item : myList) { }

// Map value iteration
map[string, integer] m = {"a" -> 1, "b" -> 2};
foreach (integer val : m) { printLog(info, val); }  // 1, 2
// Use getKeys() for key iteration

// Variant iteration
variant v = [1, "hello", true];
foreach (variant item : v) { printLog(info, item); }
```

### Jump statements
```ctl
break;              // exit loop or switch
continue;           // skip to next iteration
return;             // exit void function
return expression;  // exit function with value
```

---

## Error Handling

### try-catch (since 5.6 — recommended)
```ctl
try {
    c = a / b;
} catch (CTLException ex) {
    printLog(warn, "Error: " + ex.message);
    c = -1;
}
```

**CTLException fields:**
| Field | Type | Description |
|-------|------|-------------|
| `sourceRow` | `integer` | Line number |
| `sourceColumn` | `integer` | Column number |
| `message` | `string` | Innermost error message |
| `cause` | `string` | Exception type (e.g. `java.lang.ArithmeticException`) |
| `stackTrace` | `list[string]` | Call stack |
| `exceptionTrace` | `list[string]` | Exception chain (outer → inner) |

Can be nested. Only one catch block per try (only CTLException type exists).

### OnError Functions (legacy)
For each required function there's an optional `<name>OnError()` counterpart:
`transform()` → `transformOnError()`, `append()` → `appendOnError()`, etc.

---

## Functions

```ctl
function integer add(integer a, integer b) {
    return a + b;
}

function void logMessage(string msg) {
    printLog(info, msg);
}
```

Can contain declarations, statements, and mappings. Can return `void`.

---

## Accessing Records and Fields

### Input/Output ports
```ctl
// By port number + field name
$in.0.firstName
$out.0.fullName = $in.0.firstName + " " + $in.0.lastName;

// By port number + field index (0-based)
$in.0.2

// All fields (wildcard)
$out.0.* = $in.0.*;     // copy by name

// Multiple ports
$out.1.errorMsg = "bad record";

// By metadata name
$customers.firstname

// Single-port shortcut
$fieldName
```

### CTL Records
```ctl
MetadataName myRecord;
myRecord.field1 = "value";
myRecord.* = $in.0.*;           // copy from input
$out.0.* = myRecord.*;          // copy to output
copyByName($out.0, $in.0);     // copy matching field names
copyByPosition($out.0, $in.0); // copy by field order
```

---

## Parameters

```ctl
string dir = "${DATAIN_DIR}";              // resolved at compile time
string dir = getParamValue("DATAIN_DIR");  // resolved at runtime
```

Use `getParamValue()` when parameter name is dynamic. `${...}` syntax resolves automatically in CTL code.

---

## Regular Expressions

Java-based regex (`java.util.regex.Pattern`). Case-sensitive by default.

### Operators
```ctl
"bookcase" ~= ".*book.*"   // true — full match
"bookcase" ?= "book"       // true — contains
```

### Functions
```ctl
matches("text", "regex")           // boolean — full match
find("text", "regex")              // string — first match or null
matchGroups("text", "(\\w+)@(\\w+)") // list[string] — capture groups
```

### Common tokens
| Token | Meaning | Example |
|-------|---------|---------|
| `.` | Any character | `b.t` matches `bat`, `bit` |
| `*` `+` `?` | 0+, 1+, 0-1 repetitions | `colou?r` matches `color`, `colour` |
| `[]` | Character class | `[0-9]`, `[a-zA-Z]`, `[^aeiou]` |
| `{}` | Repetition count | `\d{2,4}` |
| `()` | Grouping | `col(ou|o)r` |
| `\d` `\w` `\s` | Digit, word char, whitespace | |
| `^` `$` | Start/end of string | |
| `\|` | Alternation | `USA\|UK` |

### Flags
- `(?i)` — case-insensitive
- `(?s)` — dotall (`.` matches newlines)
- `(?m)` — multiline (`^`/`$` match line boundaries)
