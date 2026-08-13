---
description: Scaffold a new feature's data/domain/presentation skeleton, DI registration, and test stubs, following the exact structure of the auth feature.
argument-hint: <feature_name (snake_case)>
allowed-tools: Bash(mkdir *), Read, Write, Glob
---

Scaffold a new feature named `$1` under `lib/features/$1/`, mirroring
`lib/features/auth/`'s structure exactly — do not invent a different
layout. Read `.claude/skills/flutter-architecture/SKILL.md` first if it
isn't already in context.

1. Create the folder skeleton:
   ```
   lib/features/$1/data/{datasources,models,repositories}
   lib/features/$1/domain/{entities,repositories,usecases}
   lib/features/$1/presentation/{bloc,pages,widgets}
   test/features/$1/... (mirroring the lib structure for whatever gets built)
   ```

2. If the feature needs a remote data source, create the same five-file
   pattern `flutter-networking-data` documents (`*_remote_data_source.dart`
   abstract interface, `*_api.dart` retrofit client, `real_*` and `fake_*`
   implementations, `*_datasource_module.dart` picking between them via
   `Env.useMockApi`) — copy the shape from `features/auth/data/datasources/`,
   don't design a new one.

3. Add the corresponding paths (request/response schemas, typed errors) to
   `api_contract/openapi.yaml` if this feature calls the backend and isn't
   already covered there.

4. Stub one domain entity, one repository interface + impl, and one use
   case class with `@injectable`, plus a placeholder Bloc/Cubit (ask the
   user, or infer from the PRD, whether this feature's actions are
   event-driven enough to need a Bloc with a deliberate
   `bloc_concurrency` transformer, or simple enough for a Cubit — see
   `flutter-state-management`).

5. Add a route for the feature's entry page in `core/router/app_router.dart`.

6. Create matching test file stubs (empty `blocTest`/`testWidgets` shells
   with a `// TODO` is acceptable here — this command scaffolds structure,
   it doesn't write the actual feature logic or its real tests).

7. Run `dart run build_runner build --delete-conflicting-outputs` and
   `fvm flutter analyze` to confirm the scaffold compiles before handing
   back control.

Do not implement the feature's actual business logic in this command —
that's a separate, deliberate task. This only builds the skeleton so the
next work has a correct place to land.
