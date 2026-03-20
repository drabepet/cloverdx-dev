# CTL2 Container, Record, Sequence & Mapping Functions Reference

> Source: [CloverDX 7.3.1 Documentation](https://doc.cloverdx.com/latest/developer/container-functions-ctl2.html)
> Most container functions support **object notation**: `myList.append("x")` = `append(myList, "x")`

---

## Quick Reference

| Category | Functions |
|----------|-----------|
| **List** | `append` `appendAll` `binarySearch` `clear` `containsAll` `copy` `in` `insert` `isEmpty` `length` `poll` `pop` `push` `remove` `reverse` `sort` |
| **Map** | `clear` `containsKey` `containsValue` `findAllValues` `getKeys` `getValues` `in` `isEmpty` `length` `put` `remove` `toMap` |
| **Record** | `compare` `copyByName` `copyByPosition` `get*Value` `set*Value` `getValue` `setValue` `getValueAsString` `getFieldIndex` `getFieldName` `getFieldLabel` `getFieldType` `getFieldProperties` `getRecordProperties` `isNull` `length` `resetRecord` |
| **Mapping** | `getMappedSourceFields` `getMappedTargetFields` `isSourceFieldMapped` `isTargetFieldMapped` |
| **Sequence** | `.current()` `.next()` `.reset()` |
| **Subgraph** | `getSubgraphInputPortsCount` `getSubgraphOutputPortsCount` `isSubgraphInputPortConnected` `isSubgraphOutputPortConnected` |

---

## List Functions

```ctl
<type> append(<type>[] list, <type> element)
```
Appends element to end. Returns the appended element.

```ctl
void appendAll(<type>[] list, <type>[] elements)
```
Appends all elements from second list to first.

```ctl
integer binarySearch(<type>[] list, <type> key)
```
Binary search on **sorted** list. Returns index if found, negative if not. **List MUST be sorted first.**

```ctl
void clear(<type>[] list)
void clear(map[K,V] map)
```
Removes all elements.

```ctl
boolean containsAll(<type>[] list, <type>[] elements)
```
True if list contains all elements from second list.

```ctl
void copy(<type>[] to, <type>[] from)
```
Replaces content of first list with deep copy of second.

```ctl
boolean in(<type> element, <type>[] list)
boolean in(K key, map[K,V] map)
```
True if element exists in list, or key exists in map.

```ctl
void insert(<type>[] list, integer index, <type> element)
void insert(<type>[] list, integer index, <type>[] elements)
```
Inserts at index, shifting existing elements right.

```ctl
boolean isEmpty(<type>[] list)
boolean isEmpty(map[K,V] map)
```
True if empty or null.

```ctl
integer length(<type>[] list)
integer length(map[K,V] map)
integer length(record r)
```
Number of elements/fields.

```ctl
<type> poll(<type>[] list)
```
Removes and returns **first** element (queue). Null if empty.

```ctl
<type> pop(<type>[] list)
```
Removes and returns **last** element (stack). Null if empty.

```ctl
void push(<type>[] list, <type> element)
```
Adds to end (same as append but returns void).

```ctl
<type> remove(<type>[] list, integer index)
V remove(map[K,V] map, K key)
```
Removes by index (list) or key (map). Returns removed value.

```ctl
void reverse(<type>[] list)
```
Reverses in place.

```ctl
void sort(<type>[] list)
```
Sorts ascending. Elements must be comparable.

---

## Map Functions

```ctl
boolean containsKey(map[K,V] map, K key)
boolean containsValue(map[K,V] map, V value)
```

```ctl
list[V] findAllValues(map[K,V] map, K key)
```
All values for key. Standard maps: single-element or empty list.

```ctl
list[K] getKeys(map[K,V] map)      // Also works on variant maps
list[V] getValues(map[K,V] map)
```

```ctl
V put(map[K,V] map, K key, V value)
```
Inserts key-value pair. Returns previous value or null.

```ctl
map[K,V] toMap(list[K] keys, list[V] values)
```
Creates map from two lists of equal length.

---

## Record Functions (Dynamic Field Access)

For accessing fields when name/index is determined at runtime.

### compare
```ctl
integer compare(record r1, integer fieldIdx1, record r2, integer fieldIdx2)
integer compare(record r1, string fieldName1, record r2, string fieldName2)
```
Returns <0, 0, or >0. Fails for list/map/variant fields.

### copyByName / copyByPosition
```ctl
void copyByName(record to, record from)      // Copy matching field names
void copyByPosition(record to, record from)  // Copy by field order
```

### Typed Getters and Setters
```ctl
boolean getBoolValue(record r, integer idx)
boolean getBoolValue(record r, string name)
byte    getByteValue(record r, integer idx | string name)
date    getDateValue(record r, integer idx | string name)
decimal getDecimalValue(record r, integer idx | string name)
integer getIntValue(record r, integer idx | string name)
long    getLongValue(record r, integer idx | string name)
number  getNumValue(record r, integer idx | string name)
string  getStringValue(record r, integer idx | string name)
variant getValue(record r, integer idx | string name)
string  getValueAsString(record r, integer idx | string name)
```

```ctl
void setBoolValue(record r, integer idx | string name, boolean value)
void setByteValue(record r, integer idx | string name, byte value)
void setDateValue(record r, integer idx | string name, date value)
void setDecimalValue(record r, integer idx | string name, decimal value)
void setIntValue(record r, integer idx | string name, integer value)
void setLongValue(record r, integer idx | string name, long value)
void setNumValue(record r, integer idx | string name, number value)
void setStringValue(record r, integer idx | string name, string value)
void setValue(record r, integer idx | string name, variant value)
```

Null record reference → error. Wrong type (non-variant) → error. Since 3.2.0.

### Field Metadata Inspection
```ctl
integer getFieldIndex(record r, string fieldName)
string  getFieldName(record r, integer idx)
string  getFieldLabel(record r, integer idx | string name)
string  getFieldType(record r, integer idx | string name)    // Returns type as string
map[string,string] getFieldProperties(record r, integer idx | string name)
map[string,string] getRecordProperties(record r)
boolean isNull(record r, integer idx | string name)
integer length(record r)                                      // Number of fields
void    resetRecord(record r)                                 // Reset all fields to defaults
```

### Dynamic Field Iteration Example
```ctl
// Iterate all fields of a record and log non-null values
for (integer i = 0; i < length($in.0); i++) {
    if (!isNull($in.0, i)) {
        printLog(info, getFieldName($in.0, i) + " = " + getValueAsString($in.0, i));
    }
}
```

---

## Mapping Functions

For introspecting field mappings at runtime (in Reformat/Map components):

```ctl
list[string] getMappedSourceFields(integer port, string targetField)
list[string] getMappedTargetFields(integer port, string sourceField)
boolean isSourceFieldMapped(integer port, string fieldName)
boolean isTargetFieldMapped(integer port, string fieldName)
```

---

## Sequence Functions

```ctl
// Access sequence by name
<type> sequence(name).current()   // Current value without incrementing
<type> sequence(name).next()      // Increment and return next value
void   sequence(name).reset()     // Reset to initial value
```

```ctl
// Example
integer id = sequence("mySeq").next();
$out.0.id = id;
```

---

## Subgraph Functions

For use inside subgraph components:

```ctl
integer getSubgraphInputPortsCount()
integer getSubgraphOutputPortsCount()
boolean isSubgraphInputPortConnected(integer port)
boolean isSubgraphOutputPortConnected(integer port)
```

Check port connectivity at runtime to handle optional ports.
