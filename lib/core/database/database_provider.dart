import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// The open SQLite handle.
///
/// The database is opened once during start-up in `main()` and injected here
/// with `ProviderScope(overrides: ...)`. Tests override this provider with an
/// in-memory database, which is why no repository ever opens a connection of
/// its own.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError(
    'databaseProvider must be overridden with an open Database.',
  ),
);
