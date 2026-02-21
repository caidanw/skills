# Testing Anti-Patterns

Patterns that make tests brittle, verbose, or meaningless. Each one includes a gate function — a check to run before you make the mistake.

---

## 1. Testing Mock Behavior

Asserting that a mock was called, rendered, or exists — instead of asserting on real output.

```typescript
// ❌ Testing the mock
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
});

// ✅ Testing behavior
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByRole('navigation')).toBeInTheDocument();
});
```

**Gate:** Before any assertion on a mock element — ask: "Am I testing real behavior or mock existence?" If mock existence, delete the assertion.

---

## 2. Test-Only Methods in Production Code

Adding `destroy()`, `reset()`, `_forTesting()` to production classes just so tests can call them.

```typescript
// ❌ Production class polluted
class Session {
  async destroy() { /* only tests call this */ }
}

// ✅ Test utility handles cleanup
// test-utils.ts
export async function cleanupSession(session: Session) {
  await workspaceManager.destroyWorkspace(session.id);
}
```

**Gate:** Before adding any method to a production class — ask: "Is this only used by tests?" If yes, put it in test utilities.

---

## 3. Mocking Without Understanding

Mocking something "to be safe" without knowing what side effects the real implementation has. The mock silently removes behavior the test depends on.

```typescript
// ❌ Mock removes config write that test needs
vi.mock('ToolCatalog', () => ({
  discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
}));

test('detects duplicate server', async () => {
  await addServer(config);
  await addServer(config); // Should throw — but mock ate the config write
});

// ✅ Mock only the slow/external part
vi.mock('MCPServerManager'); // Just mock slow server startup
// Config writing still works, duplicate detection works
```

**Gate:** Before mocking anything:
1. What side effects does the real method have?
2. Does this test depend on any of them?
3. If unsure: run the test with the real implementation first, observe what happens, then mock minimally.

**Red flags:** "I'll mock this to be safe." "This might be slow, better mock it." Mocking without reading the source.

---

## 4. Incomplete Mocks

Mocking only the fields you think you need. Downstream code silently breaks on missing fields.

```typescript
// ❌ Partial mock
const mockResponse = {
  status: 'success',
  data: { userId: '123' }
  // Missing: metadata.requestId that downstream code reads
};

// ✅ Complete mock matching real API shape
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' },
  metadata: { requestId: 'req-789', timestamp: 1234567890 }
};
```

**Gate:** Before creating a mock response — check the real API response shape. Include all fields the system might consume downstream, not just the ones your immediate test reads.

---

## 5. Over-Mocking (Mock Setup > Test Logic)

When mock setup takes 20 lines and the actual test is 3 lines, the test is doing too much isolation.

```typescript
// ❌ More ceremony than substance
test('submits form', () => {
  const mockRouter = { push: vi.fn() };
  const mockAuth = { user: { id: '1' }, token: 'abc' };
  const mockApi = { submit: vi.fn().mockResolvedValue({ ok: true }) };
  const mockToast = vi.fn();
  vi.mocked(useRouter).mockReturnValue(mockRouter);
  vi.mocked(useAuth).mockReturnValue(mockAuth);
  vi.mocked(useApi).mockReturnValue(mockApi);
  vi.mocked(useToast).mockReturnValue({ toast: mockToast });

  render(<Form />);
  await userEvent.type(screen.getByLabelText('Name'), 'Alice');
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));

  expect(mockApi.submit).toHaveBeenCalledWith({ name: 'Alice' });
  expect(mockRouter.push).toHaveBeenCalledWith('/success');
});

// ✅ Integration test — simpler and more meaningful
test('submits form and redirects', () => {
  render(<App initialRoute="/form" />);
  await userEvent.type(screen.getByLabelText('Name'), 'Alice');
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));

  expect(screen.getByText('Success')).toBeVisible();
});
```

**Gate:** If mock setup is more than 50% of the test code, step back. Consider an integration test with real components.

---

## 6. Asserting on Implementation, Not Behavior

Testing which functions were called, in what order, with what arguments — rather than what the user sees.

```typescript
// ❌ Implementation-coupled
test('login', async () => {
  await login('user@test.com', 'pass');
  expect(authService.authenticate).toHaveBeenCalledWith('user@test.com', 'pass');
  expect(sessionStore.set).toHaveBeenCalledWith(expect.objectContaining({ token: 'abc' }));
  expect(router.push).toHaveBeenCalledWith('/dashboard');
});

// ✅ Behavior-coupled
test('login redirects to dashboard', async () => {
  render(<LoginPage />);
  await userEvent.type(screen.getByLabelText('Email'), 'user@test.com');
  await userEvent.type(screen.getByLabelText('Password'), 'pass');
  await userEvent.click(screen.getByRole('button', { name: /log in/i }));

  expect(screen.getByText('Dashboard')).toBeVisible();
});
```

**Gate:** For every `expect()` — ask: "Could a user observe this?" If the answer is no, the assertion is testing implementation.

---

## Summary

| Anti-Pattern | One-line fix |
|---|---|
| Testing mock behavior | Assert on real output, not mock existence |
| Test-only production methods | Move to test utilities |
| Mocking without understanding | Run real first, then mock minimally |
| Incomplete mocks | Mirror the real API shape completely |
| Over-mocking | Use integration tests instead |
| Asserting on implementation | Assert on what the user sees |
