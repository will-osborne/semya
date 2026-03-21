import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:semya/data/services/media_service.dart';
import 'package:semya/domain/entities/message.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/providers.dart';

// ---------------------------------------------------------------------------
// Paginated messages — real-time stream + load-more for history
// ---------------------------------------------------------------------------

class PaginatedMessagesState {
  const PaginatedMessagesState({
    this.messages = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Message> messages;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
}

class PaginatedMessagesNotifier extends StateNotifier<PaginatedMessagesState> {
  PaginatedMessagesNotifier(this._ref, this._conversationId)
    : super(const PaginatedMessagesState()) {
    _init();
  }

  final Ref _ref;
  final String _conversationId;
  StreamSubscription<List<Message>>? _streamSub;

  /// Messages from the real-time stream (latest page).
  List<Message> _streamMessages = [];

  /// Messages loaded from pagination (older history).
  final List<Message> _historicalMessages = [];

  static const int _initialLimit = 30;
  static const int _pageSize = 20;

  void _init() {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid != null) {
      final repo = _ref.read(firestoreMessageRepositoryProvider);
      unawaited(
        repo.markStuckSendingMessagesFailed(_conversationId, uid),
      );
    }

    final repo = _ref.read(firestoreMessageRepositoryProvider);
    _streamSub = repo
        .getMessages(_conversationId, limit: _initialLimit)
        .listen(
          (messages) {
            _streamMessages = messages;
            _emitCombined(isInitialLoading: false);
          },
          onError: (error) {
            state = PaginatedMessagesState(
              isInitialLoading: false,
              error: error.toString(),
            );
          },
        );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = PaginatedMessagesState(
      messages: state.messages,
      isLoadingMore: true,
      hasMore: state.hasMore,
    );

    try {
      final allCurrent = [..._streamMessages, ..._historicalMessages];
      if (allCurrent.isEmpty) {
        state = PaginatedMessagesState(
          messages: state.messages,
          hasMore: false,
        );
        return;
      }

      // Find the oldest loaded message's server timestamp.
      final oldest = allCurrent.last;
      final cursor = oldest.serverTimestamp ?? oldest.timestamp;

      final repo = _ref.read(firestoreMessageRepositoryProvider);
      final olderMessages = await repo.getMessagesBatch(
        _conversationId,
        limit: _pageSize,
        before: cursor,
      );

      _historicalMessages.addAll(olderMessages);
      _emitCombined(
        isInitialLoading: false,
        hasMore: olderMessages.length >= _pageSize,
      );
    } catch (e) {
      state = PaginatedMessagesState(
        messages: state.messages,
        error: e.toString(),
        hasMore: state.hasMore,
      );
    }
  }

  void _emitCombined({bool isInitialLoading = false, bool? hasMore}) {
    // Merge stream and historical messages, deduplicate by ID.
    final seen = <String>{};
    final combined = <Message>[];

    for (final m in _streamMessages) {
      if (seen.add(m.id)) combined.add(m);
    }
    for (final m in _historicalMessages) {
      if (seen.add(m.id)) combined.add(m);
    }

    state = PaginatedMessagesState(
      messages: combined,
      isInitialLoading: isInitialLoading,
      hasMore: hasMore ?? state.hasMore,
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final paginatedMessagesProvider = StateNotifierProvider.family<
  PaginatedMessagesNotifier,
  PaginatedMessagesState,
  String
>((ref, conversationId) {
  return PaginatedMessagesNotifier(ref, conversationId);
});

// ---------------------------------------------------------------------------
// Send message notifier
// ---------------------------------------------------------------------------

class SendMessageState {
  const SendMessageState({
    this.isSending = false,
    this.isSendingVoice = false,
    this.isSendingMedia = false,
    this.error,
  });

  final bool isSending;
  final bool isSendingVoice;
  final bool isSendingMedia;
  final String? error;
}

class SendMessageNotifier extends StateNotifier<SendMessageState> {
  SendMessageNotifier(this._ref) : super(const SendMessageState());

  final Ref _ref;

  Future<void> sendMessage(String conversationId, String plaintext) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    state = const SendMessageState(isSending: true);

    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);
    final messageId = const Uuid().v4();

    try {
      final message = Message(
        id: messageId,
        conversationId: conversationId,
        senderId: uid,
        type: MessageType.text,
        content: plaintext,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
      );

      await messageRepo.sendMessage(message);
      await messageRepo.updateMessageStatus(
        conversationId,
        messageId,
        MessageStatus.sent,
      );

      state = const SendMessageState();
    } catch (e) {
      try {
        await messageRepo.updateMessageStatus(
          conversationId,
          messageId,
          MessageStatus.failed,
        );
      } catch (_) {}
      state = SendMessageState(error: e.toString());
    }
  }

  Future<void> sendVoiceMessage(String conversationId) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    state = const SendMessageState(isSending: true, isSendingVoice: true);

    final voiceService = _ref.read(voiceNoteServiceProvider);
    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);
    final messageId = const Uuid().v4();

    try {
      final downloadUrl = await voiceService.stopRecordingAndUpload(
        conversationId: conversationId,
        messageId: messageId,
      );

      final message = Message(
        id: messageId,
        conversationId: conversationId,
        senderId: uid,
        type: MessageType.voice,
        content: downloadUrl,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
      );

      await messageRepo.sendMessage(message);
      await messageRepo.updateMessageStatus(
        conversationId,
        messageId,
        MessageStatus.sent,
      );

      state = const SendMessageState();
    } catch (e) {
      try {
        await messageRepo.updateMessageStatus(
          conversationId,
          messageId,
          MessageStatus.failed,
        );
      } catch (_) {}
      state = SendMessageState(error: e.toString());
    }
  }

  Future<void> sendMediaMessage(
    String conversationId,
    PreparedMedia media,
  ) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    state = const SendMessageState(isSending: true, isSendingMedia: true);

    final mediaService = _ref.read(mediaServiceProvider);
    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);
    final messageId = const Uuid().v4();

    try {
      final result = await mediaService.uploadMedia(
        media: media,
        conversationId: conversationId,
        messageId: messageId,
      );

      final message = Message(
        id: messageId,
        conversationId: conversationId,
        senderId: uid,
        type: media.isVideo ? MessageType.video : MessageType.image,
        content: result.downloadUrl,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        thumbnailUrl: result.thumbnailUrl,
        mediaWidth: result.width,
        mediaHeight: result.height,
      );

      await messageRepo.sendMessage(message);
      await messageRepo.updateMessageStatus(
        conversationId,
        messageId,
        MessageStatus.sent,
      );

      state = const SendMessageState();
    } catch (e) {
      try {
        await messageRepo.updateMessageStatus(
          conversationId,
          messageId,
          MessageStatus.failed,
        );
      } catch (_) {}
      state = SendMessageState(error: e.toString());
    }
  }

  Future<void> retryMessage(Message message) async {
    state = const SendMessageState(isSending: true);

    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);

    try {
      await messageRepo.sendMessage(
        message.copyWith(status: MessageStatus.sending),
      );
      await messageRepo.updateMessageStatus(
        message.conversationId,
        message.id,
        MessageStatus.sent,
      );

      state = const SendMessageState();
    } catch (e) {
      try {
        await messageRepo.updateMessageStatus(
          message.conversationId,
          message.id,
          MessageStatus.failed,
        );
      } catch (_) {}
      state = SendMessageState(error: e.toString());
    }
  }
}

final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, SendMessageState>((ref) {
      return SendMessageNotifier(ref);
    });
