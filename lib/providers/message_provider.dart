import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:semya/data/services/media_service.dart';
import 'package:semya/domain/entities/message.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
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
    _subscribe();
    // Firestore listeners can go stale while the app is backgrounded;
    // resubscribe on resume without dropping accumulated messages.
    _ref.listen<int>(appResumedProvider, (_, _) => _resubscribe());
  }

  final Ref _ref;
  final String _conversationId;

  /// Every message seen so far, keyed by id. Live snapshots merge into this
  /// map so messages that slide out of the live query window (and paginated
  /// history) remain visible.
  final Map<String, Message> _messagesById = {};

  StreamSubscription<List<Message>>? _streamSub;
  Timer? _retryTimer;
  Duration _backoff = _minBackoff;

  static const int _initialLimit = 30;
  static const int _pageSize = 20;
  static const Duration _minBackoff = Duration(seconds: 2);
  static const Duration _maxBackoff = Duration(seconds: 30);

  void _subscribe() {
    final repo = _ref.read(firestoreMessageRepositoryProvider);
    _streamSub = repo
        .getMessages(_conversationId, limit: _initialLimit)
        .listen(
          (messages) {
            _backoff = _minBackoff;
            for (final message in messages) {
              _messagesById[message.id] = message;
            }
            _emit(isInitialLoading: false);
          },
          onError: (Object error, StackTrace _) {
            // Keep whatever is already loaded; surface the error and
            // resubscribe with exponential backoff.
            _emit(isInitialLoading: false, error: error.toString());
            _scheduleResubscribe();
          },
        );
  }

  void _resubscribe() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _streamSub?.cancel();
    _subscribe();
  }

  void _scheduleResubscribe() {
    _streamSub?.cancel();
    _streamSub = null;
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () {
      final doubled = _backoff * 2;
      _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
      _subscribe();
    });
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    // Anchor pagination on the oldest message the server has acknowledged —
    // pending local writes have no server-side position yet.
    Message? anchor;
    final sorted = state.messages;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].serverTimestamp != null) {
        anchor = sorted[i];
        break;
      }
    }
    if (anchor == null) {
      _emit(hasMore: false);
      return;
    }

    _emit(isLoadingMore: true);
    try {
      final repo = _ref.read(firestoreMessageRepositoryProvider);
      final older = await repo.getMessagesBatch(
        _conversationId,
        limit: _pageSize,
        beforeMessageId: anchor.id,
      );

      for (final message in older) {
        // Never overwrite a live (metadata-aware) entry with a one-time read.
        _messagesById.putIfAbsent(message.id, () => message);
      }
      _emit(hasMore: older.length >= _pageSize);
    } catch (e) {
      _emit(error: e.toString());
    }
  }

  /// Marks a message failed locally after the server rejected its write.
  /// Rejected writes never reach Firestore, so the retry bubble has to be
  /// kept here rather than in a document.
  void markMessageFailedLocally(Message message) {
    _messagesById[message.id] = message.copyWith(
      status: MessageStatus.failed,
      isPending: false,
    );
    _emit();
  }

  /// Removes a locally-tracked message (a retry resends it as a new write).
  void removeMessage(String messageId) {
    if (_messagesById.remove(messageId) != null) _emit();
  }

  void _emit({
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    final sorted = _messagesById.values.toList()
      ..sort((a, b) {
        final aTime = a.serverTimestamp ?? a.timestamp;
        final bTime = b.serverTimestamp ?? b.timestamp;
        return bTime.compareTo(aTime);
      });
    state = PaginatedMessagesState(
      messages: sorted,
      isInitialLoading: isInitialLoading ?? state.isInitialLoading,
      isLoadingMore: isLoadingMore ?? false,
      hasMore: hasMore ?? state.hasMore,
      error: error,
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }
}

final paginatedMessagesProvider =
    StateNotifierProvider.family<
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

  /// Sends a text message optimistically: the write is handed to Firestore's
  /// offline queue and NOT awaited — the snapshot listener surfaces it
  /// immediately as pending. Only an actual server rejection marks it failed.
  Future<void> sendMessage(
    String conversationId,
    String plaintext, {
    List<String>? participantIds,
  }) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final message = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: uid,
      type: MessageType.text,
      content: plaintext,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    );

    _dispatch(message, participantIds: participantIds);
  }

  /// Issues the batched write without awaiting it and marks the message
  /// failed locally only if the server rejects it.
  void _dispatch(Message message, {List<String>? participantIds}) {
    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);
    unawaited(() async {
      try {
        await messageRepo.sendMessage(message, participantIds: participantIds);
      } catch (e) {
        _ref
            .read(paginatedMessagesProvider(message.conversationId).notifier)
            .markMessageFailedLocally(message);
        if (mounted) state = SendMessageState(error: e.toString());
      }
    }());
  }

  Future<void> sendVoiceMessage(
    String conversationId, {
    List<String>? participantIds,
  }) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final voiceService = _ref.read(voiceNoteServiceProvider);

    String localPath;
    try {
      localPath = await voiceService.stopRecording();
    } catch (e) {
      state = SendMessageState(error: e.toString());
      return;
    }

    final message = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: uid,
      type: MessageType.voice,
      content: localPath,
      status: MessageStatus.sent,
      uploadPending: true,
      timestamp: DateTime.now(),
    );

    await _uploadAndFinalize(
      message,
      participantIds: participantIds,
      isVoice: true,
      createDoc: true,
    );
  }

  Future<void> sendMediaMessage(
    String conversationId,
    PreparedMedia media, {
    List<String>? participantIds,
  }) async {
    final uid = _ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final message = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: uid,
      type: media.isVideo ? MessageType.video : MessageType.image,
      content: media.file.path,
      status: MessageStatus.sent,
      uploadPending: true,
      timestamp: DateTime.now(),
      mediaWidth: media.width,
      mediaHeight: media.height,
    );

    await _uploadAndFinalize(
      message,
      participantIds: participantIds,
      isVoice: false,
      createDoc: true,
      media: media,
    );
  }

  Future<void> retryMessage(
    Message message, {
    List<String>? participantIds,
  }) async {
    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);

    // No server timestamp means the original write was rejected and nothing
    // (message or unread increments) was persisted — resend from scratch.
    if (message.serverTimestamp == null) {
      _ref
          .read(paginatedMessagesProvider(message.conversationId).notifier)
          .removeMessage(message.id);
      final fresh = message.copyWith(
        status: MessageStatus.sent,
        isPending: false,
        timestamp: DateTime.now(),
      );
      if (message.type == MessageType.text) {
        _dispatch(fresh, participantIds: participantIds);
      } else {
        // Rejected media placeholder: recreate the doc and rerun the upload.
        await _uploadAndFinalize(
          fresh.copyWith(uploadPending: true),
          participantIds: participantIds,
          isVoice: message.type == MessageType.voice,
          createDoc: true,
        );
      }
      return;
    }

    // The doc exists on the server, so the original batch (including unread
    // increments) committed — never resend it.
    final isLocalMedia =
        message.type != MessageType.text && !message.content.startsWith('http');
    if (!isLocalMedia) {
      // Text, or media whose upload finished: the content was delivered,
      // only the legacy status flag is wrong.
      try {
        await messageRepo.updateMessageStatus(
          message.conversationId,
          message.id,
          MessageStatus.sent,
        );
      } catch (e) {
        if (mounted) state = SendMessageState(error: e.toString());
      }
      return;
    }

    // Media placeholder whose upload failed: re-upload and finalize. The
    // placeholder never touched unreadCounts, so finalize increments once.
    await _uploadAndFinalize(
      message,
      participantIds: participantIds,
      isVoice: message.type == MessageType.voice,
      createDoc: false,
    );
  }

  /// Shared media/voice pipeline: (optionally) create the placeholder doc,
  /// upload the local file, then finalize the doc + conversation preview and
  /// unread counts in one batch. On upload failure the doc is marked failed
  /// so a retry bubble exists; the local file is kept for the retry.
  Future<void> _uploadAndFinalize(
    Message message, {
    required List<String>? participantIds,
    required bool isVoice,
    required bool createDoc,
    PreparedMedia? media,
  }) async {
    final messageRepo = _ref.read(firestoreMessageRepositoryProvider);

    state = SendMessageState(
      isSending: true,
      isSendingVoice: isVoice,
      isSendingMedia: !isVoice,
    );

    if (createDoc) {
      // The placeholder appears immediately (pending, uploading); the write
      // itself is queued and only a rejection produces a failed bubble.
      unawaited(() async {
        try {
          await messageRepo.createMessage(message);
        } catch (e) {
          _ref
              .read(paginatedMessagesProvider(message.conversationId).notifier)
              .markMessageFailedLocally(message);
          if (mounted) state = SendMessageState(error: e.toString());
        }
      }());
    } else {
      // Retry of an existing placeholder: flip it back to uploading.
      try {
        await messageRepo.updateMessageStatus(
          message.conversationId,
          message.id,
          MessageStatus.sent,
          uploadPending: true,
        );
      } catch (_) {
        // Best-effort; the upload result determines the final state.
      }
    }

    Message finalized;
    try {
      if (isVoice) {
        final voiceService = _ref.read(voiceNoteServiceProvider);
        final downloadUrl = await voiceService.uploadVoiceNote(
          filePath: message.content,
          conversationId: message.conversationId,
          messageId: message.id,
        );
        finalized = message.copyWith(content: downloadUrl);
      } else {
        final mediaService = _ref.read(mediaServiceProvider);
        final prepared =
            media ??
            PreparedMedia(
              file: File(message.content),
              isVideo: message.type == MessageType.video,
              width: message.mediaWidth,
              height: message.mediaHeight,
            );
        final result = await mediaService.uploadMedia(
          media: prepared,
          conversationId: message.conversationId,
          messageId: message.id,
        );
        finalized = message.copyWith(
          content: result.downloadUrl,
          thumbnailUrl: result.thumbnailUrl ?? message.thumbnailUrl,
          mediaWidth: result.width ?? message.mediaWidth,
          mediaHeight: result.height ?? message.mediaHeight,
        );
      }
    } catch (e) {
      unawaited(() async {
        try {
          await messageRepo.updateMessageStatus(
            message.conversationId,
            message.id,
            MessageStatus.failed,
          );
        } catch (_) {
          // Doc write also failed (likely offline/rejected) — nothing more
          // to record; the doc stays uploadPending until a retry.
        }
      }());
      if (mounted) state = SendMessageState(error: e.toString());
      return;
    }

    finalized = finalized.copyWith(uploadPending: false);
    unawaited(() async {
      try {
        await messageRepo.finalizeMessage(
          finalized,
          participantIds: participantIds,
        );
      } catch (e) {
        if (mounted) state = SendMessageState(error: e.toString());
      }
    }());

    if (mounted) state = const SendMessageState();
  }
}

final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, SendMessageState>((ref) {
      return SendMessageNotifier(ref);
    });
