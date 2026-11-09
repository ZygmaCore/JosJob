import 'package:drift/drift.dart';

import 'outbox_db.dart';

// =========================================================================
// ATVETI STELLAR — Outbox store
//
// The persistence boundary for the sync queue. [OutboxStore] is an interface
// so the [SyncEngine] can run against a Drift-backed store in the app and a
// trivial in-memory fake in unit tests. Rows are plain [OutboxRecord]s so the
// engine never touches Drift's generated types.
// =========================================================================

/// A queued mutation, decoupled from the Drift row so the engine and tests
/// share one plain model.
class OutboxRecord {
  final String id;
  final String type;
  final String payload;
  final DateTime createdAt;
  final int attempts;

  const OutboxRecord({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });
}

/// Persistent queue of fire-and-forget mutations awaiting sync.
abstract class OutboxStore {
  /// Append a record to the queue.
  Future<void> enqueue(OutboxRecord record);

  /// The records still eligible for replay (not parked), oldest first.
  Future<List<OutboxRecord>> pending();

  /// Remove a record after a confirmed server write.
  Future<void> delete(String id);

  /// Record another delivery attempt (drives retry backoff).
  Future<void> bumpAttempts(String id);

  /// Mark a record as parked so it is kept but no longer retried (permanent
  /// 4xx). Excluded from [pending].
  Future<void> park(String id);
}

/// [OutboxStore] backed by the Drift [OutboxDatabase].
class DriftOutboxStore implements OutboxStore {
  DriftOutboxStore([OutboxDatabase? db]) : _db = db ?? OutboxDatabase();

  final OutboxDatabase _db;

  @override
  Future<void> enqueue(OutboxRecord record) => _db
      .into(_db.outboxItems)
      .insert(
        OutboxItemsCompanion.insert(
          id: record.id,
          type: record.type,
          payload: record.payload,
          createdAt: record.createdAt,
          attempts: Value(record.attempts),
        ),
      );

  @override
  Future<List<OutboxRecord>> pending() async {
    final query = _db.select(_db.outboxItems)
      ..where((t) => t.parked.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return [
      for (final r in rows)
        OutboxRecord(
          id: r.id,
          type: r.type,
          payload: r.payload,
          createdAt: r.createdAt,
          attempts: r.attempts,
        ),
    ];
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.outboxItems)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> bumpAttempts(String id) => _db.customUpdate(
    'UPDATE outbox_items SET attempts = attempts + 1 WHERE id = ?',
    variables: [Variable<String>(id)],
    updates: {_db.outboxItems},
  );

  @override
  Future<void> park(String id) =>
      (_db.update(_db.outboxItems)..where((t) => t.id.equals(id))).write(
        const OutboxItemsCompanion(parked: Value(true)),
      );
}
