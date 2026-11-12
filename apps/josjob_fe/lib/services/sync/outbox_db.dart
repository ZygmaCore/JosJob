import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'outbox_db.g.dart';

// =========================================================================
// JosJob — Outbox database (Drift)
//
// A single-table persistent queue of fire-and-forget mutations awaiting sync.
// Cross-platform via [driftDatabase]: native (sqlite3_flutter_libs) and web
// (WASM — needs web/sqlite3.wasm + web/drift_worker.js). Rows are enqueued
// optimistically and replayed by the SyncEngine when connectivity returns.
// =========================================================================

/// One queued mutation. [payload] is a JSON string; [type] selects how the
/// SyncEngine replays it. [parked] marks a row that failed with a permanent
/// 4xx so it is kept for inspection but never retried.
class OutboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  BoolColumn get parked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [OutboxItems])
class OutboxDatabase extends _$OutboxDatabase {
  OutboxDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  // Web needs the WASM sqlite + worker; the URIs resolve against the deployed
  // web/ assets. On native the [web] options are ignored.
  static QueryExecutor _open() => driftDatabase(
    name: 'josjob_outbox',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
