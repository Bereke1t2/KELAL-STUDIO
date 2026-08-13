---
name: flutter-state-management
description: Bloc vs Cubit selection and bloc_concurrency event-transformer rules for the Kelal Studio Flutter app, aimed squarely at preventing race conditions (double-submit, stale async results, out-of-order writes). Use whenever adding a new Bloc/Cubit, a new event handler, or touching anything that fires an async operation from user input.
---

# Flutter State Management

## Bloc vs Cubit

- **Cubit**: trivial, direct-method-call UI state with no meaningful
  "event" semantics — a text field's obscure/reveal toggle, an
  expanded/collapsed flag. No `bloc_concurrency` concerns because there's
  nothing async to race.
- **Bloc**: anything that calls a use case, i.e. anything that touches
  `domain/`. Default to Bloc for feature logic; reach for Cubit only when
  you're confident there's no async operation to sequence.

Don't use Cubit "because it's less boilerplate" for something that fires a
network call — that's exactly the case `bloc_concurrency` exists for, and
Cubit doesn't have an equivalent transformer mechanism.

## `bloc_concurrency` — pick one deliberately for every `on<Event>` handler

The default transformer (`concurrent()`, i.e. no `transformer:` argument)
runs every incoming event's handler in parallel with no ordering
guarantee. **Never leave a handler on this default without having
consciously ruled out a race** — that's the single most common way this
codebase would grow a real bug that only shows up under load or on a slow
network, not in a quick manual test.

| Transformer | Use for | Why |
|---|---|---|
| `droppable()` | Submit-style actions: login, generate text/image/video, export, any quota-consuming call | Ignores new events while one's in flight — the structural fix for "double-tap submits twice" and (for generation calls specifically) for double-charging a scarce, per-user quota (PRD §6.14 treats quota as a financial control, not a UX nicety). |
| `restartable()` | Live-recompute actions: canvas preview updates as a slider/drag moves, search-as-you-type | Cancels the in-flight handler and starts over on the newest event — only the latest input matters, and you don't want three stale preview repaints landing out of order after the user has moved on. Pairs with `core/render_engine`'s decode-once/repaint-many strategy: the recompute is cheap repaint, not image redecode, so restarting it is cheap. |
| `sequential()` | Ordered local writes: draft autosave, any sequence of local-storage mutations that must apply in the order they were issued | Guarantees one event fully completes before the next starts, in order — never `concurrent()` for anything writing to `drift`/secure storage, or two near-simultaneous autosaves can interleave and corrupt state. |
| `concurrent()` (explicit) | Truly independent, order-doesn't-matter events (rare) | Only use this by writing `transformer: concurrent()` explicitly, so it's visibly a decision in code review — not by omitting the argument. |

```dart
on<LoginSubmitted>(_onSubmitted, transformer: droppable());
```

When adding a handler, ask: *can two of these events be in flight at once,
and if so, what happens?* If the answer isn't obviously "nothing bad,"
pick a transformer from the table above — don't guess, and don't skip the
question because "it probably won't happen in practice."

## `hydrated_bloc`

Use only for small, non-sensitive UI preferences that should survive app
restart (e.g. last-selected platform in the composer, language toggle
default) — never for drafts (those go through `drift`, per PRD §6.10's
explicit local-only/no-sync decision and its autosave/eviction
requirements) and never for anything a `SecureTokenStorage`-class secret
belongs in.

## Testing

Every Bloc gets a `bloc_test` suite asserting the exact emitted state
sequence, including at least one test that exercises the chosen
transformer's actual behavior (e.g. firing two events back-to-back and
asserting the second was dropped/restarted/serialized as intended) — not
just the happy-path single-event case. See `flutter-testing` skill.
