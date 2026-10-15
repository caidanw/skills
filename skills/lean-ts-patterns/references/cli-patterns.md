# CLI Patterns

Patterns for building lightweight CLI tools. Derived from unjs/citty (734 lines total).

## Architecture: Two-Layer Parser

**Layer 1 (raw):** Wrap `node:util.parseArgs` -- handles `--no-` negation, alias propagation.
**Layer 2 (semantic):** Add typed args (positional, string, boolean, enum), validation, defaults.

```ts
import { parseArgs as nodeParseArgs } from "node:util";

interface ArgDef {
  type: "positional" | "string" | "boolean" | "enum";
  description?: string;
  required?: boolean;
  default?: any;
  alias?: string | string[];
  options?: string[]; // for enum
}

type ArgsDef = Record<string, ArgDef>;

function parseArgs(rawArgs: string[], argsDef: ArgsDef) {
  const parseOpts = { boolean: [] as string[], string: [] as string[],
    alias: {} as Record<string, string[]>, default: {} as Record<string, any> };

  for (const [name, arg] of Object.entries(argsDef)) {
    if (arg.type === "positional") continue;
    if (arg.type === "boolean") parseOpts.boolean.push(name);
    else parseOpts.string.push(name);
    if (arg.default !== undefined) parseOpts.default[name] = arg.default;
    if (arg.alias) parseOpts.alias[name] = Array.isArray(arg.alias) ? arg.alias : [arg.alias];
  }

  const { values, positionals } = nodeParseArgs({
    args: rawArgs, options: parseOpts, allowPositionals: true, strict: false,
  });

  // Map positionals by definition order
  const positionalDefs = Object.entries(argsDef).filter(([, a]) => a.type === "positional");
  for (let i = 0; i < positionalDefs.length; i++) {
    const [name, def] = positionalDefs[i];
    if (positionals[i] !== undefined) values[name] = positionals[i];
    else if (def.required !== false) throw new Error(`Missing required: ${name.toUpperCase()}`);
    else values[name] = def.default;
  }

  // Validate enums
  for (const [name, arg] of Object.entries(argsDef)) {
    if (arg.type === "enum" && values[name] !== undefined && arg.options?.length) {
      if (!arg.options.includes(values[name] as string))
        throw new Error(`Invalid --${name}: expected one of ${arg.options.join(", ")}`);
    }
    if (arg.required && values[name] === undefined)
      throw new Error(`Missing required: --${name}`);
  }

  return values;
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
- **`--no-` prefix negation**: Preprocess `--no-verbose` to set `verbose = false`
- **Lifecycle hooks**: `setup` -> `run` -> `cleanup` (cleanup in `finally` block)
- **User-facing errors show help**, internal errors show raw error
- **Underscore-prefixed files** (`_parser.ts`, `_utils.ts`) = internal, not exported
