import 'package:signalbox/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at the FFI implementation so tests can run on the host.
///
/// Call this once from `setUpAll` in every test that touches the database.
///
/// The no-isolate factory is deliberate: `flutter_test` runs widget tests on a
/// fake async clock, and the default isolate-backed factory never completes its
/// work under that clock, which makes `pumpAndSettle` time out. Running SQLite
/// in the test isolate keeps widget tests and unit tests on the same setup.
void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
}

/// A fresh in-memory database with the production schema.
///
/// Pass `seed: true` to also insert the demo data from `SeedData`.
Future<Database> openTestDatabase({bool seed = false}) {
  return AppDatabase.instance.openInMemory(seed: seed);
}
