# Example ARCHITECTURE.md

This is a complete example for a hypothetical TypeScript API project called "taskflow" --
a task queue service. Use this as a reference for structure, tone, and level of detail.

---

# Architecture

taskflow is a persistent task queue service. Clients submit tasks via HTTP, workers pull
and execute them, and results are stored for retrieval. The system is designed for
at-least-once delivery with configurable retry policies.

## Bird's Eye View

An HTTP request arrives, is validated and parsed into a `Task`, then persisted to the
database. A scheduler polls for pending tasks and assigns them to available workers.
Workers execute the task handler, report success or failure, and the scheduler updates
the task state. Clients can poll for task status and retrieve results.

```
HTTP Request -> API Layer -> Task Store -> Scheduler -> Worker -> Result Store
                                ^                          |
                                |     retry on failure     |
                                +--------------------------+
```

The system keeps all state in PostgreSQL. There is no in-memory queue -- the database
*is* the queue. This simplifies deployment and makes the system crash-safe at the cost
of higher latency for very high-throughput scenarios.

## Code Map

This section describes the high-level structure of the codebase. Pay attention to
**Boundary** and **Invariant** callouts.

### `src/api/`

HTTP API layer. Defines routes, request validation, and response formatting.
Key types: `TaskCreateRequest`, `TaskStatusResponse`.

**Boundary:** This is the primary API boundary. All external interaction goes through
here. The API speaks in DTOs (plain objects) -- no database types or internal domain
types leak through.

**Invariant:** The API layer never directly accesses the database. It calls into
the `store` module exclusively.

### `src/store/`

Persistence layer. Wraps all database access behind a `TaskStore` interface.
Key types: `TaskStore`, `TaskRecord`, `TaskFilter`.

**Boundary:** This is an internal API boundary. The `store` module owns the database
schema and migrations. All SQL lives here.

**Invariant:** `TaskStore` methods are the *only* code that executes SQL. No raw
queries exist outside this module.

**Invariant:** All write operations are idempotent. Retrying a failed store call
is always safe.

### `src/scheduler/`

Polls the task store for pending work and assigns tasks to workers.
Key types: `Scheduler`, `SchedulerConfig`, `AssignmentStrategy`.

The scheduler runs as a background loop on a configurable interval. It uses
`SELECT ... FOR UPDATE SKIP LOCKED` to avoid contention between multiple
scheduler instances.

**Invariant:** The scheduler is stateless between iterations. Crashing and
restarting loses no information -- all state is in the database.

### `src/worker/`

Executes task handlers. A worker pulls an assigned task, runs the corresponding
handler function, and reports the result back to the store.
Key types: `Worker`, `WorkerPool`, `TaskHandler`, `TaskResult`.

Handlers are registered by task type name at startup. The worker looks up the
handler in a `Map<string, TaskHandler>` and invokes it.

**Invariant:** Workers never write to the database directly. They report results
through the store interface, which handles retries and state transitions.

### `src/retry/`

Retry policy logic. Determines whether a failed task should be retried, when, and
how many times. Key types: `RetryPolicy`, `BackoffStrategy`.

This module is pure computation -- no I/O, no side effects. Given a task's failure
history and its retry config, it returns a `RetryDecision`.

**Invariant:** This module has zero dependencies on any other module. It operates
on plain data types only.

### `src/config/`

Configuration loading and validation. Reads from environment variables and optional
config files. Key types: `AppConfig`, `SchedulerConfig`, `WorkerConfig`.

Config is loaded once at startup and frozen. It is passed as a readonly reference
to all modules that need it.

### `src/types/`

Shared domain types used across module boundaries. Key types: `Task`, `TaskId`,
`TaskStatus`, `TaskType`.

**Invariant:** This module contains only type definitions and small helper functions.
No business logic, no I/O, no side effects.

## Cross-Cutting Concerns

### Error Handling

The API layer catches all errors and maps them to HTTP status codes. Internal modules
use a `Result<T, TaskflowError>` pattern. `TaskflowError` is a discriminated union
with variants like `NotFound`, `Conflict`, `StoreError`, `HandlerError`.

Panics in task handlers are caught by the worker and treated as task failures with
a `HandlerPanic` error type. They never crash the worker process.

### Testing

Tests live next to the code they test in `__tests__/` directories.

- **Unit tests:** Pure logic modules (`retry`, `types`) are tested with plain unit tests.
- **Integration tests:** `store` tests run against a real PostgreSQL instance via testcontainers.
- **API tests:** `src/api/__tests__/` makes HTTP requests against the full server stack.

**Invariant:** No test depends on external network resources. Database tests use
disposable containers.

### Observability

Structured JSON logging via the logger in `src/logger.ts`. All log entries include
`taskId` and `requestId` for tracing.

Metrics are exported as Prometheus counters/histograms from `src/metrics.ts`.
Key metrics: `tasks_submitted_total`, `tasks_completed_total`, `task_duration_seconds`.

### Database Migrations

Migrations live in `src/store/migrations/` and are run automatically on startup.
They are forward-only (no down migrations). Each migration is a plain SQL file
named with a timestamp prefix.
