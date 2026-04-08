---
name: swift-reference-repos
description: "Curated Swift/macOS reference repositories for flow-based node graph UIs (AudioKit/Flow), SwiftUI component patterns (SwiftUIX), and terminal emulator embedding (Ghostty + Ghostling/libghostty). Use this skill when: building node-based visual editors or flow programming UIs in Swift, needing SwiftUI component examples or gap-filling patterns for macOS/iOS, embedding terminal emulators via libghostty, looking for exemplary Swift codebases to study or clone as scaffolding, or needing to understand how production-grade Swift projects structure their code. Also trigger when the user mentions 'clone a reference repo', 'node editor in Swift', 'SwiftUI component library', 'libghostty', 'Ghostling', 'AudioKit Flow', or asks for Swift architectural patterns. This skill is designed to be used by coding agents that need to clone and study these repos as working references."
---

# Swift Reference Repositories

Three curated, production-quality Swift repositories that serve as architectural references and clonable scaffolding for macOS/iOS development. Each repo is MIT-licensed and actively maintained.

## Quick Reference

| Repo | Purpose | Clone URL | Stars | License |
|------|---------|-----------|-------|---------|
| AudioKit/Flow | SwiftUI node graph editor | `https://github.com/AudioKit/Flow.git` | ~388 | MIT |
| SwiftUIX/SwiftUIX | SwiftUI component library | `https://github.com/SwiftUIX/SwiftUIX.git` | ~7,947 | MIT |
| ghostty-org/ghostty | Terminal emulator + libghostty | `https://github.com/ghostty-org/ghostty.git` | ~30k+ | MIT |
| ghostty-org/ghostling | Minimal libghostty C API demo | `https://github.com/ghostty-org/ghostling.git` | new | MIT |

## When to Clone Each Repo

### AudioKit/Flow — Flow-Based Programming UI
**Clone when:** Building any node-based visual editor, signal flow diagram, data pipeline visualizer, workflow builder, or visual programming environment in Swift/SwiftUI.

```bash
git clone https://github.com/AudioKit/Flow.git
```

**What you'll learn:** Read `references/audiokit-flow.md` for detailed architecture.

Key patterns this repo teaches:
- SwiftUI node graph rendering with draggable nodes and wire connections
- `Patch` / `Node` / `Wire` data model for representing directed graphs
- Hit testing and interaction on a canvas of connected nodes
- Recursive layout algorithms for auto-positioning node graphs
- SPM package structure for a reusable SwiftUI component

### SwiftUIX/SwiftUIX — Component Library
**Clone when:** You need SwiftUI components that Apple hasn't shipped yet, want to study how to bridge UIKit/AppKit into SwiftUI properly, or need patterns for building a cross-platform component library.

```bash
git clone https://github.com/SwiftUIX/SwiftUIX.git
```

**What you'll learn:** Read `references/swiftuix.md` for detailed architecture.

Key patterns this repo teaches:
- Bridging AppKit (`NSView`) and UIKit (`UIView`) into SwiftUI via `NSViewRepresentable`/`UIViewRepresentable`
- Cross-platform abstractions that compile for iOS, macOS, tvOS, watchOS, and visionOS
- Missing SwiftUI components: collection views, attributed text, activity views, popovers, search bars
- Extension patterns for adding functionality to existing SwiftUI views
- Proper SPM packaging for a large, multi-platform library

### Ghostty — Terminal Emulator & libghostty
**Clone when:** Building anything that embeds a terminal, needs VT sequence parsing, requires GPU-accelerated text rendering, or wants to study a world-class Zig + Swift + Metal architecture.

```bash
# Full terminal emulator (Zig + Swift + Metal)
git clone https://github.com/ghostty-org/ghostty.git

# Minimal libghostty-vt demo (~600 lines of C)
git clone https://github.com/ghostty-org/ghostling.git
```

**What you'll learn:** Read `references/ghostty.md` for detailed architecture.

Key patterns these repos teach:
- **Ghostty (full):** Production Swift app consuming a Zig-compiled C library, multi-threaded terminal architecture (IO thread + render thread per surface), Metal rendering pipeline with multi-pass compositing, macOS app lifecycle in Swift/AppKit
- **Ghostling (minimal):** How to consume the libghostty-vt C API in ~600 lines, zero-dependency terminal emulation, render state management without opinions about GUI framework
- **libghostty-vt:** Embeddable terminal emulation library with C API, SIMD-optimized VT parsing, complete Unicode/grapheme support, Kitty keyboard protocol, mouse tracking

---

## Agent Workflow: Cloning and Using References

When a coding agent needs to reference these repos, follow this workflow:

### 1. Clone to a working directory
```bash
# Clone only what you need — don't clone all three unless required
git clone --depth 1 https://github.com/AudioKit/Flow.git /tmp/ref-audiokit-flow
git clone --depth 1 https://github.com/SwiftUIX/SwiftUIX.git /tmp/ref-swiftuix
git clone --depth 1 https://github.com/ghostty-org/ghostty.git /tmp/ref-ghostty
git clone --depth 1 https://github.com/ghostty-org/ghostling.git /tmp/ref-ghostling
```

Use `--depth 1` for shallow clones to save time and space. These are reference repos, not forks.

### 2. Study the relevant files
Each reference doc in `references/` includes a **Source Map** section listing the most important files to read first. Start there, not with a full directory listing.

### 3. Adapt, don't copy
These repos are MIT-licensed, but the point is to learn patterns and adapt them, not wholesale copy. Study the architecture, understand the decisions, then implement your own version informed by what you learned.

---

## Dependency: Adding as Swift Packages

If you want to use these as dependencies rather than just references:

```swift
// Package.swift
dependencies: [
    // AudioKit/Flow — node graph editor component
    .package(url: "https://github.com/AudioKit/Flow.git", from: "1.0.4"),

    // SwiftUIX — comprehensive SwiftUI extensions
    .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", branch: "master"),
]
```

Ghostty/libghostty is not yet available as a standard SPM package. See `references/ghostty.md` for integration options.

---

## Ecosystem: Related Repos Worth Knowing

These didn't make the primary three but are valuable adjacent references:

- **awesome-libghostty** (`github.com/Uzaaft/awesome-libghostty`): Community catalog of projects built on libghostty
- **AudioKit/Controls** (`github.com/AudioKit/Controls`): SwiftUI knobs, sliders, XY pads — companion to Flow
- **AudioKit/Keyboard** (`github.com/AudioKit/Keyboard`): SwiftUI music keyboard
- **OpenSwiftUIProject/OpenSwiftUI** (`github.com/OpenSwiftUIProject/OpenSwiftUI`): Open-source reimplementation of Apple's SwiftUI internals — useful for understanding how SwiftUI works under the hood
- **libghostty-rs** (`github.com/Uzaaft/libghostty-rs`): Rust bindings for libghostty, useful if building cross-language tooling
