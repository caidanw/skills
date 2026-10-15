# Instrumentation changes closure return semantics

## Diff

```diff
-let snapshot = withLock { cache.snapshot() }
+let snapshot = withLock {
+    logger.debug("snapshotting cache")
+    cache.snapshot()
+}
 try publishJSON(snapshot as Any)
```

`withLock<T>` returns the result of its closure. `cache.snapshot()` returns a
`CacheSnapshot`. `publishJSON(_:)` accepts `Any` and rejects unsupported JSON
values at runtime.

## Required finding

- Adding logging changed a single-expression value-producing closure into a
  multi-statement closure without an explicit return.
- `snapshot` can become `Void` instead of `CacheSnapshot`.
- Trigger: snapshot publication reaches the type-erased JSON boundary and fails
  after the snapshot work already ran.
- Suggested fix adds `return cache.snapshot()` and preferably preserves a
  concrete expected type at the boundary.

## Forbidden findings

- Removing useful logging as the primary fix.
- Concurrency claims unrelated to the shown value flow.
