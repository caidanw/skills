---
name: type-system-discipline
description: >-
  Make the compiler reject impossible states, mixed-up primitives, and unhandled variants, and parse
  external data once at system boundaries. Use when designing types, data models, or function
  signatures in any typed language; wiring validation, error handling, or framework adapters; or
  reviewing code with redundant null checks, void-returning validators, stringly-typed data, boolean
  flags controlling behavior, casts, or "should never happen" branches. Triggers on: "parse don't
  validate", "make illegal states unrepresentable", "type-driven design", "boundary validation",
  "branded type", "newtype", "smart constructor", "strengthen types", "input validation".
---

# Type System Discipline

Make the compiler reject impossible states, mismatched primitives, and unhandled variants. Prefer defining errors and special cases out of existence over proliferating handlers. Examples are TypeScript; the rules hold in any typed language. For TypeScript syntax, see the **typescript-best-practices** skill.

## Rules

- **Make illegal states unrepresentable.** Model variants as sum types (discriminated unions, enums with payloads, sealed classes), not as a bag of optional fields where contradictory combinations compile. `{ completed: boolean; completedAt?: Date }` admits `completed: true` with no date. Derive the boolean from `completedAt`, or model `{ kind: 'open' } | { kind: 'done'; at: Date }`. If you can write a comment explaining when a combination of fields is valid, split it into a sum type.
- **Types are constructions, not restrictions.** Build the type up from the values you want instead of carving them out of a looser type with checks. A non-empty list is a head plus a rest. A valid time range is a start plus a duration. Choose the shape that cannot build the illegal value and expose the interface callers need on top.
- **Brand semantic primitives.** `UserId` and `OrderId` are strings underneath but should not be interchangeable. Give each its own type, such as a branded intersection in TypeScript or a newtype elsewhere. Validate once at creation, trust the type downstream. If two arguments share a primitive type but mean different things, brand them.
- **External data is untyped until parsed.** RPC payloads, JSON, IPC messages, CLI args, config files, environment variables, database rows. Have a parse function at every boundary that turns unstructured input into the typed model. **Boundary Discipline** below says where.
- **Don't lie to the type system.** Casts, unsafe coercions, and assertion functions that bypass the compiler are latent runtime crashes. If the compiler can't prove a fact, prove it (validate, narrow, refine the model) or accept that the cast is a hazard. Trace each `any`, `as`, or `assertNotNull` to the boundary and validate there.
- **Exhaustive matching is the compiler's job.** A match on a sum type must fail compilation when a new variant is added without handling, so the compiler tells the next agent where to add a case. Use your language's idiom: a `never`-typed binding in TypeScript, an unannotated `match` in Rust, `-Wincomplete-patterns` in Haskell, sealed-class `when` exhaustiveness in Kotlin, a `switch` without `default` over a Swift enum.
- **Derive types from authoritative schemas.** When a protocol buffer, OpenAPI spec, GraphQL schema, database migration, design-token file, or another file owns a shape, derive from it instead of hand-rolling a parallel type.
- **Strengthen a type only where partiality appears.** A runtime assertion, null check, or "this should never happen" throw marks the place a type is too weak. Push that check up into the type. Then stop. The type system's job is to track the cases each use site must handle, not to describe the data as precisely as possible. Prefer total functions. `sum` of an empty list is 0, so it takes the plain list. `head` of an empty list has no answer, so it demands the non-empty one. If nothing would otherwise panic, keep the plain type.

## Parse, Don't Validate

Based on Alexis King's article: https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/

A parser is a function that consumes less-structured input and produces more-structured output.
Validation checks a property and throws it away. Parsing checks a property and *preserves it
in the type system*. Always prefer parsing.

### The Core Idea

```ts
// VALIDATION: checks a property, returns nothing useful
function validateNonEmpty(list: string[]): void {
  if (list.length === 0) throw new Error("list cannot be empty");
}

// PARSING: checks the same property, returns proof in the type
function parseNonEmpty<T>(list: T[]): [T, ...T[]] {
  if (list.length === 0) throw new Error("list cannot be empty");
  return list as [T, ...T[]];
}
```

Both check the same thing. But `parseNonEmpty` gives the caller access to what it learned.
`validateNonEmpty` throws the knowledge away, forcing every downstream function to either
re-check or hope for the best.

### The Two Strategies

When a function is partial (not defined for all inputs), there are exactly two ways to make it total:

#### 1. Weaken the output (add Maybe/null)

```ts
function head<T>(list: T[]): T | undefined {
  return list[0];
}
```

Easy to implement, annoying to use. Every caller must handle `undefined` even if they already know the list is non-empty. Leads to redundant checks and `// should never happen` comments.

#### 2. Strengthen the input (narrow the type) -- PREFER THIS

```ts
function head<T>(list: [T, ...T[]]): T {
  return list[0];
}
```

The check happens once, at the boundary, when the data enters the system. After that, the type carries the proof. No redundant checks. No impossible branches. If the validation logic changes, the compiler catches every affected call site.

**Always try strategy 2 first. Fall back to strategy 1 only when 2 is impractical.**

### Practical Rules

#### 1. Make illegal states unrepresentable

Use the most precise data structure you reasonably can. Don't model things you shouldn't allow.

```ts
// BAD: allows duplicate keys, order might matter or might not
type Config = Array<[string, string]>;

// GOOD: duplicates impossible by construction
type Config = Map<string, string>;

// or even better if keys are known:
type Config = { host: string; port: number; debug: boolean };
```

#### 2. Push parsing to the boundary

Parse data into precise types as soon as it enters your system. The boundary between your
program and the outside world is where parsing belongs.

