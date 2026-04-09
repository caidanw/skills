# WKWebView Embedding Patterns for macOS Desktop Apps

This reference covers patterns for embedding WKWebView instances into macOS AppKit applications — specifically for canvas-style compositors where web views are child views within a larger native layout.

## Core: Creating a WKWebView in AppKit

```swift
import WebKit

class EmbeddedWebView: NSView {
    private var webView: WKWebView!

    override init(frame: NSRect) {
        super.init(frame: frame)

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled") // Web Inspector

        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
    }

    func loadURL(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func loadHTML(_ html: String, baseURL: URL? = nil) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    required init?(coder: NSCoder) { fatalError() }
}
```

## Swift → JavaScript Communication

Use `evaluateJavaScript(_:)` to call into web content:

```swift
// Simple evaluation
webView.evaluateJavaScript("document.title") { result, error in
    if let title = result as? String {
        print("Page title: \(title)")
    }
}

// Calling a function with arguments (JSON-serialize for safety)
func sendToJS(event: String, data: [String: Any]) {
    guard let json = try? JSONSerialization.data(withJSONObject: data),
          let jsonString = String(data: json, encoding: .utf8) else { return }

    let js = "window.onNativeEvent('\(event)', \(jsonString))"
    webView.evaluateJavaScript(js)
}

// Async/await version (macOS 12+)
func getPageTitle() async throws -> String {
    let result = try await webView.evaluateJavaScript("document.title")
    return result as? String ?? ""
}
```

## JavaScript → Swift Communication

Use `WKScriptMessageHandler` to receive messages from JavaScript:

```swift
class WebBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "resize":
            let width = body["width"] as? CGFloat ?? 0
            let height = body["height"] as? CGFloat ?? 0
            handleResize(width: width, height: height)
        case "navigate":
            let url = body["url"] as? String ?? ""
            handleNavigation(url: url)
        default:
            break
        }
    }
}

// Registration (during WKWebView setup)
let bridge = WebBridge()
let contentController = WKUserContentController()
contentController.add(bridge, name: "native")  // JS: window.webkit.messageHandlers.native

let config = WKWebViewConfiguration()
config.userContentController = contentController
let webView = WKWebView(frame: .zero, configuration: config)
```

JavaScript side:
```javascript
// Send message to Swift
window.webkit.messageHandlers.native.postMessage({
    action: "resize",
    width: 800,
    height: 600
});
```

## Injecting JavaScript at Page Load

Use `WKUserScript` to inject code before or after page content loads:

```swift
let js = """
    window.nativeBridge = {
        send: function(action, data) {
            window.webkit.messageHandlers.native.postMessage({
                action: action,
                ...data
            });
        }
    };
    console.log('Native bridge initialized');
"""

let script = WKUserScript(
    source: js,
    injectionTime: .atDocumentStart,  // or .atDocumentEnd
    forMainFrameOnly: true
)
config.userContentController.addUserScript(script)
```

## Multiple WKWebViews in a Layout

When embedding multiple web views in a compositor/canvas:

### Process Pooling

Share a `WKProcessPool` across related web views to reduce memory usage:

```swift
class WebViewManager {
    static let shared = WebViewManager()
    let processPool = WKProcessPool()

    func makeWebView(frame: NSRect) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = processPool  // Share process pool
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return WKWebView(frame: frame, configuration: config)
    }
}
```

### Lifecycle Management

WKWebView is expensive. Manage lifecycle carefully:

```swift
class CanvasWebTile: NSView {
    private var webView: WKWebView?
    private var snapshot: NSImage?
    private var isActive = false

    // Create web view only when tile becomes visible/active
    func activate() {
        guard !isActive else { return }
        isActive = true
        webView = WebViewManager.shared.makeWebView(frame: bounds)
        webView!.autoresizingMask = [.width, .height]
        addSubview(webView!)
        // Restore from snapshot URL if we had one
    }

    // Tear down web view when tile goes offscreen
    func deactivate() {
        guard isActive else { return }
        // Take snapshot first for thumbnail rendering
        webView?.takeSnapshot(with: nil) { [weak self] image, _ in
            self?.snapshot = image
        }
        webView?.removeFromSuperview()
        webView = nil
        isActive = false
    }
}
```

## WKWebView in SwiftUI (NSViewRepresentable)

For hybrid AppKit+SwiftUI apps:

```swift
struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var title: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if webView.url != url {
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.title = webView.title ?? ""
        }
    }
}
```

## Custom URL Scheme Handling

Intercept requests to serve local content:

```swift
class LocalContentHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == "app" else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        // Resolve local file from URL path
        let path = url.path
        let fileURL = Bundle.main.url(forResource: path, withExtension: nil)

        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            let mimeType = mimeTypeForPath(path)
            let response = URLResponse(url: url, mimeType: mimeType,
                                       expectedContentLength: data.count,
                                       textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

// Register during config
let config = WKWebViewConfiguration()
config.setURLSchemeHandler(LocalContentHandler(), forURLScheme: "app")
// Now web content can load: app:///styles.css, app:///script.js, etc.
```

## Keyboard and Focus Management

WKWebView and AppKit first-responder chain can conflict. Handle explicitly:

```swift
class CompositorView: NSView {
    var activeWebView: WKWebView?

    // When user clicks a web tile, make it first responder
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let tile = tileAt(point), let webView = tile.webView {
            activeWebView = webView
            window?.makeFirstResponder(webView)
        }
    }

    // Forward keyboard shortcuts that the web view shouldn't eat
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for app-level shortcuts first (Cmd+W, Cmd+T, etc.)
        if isAppShortcut(event) {
            return handleAppShortcut(event)
        }
        // Otherwise let the web view handle it
        return super.performKeyEquivalent(with: event)
    }
}
```

## Web Inspector for Debugging

Enable Safari Web Inspector for embedded WKWebViews:

```swift
// In WKWebView configuration
config.preferences.setValue(true, forKey: "developerExtrasEnabled")

// macOS 13.3+ (official API)
if #available(macOS 13.3, *) {
    webView.isInspectable = true
}
```

Then open Safari → Develop → [Your App Name] → [Web View] to inspect.

## Reference Repos for WKWebView Patterns

| Repo | What It Shows |
|------|---------------|
| `kfix/MacPin` | Full WKWebView webapp container with NSTabViewController + JavaScriptCore bridge |
| `HazAT/glimpse` | Native macOS WKWebView micro-windows with bidirectional JSON messaging |
| `danielsaidi/WebViewKit` | Clean cross-platform WKWebView SwiftUI wrapper |
| `oscartbeaumont/NativeKit` | WKWebView with WKUserContentController for JS↔Swift bridge |
| `markbattistella/BrowserKit` | WKWebView + SFSafariViewController SwiftUI integration |
