import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:injectable/injectable.dart';

part 'app_database.g.dart';

/// PRD §10.5 local Drafts feature — the first real `drift` usage in this
/// codebase (`drift`/`drift_flutter` were pinned in `pubspec.yaml` ahead of
/// time, unused until this branch). One table is enough for v1: a draft is
/// a single row capturing everything needed to resume editing later.
///
/// Column shapes mirror `features/drafts/domain/entities/draft.dart`'s
/// `Draft` entity 1:1 (see that file for the field-by-field rationale);
/// [canvasStateJson] is the JSON encoding of a
/// `features/drafts/domain/entities/draft_canvas_snapshot.dart`'s
/// `DraftCanvasSnapshot`, decoded/encoded at the repository boundary
/// (`data/repositories/draft_repository_impl.dart`) — this table itself
/// never touches `DraftCanvasSnapshot` directly, keeping `core/database`
/// free of a `features/drafts` import.
/// `@DataClassName('DraftRow')` — without it, drift would auto-singularize
/// this table class's name (`Drafts` -> `Draft`) for its generated data
/// class, colliding with `features/drafts/domain/entities/draft.dart`'s
/// own `Draft` domain entity. `DraftRow` is this generated row type's name
/// everywhere it's used (`data/repositories/draft_repository_impl.dart` is
/// the only place that should ever reference it) — never confuse it with
/// the domain `Draft` entity Blocs/use cases actually see.
@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get localId => text()();
  TextColumn get brandKitId => text().nullable()();
  TextColumn get inputText => text()();
  TextColumn get generationRecordId => text().nullable()();
  TextColumn get canvasStateJson => text()();

  /// Small enum encoded as a plain string (`draft`/`exported`) rather than
  /// an `intEnum()` — see `Draft.status`'s doc comment for why a readable
  /// on-disk value was chosen over a smaller int column for a table this
  /// size (never more than `Draft.maxLocalDrafts` rows).
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastSavedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localId};
}

/// The app's single local database — currently just [Drafts]. Exposed as
/// `@lazySingleton` via [AppDatabaseModule] below (not annotated directly
/// on this class) so DI, not this file, owns the choice of which
/// [QueryExecutor] a real app run gets — mirrors
/// `features/quota/data/datasources/quota_datasource_module.dart`'s
/// `@module` pattern for the same "one deliberate assembly point" reason.
@DriftDatabase(tables: [Drafts])
class AppDatabase extends _$AppDatabase {
  /// Real app constructor — opens (or creates) a file-backed database named
  /// `kelal_studio.sqlite` in the platform's app-documents directory via
  /// `drift_flutter`'s [driftDatabase] helper. Deliberately **not**
  /// hand-rolled `LazyDatabase`/`path_provider` wiring — `drift_flutter`
  /// exists specifically to own that platform-specific plumbing so
  /// feature code doesn't have to.
  AppDatabase() : super(driftDatabase(name: 'kelal_studio'));

  /// Test-only constructor: takes an already-constructed [QueryExecutor]
  /// (e.g. `NativeDatabase.memory()`) directly, bypassing
  /// [driftDatabase]'s file-backed default entirely — this is what lets
  /// repository tests run against a real, in-memory SQLite instance
  /// without ever touching the filesystem or DI.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Documented placeholder for a future `onUpgrade` — not present because
  /// one is needed yet (`schemaVersion` is still 1, so `onUpgrade` is
  /// unreachable today), but because the *next* schema change to this
  /// database should extend this strategy rather than someone having to
  /// discover from scratch where migrations belong.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );
}

/// Mirrors `features/quota/data/datasources/quota_datasource_module.dart`:
/// the one place that decides how the app's real [AppDatabase] gets
/// constructed, so nothing else calls `AppDatabase()` directly.
@module
abstract class AppDatabaseModule {
  @lazySingleton
  AppDatabase appDatabase() => AppDatabase();
}
