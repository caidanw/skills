# Swift for TypeScript/Python Developers

Quick reference mapping familiar concepts to Swift equivalents.

## Variables & Constants

```swift
// Swift                          // TypeScript
let name = "Caidan"              // const name = "Caidan"
var count = 0                    // let count = 0
count += 1                       // count += 1

// Type annotations
let age: Int = 30                // const age: number = 30
var items: [String] = []         // let items: string[] = []
```

**Key swap: Swift `let` = TS `const`. Swift `var` = TS `let`.**

## Functions

```swift
// Swift
func greet(name: String, times: Int = 1) -> String {
    return "Hello, \(name)"
}
greet(name: "World", times: 3)

// TypeScript equivalent
// function greet(name: string, times: number = 1): string {
//     return `Hello, ${name}`
// }
// greet("World", 3)
```

Note: Swift uses **argument labels** by default. Callers must use them. To suppress, use `_`:

```swift
func greet(_ name: String) -> String { ... }
greet("World")  // No label required
```

## Optionals (replaces null/undefined)

```swift
var nickname: String? = nil    // Explicitly optional

// Safe unwrapping (like TS optional chaining, but enforced)
if let nick = nickname {
    print(nick)  // Only runs if non-nil
}

// Guard (early return — use this constantly)
guard let nick = nickname else { return }
print(nick)  // Guaranteed non-nil from here

// Optional chaining (like TS ?.)
let length = nickname?.count

// Nil coalescing (like TS ??)
let display = nickname ?? "Anonymous"

// Force unwrap (like TS non-null assertion !)
let forced = nickname!  // Crashes if nil — avoid unless certain
```

## Closures (Lambdas)

```swift
// Swift                                    // TypeScript
let double = { (x: Int) -> Int in x * 2 }  // const double = (x: number) => x * 2

// Trailing closure syntax (idiomatic Swift):
[1, 2, 3].map { $0 * 2 }     // [1, 2, 3].map(x => x * 2)
[1, 2, 3].filter { $0 > 1 }  // [1, 2, 3].filter(x => x > 1)

// $0, $1, $2 are shorthand for closure parameters
let sorted = names.sorted { $0 < $1 }
```

## Structs vs Classes

```swift
// Struct = value type (copied on assignment, like deeply-cloned objects)
struct Point {
    var x: Double
    var y: Double
}
var a = Point(x: 1, y: 2)
var b = a      // b is a COPY
b.x = 10      // a.x is still 1

// Class = reference type (shared pointer, like normal JS objects)
class Renderer {
    var canvas: Canvas
    init(canvas: Canvas) { self.canvas = canvas }
}
let r1 = Renderer(canvas: myCanvas)
let r2 = r1    // r2 points to SAME instance
```

**Swift strongly prefers structs.** Use classes only for identity-based objects (windows, renderers, shared state).

## Protocols (Interfaces)

```swift
// Swift                                    // TypeScript
protocol Drawable {                         // interface Drawable {
    func draw(in context: CGContext)        //     draw(context: CGContext): void
    var bounds: CGRect { get }              //     readonly bounds: CGRect
}                                           // }

// Default implementations via extensions (like TS mixins, but built-in)
extension Drawable {
    func draw(in context: CGContext) {
        // Default implementation
    }
}
```

## Enums (much more powerful than TS)

```swift
// Associated values — like TS discriminated unions, but built-in
enum NetworkResult {
    case success(Data)
    case failure(Error)
    case loading(progress: Double)
}

// Pattern matching with exhaustive switch
switch result {
case .success(let data):
    process(data)
case .failure(let error):
    handle(error)
case .loading(let progress):
    updateUI(progress)
}
// No default needed — compiler ensures all cases handled
```

## Error Handling

```swift
// Swift uses throws/try/catch (similar to TS but enforced by compiler)
enum AppError: Error {
    case notFound
    case unauthorized
}

func fetchData() throws -> Data {
    throw AppError.notFound
}

// Must handle errors explicitly
do {
    let data = try fetchData()
} catch AppError.notFound {
    print("Not found")
} catch {
    print("Other error: \(error)")
}

// try? converts to optional (returns nil on error)
let data = try? fetchData()

// try! force unwraps (crashes on error — avoid)
let data = try! fetchData()
```

## Async/Await

```swift
// Swift (similar to TS but with actor isolation)
func fetchUser() async throws -> User {
    let data = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data.0)
}

// Calling async functions
Task {
    let user = try await fetchUser()
}

// Actor = thread-safe mutable state container (no TS equivalent)
actor UserStore {
    private var users: [User] = []

    func add(_ user: User) {
        users.append(user)  // Safe — actor serializes access
    }
}
```

## Collections

```swift
// Arrays
var items: [String] = ["a", "b", "c"]  // let items: string[] = ["a", "b", "c"]
items.append("d")                       // items.push("d")
items.count                             // items.length
items.first                             // items[0] (but returns optional)

// Dictionaries (like Map/Record)
var scores: [String: Int] = ["alice": 100, "bob": 85]
scores["alice"]       // Returns Int? (optional!)
scores["carol"] = 90  // Insert/update

// Sets
var tags: Set<String> = ["swift", "metal"]
tags.insert("gpu")
tags.contains("swift")  // true

// For loops
for item in items { ... }                    // for (const item of items) { ... }
for (index, item) in items.enumerated() { }  // items.forEach((item, index) => { })
for i in 0..<5 { }                           // for (let i = 0; i < 5; i++) { }
for i in 0...5 { }                           // for (let i = 0; i <= 5; i++) { }
```

## String Interpolation

```swift
let name = "World"
print("Hello, \(name)")              // console.log(`Hello, ${name}`)
print("Result: \(2 + 3)")           // console.log(`Result: ${2 + 3}`)

// Type conversion is always explicit
let num = 42
print("Answer: " + String(num))     // No implicit conversion
```

## Type System

```swift
// Generics (same concept as TS)
func first<T>(of array: [T]) -> T? {
    return array.first
}

// Where clauses (like TS conditional types, sort of)
func compare<T: Comparable>(_ a: T, _ b: T) -> Bool {
    return a < b
}

// Codable (like Zod + TS types, but built-in runtime validation)
struct User: Codable {
    let name: String
    let age: Int
}
let user = try JSONDecoder().decode(User.self, from: jsonData)
// If JSON doesn't match the struct, it throws — runtime safety!
```

## Package Management (SPM)

```swift
// Package.swift (like package.json but executable Swift)
let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/some/package.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(name: "MyApp", dependencies: ["SomePackage"]),
        .testTarget(name: "MyAppTests", dependencies: ["MyApp"]),
    ]
)
```

- No `node_modules` — dependencies cached globally
- `Package.resolved` = lockfile (like `package-lock.json`)
- `swift build` / `swift run` / `swift test` = build/run/test
