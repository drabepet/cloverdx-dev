# CTL2 Date Functions Reference

> Source: [CloverDX 7.3.1 — Date Functions](https://doc.cloverdx.com/latest/developer/date-functions-ctl2.html)
> 18 functions. Time units must be **constants**: `year`, `month`, `week`, `day`, `hour`, `minute`, `second`, `millisec`.
> They CANNOT be variables or received via ports.

---

## Quick Reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `createDate` | `date createDate(y, m, d, ...)` | Create date from components |
| `dateAdd` | `date dateAdd(date, long, unit)` | Add/subtract time |
| `dateDiff` | `long dateDiff(later, earlier, unit)` | Difference between dates |
| `extractDate` | `date extractDate(date)` | Remove time, keep date |
| `extractTime` | `date extractTime(date)` | Remove date, keep time |
| `getYear` | `integer getYear(date [,tz])` | Year component |
| `getMonth` | `integer getMonth(date [,tz])` | Month (1-12) |
| `getDay` | `integer getDay(date [,tz])` | Day of month |
| `getHour` | `integer getHour(date [,tz])` | Hour (0-23) |
| `getMinute` | `integer getMinute(date [,tz])` | Minute |
| `getSecond` | `integer getSecond(date [,tz])` | Second |
| `getMillisecond` | `integer getMillisecond(date [,tz])` | Millisecond |
| `getDayOfWeek` | `integer getDayOfWeek(date [,tz])` | Day of week (Mon=1, Sun=7) |
| `randomDate` | `date randomDate(start, end, ...)` | Random date in range |
| `today` | `date today()` | Current date and time |
| `zeroDate` | `date zeroDate()` | 1970-01-01 00:00:00 GMT |
| `trunc` | `date trunc(date)` | Remove time **DEPRECATED** |
| `truncDate` | `date truncDate(date)` | Remove date **DEPRECATED** |

---

## createDate

```ctl
date createDate(integer year, integer month, integer day)
date createDate(integer year, integer month, integer day, string timeZone)
date createDate(integer year, integer month, integer day, integer hour, integer minute, integer second)
date createDate(integer year, integer month, integer day, integer hour, integer minute, integer second, string timeZone)
date createDate(integer year, integer month, integer day, integer hour, integer minute, integer second, integer millisecond)
date createDate(integer year, integer month, integer day, integer hour, integer minute, integer second, integer millisecond, string timeZone)
```
- Month numbered from **1** (not 0)
- Missing time components default to 0; missing timezone uses system default
- **Null parameters cause failure**
- Since 3.5.0

```ctl
createDate(2024, 7, 31)                    // July 31, 2024 00:00 (default TZ)
createDate(2024, 10, 4, "GMT+3")           // Oct 4, 2024 00:00 GMT+3
createDate(2024, 2, 13, 23, 31, 30)        // Feb 13, 2024 23:31:30 (default TZ)
```

---

## dateAdd

```ctl
date dateAdd(date arg, long amount, unit timeunit)
```
- `amount` can be negative (subtract)
- Units: `year`, `month`, `week`, `day`, `hour`, `minute`, `second`, `millisec`
- **Unit must be a constant** — cannot be a variable
- Null arg → failure
- Since 3.0.0

**Critical DST gotcha:**
- `hour`, `minute`, `second`, `millisec` — adds actual elapsed time (DST-aware)
- `day`, `month`, `week`, `year` — flips calendar page, preserves clock time

```ctl
// czDate = 2014-03-30 00:00:00 Europe/Prague (DST switch night)
dateAdd(czDate, 24, hour)  // → 2014-03-31 01:00:00 CEST (only 23 hours in that day!)
dateAdd(czDate, 1, day)    // → 2014-03-31 00:00:00 CEST (preserves clock time)
```

---

## dateDiff

```ctl
long dateDiff(date later, date earlier, unit timeunit)
```
- Returns difference in specified units
- Unit must be a constant
- Null dates → failure
- Since 3.0.0

**DST affects results:**
- `hour`/`minute`/`second`/`millisec` — actual elapsed time (stopwatch)
- `day`/`month`/`year` — calendar difference (may not equal hours/24)

```ctl
// DST switch in London: clocks skip 1:00 → 2:00
// london1 = 2014-03-30 00:15:00 Europe/London
// london2 = 2014-03-30 02:15:00 Europe/London
dateDiff(london2, london1, hour)  // → 1 (only 1 actual hour elapsed!)

// Same wall-clock gap in New York (no DST that day):
// ny1 = 2014-03-30 00:15:00 America/New_York
// ny2 = 2014-03-30 02:15:00 America/New_York
dateDiff(ny2, ny1, hour)          // → 2
```

---

## extractDate / extractTime

```ctl
date extractDate(date arg)   // Removes time → same date at 00:00:00.000
date extractTime(date arg)   // Removes date → 1970-01-01 with same time
```
- Both are **timezone-sensitive** — results depend on system timezone
- Null → failure
- Since 3.0.0
- **Prefer these over deprecated `trunc`/`truncDate`**

---

## Date Component Accessors

All return `null` if arg is null. If timezone null/missing, uses default.

```ctl
integer getYear(date arg)                    // Since 3.5.0
integer getYear(date arg, string timeZone)

integer getMonth(date arg)                   // 1-12 (NOT 0-based!)
integer getMonth(date arg, string timeZone)  // Since 3.5.0

integer getDay(date arg)                     // Day of month
integer getDay(date arg, string timeZone)    // Since 3.5.0

integer getHour(date arg)                    // 24-hour clock (0-23)
integer getHour(date arg, string timeZone)   // Since 3.5.0

integer getMinute(date arg)                  // Since 3.5.0
integer getMinute(date arg, string timeZone)

integer getSecond(date arg)                  // Since 3.5.0
integer getSecond(date arg, string timeZone)

integer getMillisecond(date arg)             // Since 3.5.0
integer getMillisecond(date arg, string timeZone)
```

**Timezone matters!**
```ctl
// d = 2024-01-01 01:05:00 GMT
getYear(d, "GMT+0")   // → 2024
getYear(d, "GMT-3")   // → 2023 (midnight hasn't passed yet in GMT-3!)
getMonth(d, "GMT-3")  // → 12
getDay(d, "GMT-3")    // → 31
```

---

## getDayOfWeek

```ctl
integer getDayOfWeek(date arg)
integer getDayOfWeek(date arg, string timeZone)
```
- Returns: **Monday=1, Sunday=7** (ISO 8601)
- Null → null
- Since CloverDX **6.5**

---

## randomDate

```ctl
date randomDate(date startDate, date endDate)
date randomDate(long startDate, long endDate)
date randomDate(string startDate, string endDate, string format)
date randomDate(string startDate, string endDate, string format, string locale)
date randomDate(string startDate, string endDate, string format, string locale, string timeZone)
```
- Returns random date in range **inclusive** (can return start or end)
- Null dates → failure
- Since 4.1.0

---

## today / zeroDate

```ctl
date today()       // Current date and time. Since 3.0.0
date zeroDate()    // 1970-01-01 00:00:00 GMT. Since 3.0.0
```

---

## trunc / truncDate (DEPRECATED)

```ctl
date trunc(date arg)       // Removes time part
date truncDate(date arg)   // Removes date part (sets to 1970-01-01)
```
- **DEPRECATED** — both **modify the input parameter** AND return a value
- Use `extractDate()` and `extractTime()` instead
- Null → failure
- Since 3.0.0
