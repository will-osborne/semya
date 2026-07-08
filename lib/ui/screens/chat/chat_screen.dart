import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:semya/data/services/media_service.dart';
import 'package:semya/domain/entities/message.dart';
import 'package:go_router/go_router.dart';
import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/call_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/providers/message_provider.dart';
import 'package:semya/providers/providers.dart';
import 'package:semya/providers/user_provider.dart';

// ---------------------------------------------------------------------------
// Chat screen
// ---------------------------------------------------------------------------

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isRecording = false;

  /// Message ids that have already been built once — entry animations only
  /// run for ids not in this set.
  final Set<String> _seenMessageIds = {};

  /// False until the first non-empty list build, so the initial history
  /// renders without playing entry animations.
  bool _listRenderedOnce = false;

  void _setActiveConversation(String? conversationId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeConversationIdProvider.notifier).state = conversationId;
    });
  }

  @override
  void initState() {
    super.initState();
    _setActiveConversation(widget.conversationId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId == widget.conversationId) return;
    _setActiveConversation(widget.conversationId);
  }

  @override
  void dispose() {
    final activeConversationId = ref.read(activeConversationIdProvider);
    if (activeConversationId == widget.conversationId) {
      ref.read(activeConversationIdProvider.notifier).state = null;
    }
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more messages when scrolled near the top (end of reversed list).
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(paginatedMessagesProvider(widget.conversationId).notifier)
          .loadMore();
    }
  }

  /// Participant ids from the already-watched conversation, so sends do not
  /// need a blocking conversation read.
  List<String>? get _participantIds => ref
      .read(conversationDetailProvider(widget.conversationId))
      .valueOrNull
      ?.participantIds;

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(sendMessageProvider.notifier)
        .sendMessage(
          widget.conversationId,
          text,
          participantIds: _participantIds,
        );

    _messageController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceNoteServiceProvider);
    var hasPermission = await voiceService.hasPermission();
    if (!hasPermission && Platform.isIOS) {
      final status = await Permission.microphone.request();
      hasPermission = status.isGranted;
    }
    if (!hasPermission) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.microphonePermissionRequired),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await voiceService.startRecording();
      if (mounted) {
        setState(() => _isRecording = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    setState(() => _isRecording = false);
    await ref
        .read(sendMessageProvider.notifier)
        .sendVoiceMessage(
          widget.conversationId,
          participantIds: _participantIds,
        );
  }

  Future<void> _cancelRecording() async {
    setState(() => _isRecording = false);
    await ref.read(voiceNoteServiceProvider).cancelRecording();
  }

  void _showAttachmentPicker() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: Text(l10n.photoFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(fromCamera: false);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: colorScheme.primary),
              title: Text(l10n.videoFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo(fromCamera: false);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: colorScheme.primary),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.videocam_outlined,
                color: colorScheme.primary,
              ),
              title: Text(l10n.takeVideo),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo(fromCamera: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage({required bool fromCamera}) async {
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final prepared = fromCamera
          ? await mediaService.pickImageFromCamera()
          : await mediaService.pickImageFromGallery();
      if (prepared == null) return;

      await ref
          .read(sendMessageProvider.notifier)
          .sendMediaMessage(
            widget.conversationId,
            prepared,
            participantIds: _participantIds,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo({required bool fromCamera}) async {
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final prepared = fromCamera
          ? await mediaService.pickVideoFromCamera()
          : await mediaService.pickVideoFromGallery();
      if (prepared == null) return;

      await ref
          .read(sendMessageProvider.notifier)
          .sendMediaMessage(
            widget.conversationId,
            prepared,
            participantIds: _participantIds,
          );
    } on MediaTooLargeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // select() so the screen does not rebuild on unrelated auth state changes.
    final currentUserId =
        ref.watch(authProvider.select((state) => state.user?.uid)) ?? '';
    final l10n = AppLocalizations.of(context)!;

    // Conversation detail + title.
    final conversationAsync = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );
    final conversation = conversationAsync.valueOrNull;

    ref.listen<AsyncValue<Conversation?>>(
      conversationDetailProvider(widget.conversationId),
      (previous, next) {
        final updatedConversation = next.valueOrNull;
        if (currentUserId.isEmpty || updatedConversation == null) {
          return;
        }

        final unreadCount =
            updatedConversation.unreadCounts[currentUserId] ?? 0;
        final previousUnread =
            previous?.valueOrNull?.unreadCounts[currentUserId] ?? 0;
        // Only fire when the unread count actually changes — every
        // conversation snapshot (delivery receipts, presence, our own
        // mark-read write) retriggers this listener otherwise.
        if (unreadCount > 0 && unreadCount != previousUnread) {
          unawaited(
            ref
                .read(conversationServiceProvider)
                .markConversationRead(widget.conversationId),
          );
        }
      },
    );

    final isDirectConversation = conversation?.type == ConversationType.direct;

    // Resolve display title — for direct chats, show the other user's name.
    String conversationTitle;
    if (isDirectConversation && conversation != null) {
      final otherIds = conversation.participantIds
          .where((id) => id != currentUserId)
          .toList();
      if (otherIds.isNotEmpty) {
        final otherUserAsync = ref.watch(userByIdProvider(otherIds.first));
        conversationTitle = otherUserAsync.when(
          data: (user) => user?.displayName ?? l10n.unknown,
          loading: () => '...',
          error: (_, __) => l10n.unknown,
        );
      } else {
        conversationTitle = l10n.chat;
      }
    } else {
      conversationTitle = conversationAsync.when(
        data: (conv) => conv?.title ?? l10n.chat,
        loading: () => l10n.loading,
        error: (_, __) => l10n.chat,
      );
    }

    // Paginated messages.
    final msgState = ref.watch(
      paginatedMessagesProvider(widget.conversationId),
    );

    // Show send errors.
    ref.listen<SendMessageState>(sendMessageProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sendFailed(next.error!)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // Computed once per build (sizeOf only invalidates on actual size
    // changes, unlike MediaQuery.of which fires on every keyboard-animation
    // frame) and passed down so bubbles never touch MediaQuery themselves.
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.78;

    final messages = msgState.messages;
    // id → index map built once per list emit; findChildIndexCallback was
    // previously an O(n) indexWhere per key (O(n²) per relayout).
    final indexById = <String, int>{
      for (var i = 0; i < messages.length; i++) messages[i].id: i,
    };
    final animateNewMessages = _listRenderedOnce;
    if (messages.isNotEmpty) _listRenderedOnce = true;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.people_outline,
                color: colorScheme.onPrimaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                conversationTitle,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isDirectConversation)
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              onPressed: () async {
                final calleeId = conversation!.participantIds.firstWhere(
                  (id) => id != currentUserId,
                );
                ref.read(callProvider.notifier).setCurrentUserId(currentUserId);
                await ref
                    .read(callProvider.notifier)
                    .initiateCall(
                      calleeId: calleeId,
                      conversationId: widget.conversationId,
                      currentUserId: currentUserId,
                    );
                if (!context.mounted) return;
                final callId = ref.read(callProvider).activeCall?.id;
                if (callId != null) {
                  context.push('/call/$callId');
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Conversation options sheet — wired later.
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: msgState.isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : msgState.error != null && msgState.messages.isEmpty
                ? Center(child: Text(l10n.errorGeneric(msgState.error!)))
                : msgState.messages.isEmpty
                ? _EncryptedEmptyState()
                : ListView.builder(
                    key: const ValueKey('message-list'),
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount:
                        msgState.messages.length +
                        (msgState.isLoadingMore ? 1 : 0),
                    findChildIndexCallback: (key) {
                      if (key is ValueKey<String>) {
                        return indexById[key.value];
                      }
                      return null;
                    },
                    itemBuilder: (context, index) {
                      // Loading indicator at the end (oldest messages).
                      if (index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }

                      final message = messages[index];
                      final isMine = message.senderId == currentUserId;

                      // Group/display by server time (fallback to the
                      // sender-local timestamp for pending writes) so
                      // clock skew cannot mislabel Today/Yesterday.
                      final showDate =
                          index == messages.length - 1 ||
                          !_isSameDay(
                            _displayTime(messages[index]),
                            _displayTime(messages[index + 1]),
                          );

                      // Entry animation only for messages that appear after
                      // the first frame, land at the bottom of the reversed
                      // list (new sends/arrivals — not paginated history) and
                      // have not been built before.
                      final animate =
                          animateNewMessages &&
                          index < 3 &&
                          !_seenMessageIds.contains(message.id);
                      _seenMessageIds.add(message.id);

                      return _AnimatedMessageEntry(
                        key: ValueKey(message.id),
                        animate: animate,
                        child: Column(
                          children: [
                            if (showDate)
                              _DateSeparator(date: _displayTime(message)),
                            _MessageBubble(
                              message: message,
                              isMine: isMine,
                              maxWidth: maxBubbleWidth,
                              displayStatus: _resolveMessageStatus(
                                message: message,
                                conversation: conversation,
                                currentUserId: currentUserId,
                              ),
                              onRetry:
                                  isMine &&
                                      message.status == MessageStatus.failed
                                  ? () => ref
                                        .read(sendMessageProvider.notifier)
                                        .retryMessage(
                                          message,
                                          participantIds:
                                              conversation?.participantIds,
                                        )
                                  : null,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Voice/media upload indicator — its own Consumer so upload state
          // changes rebuild this strip only, not the whole message list.
          const _UploadIndicatorBanner(),

          // Input bar
          _MessageInputBar(
            controller: _messageController,
            focusNode: _focusNode,
            onSend: _sendMessage,
            isRecording: _isRecording,
            onRecordStart: _startRecording,
            onRecordStop: _stopRecordingAndSend,
            onRecordCancel: _cancelRecording,
            onAttach: _showAttachmentPicker,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _displayTime(Message message) =>
      message.serverTimestamp ?? message.timestamp;

  MessageStatus _resolveMessageStatus({
    required Message message,
    required Conversation? conversation,
    required String currentUserId,
  }) {
    if (message.senderId != currentUserId) return message.status;
    // Failed trumps everything (a queued failed-status write is still failed).
    if (message.status == MessageStatus.failed) return MessageStatus.failed;
    // Derived send state: unacknowledged local write or in-flight media
    // upload renders as "sending" — no persisted transient status.
    if (message.isPending || message.uploadPending) {
      return MessageStatus.sending;
    }
    if (conversation == null || conversation.type != ConversationType.direct) {
      return message.status;
    }

    final otherParticipants = conversation.participantIds.where(
      (participantId) => participantId != currentUserId,
    );
    if (otherParticipants.isEmpty) return message.status;
    final otherParticipantId = otherParticipants.first;

    final effectiveTimestamp = message.serverTimestamp ?? message.timestamp;
    final readAt = conversation.lastReadAtByUser[otherParticipantId];
    if (readAt != null && !effectiveTimestamp.isAfter(readAt)) {
      return MessageStatus.read;
    }

    final deliveredAt = conversation.lastDeliveredAtByUser[otherParticipantId];
    if (deliveredAt != null && !effectiveTimestamp.isAfter(deliveredAt)) {
      return MessageStatus.delivered;
    }

    return MessageStatus.sent;
  }
}

// ---------------------------------------------------------------------------
// Upload indicator banner (scoped Consumer — see build comment above)
// ---------------------------------------------------------------------------

class _UploadIndicatorBanner extends ConsumerWidget {
  const _UploadIndicatorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSendingVoice = ref.watch(
      sendMessageProvider.select((state) => state.isSendingVoice),
    );
    final isSendingMedia = ref.watch(
      sendMessageProvider.select((state) => state.isSendingMedia),
    );
    if (!isSendingVoice && !isSendingMedia) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isSendingVoice ? l10n.sendingVoiceMessage : l10n.sendingMedia,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message entry animation (subtle fade + slide, first mount only)
// ---------------------------------------------------------------------------

class _AnimatedMessageEntry extends StatefulWidget {
  const _AnimatedMessageEntry({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_AnimatedMessageEntry> createState() => _AnimatedMessageEntryState();
}

class _AnimatedMessageEntryState extends State<_AnimatedMessageEntry>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _opacity;
  Animation<Offset>? _offset;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 240),
      );
      final curve = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      _controller = controller;
      _opacity = curve;
      _offset = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(curve);
      controller.forward();
    }
  }

  @override
  void dispose() {
    _opacity?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity;
    final offset = _offset;
    if (opacity == null || offset == null) return widget.child;
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: offset, child: widget.child),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.displayStatus,
    required this.maxWidth,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final MessageStatus displayStatus;

  /// Max bubble width, precomputed by the list parent so bubbles do not
  /// depend on MediaQuery (which rebuilds every keyboard-animation frame).
  final double maxWidth;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bubbleColor = isMine
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final textColor = isMine ? colorScheme.onPrimary : colorScheme.onSurface;

    const radius = Radius.circular(18);
    final borderRadius = isMine
        ? const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: Radius.circular(4),
            bottomRight: radius,
          );

    final isVoice = message.type == MessageType.voice;
    final isImage = message.type == MessageType.image;
    final isVideo = message.type == MessageType.video;
    final isMedia = isImage || isVideo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              clipBehavior: isMedia ? Clip.antiAlias : Clip.none,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (isImage)
                    _ImageMessageContent(
                      url: message.content,
                      maxWidth: maxWidth,
                      width: message.mediaWidth,
                      height: message.mediaHeight,
                    )
                  else if (isVideo)
                    _VideoMessageContent(
                      url: message.content,
                      maxWidth: maxWidth,
                      thumbnailUrl: message.thumbnailUrl,
                      width: message.mediaWidth,
                      height: message.mediaHeight,
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 14,
                      right: 14,
                      top: isMedia ? 4 : 10,
                      bottom: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (isVoice)
                          _VoiceMessageContent(
                            url: message.content,
                            durationMs: message.durationMs,
                            textColor: textColor,
                          )
                        else if (!isMedia)
                          _LinkifiedText(
                            text: message.content,
                            style:
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                ) ??
                                TextStyle(color: textColor),
                            linkColor: isMine
                                ? Colors.white
                                : colorScheme.primary,
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.jm().format(
                                message.serverTimestamp ?? message.timestamp,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isMine
                                    ? colorScheme.onPrimary.withOpacity(0.7)
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              if (displayStatus == MessageStatus.failed &&
                                  onRetry != null)
                                // Padded hit area + refresh glyph so the
                                // failed state reads as tappable.
                                GestureDetector(
                                  onTap: onRetry,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 14,
                                          color: colorScheme.onPrimary,
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.refresh,
                                          size: 14,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  _statusIcon(displayStatus),
                                  size: 12,
                                  color: displayStatus == MessageStatus.read
                                      ? Colors.lightBlueAccent
                                      : colorScheme.onPrimary.withOpacity(0.7),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  IconData _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }
}

// ---------------------------------------------------------------------------
// Message text with clickable links (long-press to copy)
// ---------------------------------------------------------------------------

final _urlRegex = RegExp(r'https?://[^\s<>\[\]()]+', caseSensitive: false);

/// Renders message text with tappable links. Spans (and their gesture
/// recognizers) are built once per content change and disposed with the
/// widget — the previous implementation leaked a [TapGestureRecognizer] per
/// link per rebuild and re-ran the URL regex on every frame.
class _LinkifiedText extends StatefulWidget {
  const _LinkifiedText({
    required this.text,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];
  late TextSpan _span;

  @override
  void initState() {
    super.initState();
    _span = _buildSpan();
  }

  @override
  void didUpdateWidget(covariant _LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.style != oldWidget.style ||
        widget.linkColor != oldWidget.linkColor) {
      _disposeRecognizers();
      _span = _buildSpan();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _buildSpan() {
    final text = widget.text;
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(style: widget.style, children: spans);
  }

  Future<void> _showCopyMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selected = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<VoidCallback>(
          value: () => Clipboard.setData(ClipboardData(text: widget.text)),
          // Flutter's own material localizations — no app string needed.
          child: Text(MaterialLocalizations.of(context).copyButtonLabel),
        ),
      ],
    );
    selected?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        HapticFeedback.selectionClick();
        unawaited(_showCopyMenu(details.globalPosition));
      },
      child: Text.rich(_span),
    );
  }
}

// ---------------------------------------------------------------------------
// Image message content (inside bubble)
// ---------------------------------------------------------------------------

class _ImageMessageContent extends StatelessWidget {
  const _ImageMessageContent({
    required this.url,
    required this.maxWidth,
    this.width,
    this.height,
  });

  final String url;
  final double maxWidth;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (width != null && height != null && height! > 0)
        ? width! / height!
        : 4 / 3;

    // Decode bound: bubble width in physical pixels — full-resolution photos
    // must not decode at 1920px to fill a ~300px bubble.
    final decodeWidth = (maxWidth * MediaQuery.devicePixelRatioOf(context))
        .round();

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.5, 2.0).toDouble(),
        child: _ResilientImage(
          imageUrl: url,
          fit: BoxFit.cover,
          decodeWidth: decodeWidth,
          placeholder: Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: Container(
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.broken_image, size: 32)),
          ),
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _FullScreenImageViewer(url: url)));
  }
}

// ---------------------------------------------------------------------------
// Full screen image viewer
// ---------------------------------------------------------------------------

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: _ResilientImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades a file/network image in once its first frame is decoded.
Widget _fadeInFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    child: child,
  );
}

