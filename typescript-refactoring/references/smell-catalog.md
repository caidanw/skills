# TypeScript Smell Catalog

Code smells organized by the priority order from SKILL.md. Each smell includes what it looks like, why it's a problem, and how to detect it. For step-by-step fix recipes, see [transformation-playbook.md](transformation-playbook.md).

## Level 1: Type Safety Smells

### `any` Proliferation

```ts
// Smell: any used as escape hatch
function processData(data: any): any {
  return data.items.map((item: any) => item.name)
}
```

**Why it's a problem:** Disables the compiler entirely. Every `any` is an undetected bug waiting to happen. AI agents propagate `any` — one `any` infects every function it touches.

**Detection:** `grep -rn ': any' src/ | wc -l` — count the infection.

**Variants:**
- **Lazy `any`** — developer didn't bother typing it. Fix: add the correct type.
- **Inherited `any`** — came from a dependency or JSON.parse. Fix: parse at the boundary with a schema.
- **Complex `any`** — the real type is genuinely hard to express. Fix: use `unknown` and narrow, or simplify the data shape.

### Missing Return Types on Exports

```ts
// Smell: no return type on public function
export function getUser(id: string) {
  return db.users.findUnique({ where: { id } })
}
```

**Why it's a problem:** Compiler must infer the type. Hurts build performance, produces verbose `.d.ts` files, and AI agents can't quickly determine what the function returns.

**Detection:** Look for exported functions without `: ReturnType` after the parameter list.

### Untyped Catch Blocks

```ts
// Smell: assuming error is Error
catch (err) {
  console.error(err.message) // err is unknown, not Error
}
```

**Why it's a problem:** `err` is `unknown` in strict mode. Accessing `.message` without narrowing is unsafe. AI agents frequently generate this mistake.

### Excessive Type Assertions

```ts
// Smell: as used to silence the compiler
const user = data as User
const id = (response as any).data.id as string
```

**Why it's a problem:** Each `as` bypasses type checking. Double assertions (`as unknown as T`) are a red flag — the types are fundamentally wrong.

## Level 2: Dead Code Smells

### Unused Imports and Exports

```ts
import { formatDate, parseDate, validateDate } from "./date-utils"
// Only formatDate is used
```

**Detection:** Your editor/linter highlights these. `tsc --noUnusedLocals --noUnusedParameters` catches them at build time.

### Commented-Out Code

```ts
// function oldCalculation(items: Item[]) {
//   return items.reduce((sum, i) => sum + i.price, 0)
// }
```

**Why it's a problem:** It's not documentation — it's noise. Git preserves history. Delete it.

### Unreachable Branches

```ts
if (status === "active") {
  // ...
} else if (status === "active") { // unreachable duplicate
  // ...
}
```

### Stale Feature Flags

```ts
if (featureFlags.newCheckout) { // always true for 6 months
  return newCheckoutFlow()
}
return oldCheckoutFlow() // dead code
```

**Detection:** `git log -p --all -S 'featureFlags.newCheckout'` — if it hasn't changed in months, it's stale.

## Level 3: Naming Smells

### Generic Names

```ts
// Smell: names that say nothing
function handle(data: any, cb: Function) {
  const result = process(data)
  cb(result)
}

// Better
function processPaymentWebhook(event: WebhookEvent, onComplete: (receipt: Receipt) => void) {
  const receipt = createReceipt(event)
  onComplete(receipt)
}
```

**The test:** Can you understand what the function does from its name alone, without reading the body?

### Single-Letter Variables Outside Loops

```ts
// Acceptable: loop iterators
for (const u of users) { ... }
items.filter(x => x.active)

// Smell: business logic with cryptic names
const t = calculateTotal(items)
const d = t > 100 ? t * 0.1 : 0
const f = t - d
```

### `I`-Prefixed Interfaces

```ts
// Smell
interface IUser { ... }
interface IRepository { ... }

// Fix: just name the thing
type User = { ... }
type Repository = { ... }
```

### Misleading Names

```ts
// Smell: name suggests one thing, code does another
function getUsers() {
  // Actually fetches, filters, sorts, and paginates
  // This is "fetchActiveSortedUserPage"
}
```

## Level 4: Structural Smells

### God Files (500+ lines)

A file that does too many things. Look for multiple unrelated groups of functions, or a file that every other file imports from.

**Detection:** `find src -name '*.ts' -exec wc -l {} + | sort -rn | head -10`

**Seam-finding strategy:** Group related functions by what data they touch. Each group is a candidate for its own module.

### Deep Nesting (4+ levels)

```ts
// Smell
function processOrder(order: Order) {
  if (order.items.length > 0) {
    for (const item of order.items) {
      if (item.inStock) {
        if (item.price > 0) {
          if (order.customer.verified) {
            // actual logic buried 5 levels deep
          }
        }
      }
    }
  }
}
```

**Fix:** Early returns, guard clauses, extracted predicates. See transformation-playbook.md.

### Long Functions (50+ lines)

If you can't see the whole function on screen, it does too many things. Extract sub-operations into named functions.

### Long Parameter Lists (4+ parameters)

```ts
// Smell
function createUser(name: string, email: string, age: number, role: string, team: string, active: boolean) { ... }

// Fix: use an options object
function createUser(opts: CreateUserOptions) { ... }
```

## Level 5: Pattern Smells

### Enum Usage

```ts
// Smell
enum Status { Active, Inactive, Pending }

// Fix: union type or as const object
type Status = "active" | "inactive" | "pending"
```

**Why:** Enums emit runtime code, break `--erasableSyntaxOnly`, and are incompatible with Node's native TypeScript support. See the `typescript` skill for details.

### Boolean Soup

```ts
// Smell: impossible combinations are representable
type RequestState = {
  isLoading?: boolean
  isError?: boolean
  data?: Data
  error?: Error
}
// Can isLoading AND isError both be true? What does that mean?
```

**Fix:** Discriminated union. See the `typescript` skill, Section 5.

### Barrel File Chains

```ts
// src/utils/index.ts re-exports from 15 files
// src/index.ts re-exports from src/utils/index.ts
// Every import pulls in the entire module graph
```

**Why:** Barrel files explode module graphs, kill tree-shaking, and can add minutes to test suite execution. One barrel at a package root is fine; barrels in every subdirectory are not.

### Class-for-Everything

```ts
// Smell: class used for what should be a plain function
class UserValidator {
  validate(user: User): boolean {
    return user.email.includes("@")
  }
}
// new UserValidator().validate(user) — why not just validateUser(user)?
```

**When classes ARE appropriate:** Wrapping resources, fluent/chainable APIs, `Disposable` objects. See the `typescript` skill, Section 8.

### Namespace Usage

```ts
// Smell
namespace Utils {
  export function formatDate(d: Date): string { ... }
}

// Fix: ES module
export function formatDate(d: Date): string { ... }
```

**Why:** Namespaces are non-erasable syntax. Use modules.
