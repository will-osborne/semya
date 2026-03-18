import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(sendMessageProvider.notifier)
        .sendMessage(widget.conversationId, text);

    _messageController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceNoteServiceProvider);
    final hasPermission = await voiceService.hasPermission();
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

    await voiceService.startRecording();
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndSend() async {
    setState(() => _isRecording = false);
    await ref
        .read(sendMessageProvider.notifier)
        .sendVoiceMessage(widget.conversationId);
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
              leading: Icon(Icons.videocam_outlined, color: colorScheme.primary),
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
          .sendMediaMessage(widget.conversationId, prepared);
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
          .sendMediaMessage(widget.conversationId, prepared);
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
    final currentUserId = ref.watch(authProvider).user?.uid ?? '';
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
        if (unreadCount > 0) {
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
        final otherUserAsync = ref.watch(_otherUserNameProvider(otherIds.first));
        conversationTitle = otherUserAsync.when(
          data: (name) => name ?? l10n.unknown,
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

    // Voice/media upload state.
    final sendState = ref.watch(sendMessageProvider);

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
                    ? Center(
                        child: Text(l10n.errorGeneric(msgState.error!)),
                      )
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
                            itemCount: msgState.messages.length +
                                (msgState.isLoadingMore ? 1 : 0),
                            findChildIndexCallback: (key) {
                              if (key is ValueKey<String>) {
                                final index = msgState.messages.indexWhere(
                                  (m) => m.id == key.value,
                                );
                                return index >= 0 ? index : null;
                              }
                              return null;
                            },
                            itemBuilder: (context, index) {
                              // Loading indicator at the end (oldest messages).
                              if (index == msgState.messages.length) {
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

                              final messages = msgState.messages;
                              final message = messages[index];
                              final isMine = message.senderId == currentUserId;

                              final showDate =
                                  index == messages.length - 1 ||
                                  !_isSameDay(
                                    messages[index].timestamp,
                                    messages[index + 1].timestamp,
                                  );

                              return Column(
                                key: ValueKey(message.id),
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: message.timestamp),
                                  _MessageBubble(
                                    message: message,
                                    isMine: isMine,
                                    displayStatus: _resolveMessageStatus(
                                      message: message,
                                      conversation: conversation,
                                      currentUserId: currentUserId,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
          ),

          // Voice upload indicator
          if (sendState.isSendingVoice)
            Container(
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
                    l10n.sendingVoiceMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

          // Media upload indicator
          if (sendState.isSendingMedia)
            Container(
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
                    l10n.sendingMedia,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

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

  MessageStatus _resolveMessageStatus({
    required Message message,
    required Conversation? conversation,
    required String currentUserId,
  }) {
    if (message.senderId != currentUserId) return message.status;
    if (message.status == MessageStatus.sending ||
        message.status == MessageStatus.failed) {
      return message.status;
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
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.displayStatus,
  });

  final Message message;
  final bool isMine;
  final MessageStatus displayStatus;

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
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
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
                      width: message.mediaWidth,
                      height: message.mediaHeight,
                    )
                  else if (isVideo)
                    _VideoMessageContent(
                      url: message.content,
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
                            textColor: textColor,
                          )
                        else if (!isMedia)
                          _LinkableSelectableText(
                            text: message.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textColor,
                            ) ?? TextStyle(color: textColor),
                            linkColor: isMine
                                ? Colors.white
                                : colorScheme.primary,
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.jm().format(message.timestamp),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isMine
                                    ? colorScheme.onPrimary.withOpacity(0.7)
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
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
// Selectable text with clickable links
// ---------------------------------------------------------------------------

final _urlRegex = RegExp(
  r'https?://[^\s<>\[\]()]+',
  caseSensitive: false,
);

class _LinkableSelectableText extends StatelessWidget {
  const _LinkableSelectableText({
    required this.text,
    required this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle style;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(style: style, children: spans),
    );
  }
}

// ---------------------------------------------------------------------------
// Image message content (inside bubble)
// ---------------------------------------------------------------------------

class _ImageMessageContent extends StatelessWidget {
  const _ImageMessageContent({
    required this.url,
    this.width,
    this.height,
  });

  final String url;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (width != null && height != null && height! > 0)
        ? width! / height!
        : 4 / 3;

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.5, 2.0),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.broken_image, size: 32)),
          ),
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(url: url),
      ),
    );
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
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video message content (inside bubble)
// ---------------------------------------------------------------------------

class _VideoMessageContent extends ConsumerStatefulWidget {
  const _VideoMessageContent({
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  final String url;
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
    final aspectRatio = (widget.width != null &&
            widget.height != null &&
            widget.height! > 0)
        ? widget.width! / widget.height!
        : 16 / 9;

    return GestureDetector(
      onTap: () => _openVideoPlayer(context),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.5, 2.0).toDouble(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.thumbnailUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[800]),
                  errorWidget: (_, __, ___) =>
                      Container(color: Colors.grey[800]),
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
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
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
        builder: (_) => _FullScreenVideoPlayer(
          url: widget.url,
          cacheService: cacheService,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full screen video player
// ---------------------------------------------------------------------------

class _FullScreenVideoPlayer extends StatefulWidget {
  const _FullScreenVideoPlayer({
    required this.url,
    required this.cacheService,
  });

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
      // Try to get cached file first.
      File? cachedFile;
      try {
        cachedFile = await widget.cacheService.getFile(widget.url);
      } catch (_) {
        // Cache miss — fall back to network.
      }

      final controller = cachedFile != null
          ? VideoPlayerController.file(cachedFile)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
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
// Voice message content (inside bubble)
// ---------------------------------------------------------------------------

class _VoiceMessageContent extends ConsumerStatefulWidget {
  const _VoiceMessageContent({required this.url, required this.textColor});

  final String url;
  final Color textColor;

  @override
  ConsumerState<_VoiceMessageContent> createState() =>
      _VoiceMessageContentState();
}

class _VoiceMessageContentState extends ConsumerState<_VoiceMessageContent> {
  Duration? _metadataDuration;

  @override
  void initState() {
    super.initState();
    _fetchDuration();
  }

  Future<void> _fetchDuration() async {
    final voiceService = ref.read(voiceNoteServiceProvider);
    final duration = await voiceService.getDuration(widget.url);
    if (mounted && duration != null) {
      setState(() => _metadataDuration = duration);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = ref.watch(voiceNoteServiceProvider);
    final textColor = widget.textColor;
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<PlayerState>(
      stream: voiceService.playerStateStream,
      builder: (context, playerSnapshot) {
        final isThisPlaying = voiceService.currentlyPlayingUrl == widget.url;
        final playerState = playerSnapshot.data;
        final playing = isThisPlaying && (playerState?.playing ?? false);

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
            const SizedBox(width: 8),
            Expanded(
              child: isThisPlaying
                  ? StreamBuilder<Duration>(
                      stream: voiceService.positionStream,
                      builder: (context, posSnapshot) {
                        final position = posSnapshot.data ?? Duration.zero;
                        final duration =
                            voiceService.duration ??
                            _metadataDuration ??
                            Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? (position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: textColor.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(position)} / ${_formatDuration(duration)}',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: 0,
                          backgroundColor: textColor.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _metadataDuration != null
                              ? _formatDuration(_metadataDuration!)
                              : l10n.voiceMessage,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Resolves a user's display name by ID.
final _otherUserNameProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(firestoreUserRepositoryProvider);
  final user = await repo.getUser(userId);
  return user?.displayName;
});

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
