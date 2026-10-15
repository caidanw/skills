# Test Templates

Terse, behavior-focused templates. Copy and adapt.

---

## Unit Test — Pure Logic

```typescript
import { describe, test, expect } from 'vitest';

describe('validateEmail', () => {
  test.each([
    ['user@example.com', true],
    ['', false],
    ['   ', false],
    [null, false],
    ['no-at-sign', false],
    ['@no-local.com', false],
  ])('validateEmail(%j) → %s', (input, expected) => {
    expect(validateEmail(input)).toBe(expected);
  });
});
```

`test.each` keeps edge cases terse. One table, all boundaries visible at a glance.

---

## Unit Test — Error Handling

```typescript
describe('parseConfig', () => {
  test('throws on missing required field', () => {
    expect(() => parseConfig({})).toThrow('name is required');
  });

  test('throws on invalid type', () => {
    expect(() => parseConfig({ name: 123 })).toThrow('name must be a string');
  });

  test('returns defaults for optional fields', () => {
    const config = parseConfig({ name: 'app' });
    expect(config).toEqual({ name: 'app', port: 3000, debug: false });
  });
});
```

---

## Component Test — Behavior

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

describe('SearchForm', () => {
  test('shows results for valid query', async () => {
    render(<SearchForm />);
    await userEvent.type(screen.getByRole('searchbox'), 'react');
    await userEvent.click(screen.getByRole('button', { name: /search/i }));

    expect(screen.getByText(/results for "react"/i)).toBeVisible();
  });

  test('shows error for empty query', async () => {
    render(<SearchForm />);
    await userEvent.click(screen.getByRole('button', { name: /search/i }));

    expect(screen.getByText(/enter a search term/i)).toBeVisible();
  });

  test('shows loading state', async () => {
    render(<SearchForm />);
    await userEvent.type(screen.getByRole('searchbox'), 'slow query');
    await userEvent.click(screen.getByRole('button', { name: /search/i }));

    expect(screen.getByText(/searching/i)).toBeVisible();
  });
});
```

Note: No mocks. No `expect(fn).toHaveBeenCalled()`. Just what the user sees.

---

## Integration Test — With API Boundary

Mock only at the network boundary. Everything else is real.

```typescript
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  http.get('/api/users/:id', ({ params }) => {
    if (params.id === '404') return HttpResponse.json(null, { status: 404 });
    return HttpResponse.json({ id: params.id, name: 'Alice' });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('UserProfile', () => {
  test('shows user info', async () => {
    render(<UserProfile userId="1" />);
    expect(await screen.findByText('Alice')).toBeVisible();
  });

  test('shows not found for missing user', async () => {
    render(<UserProfile userId="404" />);
    expect(await screen.findByText(/not found/i)).toBeVisible();
  });

  test('shows error on server failure', async () => {
    server.use(http.get('/api/users/:id', () => HttpResponse.error()));
    render(<UserProfile userId="1" />);
    expect(await screen.findByText(/something went wrong/i)).toBeVisible();
  });
});
```

MSW intercepts at the network layer — components, hooks, state management all run for real.

---

## E2E Test — User Journey

```typescript
import { test, expect } from '@playwright/test';

test('complete signup flow', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="email"]', 'new@example.com');
  await page.fill('[name="password"]', 'securePass123');
  await page.click('button:has-text("Create Account")');

  await expect(page.locator('text=Welcome')).toBeVisible({ timeout: 10000 });
});

test('shows validation errors', async ({ page }) => {
  await page.goto('/signup');
  await page.click('button:has-text("Create Account")');

  await expect(page.locator('text=Email is required')).toBeVisible();
  await expect(page.locator('text=Password is required')).toBeVisible();
});

test('prevents duplicate signup', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="email"]', 'existing@example.com');
  await page.fill('[name="password"]', 'pass123');
  await page.click('button:has-text("Create Account")');

  await expect(page.locator('text=already exists')).toBeVisible();
});
```

---

## Test Data Factories

Keep test data creation terse and composable.

```typescript
let id = 0;

export const buildUser = (overrides = {}) => ({
  id: `user-${++id}`,
  email: `test${id}@example.com`,
  name: 'Test User',
  role: 'user',
  ...overrides,
});

export const buildPost = (overrides = {}) => ({
  id: `post-${++id}`,
  title: 'Test Post',
  body: 'Content',
  authorId: `user-1`,
  createdAt: new Date().toISOString(),
  ...overrides,
});

// Usage: buildUser({ role: 'admin' })
```

---

## Setup Helpers

When multiple tests share the same preconditions, extract a helper — but keep it visible.

```typescript
function renderWithAuth(ui: React.ReactElement, user = buildUser()) {
  return render(
    <AuthContext.Provider value={{ user, isAuthenticated: true }}>
      {ui}
    </AuthContext.Provider>
  );
}

// Usage
test('shows admin panel for admin', () => {
  renderWithAuth(<Dashboard />, buildUser({ role: 'admin' }));
  expect(screen.getByText('Admin Panel')).toBeVisible();
});

test('hides admin panel for regular user', () => {
  renderWithAuth(<Dashboard />);
  expect(screen.queryByText('Admin Panel')).not.toBeInTheDocument();
});
```

---

## Python Equivalents

### pytest — Parametrize for Edge Cases

```python
import pytest

@pytest.mark.parametrize("input,expected", [
    ("user@example.com", True),
    ("", False),
    ("   ", False),
    (None, False),
    ("no-at-sign", False),
])
def test_validate_email(input, expected):
    assert validate_email(input) == expected
```

### pytest — Fixtures as Factories

```python
@pytest.fixture
def make_user():
    counter = 0
    def _make(**overrides):
        nonlocal counter
        counter += 1
        return {"id": f"user-{counter}", "name": "Test", "role": "user", **overrides}
    return _make

def test_admin_access(make_user):
    admin = make_user(role="admin")
    assert has_access(admin, "/admin") is True

def test_user_denied(make_user):
    user = make_user()
    assert has_access(user, "/admin") is False
```

### pytest — API Behavior with httpx/respx

```python
import respx
from httpx import Response

@respx.mock
def test_fetch_user():
    respx.get("/api/users/1").mock(return_value=Response(200, json={"name": "Alice"}))
    user = fetch_user(1)
    assert user.name == "Alice"

@respx.mock
def test_fetch_user_not_found():
    respx.get("/api/users/404").mock(return_value=Response(404))
    with pytest.raises(UserNotFoundError):
        fetch_user(404)
```
