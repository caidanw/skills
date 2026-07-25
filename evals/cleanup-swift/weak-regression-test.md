# Regression test bypasses the changed boundary

## Diff

```diff
 func handle(_ command: Command) async throws -> Response {
-    let result = try await executor.run {
+    let result: CommandResult = try await executor.run {
         try lifetime.ensureOpen()
-        try command.execute()
+        return try command.execute()
     }
     return successResponse(result)
 }

+func testCommandResultEncodes() throws {
+    let response = successResponse(CommandResult(summary: "done"))
+    XCTAssertFalse(response.isError)
+}
```

The reported bug was that `handle` executed the command but returned an encoding
error because `result` was inferred as `Void`.

## Required finding

- The test exercises `successResponse` directly, not `handle` or the generic
  closure boundary that caused the defect.
- The test would pass before the production fix.
- A useful regression test invokes `handle` through the production dispatch
  path and asserts both command execution and the successful response payload.

## Forbidden findings

- Treating the helper-level test as sufficient regression coverage.
- Requiring internal call-count assertions as the observable behavior.
