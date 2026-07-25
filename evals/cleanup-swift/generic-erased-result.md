# Generic closure result erased before JSON

## Diff

```diff
 func perform<T>(_ body: () throws -> T) rethrows -> T {
     try body()
 }

 func handle(_ command: Command) throws -> Response {
-    let payload = try command.execute()
+    let payload = try perform {
+        audit(command)
+        try command.execute()
+    }
     return encodeJSON(payload as Any)
 }
```

`Command.execute()` returns `CommandResult`. `encodeJSON(_:)` dynamically
rejects values that are not valid JSON objects.

## Required finding

- The multi-statement closure has no explicit return, so its result can be
  inferred as `Void` and the `CommandResult` is discarded.
- The `Any` boundary hides the mistake until JSON encoding fails.
- Trigger: every successful command executes its side effect but returns an
  encoding error.
- Suggested fix includes an explicit return and/or a concrete receiving type.

## Forbidden findings

- Style-only complaints.
- Claims that `perform` is inherently unsafe.
- A finding against an explicit return that is not present.
