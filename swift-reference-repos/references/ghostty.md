# Ghostty & Ghostling — Terminal Emulator + libghostty

**Ghostty Repo:** `https://github.com/ghostty-org/ghostty.git`
**Ghostling Repo:** `https://github.com/ghostty-org/ghostling.git`
**License:** MIT
**Languages:** Zig (core + libghostty), Swift (macOS app), C (Ghostling demo, API headers)
**Creator:** Mitchell Hashimoto (founder of HashiCorp, creator of Terraform/Vagrant/Vault)
**Stars:** 30k+ (Ghostty)

## What These Repos Are

**Ghostty** is a fast, feature-rich, cross-platform terminal emulator with GPU-accelerated rendering. It uses platform-native UI (AppKit on macOS, GTK on Linux) and Metal/OpenGL for rendering. The architecture is unique: the core is written in Zig and compiled into **libghostty**, an embeddable library with a C API.

**Ghostling** is the official minimal demo of the libghostty-vt C API — a complete (if bare-bones) terminal emulator in ~600 lines of C using Raylib for rendering. It proves you can build a functional terminal on top of libghostty with minimal effort.

**libghostty-vt** is the embeddable zero-dependency library extracted from Ghostty's core. It handles VT sequence parsing, terminal state management, cursor, styles, text reflow, scrollback, and renderer state — everything except actual drawing. Consumers provide their own renderer and windowing.

## When to Use Which

| Goal | Clone |
|------|-------|
| Study production macOS app architecture (Swift + Zig + Metal) | `ghostty` |
| Study how Swift consumes a C library compiled from Zig | `ghostty` → `macos/` |
| Study terminal emulation internals (VT parsing, escape sequences) | `ghostty` → `src/` |
| Build a minimal terminal using libghostty C API | `ghostling` |
| Embed terminal functionality in your own app | Both — `ghostling` for patterns, `ghostty` for production reference |

## Source Map — Ghostty (Full)

```
ghostty/
├── macos/                              ← macOS SWIFT APP
│   ├── Sources/
│   │   ├── App.swift                   ← NSApplicationDelegate, app lifecycle
│   │   ├── AppDelegate.swift           ← Window creation, menu setup
│   │   ├── Ghostty/
│   │   │   ├── SurfaceView.swift       ← NSView subclass hosting terminal surface
│   │   │   ├── SurfaceView+Keyboard.swift ← Keyboard event forwarding to libghostty
│   │   │   ├── SurfaceView+Mouse.swift    ← Mouse event forwarding
│   │   │   ├── TerminalController.swift   ← Window controller managing surfaces
│   │   │   └── Package.swift              ← Swift wrapper around C API types
│   │   └── Helpers/                       ← Utilities, extensions
│   └── Ghostty.xcodeproj
│
├── src/                                ← ZIG CORE (libghostty)
│   ├── terminal/
│   │   ├── Terminal.zig                ← Core terminal state machine
│   │   ├── Parser.zig                  ← VT sequence parser (SIMD-optimized)
│   │   ├── Screen.zig                  ← Screen buffer (cells, scrollback)
│   │   ├── Cell.zig                    ← Individual cell: codepoint + style
│   │   └── stream.zig                  ← Byte stream → parsed sequences
│   │
│   ├── renderer/
│   │   ├── Metal.zig                   ← Metal renderer (macOS)
│   │   ├── OpenGL.zig                  ← OpenGL renderer (Linux)
│   │   └── metal/
│   │       └── shaders.zig             ← Metal shader pipelines, CellText struct
│   │
│   ├── font/                           ← Font discovery, shaping, atlas
│   │   ├── face.zig                    ← Font face loading
│   │   ├── shaper.zig                  ← Text shaping (harfbuzz integration)
│   │   └── atlas.zig                   ← Glyph texture atlas for GPU rendering
│   │
│   ├── Surface.zig                     ← Core surface abstraction
│   ├── apprt/
│   │   ├── embedded.zig                ← Embedded library mode (for Swift app)
│   │   └── gtk.zig                     ← GTK app runtime (Linux)
│   │
│   └── os/                             ← OS abstractions
│       ├── pty.zig                     ← PTY creation and management
│       └── pipe.zig                    ← Inter-process pipe management
│
├── include/
│   └── ghostty.h                       ← C API HEADER — the integration boundary
│
├── examples/                           ← Small C and Zig examples
│   ├── c/                              ← C API usage examples
│   └── zig/                            ← Zig API usage examples
│
└── build.zig                           ← Zig build system
```

## Source Map — Ghostling (Minimal)

```
ghostling/
├── main.c                              ← THE WHOLE THING. ~600 lines of C.
│                                         Creates terminal, handles input,
│                                         renders cells via Raylib.
├── CMakeLists.txt                      ← Build config (CMake + Ninja)
├── build.zig.zon                       ← Zig package dependency (pulls libghostty)
└── README.md                           ← Explains architecture and feature list
```

Ghostling's `main.c` is the single most important file to read if you want to understand the libghostty C API. It demonstrates:

1. Creating a `ghostty_terminal_t`
2. Feeding input bytes via `ghostty_terminal_vt_write()`
3. Reading render state via `ghostty_terminal_render_state()`
4. Iterating rows and cells for drawing
5. Forwarding keyboard input via `ghostty_terminal_key_encode()`
6. Forwarding mouse events
7. Handling resize with text reflow
8. Scrollback buffer with scrollbar

## Key Architectural Patterns

