# CTL2 String Functions Reference

> Source: [CloverDX 7.3.1 — String Functions](https://doc.cloverdx.com/latest/developer/string-functions-ctl2.html)
> 82 functions total. Most return null for null input unless noted otherwise.

---

## Quick Reference

| Category | Functions |
|----------|-----------|
| **Basic** | `charAt` `codePointAt` `codePointLength` `codePointToChar` `concat` `concatWithSeparator` `length` `substring` `reverse` `left` `right` |
| **Search** | `contains` `startsWith` `endsWith` `indexOf` `lastIndexOf` `countChar` `find` `matches` `matchGroups` |
| **Transform** | `upperCase` `lowerCase` `properCase` `trim` `lpad` `rpad` `replace` `translate` `chop` `normalizeWhitespaces` `removeBlankSpace` `removeDiacritic` `removeNonAscii` `removeNonPrintable` `getAlphanumericChars` `unicodeNormalize` |
| **Split/Join** | `split` `join` `cut` |
| **Validate** | `isAscii` `isBlank` `isDate` `isDecimal` `isEmpty` `isInteger` `isLong` `isNumber` `isUnicodeNormalized` `isUrl` `isValidCodePoint` `validateCreditCard` `validateEmail` `validatePhoneNumber` |
| **URL** | `escapeUrl` `unescapeUrl` `escapeUrlFragment` `unescapeUrlFragment` `getUrlHost` `getUrlPath` `getUrlPort` `getUrlProtocol` `getUrlQuery` `getUrlRef` `getUrlUserInfo` `toProjectUrl` |
| **XML** | `escapeXML` `unescapeXML` |
| **File Path** | `getFileExtension` `getFileName` `getFileNameWithoutExtension` `getFilePath` `normalizePath` |
| **Phonetic** | `editDistance` `metaphone` `soundex` `NYSIIS` |
| **Other** | `getComponentProperty` `formatMessage` `randomString` `randomUUID` `byteAt` |

---

## Basic String Operations

```
string charAt(string arg, integer index)
```
Returns character at index. **Fails** if index out of range, null, or empty input.

```
integer codePointAt(string str, integer index)
```
Unicode code point at position. Fails if null.

```
integer codePointLength(string str)
```
Number of Unicode code points (may differ from `length()` for supplementary chars). Fails if null.

```
string codePointToChar(integer codePoint)
```
Converts code point to character. Fails if null or invalid.

```
string concat(string... args)
```
Concatenates all arguments. **Faster than `+` operator** — use this for multiple strings. Null args become `"null"`.

```
string concatWithSeparator(string separator, string... args)
```
Concatenates with separator between each argument.

```
integer length(string arg)
```
String length. Returns 0 for empty. **Null returns null** (not 0).

```
string substring(string arg, integer from)
string substring(string arg, integer from, integer length)
```
Extract substring. `from` is 0-based. Fails if null or out of bounds.

```
string reverse(string arg)
```
Reverses string. Null input fails.

```
string left(string arg, integer length)
```
First N characters. If length > string length, returns whole string. Null fails.

```
string right(string arg, integer length)
```
Last N characters. Same behavior as `left`.

---

## Search & Match

```
boolean contains(string arg, string search)
```
True if arg contains search substring. Null args fail.

```
boolean startsWith(string arg, string prefix)
boolean endsWith(string arg, string suffix)
```
Prefix/suffix test. Null fails.

```
integer indexOf(string arg, string search)
integer indexOf(string arg, string search, integer from)
```
First occurrence index, **-1 if not found**. Optional start position. Null fails.

```
integer lastIndexOf(string arg, string search)
integer lastIndexOf(string arg, string search, integer from)
```
Last occurrence index, -1 if not found. Null fails.

```
integer countChar(string arg, string search)
```
Count occurrences of search in arg.

```
string find(string arg, string regex)
```
First substring matching regex. **Returns null if no match** (doesn't fail).

```
boolean matches(string arg, string regex)
```
True if **entire** string matches regex. Use `?=` operator for partial match.

```
list[string] matchGroups(string arg, string regex)
```
Returns capture groups from first match. Index 0 = full match, 1+ = groups.

---

## Transformation

```
string upperCase(string arg)      // Null → null
string lowerCase(string arg)      // Null → null
string properCase(string arg)     // Capitalizes first letter of each word. Null → null
string trim(string arg)           // Removes leading/trailing whitespace. Null → null
```

```
string lpad(string arg, string filler, integer length)
string rpad(string arg, string filler, integer length)
```
Pad to target length. Null arg fails.

```
string replace(string arg, string regex, string replacement)
```
Replaces **all** regex matches. Null regex fails. Uses Java regex syntax.

```
string translate(string arg, string from, string to)
```
Character-by-character translation (like Unix `tr`).

```
string chop(string arg)
string chop(string arg, string regexp)
```
Without regex: removes trailing newlines. With regex: removes all matches. Null regex fails.

```
string normalizeWhitespaces(string arg)
```
Replaces whitespace sequences with single space and trims.

```
string removeBlankSpace(string arg)     // Removes ALL whitespace
string removeDiacritic(string arg)      // Removes accents: é→e, ü→u
string removeNonAscii(string arg)       // Removes non-ASCII chars
string removeNonPrintable(string arg)   // Removes non-printable chars
string getAlphanumericChars(string arg) // Returns only [a-zA-Z0-9]
```

```
string unicodeNormalize(string arg, string form)
```
Unicode normalization. Forms: `"NFC"`, `"NFD"`, `"NFKC"`, `"NFKD"`. Since 5.9.

---

## Split & Join

```
list[string] split(string arg, string regex)
```
Splits by regex delimiter. `split("a,b,,c", ",")` → `["a","b","","c"]`.

```
string join(string separator, list[string] args)
```
Joins list with separator. Null elements become `"null"`.

```
list[string] cut(string arg, integer[] lengths)
```
Cuts string into fixed-width pieces. `cut("abcdef", [2,3,1])` → `["ab","cde","f"]`.

---

## Validation & Testing

```
boolean isAscii(string arg)       // Null → false
boolean isBlank(string arg)       // True if null, empty, or only whitespace
boolean isEmpty(string arg)       // True if null or empty (NOT whitespace)
boolean isUrl(string arg)         // Valid URL test
```

```
boolean isDate(string arg, string pattern)
boolean isDate(string arg, string pattern, string locale)
boolean isDate(string arg, string pattern, string locale, string timeZone)
```
Tests if string is valid date in given format. Null → false.

```
boolean isInteger(string arg)     // Valid integer test
boolean isLong(string arg)        // Valid long test
boolean isNumber(string arg)      // Valid double test
boolean isDecimal(string arg)     // Valid decimal test
```

```
boolean isUnicodeNormalized(string arg, string form)  // Since 5.9
boolean isValidCodePoint(integer codePoint)
```

```
boolean validateCreditCard(string arg)   // Luhn algorithm
boolean validateEmail(string arg)        // Email format
boolean validatePhoneNumber(string arg)  // Phone format
```

---

## URL Functions

```
string escapeUrl(string arg)            // URL-encode (application/x-www-form-urlencoded)
string unescapeUrl(string arg)          // URL-decode
string escapeUrlFragment(string arg)    // URI fragment encoding. Since 5.1
string unescapeUrlFragment(string arg)  // URI fragment decoding
```

```
string getUrlHost(string url)           // Extract host
string getUrlPath(string url)           // Extract path
integer getUrlPort(string url)          // Extract port (-1 if not specified)
string getUrlProtocol(string url)       // Extract protocol
string getUrlQuery(string url)          // Extract query string
string getUrlRef(string url)            // Extract fragment/anchor
string getUrlUserInfo(string url)       // Extract user info
string toProjectUrl(string path)        // Convert to project-relative URL
```

---

## XML Functions

```
string escapeXML(string arg)     // Escapes < > & " '
string unescapeXML(string arg)   // Unescapes XML entities
```

---

## File Path Functions

```
string getFileExtension(string path)              // "txt" (no dot)
string getFileName(string path)                   // "file.txt"
string getFileNameWithoutExtension(string path)   // "file"
string getFilePath(string path)                   // "/dir/subdir/"
string normalizePath(string path)                 // Normalize separators
```

---

## Phonetic & Similarity

```
integer editDistance(string a, string b)
integer editDistance(string a, string b, integer strength)
integer editDistance(string a, string b, string locale)
integer editDistance(string a, string b, integer strength, string locale)
```
Levenshtein edit distance. Strength: 1 (primary/base chars) to 4 (identical).

```
string metaphone(string arg)     // Metaphone phonetic code
string soundex(string arg)       // Soundex code
string NYSIIS(string arg)        // NYSIIS phonetic code
```

---

## Other

```
string getComponentProperty(string name)  // Component property value
```

```
string formatMessage(string pattern, variant... args)
```
Java `MessageFormat` formatting: `formatMessage("Hello {0}, you are {1}", name, age)`.

```
string randomString(integer minLength, integer maxLength)  // Random alphanumeric
string randomUUID()                                         // UUID v4
```

```
integer byteAt(byte arg, integer index)  // Byte value at position (0-based). Fails if out of bounds
```
