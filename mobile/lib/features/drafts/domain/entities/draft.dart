import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';

/// A draft's lifecycle state — PRD §10.5 only names "draft" explicitly;
/// `exported` is added so a draft that was actually carried through to a
/// completed export can be told apart from one still mid-edit (e.g. for a
/// future "hide exported drafts" filter) without inventing a second table.
/// Encoded as a plain lowercase string on disk (`Drafts.status`), not an
/// int index, so an existing row stays readable/debuggable if a future
/// migration reorders this enum.
enum DraftStatus {
  draft,
  exported;

  String toWire() => name;

  static DraftStatus fromWire(String value) => DraftStatus.values.firstWhere(
    (status) => status.name == value,
    // Defensive fallback for a row written by a future app version with a
    // status value this build doesn't know about yet — treat it as an
    // ordinary in-progress draft rather than crashing the drafts list.
    orElse: () => DraftStatus.draft,
  );
}

/// Domain entity for one row of `core/database/app_database.dart`'s
/// `Drafts` table — PRD §10.5's local Drafts feature. Pure Dart (no
/// `drift`/`flutter` imports here; see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule) other than [DraftCanvasSnapshot], which carries its own flagged,
/// deliberate exception to that rule (see its doc comment).
class Draft extends Equatable {
  const Draft({
    required this.localId,
    required this.brandKitId,
    required this.inputText,
    required this.generationRecordId,
    required this.canvasSnapshot,
    required this.status,
    required this.createdAt,
    required this.lastSavedAt,
  });

  /// `uuid` v4 string, generated client-side (see
  /// `DraftAutosaveCubit`'s doc comment) — never server-assigned; a draft
  /// is local-only in v1 (PRD §6.10: no server sync).
  final String localId;

  /// Null when the editing session that produced this draft had no brand
  /// kit resolved yet — see `CanvasEditorPageArgs.brandKitId`'s doc
  /// comment for the flagged gap in how a real id would reach here today.
  final String? brandKitId;

  /// The original idea text this graphic was generated from — carried so
  /// resuming a draft can show *something* about what it was for, even
  /// though (see `DraftsPage`'s doc comment) the AI-generated captions
  /// themselves are not part of this schema and are lost on resume.
  final String inputText;

  /// Null until/unless a future branch threads a real generation-record id
  /// through — nothing in this codebase produces one today (see
  /// `CanvasEditorPageArgs.brandKitId`'s doc comment for the sibling gap);
  /// kept here because PRD §10.5's draft schema names it explicitly.
  final String? generationRecordId;

  final DraftCanvasSnapshot canvasSnapshot;
  final DraftStatus status;
  final DateTime createdAt;
  final DateTime lastSavedAt;

  /// PRD §10.5 describes local drafts but leaves any cap on how many can
  /// exist unset — 20 is a conservative, clearly-flagged default (a few
  /// weeks of typical use, not an authoritative product limit) rather than
  /// an invented "real" number; see
  /// mobile/.claude/skills/flutter-architecture/SKILL.md's "flag, don't
  /// silently assume" rule. `DraftRepositoryImpl.save` evicts the
  /// least-recently-saved draft once a new insert would exceed this.
  static const maxLocalDrafts = 20;

  Draft copyWith({
    String? brandKitId,
    String? inputText,
    String? generationRecordId,
    DraftCanvasSnapshot? canvasSnapshot,
    DraftStatus? status,
    DateTime? lastSavedAt,
  }) {
    return Draft(
      localId: localId,
      brandKitId: brandKitId ?? this.brandKitId,
      inputText: inputText ?? this.inputText,
      generationRecordId: generationRecordId ?? this.generationRecordId,
      canvasSnapshot: canvasSnapshot ?? this.canvasSnapshot,
      status: status ?? this.status,
      createdAt: createdAt,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }

  @override
  List<Object?> get props => [
    localId,
    brandKitId,
    inputText,
    generationRecordId,
    canvasSnapshot,
    status,
    createdAt,
    lastSavedAt,
  ];
}
