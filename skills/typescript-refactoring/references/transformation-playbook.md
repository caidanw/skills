# Transformation Playbook

Step-by-step recipes for the most common TypeScript refactorings. Each recipe shows the mechanical transformation with before/after code. For identifying what to fix, see [smell-catalog.md](smell-catalog.md).

## 1. Eliminate `any`

Work through `any` types one at a time. Each has a different fix strategy.

**Lazy `any` — developer skipped typing:**
```ts
// Before
function getFullName(user: any): any {
  return `${user.first} ${user.last}`
}

// After
function getFullName(user: { first: string; last: string }): string {
  return `${user.first} ${user.last}`
}
```

**JSON.parse / API response `any`:**
```ts
// Before
const data = JSON.parse(raw)  // any
doSomething(data.name)

// After — parse at the boundary
function parseConfig(raw: string): Config {
  const data: unknown = JSON.parse(raw)
  if (!data || typeof data !== "object") throw new Error("expected object")
  const obj = data as Record<string, unknown>
  if (typeof obj.name !== "string") throw new Error("missing name")
  return { name: obj.name }
}
```

**Third-party `any` — dependency returns `any`:**
```ts
// Before
const result = externalLib.doThing()  // any

// After — type at the call site
const result: ExpectedType = externalLib.doThing()
// Or wrap in a typed function
function doThing(): ExpectedType {
  return externalLib.doThing() as ExpectedType
}
```

**Genuinely complex `any`:**
```ts
// Before
function merge(a: any, b: any): any { ... }

// After — use unknown + narrowing, or generics
function merge<T extends Record<string, unknown>>(a: T, b: Partial<T>): T { ... }
```

## 2. Extract Function

The most common refactoring. Identify a block of code that does one thing, give it a name.

```ts
// Before
function processOrder(order: Order): Receipt {
  // validate
  if (!order.items.length) throw new Error("empty order")
  if (!order.customer.verified) throw new Error("unverified customer")

  // calculate
  let total = 0
  for (const item of order.items) {
    total += item.price * item.quantity
  }
  const discount = total > 100 ? total * 0.1 : 0
  const finalTotal = total - discount

  // build receipt
  return {
    orderId: order.id,
    customer: order.customer.name,
    total: finalTotal,
    items: order.items.length,
  }
}

// After
function processOrder(order: Order): Receipt {
  validateOrder(order)
  const total = calculateTotal(order.items)
  const discount = calculateDiscount(total)
  return buildReceipt(order, total - discount)
}

function validateOrder(order: Order): void {
  if (!order.items.length) throw new Error("empty order")
  if (!order.customer.verified) throw new Error("unverified customer")
}

function calculateTotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0)
}

function calculateDiscount(total: number): number {
  return total > 100 ? total * 0.1 : 0
}

function buildReceipt(order: Order, total: number): Receipt {
  return {
    orderId: order.id,
    customer: order.customer.name,
    total,
    items: order.items.length,
  }
}
```

**Rules:**
- Name the extraction by what it does, not how (`calculateDiscount`, not `applyTenPercent`)
- If the extracted function needs 4+ parameters, the original function is doing too many things — extract further
- Keep extracted functions in the same file until a second consumer appears

## 3. Split Large File

Find seams by grouping related functions by the data they touch.

```ts
// Before: src/user.ts (600 lines)
// Contains: User type, validation, DB queries, email sending, formatting

// After: split by responsibility
// src/user/user.types.ts    — User, CreateUserInput, UserStatus types
// src/user/user.repo.ts     — DB queries (getUser, createUser, updateUser)
// src/user/user.service.ts  — business logic (validateUser, processSignup)
// src/user/user.format.ts   — display formatting (formatUserName, formatUserList)
```

**Steps:**
1. Move types first — they have no runtime behavior, so moving them can't break anything
2. Move pure utility functions next (formatting, calculation)
3. Move side-effecting functions last (DB, network, email)
4. Update imports across the codebase after each move
5. Run tests after each step

## 4. Flatten Nesting

Replace deep nesting with early returns and guard clauses.

```ts
// Before: 5 levels deep
function processItem(item: Item | null): Result | null {
  if (item) {
    if (item.isValid) {
      if (item.price > 0) {
        const discount = getDiscount(item)
        if (discount) {
          return { price: item.price - discount, item }
        }
      }
    }
  }
  return null
}

// After: flat with early returns
function processItem(item: Item | null): Result | null {
  if (!item) return null
  if (!item.isValid) return null
  if (item.price <= 0) return null

  const discount = getDiscount(item)
  if (!discount) return null

  return { price: item.price - discount, item }
}
```

**Rules:**
- Invert the condition, return early
- The happy path flows straight down without indentation
- Each guard clause is one concern — easy to read, easy to add new guards

## 5. Enum → Union Type

Mechanical transformation. Safe when done codebase-wide in one pass.

```ts
// Before
enum Status {
  Active = "ACTIVE",
  Inactive = "INACTIVE",
  Pending = "PENDING",
}

function isActive(status: Status): boolean {
  return status === Status.Active
}

// After — union type
type Status = "ACTIVE" | "INACTIVE" | "PENDING"

function isActive(status: Status): boolean {
  return status === "ACTIVE"
}
```

**For enums used as namespace-like access patterns:**
```ts
// Before
enum HttpMethod {
  GET = "GET",
  POST = "POST",
}
fetch(url, { method: HttpMethod.GET })

// After — as const object preserves the namespace access
const HttpMethod = {
  GET: "GET",
  POST: "POST",
} as const
type HttpMethod = typeof HttpMethod[keyof typeof HttpMethod]

fetch(url, { method: HttpMethod.GET })  // still works
```