```ts
// BAD: raw data flows deep into the system, validated ad-hoc
function processUser(data: unknown) {
  // 50 lines later...
  if (typeof data.email !== "string") throw new Error("invalid email");
}

// GOOD: parse at the boundary, use precise types everywhere else
interface User { name: string; email: string; age: number; }

function parseUser(data: unknown): User {
  // validate and parse here, once
}

function processUser(user: User) {
  // no validation needed -- the type guarantees it
}
```

In practice a schema library is usually the parser. If the project has Zod, Valibot, or ArkType,
use it: `const user = UserSchema.parse(data)` returns a typed `User` or throws, and the type is
derived from the schema so the two cannot drift.

#### 3. Treat `void`-returning validators with deep suspicion

A function whose primary purpose is checking a property but returns `void` is almost always
a missed opportunity. It should return a more precise type instead.

```ts
// SUSPICIOUS: checks something, returns nothing
function validateAge(age: number): void {
  if (age < 0 || age > 150) throw new Error("invalid age");
}

// BETTER: returns proof of validity as a branded type
type ValidAge = number & { readonly __brand: "ValidAge" };
function parseAge(age: number): ValidAge {
  if (age < 0 || age > 150) throw new Error("invalid age");
  return age as ValidAge;
}
```

#### 4. Use branded/opaque types as "fake parsers"

When making an illegal state truly unrepresentable is impractical (e.g., "integer in range
1-100"), use branded types with smart constructors to fake it:

```ts
type EmailAddress = string & { readonly __brand: "EmailAddress" };

function parseEmail(input: string): EmailAddress {
  if (!input.includes("@")) throw new Error("invalid email");
  return input as EmailAddress;
}

// Now functions can demand EmailAddress instead of string
function sendEmail(to: EmailAddress, body: string): void { /* ... */ }
```

The type system won't let you pass a raw `string` where `EmailAddress` is expected.
You must go through `parseEmail` first.

#### 5. Let types inform code, not vice versa

Don't stick a `boolean` in a record because your current function needs it. Design the
types first, then write functions that transform between them.

```ts
// BAD: boolean flag controlling behavior
interface Request { url: string; isAuthenticated: boolean; token?: string; }

// GOOD: discriminated union makes invalid state impossible
type Request =
  | { kind: "anonymous"; url: string }
  | { kind: "authenticated"; url: string; token: string };
```

#### 6. Avoid denormalized data

Duplicating the same information in multiple places creates a trivially representable
illegal state: the copies getting out of sync. Strive for a single source of truth.

If denormalization is necessary for performance, hide it behind an abstraction boundary
where a small, trusted module keeps representations in sync.

#### 7. Parse in multiple passes if needed

Avoiding shotgun parsing means don't *act on* data before it's fully parsed. It doesn't
mean you can't use some input data to decide how to parse other input data.

```ts
// Fine: first parse the header to determine the format, then parse the body
const header = parseHeader(raw);
const body = parseBody(raw, header.format);
```

### Shotgun Parsing -- The Anti-Pattern

Shotgun parsing is when validation code is mixed with and spread across processing code.
Checks are scattered everywhere, hoping to catch all bad cases without systematic
justification.

The danger: if a late-discovered error means some invalid input was already partially
processed, you may need to roll back state changes. This is fragile and error-prone.

Parsing avoids this by stratifying the program into two phases:
1. **Parsing phase** -- failure due to invalid input can only happen here
2. **Execution phase** -- input is known-good, failure modes are minimal

## Boundary Discipline

Place validation, type narrowing, and error handling at system boundaries. Trust internal code unconditionally. Business logic lives in pure functions. The shell is thin and mechanical.

**Why:** Scattered validation is noisy, redundant, and gives a false sense of safety. Keep logic out of framework wiring so it can be tested without the framework.

- **At boundaries** (CLI args, config files, external APIs, network protocols, persisted data): validate, return errors, handle defensively.
- **Inside the system:** typed data, error propagation, no re-validation. Trust the types. No redundant null checks deep in call chains when the boundary already validated.
- **Across a module boundary:** expose domain concepts, not the boundary's private representation. Do not re-export transport, storage, framework, or wire types through the public surface. Keep general-purpose mechanism inside and special-purpose policy at the edge.
- **Code organization:** business logic in pure functions with no framework dependencies. Parsers are pure transforms from raw input to typed state. Prompt and message construction is structured state in, string out. Scoring and assessment are pure transforms from state to results.

**The tests:**
- "Is this data crossing a system boundary right now?" If not, validation is redundant.
- "Can this be a pure function that the shell just calls?" If yes, extract it.

## Code Review Checklist

When reviewing code, watch for these smells:

- [ ] Function accepts `string` where a more specific type exists (URL, email, ID)
- [ ] Validation function returns `void` instead of a refined type
- [ ] Same property checked in multiple places (redundant validation)
- [ ] `// should never happen` or `// impossible` comments
- [ ] Raw `unknown`/`any`/`object` flowing past the system boundary into business logic
- [ ] Boolean fields that could be discriminated unions
- [ ] Optional fields that are actually always present after a certain point
- [ ] Arrays where non-empty arrays are required
- [ ] `null` checks deep in business logic for data validated at entry
- [ ] `as` casts, non-null `!`, or "should never happen" throws marking a type that is too weak
- [ ] A `switch` on a union with no exhaustiveness check in the default arm
- [ ] A hand-written type that duplicates a schema, migration, or generated type
- [ ] Transport, storage, or framework types leaking through a module's public surface
- [ ] Business logic tangled with framework wiring, so it can't be tested without the framework
