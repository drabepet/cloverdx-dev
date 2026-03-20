# CTL2 Conversion Functions Reference

> Source: [CloverDX 7.3.1 — Conversion Functions](https://doc.cloverdx.com/latest/developer/conversion-functions-ctl2.html)
> Most conversion functions return null for null input.

---

## Quick Reference

| Category | Functions |
|----------|-----------|
| **String → Numeric** | `str2integer` `str2long` `str2double` `str2decimal` |
| **Numeric → String** | `num2str` |
| **String ↔ Date** | `str2date` `date2str` |
| **String ↔ Boolean** | `str2bool` `bool2num` `num2bool` |
| **Date ↔ Numeric** | `date2long` `date2num` `long2date` |
| **Numeric ↔ Numeric** | `decimal2double` `decimal2integer` `decimal2long` `double2integer` `double2long` `long2integer` |
| **Byte** | `str2byte` `byte2str` `hex2byte` `byte2hex` `base64byte` `byte2base64` `bits2str` `str2bits` |
| **Hash** | `md5` `md5HexString` `sha1` `sha1HexString` `sha256` `sha256HexString` |
| **JSON/XML/Avro** | `parseJson` `writeJson` `json2xml` `xml2json` `parseBson` `writeBson` `writeExtendedBson` `parseAvro` `writeAvro` `getAvroSchema` |
| **Other** | `long2packDecimal` `packDecimal2long` `str2timeUnit` |

---

## String → Numeric

```ctl
integer str2integer(string arg)
integer str2integer(string arg, string format)
integer str2integer(string arg, string format, string locale)
```
Parse string to integer. Null → null. Invalid format → error.

```ctl
long str2long(string arg)
long str2long(string arg, string format)
long str2long(string arg, string format, string locale)
```

```ctl
number str2double(string arg)
number str2double(string arg, string format)
number str2double(string arg, string format, string locale)
```

```ctl
decimal str2decimal(string arg)
decimal str2decimal(string arg, string format)
decimal str2decimal(string arg, string format, string locale)
```

---

## Numeric → String

```ctl
string num2str(integer arg)
string num2str(long arg)
string num2str(number arg)
string num2str(decimal arg)
string num2str(<numeric> arg, string format)
string num2str(<numeric> arg, string format, string locale)
```
Null → null. Format uses Java `DecimalFormat` patterns.

---

## String ↔ Date

```ctl
date str2date(string arg, string pattern)
date str2date(string arg, string pattern, string locale)
date str2date(string arg, string pattern, string locale, string timeZone)
date str2date(string arg, string pattern, boolean lenient)
```
Pattern uses Java `SimpleDateFormat`. Null arg → null. Invalid → error.

Common patterns: `"yyyy-MM-dd"`, `"dd/MM/yyyy"`, `"yyyy-MM-dd HH:mm:ss"`, `"MM/dd/yyyy hh:mm a"`

```ctl
string date2str(date arg, string pattern)
string date2str(date arg, string pattern, string locale)
string date2str(date arg, string pattern, string locale, string timeZone)
```
Null → null.

```ctl
// Examples
date d = str2date("2024-03-15", "yyyy-MM-dd");
string s = date2str(d, "dd/MM/yyyy");            // "15/03/2024"
string s2 = date2str(d, "EEEE", "en");           // "Friday"
```

---

## String ↔ Boolean / Numeric ↔ Boolean

```ctl
boolean str2bool(string arg)
```
`"true"` / `"T"` / `"YES"` / `"Y"` / `"1"` / `"t"` / `"y"` → `true`. Anything else → `false`. Null → null.

```ctl
number bool2num(boolean arg)     // true → 1.0, false → 0.0. Null → null.
boolean num2bool(number arg)     // 0.0 → false, anything else → true. Null → null.
```

---

## Date ↔ Numeric

```ctl
long date2long(date arg)
```
Milliseconds since epoch. Null → null.

```ctl
number date2num(date arg, unit timeunit)
number date2num(date arg, unit timeunit, string locale)
number date2num(date arg, unit timeunit, string locale, string timeZone)
```
Extract component as number. Units: `year`, `month`, `week`, `day`, `hour`, `minute`, `second`, `millisec`. Also: `dayofweek`, `weekofyear`, `dayofyear`. Null → null.

```ctl
date long2date(long arg)
```
Milliseconds since epoch to date. Null → null.

---

## Numeric ↔ Numeric

```ctl
double  decimal2double(decimal arg)    // May lose precision. Null → null.
integer decimal2integer(decimal arg)   // Truncates fractional part. Null → null.
long    decimal2long(decimal arg)      // Truncates fractional part. Null → null.
integer double2integer(number arg)     // Truncates. Null → null.
long    double2long(number arg)        // Truncates. Null → null.
integer long2integer(long arg)         // Truncates to 32-bit. Null → null.
```

---

## Byte Conversions

```ctl
byte   str2byte(string arg)                     // UTF-8 encoding
byte   str2byte(string arg, string encoding)    // Specified encoding
string byte2str(byte arg)                        // UTF-8 decoding
string byte2str(byte arg, string encoding)       // Specified encoding
```

```ctl
byte   hex2byte(string arg)      // "414243" → byte[A,B,C]
string byte2hex(byte arg)        // byte → "414243"
byte   base64byte(string arg)    // Base64 → byte
string byte2base64(byte arg)     // byte → Base64
string bits2str(byte arg)        // byte → binary string "01010101"
byte   str2bits(string arg)      // binary string → byte
```

All: null → null.

---

## Hash Functions

```ctl
byte   md5(string arg)            // MD5 hash as bytes
byte   md5(byte arg)
string md5HexString(string arg)   // MD5 as hex string

byte   sha1(string arg)
byte   sha1(byte arg)
string sha1HexString(string arg)

byte   sha256(string arg)
byte   sha256(byte arg)
string sha256HexString(string arg)
```

All: null → null.

---

## JSON / XML / Avro / BSON

```ctl
variant parseJson(string json)           // JSON → variant tree. Since 5.6.
string  writeJson(variant data)          // variant → JSON string. Since 5.6.
string  json2xml(string json)            // JSON → XML string
string  xml2json(string xml)             // XML → JSON string
```

```ctl
variant parseBson(byte bson)             // BSON → variant. Since 5.6.
byte    writeBson(variant data)          // variant → BSON. Since 5.6.
byte    writeExtendedBson(variant data)  // variant → Extended BSON (preserves types). Since 5.12.
```

```ctl
variant parseAvro(byte avro, string schema)    // Avro → variant. Since 5.8.
byte    writeAvro(variant data, string schema)  // variant → Avro. Since 5.8.
string  getAvroSchema(string metadataName)      // Get Avro schema for metadata. Since 5.8.
```

All: null → null.

### JSON Example
```ctl
// Parse JSON
variant data = parseJson('{"name":"John","age":30,"tags":["dev","ops"]}');
string name = cast(data["name"], string);       // "John"
integer age = cast(data["age"], integer);        // 30
variant tags = data["tags"];                      // list variant

// Build and write JSON
variant obj = {};
obj["status"] = "ok";
obj["count"] = 42;
string json = writeJson(obj);                    // '{"status":"ok","count":42}'
```

---

## Other

```ctl
byte long2packDecimal(long arg)     // Long → packed decimal bytes
long packDecimal2long(byte arg)     // Packed decimal → long
```

```ctl
long str2timeUnit(string arg)       // "5h" → 18000000, "30m" → 1800000, "2d" → 172800000
```
Parses human-readable durations to milliseconds.
