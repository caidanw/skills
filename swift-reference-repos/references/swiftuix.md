# SwiftUIX — Exhaustive SwiftUI Component Library

**Repo:** `https://github.com/SwiftUIX/SwiftUIX.git`
**License:** MIT
**Language:** Swift (100%)
**Platforms:** iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+
**Dependencies:** None
**SPM:** `.package(url: "https://github.com/SwiftUIX/SwiftUIX.git", branch: "master")`
**Maintainer:** Vatsal Manot (@vatsal_manot) + 61 contributors

## What This Repo Is

SwiftUIX is the most comprehensive open-source extension to Apple's SwiftUI framework. It fills gaps where SwiftUI lacks native components by bridging UIKit (iOS) and AppKit (macOS) functionality into SwiftUI-compatible views. With ~8,000 stars and 2,259+ commits, it's the de facto standard for production SwiftUI apps that need more than Apple provides out of the box.

The repo is not a UI kit with its own design language — it extends SwiftUI's native look and feel with missing functionality. Think of it as "the SwiftUI standard library, expanded."

## Source Map — Read These First

```
SwiftUIX/
├── Sources/
│   ├── _SwiftUIX/                    ← Internal utilities and extensions
│   │   ├── Intermodular/
│   │   │   └── Extensions/
│   │   │       ├── AppKit or UIKit/  ← Cross-platform AppKit/UIKit abstractions
│   │   │       ├── CoreGraphics/     ← CGRect, CGPoint, CGSize extensions
│   │   │       ├── Foundation/       ← String, URL, Data extensions
│   │   │       └── Swift/           ← Standard library extensions
│   │   └── Intramodular/
│   │       ├── Bridging/            ← AppKitOrUIKitView type aliases
│   │       └── Miscellaneous/       ← Shared utilities
│   │
│   └── SwiftUIX/                     ← Public API
│       └── Intramodular/
│           ├── Collection View/      ← CollectionView (missing from SwiftUI)
│           ├── Text/                 ← AttributedText, TextView, CocoaTextField
│           ├── Navigation/           ← Coordinator, NavigationView extensions
│           ├── Presentation/         ← Popover, Sheet, ActionSheet extensions
│           ├── Search/               ← SearchBar (native wrapper)
│           ├── Scroll View/          ← ScrollView extensions, pagination
│           ├── Keyboard/             ← Keyboard avoidance, dismissal
│           ├── Activity Indicator/   ← ActivityIndicator (UIActivityIndicatorView)
│           ├── Image/                ← ImagePicker, image processing
│           ├── Visual Effect/        ← VisualEffectBlurView
│           ├── Window/               ← Window management helpers
│           └── General Helpers/      ← View extensions, conditionals
│
├── Package.swift
└── Tests/
```

## Key Architectural Patterns

### Pattern 1: Cross-Platform Type Aliases
The foundational pattern in SwiftUIX. Instead of `#if os(macOS)` everywhere, it defines unified type aliases:

```swift
#if os(macOS)
public typealias AppKitOrUIKitView = NSView
public typealias AppKitOrUIKitViewController = NSViewController
public typealias AppKitOrUIKitWindow = NSWindow
public typealias AppKitOrUIKitColor = NSColor
public typealias AppKitOrUIKitFont = NSFont
public typealias AppKitOrUIKitImage = NSImage
#else
public typealias AppKitOrUIKitView = UIView
public typealias AppKitOrUIKitViewController = UIViewController
public typealias AppKitOrUIKitWindow = UIWindow
public typealias AppKitOrUIKitColor = UIColor
public typealias AppKitOrUIKitFont = UIFont
public typealias AppKitOrUIKitImage = UIImage
#endif
```

All internal code then uses `AppKitOrUIKitView` etc. This is the go-to pattern for writing cross-platform Swift code. **Study and adopt this pattern** for any library that targets both macOS and iOS.

