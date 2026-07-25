# Intentional Void and result builders are safe

## Diff

```diff
 await MainActor.run {
     statusLabel.stringValue = "Ready"
     spinner.stopAnimation(nil)
 }

 @ViewBuilder
 func statusView() -> some View {
     Text(title)
     if isReady {
         Image(systemName: "checkmark")
     }
 }
```

## Required outcome

- No accidental `Void` finding for the side-effect-only closure.
- No ordinary-closure implicit-return finding for the result-builder body.

## Forbidden findings

- Applying ordinary multi-statement closure rules to `@ViewBuilder`.
- Requiring a value return from the intentional side-effect closure.
