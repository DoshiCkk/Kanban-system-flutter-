import 'package:equatable/equatable.dart';

/// The card a push points at (docs/push.md, "Payload").
class PushTarget extends Equatable {
  const PushTarget({
    required this.workspaceId,
    required this.boardId,
    required this.cardId,
  });

  final String workspaceId;
  final String boardId;
  final String cardId;

  /// `null` when [data] does not name a card.
  static PushTarget? fromData(Map<String, dynamic> data) {
    final workspaceId = data['workspaceId'];
    final boardId = data['boardId'];
    final cardId = data['cardId'];
    if (workspaceId is! String || boardId is! String || cardId is! String) {
      return null;
    }
    return PushTarget(
      workspaceId: workspaceId,
      boardId: boardId,
      cardId: cardId,
    );
  }

  @override
  List<Object?> get props => [workspaceId, boardId, cardId];
}

/// A push received while the app is in the foreground. Texts come
/// localized from the server.
class ForegroundPush extends Equatable {
  const ForegroundPush({required this.title, required this.body, this.target});

  final String title;
  final String body;
  final PushTarget? target;

  @override
  List<Object?> get props => [title, body, target];
}

/// Push notifications behind an interface: Firebase Cloud Messaging when
/// the build is configured for it, otherwise [NoopNotificationService], so
/// the app runs without a Firebase project (docs/push.md).
abstract interface class NotificationService {
  /// Signed in: asks for permission and registers this device's token.
  Future<void> start();

  /// Before signing out: unregisters the token (best effort).
  Future<void> stop();

  /// Language of push texts (`en`, `ru`, `kk`); re-registers on change.
  void setLocale(String languageCode);

  /// Registers again if the last attempt failed (e.g. it was offline).
  Future<void> retryRegistration();

  /// Pushes the user tapped. Buffered until the first listener, so a tap
  /// that launched the app is not lost.
  Stream<PushTarget> get opened;

  /// Pushes that arrived while the app was open.
  Stream<ForegroundPush> get foreground;
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void setLocale(String languageCode) {}

  @override
  Future<void> retryRegistration() async {}

  @override
  Stream<PushTarget> get opened => const Stream.empty();

  @override
  Stream<ForegroundPush> get foreground => const Stream.empty();
}
