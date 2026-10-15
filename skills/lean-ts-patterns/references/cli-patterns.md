# CLI Patterns

Patterns for building lightweight CLI tools. Derived from unjs/citty, rebuilt on `node:util.parseArgs`.

## Architecture: Two-Layer Parser

**Layer 1 (raw):** `node:util.parseArgs` handles flags, short aliases, defaults, and `--no-` negation
(`allowNegative`, Node 22.4+). With `strict: true` it rejects unknown flags.
**Layer 2 (semantic):** Add positionals by name, enums, and required checks on top.

Note: citty itself vendors a minimist-style parser. This version uses the built-in instead.

```ts
import { parseArgs as nodeParseArgs } from "node:util";

interface ArgDef {
  type: "positional" | "string" | "boolean" | "enum";
  description?: string;
  required?: boolean;
  default?: string | boolean;
  alias?: string; // single-character short flag
  options?: string[]; // for enum
}

type ArgsDef = Record<string, ArgDef>;

function parseArgs(rawArgs: string[], argsDef: ArgsDef) {
  const options: Record<string, { type: "string" | "boolean"; short?: string; default?: string | boolean }> = {};
  for (const [name, arg] of Object.entries(argsDef)) {
    if (arg.type === "positional") continue;
    // node:util.parseArgs rejects keys set to undefined, so only add what is defined.
    options[name] = { type: arg.type === "boolean" ? "boolean" : "string" };
    if (arg.alias) options[name].short = arg.alias;
    if (arg.default !== undefined) options[name].default = arg.default;
  }

  const { values, positionals } = nodeParseArgs({
    args: rawArgs, options, allowPositionals: true, allowNegative: true, strict: true,
  });
  const result: Record<string, unknown> = { ...values };

  // Map positionals by definition order
  const positionalDefs = Object.entries(argsDef).filter(([, a]) => a.type === "positional");
  positionalDefs.forEach(([name, def], i) => {
    if (positionals[i] !== undefined) result[name] = positionals[i];
    else if (def.required !== false) throw new Error(`Missing required: ${name.toUpperCase()}`);
    else result[name] = def.default;
  });

  for (const [name, arg] of Object.entries(argsDef)) {
    if (arg.type === "enum" && result[name] !== undefined && !arg.options?.includes(result[name] as string))
      throw new Error(`Invalid --${name}: expected one of ${arg.options?.join(", ")}`);
    if (arg.required && result[name] === undefined) throw new Error(`Missing required: --${name}`);
  }
  return result;
}
```

## Auto camelCase/kebab-case Aliasing

Use a Proxy so `args.workDir` and `args["work-dir"]` both resolve:

```ts
const parsed = new Proxy(values, {
  get(target, prop: string) {
    return target[prop]
      ?? target[prop.replace(/[A-Z]/g, m => `-${m.toLowerCase()}`)]  // camel -> kebab
      ?? target[prop.replace(/-([a-z])/g, (_, c) => c.toUpperCase())]; // kebab -> camel
  },
});
```

## Subcommand Dispatch with Lazy Loading

```ts
type Resolvable<T> = T | Promise<T> | (() => T) | (() => Promise<T>);

interface CommandDef {
  meta?: Resolvable<{ name: string; version?: string; description?: string }>;
  args?: ArgsDef;
  subCommands?: Resolvable<Record<string, Resolvable<CommandDef>>>;
  setup?: (ctx: any) => any;
  run?: (ctx: any) => any;
  cleanup?: (ctx: any) => any;
}

async function runCommand(cmd: CommandDef, rawArgs: string[]) {
  const meta = await resolveValue(cmd.meta);
  const subCommands = await resolveValue(cmd.subCommands);

  // setup -> run -> cleanup lifecycle
  const ctx = { rawArgs, args: cmd.args ? parseArgs(rawArgs, cmd.args) : {}, cmd };
  if (cmd.setup) await cmd.setup(ctx);

  try {
    if (subCommands && Object.keys(subCommands).length > 0) {
      const subIdx = rawArgs.findIndex(a => !a.startsWith("-"));
      const subName = rawArgs[subIdx];
      if (subName && subCommands[subName]) {
        const sub = await resolveValue(subCommands[subName]);
        await runCommand(sub, rawArgs.slice(subIdx + 1));
      } else if (!cmd.run) {
        throw new Error(`Unknown command: ${subName || "(none)"}`);
      }
    }
    if (cmd.run) await cmd.run(ctx);
  } finally {
    if (cmd.cleanup) await cmd.cleanup(ctx);
  }
}
```

Subcommands are lazy -- only the invoked command's module is loaded:

```ts
const main = defineCommand({
  subCommands: {
    build: () => import("./commands/build").then(m => m.default),
    deploy: () => import("./commands/deploy").then(m => m.default),
  },
});
```

## Auto-Generated Help Text

```ts
function renderUsage(cmd: CommandDef, meta?: { name: string; description?: string }) {
  const lines: string[] = [];
  if (meta?.description) lines.push(meta.description, "");

  const args = cmd.args ? Object.entries(cmd.args) : [];
  const positionals = args.filter(([, a]) => a.type === "positional");
  const flags = args.filter(([, a]) => a.type !== "positional");

  // Usage line
  const posStr = positionals.map(([n, a]) =>
    a.required !== false ? n.toUpperCase() : `[${n.toUpperCase()}]`).join(" ");
  lines.push(`Usage: ${meta?.name || "command"} ${flags.length ? "[options] " : ""}${posStr}`, "");

  // Flags table
  if (flags.length) {
    lines.push("Options:");
    const maxLen = Math.max(...flags.map(([n]) => n.length + 4));
    for (const [name, arg] of flags) {
      const alias = arg.alias ? `-${Array.isArray(arg.alias) ? arg.alias[0] : arg.alias}, ` : "    ";
      const flag = `--${name}`.padEnd(maxLen);
      const desc = arg.description || "";
      const def = arg.default !== undefined ? ` (default: ${arg.default})` : "";
      lines.push(`  ${alias}${flag}  ${desc}${def}`);
    }
  }
  return lines.join("\n");
}
```

## runMain: The Full CLI Entry Point

Handles `--help`, `--version`, errors, and `process.exit`:

```ts
async function runMain(cmd: CommandDef) {
  const rawArgs = process.argv.slice(2);
  try {
    if (rawArgs.includes("--help") || rawArgs.includes("-h")) {
      const meta = await resolveValue(cmd.meta);
      console.log(renderUsage(cmd, meta));
      process.exit(0);
    }
    if (rawArgs.includes("--version") || rawArgs.includes("-v")) {
      const meta = await resolveValue(cmd.meta);
      console.log(meta?.version || "unknown");
      process.exit(0);
    }
    await runCommand(cmd, rawArgs);
  } catch (error: any) {
    console.error(error.message || error);
    process.exit(1);
  }
}
```

## Key Patterns

- **Positionals default to required**, named args to optional -- matches user expectations
- **`--no-` prefix negation**: `allowNegative: true` turns `--no-verbose` into `verbose: false`
- **Lifecycle hooks**: `setup` -> `run` -> `cleanup` (cleanup in `finally` block)
- **User-facing errors show help**, internal errors show raw error
- **Underscore-prefixed files** (`_parser.ts`, `_utils.ts`) = internal, not exported
