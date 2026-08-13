---
name: flutter-architecture
description: Clean Architecture + feature-first layering rules for the Kelal Studio Flutter app — layer boundaries, DI, the Result error type, and the standing rule to flag rather than silently resolve the PRD's open questions. Use before creating a new feature, moving code between layers, adding a dependency between features, or whenever a change touches more than one of data/domain/presentation.
---

# Flutter Architecture

## Layering (hard rule, not a suggestion)

```
lib/features/<name>/
  data/{datasources,models,repositories}
  domain/{entities,repositories,usecases}
  presentation/{bloc,pages,widgets}
```

- **`domain/` is pure Dart.** No `package:flutter`, no `flutter_bloc`, no
  `dio`, no `drift`, no `injectable` annotations beyond `@injectable` on the
  use case class itself. If a domain file needs to import anything besides
  another domain file or `dart:core`/`dart:async`, stop — that's a layering
  violation, not a convenience import.
- **One usecase class per use case.** Single public method, always named
  `call()`, so call sites read as `await loginUseCase(email: ..., password: ...)`.
  A usecase depends on one or more repository *interfaces*, never on a
  concrete `*RepositoryImpl` or a data source directly.
- **Repositories**: interface in `domain/repositories`, implementation in
  `data/repositories`. The implementation is the only place that knows
  whether it's talking to a real or fake data source (see
  `flutter-networking-data` skill) and the only place that catches
  `ApiException`/other data-layer exceptions and converts them to `Result`.
- **Presentation** (Bloc/Cubit) calls use cases only. Never a repository,
  never a data source, never `dio`, directly from a Bloc or a widget.
- **`core/`** holds cross-cutting infrastructure with no feature
  ownership: DI bootstrap, theme, router, the shared `render_engine`,
  network plumbing, secure storage, error types. A `core/` file must never
  import from `features/**` — dependencies point one way.
- **`shared/`** holds widgets reused across 2+ features that aren't
  design-system primitives (those live in `core/theme` or get built
  per-component from Figma — see `flutter-design-system`). If something in
  `shared/` is only used by one feature, move it into that feature.

## Error handling

Every domain/data public method that can fail returns
`Result<Failure, T>` (`core/error/result.dart`) — never throws across that
boundary, never returns a nullable "it worked, probably" value. Exceptions
are allowed *inside* a data source (they're caught and mapped at the
repository boundary) but must never escape a repository implementation.

`switch` exhaustively on `Result`/`Failure` subtypes rather than
`is`-checking one branch and assuming the other — the whole point of a
sealed type here is that the compiler catches an unhandled case.

## Dependency injection

`get_it` + `injectable`. Annotate:
- `@injectable` — a new instance per resolution (use cases, most Blocs).
- `@lazySingleton` — one instance for the app's lifetime (repositories,
  Dio, secure storage, the router).
- `@module` — for anything that isn't itself annotable (third-party
  classes like `Dio`, `FlutterSecureStorage`) or that needs a runtime
  branch (the mock/real data source swap — see `flutter-networking-data`).

After adding or changing any of the above, run
`dart run build_runner build --delete-conflicting-outputs` — a missing
registration fails at `getIt<T>()` call time, not at analyze time, so
don't assume it worked without actually running the app or a test that
resolves the type.

## The standing "flag, don't silently assume" rule

The PRD (`docs/Kelal_Studio_PRD.pdf`, §14) lists ~20 explicitly open
questions and says outright that an AI coding tool must not resolve them
silently. The ones most likely to surface during mobile work:

| Touches... | Open question | Do this |
|---|---|---|
| Image/graphic aspect ratios | 2 ratios (1:1, 4:5) or 3 (+9:16)? | Build against the 2-ratio contract already in `api_contract/openapi.yaml`; if a task implies 9:16, stop and ask before adding it. |
| Canvas safe zones | Exact per-platform percentages are undefined | Don't invent numbers; ask for the source or treat as a visible TODO with a conservative placeholder, clearly marked. |
| Idea Composer input | Can users reliably type Amharic, or is transliteration the norm? | Don't hard-code an assumption into the composer's input handling; support both, flag if a task forces a single choice. |
| Any date/time UI | Ethiopian calendar vs. Gregorian | Store/transmit UTC always (already enforced); ask before deciding which calendar the *UI* shows. |
| Moderation UX | Measured Amharic recall is unverified | Don't claim or imply the safety filter is equally reliable in both languages. |

If a task doesn't touch any of these, proceed normally — this table is a
checklist for *when relevant*, not a blanket "ask about everything."

**Resolved, not open**: whether the app interface itself (not just
generated content) is localized into Amharic — **yes**, via
`AppLocalizations` (`lib/core/l10n/`). New screens must add both `en`/`am`
ARB entries, not hardcode English strings — see `mobile/CLAUDE.md`'s
Localization section. Amharic *translation quality* is still unverified
per-string (flag any new `am` entry as pending native-speaker review), but
the *decision to localize* is made and should not be re-asked.
