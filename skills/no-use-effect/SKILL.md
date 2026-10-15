---
name: no-use-effect
description: >-
  Prevent unnecessary React `useEffect` usage by steering code toward derived state,
  event handlers, memoization, `key`-based resets, `useSyncExternalStore`, and
  framework or query-library data APIs. Use when writing or reviewing React/Next.js
  components, refactoring effect-heavy code, or when a change introduces `useEffect`,
  `useLayoutEffect`, or dependency-array churn. Triggers on: "avoid useEffect",
  "remove useEffect", "you might not need an effect", "effect dependencies",
  "derived state", "React side effects".
---

# No useEffect

Treat raw `useEffect` as a last resort, not a default tool. Most component logic belongs in
render, event handlers, framework data APIs, or narrower React primitives.

This skill is based primarily on the React docs (`You Might Not Need an Effect`,
`Synchronizing with Effects`, `Removing Effect Dependencies`), with supporting guidance from
Dan Abramov, Kent C. Dodds, TkDodo, and team practices that ban or heavily restrict raw
`useEffect`.

## Core Rule

Before adding an Effect, answer this question:

"What external system am I synchronizing with, and why can't this be done during render,
in an event handler, or with a more specific primitive?"

If you cannot name the external system, do not write the Effect.

External systems include:
- browser APIs and DOM subscriptions
- timers, sockets, observers, media APIs
- third-party widgets and imperative libraries
- network synchronization that truly happens because the component is visible

Not external systems:
- derived values from props or state
- event-driven actions like submit, save, buy, delete, notify
- resetting local state because props changed
- chaining state updates to trigger more state updates
- passing data upward just because a child rendered

## Replacement Patterns

### 1. Derive during render

Do not mirror props or state into more state.

```tsx
// Bad
const [fullName, setFullName] = useState("");
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);

// Good
const fullName = `${firstName} ${lastName}`;
```

Use this for filtered lists, labels, counts, booleans, selected objects, and other values that
can be computed from current inputs.

### 2. Memoize expensive pure work

If the calculation is slow, cache it with `useMemo`. Do not use an Effect that immediately
calls `setState` with a computed value.

```tsx
const visibleTodos = useMemo(() => getVisibleTodos(todos, filter), [todos, filter]);
```

First ask whether the work is actually expensive. If not, calculate it directly during render.

### 3. Put user actions in event handlers

If the code runs because the user clicked, submitted, selected, dragged, or typed, keep it in
the corresponding handler.

```tsx
// Bad
useEffect(() => {
  if (shouldSubmit) {
    void saveForm(form);
  }
}, [shouldSubmit, form]);

// Good
async function handleSubmit() {
  await saveForm(form);
}
```

Never build "set flag -> Effect notices flag -> Effect does the real work" flows unless the
flag is synchronizing with a real external system.

### 4. Reset identity with `key` when you want a fresh instance

If a component should become a brand-new instance when some identity changes, give it a
different `key`. React will unmount the old subtree and mount a new one, which resets all local
state below that point without an Effect.

```tsx
// Bad
function Profile({ userId }: { userId: string }) {
  const [comment, setComment] = useState("");

  useEffect(() => {
    setComment("");
  }, [userId]);

  return <input value={comment} onChange={(e) => setComment(e.target.value)} />;
}

// Good
function ProfilePage({ userId }: { userId: string }) {
  return <Profile key={userId} userId={userId} />;
}

function Profile({ userId }: { userId: string }) {
  const [comment, setComment] = useState("");
  return <input value={comment} onChange={(e) => setComment(e.target.value)} />;
}
```

Use this when the identity really changed: user, document, chat room, wizard step, or form
instance. Do not use it when you only want to tweak one field, because remounting resets the
entire subtree.

### 5. Lift state or control the component

If an Effect exists only to notify a parent after local state changed, the data model is usually
wrong. Prefer lifting state up or updating both sides in the same event.

```tsx
// Bad
function Toggle({ onChange }: { onChange: (next: boolean) => void }) {
  const [isOn, setIsOn] = useState(false);

  useEffect(() => {
    onChange(isOn);
  }, [isOn, onChange]);

  return <button onClick={() => setIsOn(!isOn)}>{isOn ? "On" : "Off"}</button>;
}

// Good
function Toggle({ isOn, onChange }: { isOn: boolean; onChange: (next: boolean) => void }) {
  return <button onClick={() => onChange(!isOn)}>{isOn ? "On" : "Off"}</button>;
}
```

### 6. Use `useSyncExternalStore` for external subscriptions

Use `useSyncExternalStore` when the source of truth lives outside React and changes over time.
This is React's built-in primitive for subscribing to external stores.