class _ResilientImage extends StatelessWidget {
  const _ResilientImage({
    required this.imageUrl,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
    this.decodeWidth,
  });

  final String imageUrl;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;

  /// Optional decode budget in physical pixels (null = full resolution,
  /// e.g. the full-screen viewer).
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    // Mid-upload messages (uploadPending) hold a local file path — render it
    // straight from disk, never as a network image.
    if (!imageUrl.startsWith('http')) {
      return Image.file(
        File(imageUrl),
        fit: fit,
        cacheWidth: decodeWidth,
        frameBuilder: _fadeInFrame,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }

    // iOS: CachedNetworkImage's HTTP pipeline could not load these Firebase
    // download URLs reliably (stale/rejected download-URL tokens after the
    // auth migration), so images are fetched through the Storage SDK, which
    // re-authenticates from the storage path. The fetch is cached by URL in
    // MediaCacheService so each image downloads once — previously every
    // scroll-into-view re-downloaded to a fresh temp file.
    if (Platform.isIOS) {
      return _StorageImageFallback(
        imageUrl: imageUrl,
        fit: fit,
        decodeWidth: decodeWidth,
        loadingWidget: placeholder,
        errorWidget: errorWidget,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: decodeWidth,
      placeholder: (context, url) => placeholder,
      // Resilience fallback: expired/403 download URLs re-fetch through the
      // Storage SDK (and land in the same cache).
      errorWidget: (context, url, error) => _StorageImageFallback(
        imageUrl: imageUrl,
        fit: fit,
        decodeWidth: decodeWidth,
        loadingWidget: placeholder,
        errorWidget: errorWidget,
      ),
    );
  }
}

class _StorageImageFallback extends ConsumerStatefulWidget {
  const _StorageImageFallback({
    required this.imageUrl,
    required this.fit,
    required this.loadingWidget,
    required this.errorWidget,
    this.decodeWidth,
  });