**Steps:**
1. Find all enum declarations: `grep -rn 'enum ' src/`
2. For each enum, find all references: `grep -rn 'EnumName\.' src/`
3. Replace enum with union type or `as const` object
4. Update all references
5. Run tests

## 6. Class → Factory Function

Only convert classes that aren't wrapping resources, building fluent APIs, or implementing `Disposable`.

```ts
// Before
class UserService {
  private db: Database

  constructor(db: Database) {
    this.db = db
  }

  async getUser(id: string): Promise<User | null> {
    return this.db.users.findUnique({ where: { id } })
  }

  async createUser(input: CreateUserInput): Promise<User> {
    return this.db.users.create({ data: input })
  }
}

const service = new UserService(db)

// After
function createUserService(db: Database) {
  return {
    getUser: (id: string): Promise<User | null> =>
      db.users.findUnique({ where: { id } }),

    createUser: (input: CreateUserInput): Promise<User> =>
      db.users.create({ data: input }),
  }
}

const service = createUserService(db)
```

**Don't convert when:**
- The class wraps a resource (DB connection, WebSocket, file handle)
- The class is a fluent/chainable API (builder, schema validator)
- The class implements `Disposable` for `using`
- The class uses inheritance meaningfully (`extends` with overrides)

## 7. Boolean Soup → Discriminated Union

Identify the distinct states, then model each state with exactly the data it carries.

```ts
// Before — boolean soup
type RequestState = {
  isLoading: boolean
  isError: boolean
  data?: UserData
  error?: Error
}

// Step 1: List all valid combinations
// idle:    isLoading=false, isError=false, no data, no error
// loading: isLoading=true, isError=false, no data, no error
// success: isLoading=false, isError=false, data present, no error
// error:   isLoading=false, isError=true, no data, error present

// Step 2: Model as discriminated union
type RequestState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: UserData }
  | { status: "error"; error: Error }

// Step 3: Update all consumers to switch on status
function renderState(state: RequestState) {
  switch (state.status) {
    case "idle": return null
    case "loading": return <Spinner />
    case "success": return <UserCard data={state.data} />
    case "error": return <ErrorBanner error={state.error} />
  }
}
```

## 8. Add Parse-at-Boundary

Wrap raw external data with validation at the system boundary.

```ts
// Before — raw data flows deep into the app
app.post("/users", async (req, res) => {
  const user = req.body  // any / unknown
  await db.users.create({ data: user })  // unsafe
  res.json(user)
})

// After — parse at the boundary, trust types after
type CreateUserInput = {
  name: string
  email: string
  age: number
}

function parseCreateUserInput(data: unknown): CreateUserInput {
  if (!data || typeof data !== "object") throw new ValidationError("expected object")
  const obj = data as Record<string, unknown>
  if (typeof obj.name !== "string") throw new ValidationError("name must be string")
  if (typeof obj.email !== "string") throw new ValidationError("email must be string")
  if (typeof obj.age !== "number") throw new ValidationError("age must be number")
  return { name: obj.name, email: obj.email, age: obj.age }
}

app.post("/users", async (req, res) => {
  const input = parseCreateUserInput(req.body)  // typed!
  const user = await db.users.create({ data: input })
  res.json(user)
})
```

**For complex schemas,** use Zod or Valibot instead of hand-written parsers.

## 9. Barrel File Removal

Replace barrel re-exports with direct imports.

```ts
// Before: src/utils/index.ts
export { formatDate } from "./date"
export { formatCurrency } from "./currency"
export { slugify } from "./string"
// ... 20 more re-exports

// Consumer imports from barrel
import { formatDate, slugify } from "../utils"

// After: direct imports
import { formatDate } from "../utils/date"
import { slugify } from "../utils/string"
```

**Steps:**
1. List all exports in the barrel file
2. For each export, find all consumers: `grep -rn "from.*utils[\"']" src/`
3. Replace barrel import with direct import
4. Remove the re-export from the barrel file
5. When barrel file is empty, delete it
6. Run tests after each batch of changes

**Keep a barrel at the package root** if the package is consumed by other packages — the barrel is the public API.

## 10. Strangler Fig Migration

For large, risky transformations. Run old and new implementations side by side, migrate callers incrementally.

```ts
// Phase 1: Create new implementation alongside old
// old: src/pricing/calculate.ts (legacy)
// new: src/pricing/calculate-v2.ts

// Phase 2: Create a router that delegates
export function calculatePrice(order: Order): number {
  if (useNewPricing(order)) {
    return calculatePriceV2(order)
  }
  return calculatePriceLegacy(order)
}

// Phase 3: Expand the new path gradually
function useNewPricing(order: Order): boolean {
  // Start with a small percentage or specific conditions
  return order.region === "US"  // only US orders use new pricing
}

// Phase 4: When 100% of traffic uses new path, delete legacy
// - Remove calculatePriceLegacy
// - Remove useNewPricing router
// - Rename calculatePriceV2 → calculatePrice
```

**When to use strangler fig:**
- Replacing a core algorithm (pricing, permissions, routing)
- Migrating a data model (DB schema changes)
- Replacing a third-party dependency with a different one
- Any change where "just swap it" risks production breakage

**When NOT to use it:**
- Simple renames, extractions, or type changes — just do them directly
- Dead code removal — delete it and move on
