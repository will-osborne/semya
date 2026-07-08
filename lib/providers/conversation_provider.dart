import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/domain/entities/user.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/providers.dart';

// ---------------------------------------------------------------------------
// App lifecycle
// ---------------------------------------------------------------------------

/// Incremented every time the app returns to the foreground (see the
/// lifecycle observer in app.dart). Watch/listen to this to resubscribe
/// Firestore streams that may have gone stale in the background.
final appResumedProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Conversations stream (real-time list for the current user)
// ---------------------------------------------------------------------------

const _kMinStreamBackoff = Duration(seconds: 2);
const _kMaxStreamBackoff = Duration(seconds: 30);

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  // Resubscribe with a fresh listener whenever the app resumes.
  ref.watch(appResumedProvider);

  final uid = ref.watch(authProvider.select((state) => state.user?.uid));
  if (uid == null) return Stream.value(const <Conversation>[]);

  final repo = ref.watch(firestoreConversationRepositoryProvider);

  // A raw Firestore stream error would leave the StreamProvider errored until
  // invalidated. Instead: keep the last emitted data, surface the error only
  // if nothing has loaded yet, and resubscribe with exponential backoff.
  final controller = StreamController<List<Conversation>>();
  StreamSubscription<List<Conversation>>? sub;
  Timer? retryTimer;
  var backoff = _kMinStreamBackoff;
  var hasData = false;

  void subscribe() {
    sub = repo
        .getUserConversations(uid)
        .listen(
          (conversations) {
            backoff = _kMinStreamBackoff;
            hasData = true;
            controller.add(conversations);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!hasData) controller.addError(error, stackTrace);
            sub?.cancel();
            retryTimer?.cancel();
            retryTimer = Timer(backoff, subscribe);
            final doubled = backoff * 2;
            backoff = doubled > _kMaxStreamBackoff
                ? _kMaxStreamBackoff
                : doubled;
          },
        );
  }

  subscribe();

  ref.onDispose(() {
    retryTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Single conversation detail
// ---------------------------------------------------------------------------

final conversationDetailProvider = StreamProvider.family<Conversation?, String>(
  (ref, conversationId) {
    // Resubscribe on app resume so a stale/errored listener recovers.
    ref.watch(appResumedProvider);
    final repo = ref.watch(firestoreConversationRepositoryProvider);
    return repo.watchConversation(conversationId);
  },
);

// ---------------------------------------------------------------------------
// User search by email
// ---------------------------------------------------------------------------

final userSearchProvider = FutureProvider.family<List<AppUser>, String>((
  ref,
  query,
) {
  if (query.trim().isEmpty) return Future.value([]);
  final repo = ref.watch(firestoreUserRepositoryProvider);
  return repo.searchUsersByEmail(query.trim());
});

// ---------------------------------------------------------------------------
// Conversation service — high-level operations
// ---------------------------------------------------------------------------

class ConversationService {
  ConversationService(this._ref);

  final Ref _ref;

  Future<void> markConversationDelivered(String conversationId) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final repo = _ref.read(firestoreConversationRepositoryProvider);
    await repo.markConversationDelivered(conversationId, uid);
  }

  Future<void> markConversationRead(String conversationId) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final repo = _ref.read(firestoreConversationRepositoryProvider);
    await repo.markConversationRead(conversationId, uid);
  }

  /// Starts or returns an existing direct conversation with [otherUserId].
  Future<String> startDirectConversation(String otherUserId) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) throw StateError('Not authenticated.');

    final repo = _ref.read(firestoreConversationRepositoryProvider);

    // Check for existing direct conversation.
    final existing = await repo.findDirectConversation(uid, otherUserId);
    if (existing != null) return existing.id;

    // Create new direct conversation.
    final conversation = Conversation(
      id: const Uuid().v4(),
      type: ConversationType.direct,
      participantIds: [uid, otherUserId],
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      unreadCounts: {uid: 0, otherUserId: 0},
      lastDeliveredAtByUser: {uid: DateTime.now()},
      lastReadAtByUser: {uid: DateTime.now()},
      createdBy: uid,
    );

    await repo.createConversation(conversation);
    return conversation.id;
  }

  /// Creates a group conversation with the given [title] and [memberIds].
  /// The current user is automatically added as a participant.
  Future<String> createGroupConversation(
    String title,
    List<String> memberIds,
  ) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) throw StateError('Not authenticated.');

    final allParticipants = {uid, ...memberIds}.toList();
    final now = DateTime.now();

    final conversation = Conversation(
      id: const Uuid().v4(),
      type: ConversationType.group,
      participantIds: allParticipants,
      title: title,
      createdAt: now,
      lastMessageAt: now,
      unreadCounts: {
        for (final participantId in allParticipants) participantId: 0,
      },
      lastDeliveredAtByUser: {uid: now},
      lastReadAtByUser: {uid: now},
      createdBy: uid,
    );

    final repo = _ref.read(firestoreConversationRepositoryProvider);
    await repo.createConversation(conversation);
    return conversation.id;
  }
}

final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService(ref);
});

final conversationSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<Conversation>>>(conversationsProvider, (
    previous,
    next,
  ) {
    final currentUserId = ref.read(authProvider).user?.uid;
    if (currentUserId == null) return;

    final activeConversationId = ref.read(activeConversationIdProvider);
    final conversations = next.valueOrNull;
    if (conversations == null) return;

    final service = ref.read(conversationServiceProvider);
    for (final conversation in conversations) {
      if (conversation.type != ConversationType.direct) continue;
      if (conversation.id == activeConversationId) continue;

      final unreadCount = conversation.unreadCounts[currentUserId] ?? 0;
      final lastMessageAt = conversation.lastMessageAt;
      final lastDeliveredAt = conversation.lastDeliveredAtByUser[currentUserId];
      final needsDeliveredUpdate =
          unreadCount > 0 &&
          lastMessageAt != null &&
          (lastDeliveredAt == null || lastDeliveredAt.isBefore(lastMessageAt));
      if (needsDeliveredUpdate) {
        unawaited(service.markConversationDelivered(conversation.id));
      }
    }
  });
});
