import 'dart:async';

import 'package:drift/drift.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests open a fresh in-memory AppDatabase each; that is intentional.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
