# Branch Coverage

Systematic approach to ensuring every user-reachable code path is tested — without testing every permutation.

---

## Branch Matrix

For any feature or change, map the conditions that affect behavior:

```markdown
| ID  | Condition              | True                 | False              | Priority |
|-----|------------------------|----------------------|--------------------|:--------:|
| B01 | user is authenticated  | Show dashboard       | Redirect to login  | P0       |
| B02 | input is empty         | Show validation error| Process input      | P0       |
| B03 | API returns 200        | Show result          | Show error         | P0       |
| B04 | API returns 500        | Show retry option    | -                  | P0       |
| B05 | credits >= required    | Proceed              | Show upgrade prompt| P1       |
| B06 | credits == exactly 0   | Boundary: show empty | -                  | P1       |
```

**Priority guide:**
- **P0** — Test on every commit. Auth, empty inputs, API success/failure, core happy path.
- **P1** — Test before merge. Boundaries, credit limits, permission edges.
- **P2** — Test before release. Rare combos, edge UX (back button, refresh mid-action).
- **P3** — Periodic. Load testing, chaos scenarios.

---

## Must-Test Branches (Quick Reference)

| Category | Values to test |
|----------|---------------|
| **Empty values** | `null`, `undefined`, `""`, `"   "` (whitespace), `[]`, `{}` |
| **Boundaries** | min-1, min, min+1, max-1, max, max+1 |
| **Auth states** | Logged in, logged out, session expired, loading |
| **API responses** | 200+data, 200+empty, 400, 401, 403, 404, 500, timeout, offline |
| **User chaos** | Double-click, rapid navigation, refresh mid-action, back button |

### The Whitespace Trap

Most common production bug. Whitespace strings are truthy in JavaScript:

```javascript
// ❌ Whitespace "   " passes this check
if (!text) throw new Error('Required');

// ✅ Catches whitespace
if (!text?.trim()) throw new Error('Required');
```

Always test whitespace-only input separately from empty string.

---

## Handling Combinatorial Explosion

Not every combination of conditions needs a test. Prioritize:

**P0 — Test all independently:**
- Happy path (all conditions true)
- Each condition's false branch in isolation

**P1 — Test common combinations:**
- Business-critical combos (e.g., free user + no credits + API error)
- Conditions that interact (e.g., auth expired + form unsaved)

**Skip:**
- Logically impossible combos (e.g., not authenticated + premium features)
- Combos already covered implicitly by other tests

### Example: 4 conditions = 16 combos, but only ~8 tests needed

```
Conditions: Auth, Permission, Data exists, Network OK

P0 (must test):
  ✅ All true → happy path
  ✅ Auth=false → redirect (others irrelevant)
  ✅ Permission=false → 403
  ✅ Data=false → 404
  ✅ Network=false → offline error

P1 (important combos):
  ✅ Auth + Permission + No data → empty state
  ✅ Auth + Permission + Data + Slow network → loading state
  ✅ Auth + No permission + Data → 403 with context

Skipped (8 combos):
  No auth + anything else → already covered by auth=false test
```

---

## Context Setup Pattern

Every test must make its preconditions explicit. No implicit state.

```typescript
// ✅ Clear context
describe('Upload feature', () => {
  describe('when authenticated with sufficient credits', () => {
    beforeEach(() => {
      setupAuth({ user: { id: '1' } });
      setupCredits({ amount: 100 });
    });

    test('processes upload and shows result', async () => { /* ... */ });
  });

  describe('when credits are insufficient', () => {
    beforeEach(() => {
      setupAuth({ user: { id: '1' } });
      setupCredits({ amount: 0 });
    });

    test('shows upgrade prompt', async () => { /* ... */ });
  });
});

// ❌ Unclear what state the test runs in
describe('Upload', () => {
  test('should work', async () => {
    // What auth state? What credits? What network? Who knows.
  });
});
```

---

## Verification Checklist

Before shipping, verify matrix completion:

```
□ All P0 branches have passing tests
□ All P1 branches have passing tests
□ No untested error paths
□ Empty/null/whitespace inputs tested separately
□ API failure + recovery tested
□ At least one "user chaos" scenario tested (double-click, refresh, back button)
```

---

## Error Paths Are Half the Code

```
Typical code distribution:
  Happy path:     ~30%
  Error handling:  ~40%
  Edge cases:      ~20%
  Validation:      ~10%

Test coverage should roughly match this distribution.
```

If all your tests are happy-path, you've tested 30% of the behavior. The bugs live in the other 70%.
