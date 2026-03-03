# Logging Patterns

Patterns for building lightweight loggers. Derived from unjs/consola (~1500 lines).

## Architecture: Environment-Agnostic Core + Injected Reporters

The core logger class knows nothing about Node streams, colors, or browsers. Each entry point
composes the core with the right reporter:

```ts
// Core: environment-agnostic
class Logger {
  options: LoggerOptions;
  constructor(opts: LoggerOptions) { this.options = opts; }
}

// Node entry: fancy reporter
export function createLogger(opts = {}) {
  return new Logger({
    level: isCI ? 1 : 3,
    reporters: [isCI ? new BasicReporter() : new FancyReporter()],
    ...opts,
  });
}

// Browser entry: native console
export function createLogger(opts = {}) {
  return new Logger({
    reporters: [new BrowserReporter()],
    ...opts,
  });
}
```

## Log Level Hierarchy

Use numeric levels with `Infinity`/`-Infinity` for verbose/silent:

```ts
const LogLevels = {
  silent: -Infinity,
  fatal: 0, error: 0,
  warn: 1,
  log: 2,
  info: 3, success: 3, ready: 3,
  debug: 4,
  trace: 5,
  verbose: Infinity,
} as const;

// Branded number type for autocomplete + flexibility
type LogLevel = 0 | 1 | 2 | 3 | 4 | 5 | (number & {});
```

The `(number & {})` trick gives IDE autocomplete for 0-5 while still accepting arbitrary numbers.

## Single-Method Reporter Interface

Reporters are dead simple -- one method:

```ts
interface LogObject {
  level: number;
  type: string;
  tag: string;
  args: any[];
  date: Date;
}

interface Reporter {
  log(logObj: LogObject, ctx: { options: LoggerOptions }): void;
}
```

### Basic Reporter (plain text)

```ts
class BasicReporter implements Reporter {
  log(logObj: LogObject, ctx: { options: LoggerOptions }) {
    const msg = logObj.args.map(a => typeof a === "string" ? a : JSON.stringify(a)).join(" ");
    const line = `[${logObj.type}]${logObj.tag ? ` [${logObj.tag}]` : ""} ${msg}\n`;
    const stream = logObj.level < 2 ? process.stderr : process.stdout;
    stream.write(line);
  }
}
```

### Fancy Reporter (colors + icons)

```ts
const TYPE_ICONS: Record<string, string> = {
  error: "\u2716", warn: "\u26A0", info: "\u2139", success: "\u2714",
  debug: "\u2699", trace: "\u2192", start: "\u25D0", ready: "\u2714",
};

class FancyReporter extends BasicReporter {
  log(logObj: LogObject, ctx: { options: LoggerOptions }) {
    const icon = TYPE_ICONS[logObj.type] || "";
    const color = logObj.level < 1 ? red : logObj.level === 1 ? yellow : cyan;
    const tag = logObj.tag ? gray(` [${logObj.tag}]`) : "";
    const msg = logObj.args.map(a => typeof a === "string" ? a : JSON.stringify(a)).join(" ");
    const line = `${color(icon)} ${msg}${tag}\n`;
    const stream = logObj.level < 2 ? process.stderr : process.stdout;
    stream.write(line);
  }
}
```

### JSON Reporter (structured logging)

```ts
const jsonReporter: Reporter = {
  log(logObj) { console.log(JSON.stringify(logObj)); },
};
```

### Browser Reporter (CSS badges in devtools)

```ts
class BrowserReporter implements Reporter {
  log(logObj: LogObject) {
    const fn = logObj.level < 1 ? console.error : logObj.level === 1 ? console.warn : console.log;
    const color = logObj.level < 1 ? "#c0392b" : logObj.level === 1 ? "#f39c12" : "#00BCD4";
    const badge = `%c${logObj.type}`;
    const style = `background:${color};border-radius:0.5em;color:white;font-weight:bold;padding:2px 0.5em`;
    fn(badge, style, ...logObj.args);
  }
}
```

## InputLogObject vs LogObject

Separate "what the user provides" from "what the system guarantees":

```ts
interface InputLogObject {
  level?: number;
  type?: string;
  tag?: string;
  message?: string;
  args?: any[];
}

interface LogObject extends Required<InputLogObject> {
  date: Date;
}
```

Reporters always receive `LogObject` with all fields populated.

## Console Wrapping (Infinite Recursion Prevention)

When wrapping `console.log` / `process.stdout.write`, back up the original:

```ts
function wrapConsole(logger: Logger) {
  for (const type of ["log", "warn", "error", "info", "debug"]) {
    if (!(console as any)[`__${type}`]) {
      (console as any)[`__${type}`] = (console as any)[type]; // backup
    }
    (console as any)[type] = (...args: any[]) => logger._logFn({ type }, args, true);
  }
}

function restoreConsole() {
  for (const type of ["log", "warn", "error", "info", "debug"]) {
    if ((console as any)[`__${type}`]) {
      (console as any)[type] = (console as any)[`__${type}`];
      delete (console as any)[`__${type}`];
    }
  }
}

// In reporter: always use the ORIGINAL write to avoid recursion
function writeStream(data: string, stream: NodeJS.WriteStream) {
  const write = (stream as any).__write || stream.write;
  return write.call(stream, data);
}
```

## Spam Prevention (Throttle + Dedup)

Suppress duplicate messages, summarize later:

```ts
interface ThrottleState {
  count: number;
  timeout?: ReturnType<typeof setTimeout>;
  serialized?: string;
  time?: number;
  logObj?: LogObject;
}

function shouldThrottle(
  state: ThrottleState, logObj: LogObject, throttleMs = 1000, minCount = 5,
): boolean {
  const now = Date.now();
  const diff = state.time ? now - state.time : Infinity;
  state.time = now;

  if (diff > throttleMs) { state.count = 0; return false; }

  try {
    const serialized = JSON.stringify([logObj.type, logObj.tag, logObj.args]);
    if (state.serialized !== serialized) { state.serialized = serialized; state.count = 0; return false; }
  } catch { return false; } // circular refs -- skip throttle

  state.count++;
  return state.count > minCount;
}
```

## Scoped Loggers (withTag / withDefaults)

Create child loggers with inherited config:

```ts
withTag(tag: string) {
  return this.create({ defaults: { tag } });
}

withDefaults(defaults: InputLogObject) {
  return this.create({ defaults: { ...this.options.defaults, ...defaults } });
}

create(opts: Partial<LoggerOptions>) {
  return new Logger({ ...this.options, ...opts });
}
```

## Key Patterns

- **stderr for errors** (`level < 2`), stdout for everything else
- **Fan-out to multiple reporters** -- just loop and call each one
- **`.raw` variant on every log method** -- skips LogObject detection for wrapping
- **Module-level pause queue** -- `pauseLogs()` buffers across ALL instances
- **Mock support** -- `mockTypes(fn)` replaces log methods for testing
- **Box/tree drawing** -- use Unicode box chars (`\u250C\u2500\u2510`, `\u251C\u2500`, `\u2514\u2500`) for structured output