### Pattern 2: Representable Wrappers
SwiftUIX wraps UIKit/AppKit views into SwiftUI using `UIViewRepresentable` (iOS) / `NSViewRepresentable` (macOS). The general pattern:

```swift
public struct CocoaTextField: View {
    #if os(macOS)
    typealias Representable = _NSTextField
    #else
    typealias Representable = _UITextField
    #endif

    // ... configuration properties ...

    public var body: some View {
        Representable(/* pass config */)
    }
}

#if os(macOS)
struct _NSTextField: NSViewRepresentable {
    func makeNSView(context: Context) -> NSTextField { /* ... */ }
    func updateNSView(_ nsView: NSTextField, context: Context) { /* ... */ }
}
#else
struct _UITextField: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextField { /* ... */ }
    func updateUIView(_ uiView: UITextField, context: Context) { /* ... */ }
}
#endif
```

### Pattern 3: View Extension API
SwiftUIX adds functionality via `View` extensions, keeping the API surface SwiftUI-idiomatic:

```swift
// Visibility control
someView.visible(condition)

// Keyboard
someView.dismissKeyboardOnTap()

// Navigation
someView.onDismiss { /* ... */ }
```

### Pattern 4: Conditional Compilation with Feature Flags
Throughout the codebase, availability checks gate features:

```swift
@available(macOS 12.0, iOS 15.0, *)
extension View {
    public func searchable(text: Binding<String>) -> some View { /* ... */ }
}
```

This lets SwiftUIX support older deployment targets while still offering newer features where available.

### Pattern 5: Coordinator Pattern for Complex State
For views with complex internal state (text editors, collection views), SwiftUIX uses the `Coordinator` pattern where the coordinator holds mutable state and delegates:

```swift
class Coordinator: NSObject, NSTextViewDelegate {
    var parent: SomeRepresentable
    // Handles two-way binding between SwiftUI state and AppKit/UIKit
}
```

## Most Useful Components to Study

### CollectionView
SwiftUI has no built-in `UICollectionView` equivalent with custom layouts. SwiftUIX provides one. Study `Sources/SwiftUIX/Intramodular/Collection View/` for the full implementation — it's a masterclass in wrapping a complex UIKit view for SwiftUI.

### CocoaTextField / TextView
SwiftUI's native `TextField` is limited. SwiftUIX's `CocoaTextField` wraps `NSTextField`/`UITextField` with full feature access (secure entry, return key handling, focus control). The `TextView` wraps `NSTextView`/`UITextView` for multi-line rich text.

### VisualEffectBlurView
Wraps `NSVisualEffectView` (macOS) / `UIVisualEffectView` (iOS) for material blur effects that SwiftUI doesn't expose directly.

### ActivityIndicator
Simple but demonstrates the representable pattern cleanly. Good starter file to read.

### SearchBar
Wraps `UISearchBar` for iOS (SwiftUI's `.searchable` wasn't available until iOS 15). Shows how to bridge delegate-based APIs into SwiftUI bindings.

## Adapting for Your Use Case

SwiftUIX is most valuable as:

1. **A dependency** — Just add it to your SPM manifest and use the components directly. This is the intended use case.
2. **A pattern library** — Study how it bridges AppKit/UIKit for your own custom components. The cross-platform type alias pattern alone is worth cloning the repo for.
3. **A gap reference** — When SwiftUI can't do something, check SwiftUIX first. If they've solved it, study their approach even if you don't use their code.

### Key Files for Specific Needs

| Need | Study These |
|------|------------|
| Wrapping AppKit views for SwiftUI | Any file in `Intramodular/Text/` |
| Cross-platform macOS + iOS | `_SwiftUIX/Intermodular/Extensions/AppKit or UIKit/` |
| Collection view / grid layouts | `Intramodular/Collection View/` |
| View visibility / conditional rendering | `View.visible()` extension |
| Keyboard handling on macOS | `Intramodular/Keyboard/` |
| Window management | `Intramodular/Window/` |
| Popover / sheet improvements | `Intramodular/Presentation/` |