  final String imageUrl;
  final BoxFit fit;
  final Widget loadingWidget;
  final Widget errorWidget;
  final int? decodeWidth;

  @override
  ConsumerState<_StorageImageFallback> createState() =>
      _StorageImageFallbackState();
}

class _StorageImageFallbackState extends ConsumerState<_StorageImageFallback> {
  static const int _maxImageBytes = 32 * 1024 * 1024;

  File? _file;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final cache = ref.read(mediaCacheServiceProvider);
    try {
      // Cache-first: a URL is downloaded at most once onto a stable cache
      // path (the old implementation wrote a unique temp file per mount).
      var file = await cache.getCachedFile(widget.imageUrl);
      if (file == null) {
        final bytes = await FirebaseStorage.instance
            .refFromURL(widget.imageUrl)
            .getData(_maxImageBytes);
        if (bytes == null) {
          throw StateError('Empty image data');
        }
        file = await cache.putFile(widget.imageUrl, bytes);
      }
      if (!mounted) return;
      setState(() {
        _file = file;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        cacheWidth: widget.decodeWidth,
        frameBuilder: _fadeInFrame,
        errorBuilder: (_, __, ___) => widget.errorWidget,
      );
    }
    if (_isLoading) {
      return widget.loadingWidget;
    }
    return widget.errorWidget;
  }
}

// ---------------------------------------------------------------------------
// Video message content (inside bubble)
// ---------------------------------------------------------------------------

class _VideoMessageContent extends ConsumerStatefulWidget {
  const _VideoMessageContent({
    required this.url,
    required this.maxWidth,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  final String url;
  final double maxWidth;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  @override
  ConsumerState<_VideoMessageContent> createState() =>
      _VideoMessageContentState();
}

class _VideoMessageContentState extends ConsumerState<_VideoMessageContent> {
  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        (widget.width != null && widget.height != null && widget.height! > 0)
        ? widget.width! / widget.height!
        : 16 / 9;

    final decodeWidth =
        (widget.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();

    return GestureDetector(
      onTap: () => _openVideoPlayer(context),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.5, 2.0).toDouble(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.thumbnailUrl != null)
              Positioned.fill(
                child: _ResilientImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  decodeWidth: decodeWidth,
                  placeholder: Container(color: Colors.grey[800]),
                  errorWidget: Container(color: Colors.grey[800]),
                ),
              )
            else
              Positioned.fill(child: Container(color: Colors.grey[800])),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context) {
    // Get the cached file if available, otherwise use the URL directly.
    final cacheService = ref.read(mediaCacheServiceProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenVideoPlayer(url: widget.url, cacheService: cacheService),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full screen video player
// ---------------------------------------------------------------------------

class _FullScreenVideoPlayer extends StatefulWidget {
  const _FullScreenVideoPlayer({required this.url, required this.cacheService});

  final String url;
  final dynamic cacheService;

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      VideoPlayerController controller;
      if (!widget.url.startsWith('http')) {
        // Mid-upload message: the content is still a local file path.
        controller = VideoPlayerController.file(File(widget.url));
      } else {
        // Try to get cached file first.
        File? cachedFile;
        try {
          cachedFile = await widget.cacheService.getFile(widget.url);
        } catch (_) {
          // Cache miss — fall back to network.
        }

        controller = cachedFile != null
            ? VideoPlayerController.file(cachedFile)
            : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
      controller.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _isInitializing
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
            ? Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              )
            : _controller != null
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    if (!_controller!.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date separator
// ---------------------------------------------------------------------------

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final now = DateTime.now();
    String label;
    if (now.difference(date).inDays == 0) {
      label = l10n.today;
    } else if (now.difference(date).inDays == 1) {
      label = l10n.yesterday;
    } else {
      label = DateFormat.yMMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message input bar
// ---------------------------------------------------------------------------

class _MessageInputBar extends StatefulWidget {
  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isRecording,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onRecordCancel,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isRecording;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onRecordCancel;
  final VoidCallback onAttach;

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: widget.isRecording
            ? _buildRecordingRow(theme, colorScheme)
            : _buildNormalRow(theme, colorScheme),
      ),
    );
  }

  Widget _buildRecordingRow(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: widget.onRecordCancel,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: colorScheme.error, size: 10),
              const SizedBox(width: 8),
              Text(
                l10n.recording,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded),
          onPressed: widget.onRecordStop,
        ),
      ],
    );
  }