### Pattern 1: Library + App Separation
Ghostty's most important architectural decision: the terminal emulation core (libghostty) is a **library**, not tangled into the app. The macOS app in `macos/` is just one consumer. This means:
- Other apps can embed terminal functionality
- The core can be tested independently
- Platform-specific code stays in thin app layers

### Pattern 2: C API as Integration Boundary
Zig compiles to a static library with C headers. Swift consumes the C API:

```
Zig source → Zig compiler → static library (.a) + C header (.h)
                                        ↓
Swift app imports C header via bridging header or module map
Swift calls C functions directly (no wrapper needed)
```

This is the canonical pattern for embedding any Zig/Rust/C library in a Swift app. Study `include/ghostty.h` for the API surface and `macos/Sources/Ghostty/Package.swift` for how Swift wraps it.

### Pattern 3: Multi-Threaded Terminal Architecture
Each terminal surface runs three threads:

```
Main Thread (AppKit)
├── Event loop
├── Gesture handling
└── Layout

IO Thread (per terminal)
├── PTY read
├── VT sequence parsing
└── Screen state updates

Render Thread (per terminal)
├── Metal command buffer encoding
├── Glyph atlas updates
└── Frame submission
```

Communication between threads uses lock-free ring buffers where possible.

### Pattern 4: Render State Snapshot
libghostty doesn't draw anything. Instead, it maintains a **render state** that consumers can snapshot and draw however they want:

```c
// Get render state (thread-safe snapshot)
ghostty_render_state_t state = ghostty_terminal_render_state(terminal);

// Iterate rows
for (int row = 0; row < state.rows; row++) {
    ghostty_render_row_t* render_row = ghostty_render_state_row(&state, row);
    // Iterate cells in row
    for (int col = 0; col < state.cols; col++) {
        ghostty_render_cell_t* cell = ghostty_render_row_cell(render_row, col);
        // cell->codepoint, cell->fg, cell->bg, cell->flags
        // → draw with your own renderer
    }
}
```

This is how Ghostling renders with Raylib, and how any consumer would render with Metal, OpenGL, Vulkan, or even a web canvas.

### Pattern 5: Metal Multi-Pass Rendering (Ghostty Full)
The full Ghostty app uses a multi-pass Metal pipeline:

```
Pass 1: Background colors    ← Fills cell background rectangles
Pass 2: Cell text             ← Samples glyph atlas, composites text
Pass 3: Cursor                ← Draws cursor overlay
Pass 4: Custom shaders        ← Optional user-provided MSL post-processing
```

Triple-buffered (3 frame states) with semaphore synchronization. Study `src/renderer/Metal.zig` for the full implementation.

### Pattern 6: SIMD-Optimized VT Parsing
The VT parser in `src/terminal/Parser.zig` uses CPU-specific SIMD instructions to scan for escape sequence boundaries in bulk, rather than byte-by-byte. This is one of the key reasons Ghostty matches Alacritty's performance despite being much more feature-rich.

## libghostty-vt Feature List (What You Get for Free)

When you use libghostty-vt, all of these are handled for you:

- Full 24-bit color and 256-color palette
- Bold, italic, underline, strikethrough, inverse, blink text styles
- Unicode with multi-codepoint grapheme cluster support
- Resize with text reflow
- Scrollback buffer
- Kitty keyboard protocol
- Mouse tracking (X10, normal, button, any-event modes)
- Mouse reporting formats (SGR, URxvt, UTF8, X10)
- Focus reporting (CSI I / CSI O)
- Kitty graphics protocol
- Clipboard sequences
- Synchronized rendering
- Light/dark mode notifications
- OSC sequences (window title, colors, etc.)

You are responsible for:
- Windowing and event loop
- Rendering (drawing cells to screen)
- Font loading and glyph rasterization
- PTY management (creating shell process)
- Clipboard integration
- Selection and copy/paste UI
- Tabs, splits, and window management

## Building and Integrating

### Ghostty (full build)
```bash
# Requires Zig 0.15.2+
git clone https://github.com/ghostty-org/ghostty.git
cd ghostty
zig build -Doptimize=ReleaseFast
```

### Ghostling (minimal demo)
```bash
# Requires CMake, Ninja, and a C compiler
git clone https://github.com/ghostty-org/ghostling.git
cd ghostling
cmake -B build -G Ninja
cmake --build build
./build/ghostling
```

### Using libghostty in your own project
The recommended approach as of 2026 is:
1. Clone `ghostty` as a submodule or use as a Zig package dependency
2. Build the `libghostty-vt` target for your platform
3. Link the resulting static library
4. Include `ghostty.h` header
5. Use the C API (see Ghostling for a complete example)

For Swift projects, check if `libghostty-spm` (a prebuilt xcframework package) is available — it provides SPM-compatible distribution.

## Ecosystem Projects Built on libghostty

These repos demonstrate libghostty in different contexts (see `awesome-libghostty`):

- **Kytos** — macOS terminal emulator built on libghostty + KelyphosKit
- **OpenOwl** — macOS native Git GUI with embedded terminal (Swift + libghostty + Metal)
- **Factory Floor** — macOS workspace for parallel dev with git worktrees + Claude Code agents
- **Supacode** — macOS command center for running coding agents in parallel
- **browstty** — Zig WASM module running libghostty in the browser
- **vscode-bootty** — VS Code terminal extension powered by libghostty WASM
- **libghostty-rs** — Rust bindings with a Rust port of Ghostling
