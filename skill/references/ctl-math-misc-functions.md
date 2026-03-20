# CTL2 Mathematical, Miscellaneous & Utility Functions Reference

> Source: [CloverDX 7.3.1 Documentation](https://doc.cloverdx.com/latest/developer/mathematical-functions-ctl2.html)

---

## Quick Reference

| Category | Functions |
|----------|-----------|
| **Basic Math** | `abs` `ceil` `floor` `round` `roundHalfToEven` `max` `min` `signum` |
| **Powers/Roots** | `pow` `sqrt` `exp` `log` `log10` `e` `pi` |
| **Trigonometry** | `sin` `cos` `tan` `asin` `acos` `atan` `toDegrees` `toRadians` |
| **Random** | `random` `randomBoolean` `randomInteger` `randomLong` `randomGaussian` `randomDecimal` `setRandomSeed` |
| **Noise** | `addNoise` |
| **Bit Ops** | `bitAnd` `bitOr` `bitXor` `bitNegate` `bitLShift` `bitRShift` `bitIsSet` `bitSet` |
| **Null Handling** | `isnull` `nvl` `nvl2` `iif` `isBlank` |
| **Type System** | `cast` `getType` `typeof` |
| **Parameters** | `getParamValue` `getParamValues` `getRawParamValue` `getRawParamValues` `resolveParams` `getEnvironmentVariables` `getJavaProperties` |
| **Logging** | `printLog` `printErr` `raiseError` |
| **Dynamic Eval** | `evalExpression` |
| **OAuth2** | `getOAuth2Token` |
| **Utility** | `currentTimeMillis` `sleep` `hashCode` `parseProperties` `toAbsolutePath` |
| **HTTP/Data Service** | `getRequest*` `setResponse*` `addResponseHeader` `containsResponseHeader` |
| **Lookup** | `lookup(name).get` `.next` `.count` `.put` |

---

## Mathematical Functions

### Basic Math
```ctl
integer|long|number|decimal abs(arg)
```
Absolute value. **Gotcha:** `abs(-2147483648)` returns `-2147483648` (MIN_INTEGER wraps). Null → error.

```ctl
number ceil(number arg)                       // Round up
number floor(number arg)                      // Round down
integer|long round(number arg)                // Half-up rounding
integer|long roundHalfToEven(number arg)      // Banker's rounding
number|decimal max(arg1, arg2)                // Larger value
number|decimal min(arg1, arg2)                // Smaller value
number signum(number arg)                     // Returns -1.0, 0.0, or 1.0
```
All work with integer, long, number, decimal overloads. Null → error.

### Powers & Roots
```ctl
number pow(number base, number exponent)      // base^exponent
number sqrt(number arg)                       // Square root
number exp(number arg)                        // e^arg
number log(number arg)                        // Natural log (ln)
number log10(number arg)                      // Base-10 log
number e()                                    // Euler's number 2.71828...
number pi()                                   // Pi 3.14159...
```

### Trigonometry
```ctl
number sin(number|decimal arg)     // Sine (radians)
number cos(number|decimal arg)     // Cosine
number tan(number|decimal arg)     // Tangent
number asin(number|decimal arg)    // Arc sine
number acos(number|decimal arg)    // Arc cosine. Returns null if |arg| > 1
number atan(number|decimal arg)    // Arc tangent
number toDegrees(number radians)   // Radians → degrees
number toRadians(number degrees)   // Degrees → radians
```

### Random Numbers
```ctl
number  random()                                        // [0.0, 1.0)
boolean randomBoolean()
integer randomInteger()                                  // Full range
integer randomInteger(integer min, integer max)          // [min, max]
long    randomLong()
long    randomLong(long min, long max)
number  randomGaussian()                                 // Mean=0, stddev=1
decimal randomDecimal()                                  // [0, 1)
decimal randomDecimal(decimal min, decimal max)
void    setRandomSeed(long seed)                         // Reproducible results
```

### Noise
```ctl
integer|long|number|decimal addNoise(value, noise)
```
Adds random noise in range [-noise, +noise].

### Bit Operations
```ctl
long    bitAnd(long a, long b)            // AND
long    bitOr(long a, long b)             // OR
long    bitXor(long a, long b)            // XOR
long    bitNegate(long a)                 // NOT
long    bitLShift(long a, long b)         // Left shift
long    bitRShift(long a, long b)         // Right shift (arithmetic)
boolean bitIsSet(long a, integer bit)     // Test bit
long    bitSet(long a, integer bit)       // Set bit
```

---

## Null Handling

```ctl
boolean isnull(<any> arg)
```
True if null. **Gotcha:** respects metadata "Null value" property — if field's Null value is `"N/A"`, `isnull(field)` returns true when field contains `"N/A"`.

```ctl
<any> nvl(<any> arg, <any> default)
```
Returns arg if not null, else default. Both must be same type.

```ctl
<any> nvl2(<any> arg, <any> ifNotNull, <any> ifNull)
```
Returns 2nd arg if 1st non-null, else 3rd.

```ctl
<any> iif(boolean cond, <any> ifTrue, <any> ifFalse)
```
Inline if. **Null condition → error!**

```ctl
boolean isBlank(<any> arg)
```
- String: true if null, empty, or only whitespace
- Container (list, map, byte, variant): true if null or empty
- Primitive (integer, long, etc.): true if null
- Record: true if 0 fields
- Since 6.5 for non-string types

---

## Type System (variant)

```ctl
<type> cast(variant value, <type>, <subtype...>)
```
Cast variant to specific type. Null → null. Wrong type → error. **Does NOT check element types of lists/maps!** Since 5.6.

```ctl
string getType(variant arg)
```
Returns runtime type as string: `"string"`, `"integer"`, `"list"`, `"map"`, `"null"`. Since 5.6.

```ctl
boolean <value> typeof <type>
```
Operator (not function). Tests runtime type. **Returns false for null.** Since 5.6.

```ctl
// Example
variant v = parseJson(jsonString);
if (v typeof map) {
    string name = cast(v["name"], string);
} else if (v typeof list) {
    integer count = length(v);
}
```

---

## Parameters & Environment

```ctl
string getParamValue(string name)
```
Resolved graph parameter value. Null for non-existent. **Decrypts secure params — cache for performance!**

```ctl
map[string,string] getParamValues()           // All parameters (resolved)
string getRawParamValue(string name)           // Unresolved (refs not expanded, secure not decrypted)
map[string,string] getRawParamValues()         // All parameters (unresolved)
map[string,string] getEnvironmentVariables()   // System env vars (case-sensitive keys!)
map[string,string] getJavaProperties()         // JVM system properties
```

```ctl
string resolveParams(string text)
string resolveParams(string text, boolean resolveSpecialChars)
```
Resolves `${PARAM}` references in text. Only needed for dynamically constructed strings — `${...}` in CTL code resolves automatically at compile time.

---

## Logging & Errors

```ctl
void printLog(level loglevel, <any> message)
void printLog(level loglevel, string logger, <any> message)
```
Log levels: `debug`, `info`, `warn`, `error`, `fatal`. **Level MUST be a constant!** Custom logger since 6.4.

```ctl
void printErr(<any> message)
void printErr(<any> message, boolean printLocation)
```
Logs with error level. `printLocation=true` appends `(on line: L col: C)`.

```ctl
void raiseError(string message)
```
**Aborts graph execution** with error.

---

## Dynamic Evaluation

```ctl
variant evalExpression(string expr)
```
Evaluate CTL expression at runtime. Returns variant. Since 6.1.
- No statements allowed (no `for`, `if`, etc.) — expressions only
- Can call imported functions
- **Always use try-catch!**

```ctl
try {
    variant result = evalExpression(getParamValue("USER_FORMULA"));
    $out.0.value = cast(result, decimal);
} catch (CTLException e) {
    printLog(warn, "Invalid expression: " + e.message);
}
```

---

## OAuth2

```ctl
string getOAuth2Token(string connectionName)
string getOAuth2Token(string connectionName, boolean forceRefresh)
```
Get access token from linked OAuth2 connection. `forceRefresh=true` gets new token (slower but maximum validity). Since 5.12.

---

## Utility

```ctl
long currentTimeMillis()                       // Epoch millis. Since 6.4.
void sleep(long millis)                        // Pause execution
integer hashCode(<any> arg)                    // Java hashCode
map[string,string] parseProperties(string s)   // Parse key=value text to map. Since 4.1.
string toAbsolutePath(string path)             // Resolve to absolute OS path. Fails on Server!
```

---

## Data Service HTTP Functions

For use in **Data API (REST endpoint) graphs only**.

### Request
```ctl
string getRequestMethod()                              // GET, POST, etc.
string getRequestBody()                                // Request body
string getRequestContentType()                         // Content-Type header
string getRequestEncoding()                            // Character encoding
string getRequestClientIPAddress()                     // Client IP
string getRequestHeader(string name)                   // Specific header
list[string] getRequestHeaderNames()                   // All header names
map[string,list[string]] getRequestHeaders()           // All headers
string getRequestParameter(string name)                // Query/form parameter
list[string] getRequestParameterNames()                // All parameter names
map[string,list[string]] getRequestParameters()        // All parameters
string getRequestPartFilename(string partName)         // Multipart filename
void setRequestEncoding(string enc)                    // Override request encoding
```

### Response
```ctl
void setResponseBody(string body)                      // Set response body
void setResponseContentType(string contentType)        // Set Content-Type
void setResponseEncoding(string encoding)              // Set encoding
void setResponseHeader(string name, string value)      // Set header (replaces)
void addResponseHeader(string name, string value)      // Add header (appends)
void setResponseStatus(integer code)                   // HTTP status code
boolean containsResponseHeader(string name)            // Check if header set
string getResponseContentType()                        // Get current Content-Type
string getResponseEncoding()                           // Get current encoding
```

### Data Service Example
```ctl
// Simple REST endpoint that returns JSON
string method = getRequestMethod();
if (method == "GET") {
    string id = getRequestParameter("id");
    // ... process request ...
    setResponseContentType("application/json");
    setResponseBody(writeJson(result));
    setResponseStatus(200);
} else {
    setResponseStatus(405);
    setResponseBody("Method not allowed");
}
```

---

## Lookup Table Functions

```ctl
record lookup(name).get(key...)       // Find record by key(s). Null if not found.
record lookup(name).next()            // Next matching record (for duplicate keys)
integer lookup(name).count(key...)    // Count matching records
void lookup(name).put(record)         // Insert record into lookup
```

```ctl
// Example
string country = lookup("countryLookup").get($in.0.code).name;
if (isnull(country)) {
    $out.0.country = "UNKNOWN";
} else {
    $out.0.country = country;
}
```
