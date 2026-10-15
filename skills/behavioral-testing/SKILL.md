---
name: behavioral-testing
description: >
  Behavioral testing methodology — test what users experience, not how code is structured.
  Use when writing tests, reviewing test quality, planning test strategy for new features,
  or when existing tests are brittle/verbose/coupled to implementation details.
  Pairs with the `tdd` skill when working test-first.
  Triggers: writing tests, test review, "tests keep breaking", "too many mocks",
  "tests are verbose", "is this test any good", test coverage planning.
---

# Behavioral Testing

Test observable behavior. Keep tests terse. Never test implementation details.

## Core Laws

```
1. Test what the user sees, not how the code works
2. If a refactor breaks a test, the test was wrong
3. Mocks isolate — they are never the thing being tested
4. Every assertion must trace to a user-observable outcome
5. Terse tests > thorough ceremony
```

## Writing Tests

### The Pattern

```
Arrange: Set up the minimum preconditions
Act:     Do the thing the user would do
Assert:  Check what the user would see
```

No verbose setup. If test setup is longer than the assertion, something is wrong.

### What to Test

Test **behavior at boundaries**, not every line of code:

| Always test | Skip |
|-------------|------|
| What happens with empty/null/whitespace input | Internal method call order |
| Error messages users see | Which helper function was called |
| State transitions (loading → success → error) | Implementation details of state management |
| API failure recovery | Mock call counts (unless it IS the behavior) |
| Edge cases users will hit | Happy-path-only coverage |

### Test Naming

Name tests after the behavior, not the function:

```
✅ "shows error when email is empty"
✅ "redirects to login after session expires"
✅ "prevents duplicate submission on double-click"

❌ "test validateEmail"
❌ "test handleSubmit calls api"
❌ "test useAuth hook returns null"
```

### Keep Tests Terse

```typescript
// ✅ Terse — tests one behavior, reads in 3 seconds
test('shows error when email is empty', async () => {
  render(<LoginForm />);
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));
  expect(screen.getByText('Email is required')).toBeVisible();
});

// ❌ Verbose — ceremony obscures intent
test('should display an error message when the user submits the form without entering an email address', async () => {
  const mockOnSubmit = vi.fn();
  const mockOnError = vi.fn();
  const { container } = render(
    <LoginForm onSubmit={mockOnSubmit} onError={mockOnError} />
  );
  const form = container.querySelector('form');
  const button = screen.getByRole('button', { name: /submit/i });
  await userEvent.click(button);
  expect(mockOnSubmit).not.toHaveBeenCalled();
  expect(mockOnError).toHaveBeenCalledWith(expect.objectContaining({ field: 'email' }));
  expect(screen.getByText('Email is required')).toBeVisible();
});
```

The terse test catches the same bug. The verbose test also asserts on mock internals — those assertions break when you refactor, even if behavior is unchanged.

## Stop Checks

Before writing or reviewing any test, run these checks:

```
□ Am I asserting on a mock instead of real output?
  → If yes: delete the assertion or unmock it

□ Would a refactor break this test even though behavior hasn't changed?
  → If yes: the test is coupled to implementation — rewrite it

□ Is mock setup > 50% of the test?
  → If yes: use an integration test with real components instead

□ Does this test name describe a user-visible behavior?
  → If no: rename it or question whether it needs to exist

□ Did I write this test after the implementation?
  → If yes: verify it actually fails when behavior is broken, not just when code changes

□ Would this test still pass if every function it imports returned undefined or a wrong value?
  → If yes: the assertion is too loose. Call the subject with one concrete input and assert
    the literal output or effect. Tells: toBeDefined, toBeTruthy, not.toThrow,
    toHaveBeenCalled alone, an expected value computed by the code under test,
    or a restated constant
```

## Regression Tests for Bugs

When a bug has a clear, cheap test path, make the broken behavior executable before you change production code.

1. Pick the narrowest check the codebase already uses for that path (unit, component, integration).
2. Write the smallest test that would have caught the bug. It encodes the intended behavior, not the current implementation.
3. Run it before the fix and confirm it fails for the intended reason. If it passes, or fails for another reason, fix the test first.
4. Make the smallest fix, rerun, and confirm it passes. Report the failing-before and passing-after output.

Don't force a test when the path needs broad harness setup, brittle mocks, slow end-to-end infrastructure, production-only state, vague repro steps, or large fixture churn. Use the closest executable check instead (a targeted script, a repro command, browser automation, a log assertion) and say why. No new test beats a bad test.

Never change a test to match a wrong implementation, and never weaken an existing assertion unless the intended behavior changed. If the bug is flaky, make the test deterministic and name the signal it locks down.

## When to Mock

**Mock external boundaries only.** Network calls, third-party services, timers — things outside your control.

**Never mock** internal modules, components you own, or "just to be safe."

If you need to mock something you own to test it, the design has a coupling problem. Fix the design, not the test.

## Detailed References

Load these only when needed:

- **[references/anti-patterns.md](references/anti-patterns.md)** — Common testing mistakes with examples: testing mock behavior, test-only production methods, incomplete mocks, over-mocking
- **[references/test-templates.md](references/test-templates.md)** — Copy-paste test patterns for unit, integration, and E2E tests. Factories, helpers, and terse assertion patterns
- **[references/branch-coverage.md](references/branch-coverage.md)** — Branch matrix methodology for systematic coverage: how to map conditions, prioritize, and verify completeness without testing every permutation
