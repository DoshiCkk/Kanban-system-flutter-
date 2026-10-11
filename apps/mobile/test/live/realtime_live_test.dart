/// End-to-end check of phase 5 against a running API (README, "Real-time:
/// check"): two devices with their own databases, the real sync client and
/// the real Socket.IO client. Skipped unless FLOWBOARD_LIVE_API is set.
@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flowboard/core/config/app_config.dart';
import 'package:flowboard/core/db/app_database.dart';
import 'package:flowboard/core/network/access_token.dart';
import 'package:flowboard/core/network/api_client.dart';
import 'package:flowboard/core/network/auth_interceptor.dart';
import 'package:flowboard/core/network/session_storage.dart';
import 'package:flowboard/core/sync/realtime.dart';
import 'package:flowboard/core/sync/socket_io_transport.dart';
import 'package:flowboard/core/sync/sync_api.dart';
import 'package:flowboard/core/sync/sync_engine.dart';
import 'package:flowboard/core/sync/sync_store.dart';
import 'package:flowboard/features/boards/data/drift_boards_repository.dart';
import 'package:flowboard/features/boards/domain/board_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../helpers/fakes.dart';

final String? _baseUrl = Platform.environment['FLOWBOARD_LIVE_API'];

class LiveDevice {
  LiveDevice._(this.dio, this.tokens, AuthInterceptor auth, this.userId)
    : db = AppDatabase(NativeDatabase.memory()) {
    realtime = RealtimeClient(
      transport: SocketIoTransport(_baseUrl!),
      token: AccessTokenSource(tokens, auth.refreshAccessToken).call,
    );
    repo = DriftBoardsRepository(db, watchRoom: realtime.watch);
    // Production timings (500 ms debounce).
    engine = SyncEngine(store: SyncStore(db), api: DioSyncApi(dio));
  }

  static Future<LiveDevice> signUp(String name) async {
    final tokens = TokenStore(InMemorySessionStorage());
    final client = createApiClient(
      config: AppConfig(apiBaseUrl: _baseUrl!),
      tokens: tokens,
      onSessionExpired: () {},
    );
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final res = await client.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': '${name.toLowerCase()}$stamp@example.com',
        'password': 'correct-horse-battery',
        'name': name,
      },
      options: Options(extra: {AuthExtra.skipAuth: true}),
    );
    final body = res.data!;
    final issued = body['tokens'] as Map<String, dynamic>;
    await tokens.save(
      AuthTokens(
        accessToken: issued['accessToken'] as String,
        refreshToken: issued['refreshToken'] as String,
      ),
    );
    final user = body['user'] as Map<String, dynamic>;
    return LiveDevice._(client.dio, tokens, client.auth, user['id'] as String);
  }

  final Dio dio;
  final TokenStore tokens;
  final String userId;
  final AppDatabase db;
  late final RealtimeClient realtime;
  late final DriftBoardsRepository repo;
  late final SyncEngine engine;

  Future<void> goOnline(String workspaceId) async {
    await db
        .into(db.cachedWorkspaces)
        .insert(
          CachedWorkspacesCompanion.insert(
            id: workspaceId,
            name: 'Live',
            role: 'member',
            memberCount: 2,
          ),
        );
    realtime.start();
    engine.start(triggers: [realtime.changes]);
    expect(await engine.syncNow(), isTrue);
  }

  Future<void> close() async {
    await realtime.dispose();
    await engine.dispose();
    await db.close();
  }
}

void main() {
  test(
    'a card moved on one device appears on the other in about a second',
    () async {
      final alice = await LiveDevice.signUp('Alice');
      final bob = await LiveDevice.signUp('Bob');
      addTearDown(() async {
        await alice.close();
        await bob.close();
      });
      final workspaceId = const Uuid().v4();
      await alice.dio.post<void>(
        '/workspaces',
        data: {'id': workspaceId, 'name': 'Live'},
      );
      final invite = await alice.dio.post<Map<String, dynamic>>(
        '/workspaces/$workspaceId/invites',
      );
      await bob.dio.post<void>('/invites/${invite.data!['token']}/accept');

      final created = await alice.repo.createBoard(
        workspaceId: workspaceId,
        title: 'Live board',
        template: BoardTemplate.basic,
        columnTitles: const ['To do', 'Doing', 'Done'],
      );
      final board = (await alice.repo.watchBoard(created.id).first)!;
      final card = await alice.repo.createCard(
        board.columns.first.column.id,
        'Intro',
      );
      await alice.goOnline(workspaceId);
      await bob.goOnline(workspaceId);

      // Bob opens the board: its stream joins board:<id>.
      final onBob = bob.repo.watchBoard(board.board.id).asBroadcastStream();
      await onBob.firstWhere((b) => b != null);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final latencies = <int>[];
      for (final column in board.columns.skip(1)) {
        final arrived = onBob.firstWhere(
          (b) => b!.columns
              .firstWhere((c) => c.column.id == column.column.id)
              .cards
              .any((c) => c.id == card.id),
        );
        final watch = Stopwatch()..start();
        await alice.repo.moveCard(
          card.id,
          toColumnId: column.column.id,
          toIndex: 0,
        );
        await arrived.timeout(const Duration(seconds: 3));
        latencies.add(watch.elapsedMilliseconds);
      }
      // The measurement is the point of this test.
      // ignore: avoid_print
      print('move latency, ms (500 ms of it is the push debounce): $latencies');
      expect(latencies, everyElement(lessThan(1500)));
    },
    skip: _baseUrl == null ? r'set $env:FLOWBOARD_LIVE_API to run' : null,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
