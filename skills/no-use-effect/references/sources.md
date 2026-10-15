This file collects the sources behind `no-use-effect` and the key idea taken from each.

- React docs - `https://react.dev/learn/you-might-not-need-an-effect`
  - Canonical source for removing unnecessary Effects. Most replacements in this skill come
    directly from this article: derive during render, move user actions into handlers, reset with
    `key`, and use `useSyncExternalStore` for subscriptions.

- React docs - `https://react.dev/learn/synchronizing-with-effects`
  - Establishes the core mental model: Effects synchronize React with external systems. This is
    the line between valid and invalid Effect usage.

- React docs - `https://react.dev/learn/removing-effect-dependencies`
  - Strong guidance on dependency honesty, avoiding stale closures, and refactoring code so the
    dependency list can stay complete.

- React docs - `https://react.dev/reference/react/useEffect`
  - API-level caveats for cleanup, client-only execution, and Strict Mode behavior.

- Dan Abramov - `https://overreacted.io/a-complete-guide-to-useeffect/`
  - Deep mental model for render snapshots, closures, and why lifecycle thinking leads to bugs.

- Kent C. Dodds - `https://www.epicreact.dev/myths-about-useeffect`
  - Useful review guidance: do not treat Effects as lifecycles, do not suppress exhaustive-deps,
    and separate unrelated concerns.

- Kent C. Dodds - `https://kentcdodds.com/blog/useeffect-vs-uselayouteffect`
  - Clarifies that `useLayoutEffect` is even rarer than `useEffect` and should be reserved for
    pre-paint DOM work.

- TkDodo - `https://tkdodo.eu/blog/you-might-not-need-an-effect`
  - Practical examples of refactoring common overuse patterns in real React codebases.

- Alvin Sng thread / mirrored gist -
  `https://gist.github.com/alvinsng/5dd68c6ece355dbdbd65340ec2927b1d`
  - Strong team-policy framing for banning or heavily restricting raw `useEffect`, plus clear
    replacement categories. The original X link was not directly fetchable without JavaScript,
    but the gist appears to mirror the substance.

- React docs - `https://react.dev/reference/react/useSyncExternalStore`
  - Purpose-built alternative to subscription Effects when reading mutable external stores.

- Data-fetching ecosystem examples
  - `https://tanstack.com/query/latest`
  - `https://swr.vercel.app/`
  - These are not the source of the core principle, but they are concrete alternatives when an
    app would otherwise fetch in component Effects.