  Widget _buildNormalRow(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment button
        IconButton(
          icon: Icon(
            Icons.attach_file_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: widget.onAttach,
        ),

        // Text field
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            maxLines: 5,
            minLines: 1,
            decoration: InputDecoration(
              hintText: l10n.message,
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Send / mic toggle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _hasText
              ? IconButton.filled(
                  key: const ValueKey('send'),
                  icon: const Icon(Icons.send_rounded),
                  onPressed: widget.onSend,
                )
              : GestureDetector(
                  key: const ValueKey('mic'),
                  onLongPress: widget.onRecordStart,
                  onLongPressEnd: (_) => widget.onRecordStop(),
                  child: IconButton(
                    icon: Icon(
                      Icons.mic_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: widget.onRecordStart,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice message content (inside bubble) — play/pause + draggable scrubber
// ---------------------------------------------------------------------------

class _VoiceMessageContent extends ConsumerStatefulWidget {
  const _VoiceMessageContent({
    required this.url,
    required this.textColor,
    this.durationMs,
  });

  final String url;
  final Color textColor;

  /// Duration persisted on the message at send time; null for legacy
  /// messages (falls back to a one-time Storage metadata fetch).
  final int? durationMs;

  @override
  ConsumerState<_VoiceMessageContent> createState() =>
      _VoiceMessageContentState();
}

class _VoiceMessageContentState extends ConsumerState<_VoiceMessageContent> {
  Duration? _knownDuration;

  /// Non-null while the user is dragging the scrubber (milliseconds).
  double? _dragValueMs;

  @override
  void initState() {
    super.initState();
    _applyMessageDuration();
    if (_knownDuration == null && widget.url.startsWith('http')) {
      unawaited(_fetchDuration());
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // durationMs lands via a queued Firestore update shortly after the
    // bubble first renders — pick it up without a refetch.
    if (widget.durationMs != oldWidget.durationMs) {
      _applyMessageDuration();
    }
  }

  void _applyMessageDuration() {
    final ms = widget.durationMs;
    if (ms != null && ms > 0) {
      _knownDuration = Duration(milliseconds: ms);
    }
  }

  Future<void> _fetchDuration() async {
    // Memoized in VoiceNoteService — at most one metadata roundtrip per URL
    // per session, shared across recycled bubbles.
    final voiceService = ref.read(voiceNoteServiceProvider);
    final duration = await voiceService.getDuration(widget.url);
    if (mounted && duration != null && _knownDuration == null) {
      setState(() => _knownDuration = duration);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _onScrubEnd(double valueMs) async {
    final voiceService = ref.read(voiceNoteServiceProvider);
    try {
      await voiceService.seek(
        widget.url,
        Duration(milliseconds: valueMs.round()),
      );
    } catch (_) {
      // Source failed to load — leave the bubble untouched.
    }
    if (mounted) {
      setState(() => _dragValueMs = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = ref.watch(voiceNoteServiceProvider);
    final textColor = widget.textColor;

    return StreamBuilder<PlayerState>(
      stream: voiceService.playerStateStream,
      builder: (context, playerSnapshot) {
        final isActive = voiceService.currentlyPlayingUrl == widget.url;
        final playing = isActive && (playerSnapshot.data?.playing ?? false);

        return Row(
          children: [
            GestureDetector(
              onTap: () {
                if (playing) {
                  voiceService.pause();
                } else {
                  voiceService.play(widget.url);
                }
              },
              child: Icon(
                playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: textColor,
                size: 36,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: isActive
                  // Only the active bubble subscribes to the position stream.
                  ? StreamBuilder<Duration>(
                      stream: voiceService.positionStream,
                      builder: (context, posSnapshot) => _buildScrubber(
                        position: posSnapshot.data ?? Duration.zero,
                        duration: voiceService.duration ?? _knownDuration,
                      ),
                    )
                  : _buildScrubber(
                      position: Duration.zero,
                      duration: _knownDuration,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrubber({
    required Duration position,
    required Duration? duration,
  }) {
    final textColor = widget.textColor;
    final l10n = AppLocalizations.of(context)!;

    final durationMs = duration?.inMilliseconds ?? 0;
    final canScrub = durationMs > 0;
    final maxMs = canScrub ? durationMs.toDouble() : 1.0;
    // While dragging, the indicator and time label follow the finger; the
    // player position only updates on release (seek on drag end).
    final displayMs = (_dragValueMs ?? position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visually slim track, but a 40px-tall gesture surface so the thumb
        // is comfortably draggable inside a chat bubble.
        SizedBox(
          height: 40,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: textColor,
              inactiveTrackColor: textColor.withOpacity(0.3),
              thumbColor: textColor,
              overlayColor: textColor.withOpacity(0.12),
              disabledActiveTrackColor: textColor,
              disabledInactiveTrackColor: textColor.withOpacity(0.3),
              disabledThumbColor: textColor.withOpacity(0.5),
            ),
            child: Slider(
              value: displayMs,
              max: maxMs,
              onChangeStart: canScrub
                  ? (value) => setState(() => _dragValueMs = value)
                  : null,
              onChanged: canScrub
                  ? (value) => setState(() => _dragValueMs = value)
                  : null,
              onChangeEnd: canScrub ? _onScrubEnd : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            duration != null
                ? '${_formatDuration(Duration(milliseconds: displayMs.round()))}'
                      ' / ${_formatDuration(duration)}'
                : l10n.voiceMessage,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Encrypted empty state
// ---------------------------------------------------------------------------

class _EncryptedEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Text(
        l10n.sayHello,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
