# Explicit value return is safe

## Diff

```diff
 let payload: CommandResult = try await performOnActor {
     audit(command)
     return try command.execute()
 }
 return encode(payload)
```

## Required outcome

- No accidental `Void`, dropped-return, or wrong-overload finding.

## Forbidden findings

- Claiming every multi-statement closure is unsafe.
- Demanding removal of the explicit type or return.