Good fits:
- browser APIs with a current value plus subscription events
- third-party or app-level stores outside React state
- reusable hooks like `useOnlineStatus()` or `useMediaQuery()`

The shape is:

```tsx
const value = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
```

Where:
- `subscribe` tells React how to listen for changes and return cleanup
- `getSnapshot` reads the current value from the external store
- `getServerSnapshot` provides the initial server and hydration value when SSR is involved

```tsx
// Bad
function useOnlineStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    function updateStatus() {
      setIsOnline(navigator.onLine);
    }

    updateStatus();
    window.addEventListener("online", updateStatus);
    window.addEventListener("offline", updateStatus);

    return () => {
      window.removeEventListener("online", updateStatus);
      window.removeEventListener("offline", updateStatus);
    };
  }, []);

  return isOnline;
}

// Good
const isOnline = useSyncExternalStore(subscribe, () => navigator.onLine, () => true);
```

Prefer this over hand-rolled subscription Effects in components.

Important caveats from the React docs:
- `getSnapshot` must return a stable cached value unless the store actually changed
- if `subscribe` changes identity every render, React will resubscribe every render
- if you support SSR, `getServerSnapshot` must match between server render and hydration

Do not use this for:
- normal component state that should live in `useState`, `useReducer`, or context
- derived values you can calculate during render
- user actions handled by event handlers
- one-time fetching
- general side effects that are not subscriptions

### 7. Fetch through the framework or a data library

Avoid raw fetch-in-Effect code in app components when a framework loader or query library is
available.

Preferred order:
1. framework data APIs (`Next.js`, `React Router`, Remix, server components, route loaders)
2. data libraries (`TanStack Query`, `SWR`)
3. a focused custom hook
4. raw `useEffect` only if none of the above fit

If you must fetch in an Effect, handle cleanup so stale responses are ignored.

```tsx
// Bad
useEffect(() => {
  void fetchResults(query).then(setResults);
}, [query]);

// Good
useEffect(() => {
  let ignore = false;

  void fetchResults(query).then((next) => {
    if (!ignore) {
      setResults(next);
    }
  });

  return () => {
    ignore = true;
  };
}, [query]);
```

### 8. Encapsulate unavoidable imperative synchronization

Sometimes an Effect is correct: sockets, observers, widgets, media controls, focus management,
layout measurement, or DOM APIs that must stay in sync with rendered output.

When that happens:
- keep the Effect tiny and specific
- name the external system in a comment or hook name
- include full cleanup
- prefer a custom hook over open-coded Effect logic in many components
- consider `useLayoutEffect` only for pre-paint measurement or visual correctness

```tsx
// Bad
function ChatRoom({ roomId }: { roomId: string }) {
  useEffect(() => {
    const connection = createConnection(roomId);
    connection.connect();
  }, [roomId]);
}

// Good
function useChatConnection(roomId: string) {
  useEffect(() => {
    const connection = createConnection(roomId);
    connection.connect();

    return () => {
      connection.disconnect();
    };
  }, [roomId]);
}
```

If your team bans raw `useEffect`, put these escape hatches behind approved hooks instead of
sprinkling Effects through feature code.

## Anti-Patterns

Treat these as red flags during authoring or review:
- `useEffect(() => setX(...), [...])` for derived state
- Effect only exists to call a function after a button click
- effect chains where one state update triggers another Effect and another render
- dependency arrays fought with `eslint-disable`, refs-as-flags, or intentionally stale closures
- object or function dependencies recreated every render without need
- child component fetching data and pushing it upward in an Effect
- mount-only initialization that should live in module scope, entrypoints, or framework boot code

## Review Checklist

Before accepting a new Effect, verify all of these:
- [ ] The code synchronizes with a real external system
- [ ] Derived render data, memoization, events, `key`, lifted state, and `useSyncExternalStore`
      were all considered first
- [ ] The dependency list is honest and complete
- [ ] Setup and cleanup are symmetrical
- [ ] The Effect is idempotent under Strict Mode re-mounting
- [ ] Data fetching is not bypassing an existing framework or query abstraction
- [ ] The logic is small enough that a custom hook or helper name explains its purpose

## Team Policy

For teams trying to ban or heavily restrict raw `useEffect`, use this policy:

1. Do not introduce `useEffect` for derived state, events, or resets.
2. Prefer render-time derivation, event handlers, `key`, `useMemo`, and `useSyncExternalStore`.
3. Route data loading through the framework or an approved query library.
4. If an Effect is still necessary, hide it behind a narrowly named custom hook or document the
   external system and cleanup explicitly in review.
5. Never silence `react-hooks/exhaustive-deps` to "make it work".

## References

For source material and further reading, see `references/sources.md`.
