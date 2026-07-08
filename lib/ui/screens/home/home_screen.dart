import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:semya/config/constants.dart';
import 'package:semya/config/router.dart';
import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/domain/entities/user.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/providers/providers.dart';
import 'package:semya/providers/user_provider.dart';

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            tooltip: l10n.search,
            onPressed: () {
              // Search will be wired later.
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: conversationsAsync.when(
        // Keep showing the current list while the stream resubscribes (e.g.
        // after app resume) instead of flashing a loading state.
        skipLoadingOnReload: true,
        loading: () => const _ConversationListSkeleton(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.errorLoadingConversations(error.toString()),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (conversations) => conversations.isEmpty
            ? _EmptyState(
                onStartConversation: () => _showNewChatDialog(context, ref),
              )
            : _ConversationList(conversations: conversations),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewChatDialog(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.newChat),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NewChatSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// New chat bottom sheet — email search for DM (primary), group chat (secondary)
// ---------------------------------------------------------------------------

class _NewChatSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  static const _debounceDuration = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      // Clearing should feel instant.
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _debounce = Timer(_debounceDuration, () {
      if (mounted && _query != trimmed) setState(() => _query = trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.newChat, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // Email search — primary action
              TextField(
                controller: _searchController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchByEmail,
                  prefixIcon: const Icon(Icons.search),
                  // Listen to the controller directly so typing doesn't
                  // rebuild the whole sheet just to toggle the clear button.
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),

              // Results or empty state
              if (_query.isNotEmpty)
                Expanded(
                  child: _SearchResults(
                    query: _query,
                    scrollController: scrollController,
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.enterEmailToFind,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // New group — secondary action
              const Divider(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.createGroup);
                },
                icon: const Icon(Icons.group_add_outlined),
                label: Text(l10n.newGroup),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Email search, scoped to this screen. autoDispose so abandoned prefixes
/// ("a", "an", "ann"…) don't stay cached forever. Family-keyed by query, so
/// results can never be applied to a different (stale) query.
final _userSearchProvider = FutureProvider.autoDispose
    .family<List<AppUser>, String>((ref, query) {
      final repo = ref.watch(firestoreUserRepositoryProvider);
      return repo.searchUsersByEmail(query);
    });

class _SearchResults extends ConsumerStatefulWidget {
  const _SearchResults({required this.query, required this.scrollController});

  final String query;
  final ScrollController scrollController;

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  /// Last successfully loaded results — kept on screen while a new query is
  /// in flight so the list doesn't flash away on every keystroke.
  List<AppUser>? _lastResults;

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(_userSearchProvider(widget.query));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final loaded = resultsAsync.valueOrNull;
    if (loaded != null) _lastResults = loaded;
    final users = loaded ?? _lastResults;
    final isSearching = resultsAsync.isLoading;

    if (resultsAsync.hasError && !isSearching) {
      return Center(
        child: Text(l10n.searchFailed(resultsAsync.error.toString())),
      );
    }

    return Column(
      children: [
        // Small inline progress instead of a full-height spinner.
        SizedBox(
          height: 2,
          child: isSearching
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(
          child: users == null
              ? const _SearchResultsSkeleton()
              : users.isEmpty
              ? Center(
                  child: Text(
                    l10n.noUsersFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: _UserAvatar(
                        seed: user.id,
                        initialSource: user.displayName,
                        radius: 20,
                      ),
                      title: Text(user.displayName ?? l10n.unknown),
                      subtitle: Text(user.email ?? user.phoneNumber),
                      onTap: () async {
                        Navigator.of(context).pop();
                        final conversationService = ref.read(
                          conversationServiceProvider,
                        );
                        final conversationId = await conversationService
                            .startDirectConversation(user.id);
                        if (context.mounted) {
                          context.push('/chat/$conversationId');
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation list
// ---------------------------------------------------------------------------

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const Divider(indent: 72, height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationTile(conversation: conversation);
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isGroup = conversation.type == ConversationType.group;
    // Only the uid matters here — don't rebuild every tile when unrelated
    // auth flags (isLoading, error) change.
    final currentUserId = ref.watch(
      authProvider.select((state) => state.user?.uid),
    );
    final unreadCount = currentUserId == null
        ? 0
        : (conversation.unreadCounts[currentUserId] ?? 0);
    final hasUnread = unreadCount > 0;
    final previewText = conversation.lastMessagePreview?.trim() ?? '';
    final hasPreview = previewText.isNotEmpty;

    // Resolve display title. Null means "still loading" (direct chats only)
    // and renders as a fixed-size placeholder bar, so nothing jumps once the
    // name arrives.
    String? title;
    String? otherUserId;
    if (isGroup) {
      title = conversation.title ?? l10n.group;
    } else {
      final otherIds = conversation.participantIds
          .where((id) => id != currentUserId)
          .toList();
      if (otherIds.isEmpty) {
        title = l10n.chat;
      } else {
        otherUserId = otherIds.first;
        // Shared cached lookup — resolved once per user, reused by every
        // tile/screen that needs this user.
        final otherUserAsync = ref.watch(userByIdProvider(otherUserId));
        title = otherUserAsync.when(
          skipLoadingOnReload: true,
          data: (user) => user?.displayName ?? l10n.unknown,
          loading: () => null,
          error: (_, _) => l10n.unknown,
        );
      }
    }

    String? formattedTime;
    final msgDate = conversation.lastMessageAt;
    if (msgDate != null) {
      formattedTime = _formatTimestamp(
        msgDate,
        Localizations.localeOf(context).toString(),
      );
    }

    return InkWell(
      onTap: () => context.push('/chat/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (isGroup)
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.group,
                  color: colorScheme.onSecondaryContainer,
                ),
              )
            else
              _UserAvatar(
                seed: otherUserId ?? conversation.id,
                initialSource: title,
                radius: 28,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: title == null
                            ? const _TextPlaceholder(width: 120, height: 16)
                            : Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (formattedTime != null)
                        Text(
                          formattedTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hasUnread
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  if (hasPreview || hasUnread) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: hasPreview
                              ? Text(
                                  previewText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 12),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today → time, last week → weekday, older → short date. Compares calendar
  /// days (not 24h windows) so late-night messages land in the right bucket.
  String _formatTimestamp(DateTime date, String localeName) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(day).inDays;
    if (daysAgo <= 0) return DateFormat.jm(localeName).format(date);
    if (daysAgo < 7) return DateFormat.E(localeName).format(date);
    return DateFormat.MMMd(localeName).format(date);
  }
}

// ---------------------------------------------------------------------------
// Shared visual helpers
// ---------------------------------------------------------------------------

/// Circle avatar with an initials fallback, colored deterministically from
/// [seed] (typically the user id) so a user keeps the same color everywhere.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.seed,
    required this.initialSource,
    required this.radius,
  });

  final String seed;
  final String? initialSource;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final hue = (seed.hashCode.abs() % 360).toDouble();
    final background = HSLColor.fromAHSL(
      1,
      hue,
      isLight ? 0.42 : 0.36,
      isLight ? 0.84 : 0.30,
    ).toColor();
    final foreground = HSLColor.fromAHSL(
      1,
      hue,
      isLight ? 0.48 : 0.38,
      isLight ? 0.28 : 0.88,
    ).toColor();

    final source = initialSource?.trim() ?? '';
    final initial = source.isEmpty ? '?' : source[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initial,
        style: theme.textTheme.titleLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Static grey rounded bar standing in for a line of text.
class _TextPlaceholder extends StatelessWidget {
  const _TextPlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// Gently pulsing wrapper for skeleton placeholders. Pure Flutter — no
/// packages.
class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TextPlaceholder(width: 140, height: 14),
                SizedBox(height: 10),
                _TextPlaceholder(width: 220, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for the conversation list — shown only on first load,
/// reloads keep the previous data on screen.
class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 8,
        itemBuilder: (_, _) => const _SkeletonTile(),
      ),
    );
  }
}

/// Loading placeholder for the first user-search request.
class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, _) => const _SkeletonTile(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStartConversation});

  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 56,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noConversationsYet,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.startConversationPrompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onStartConversation,
              icon: const Icon(Icons.add),
              label: Text(l10n.startConversation),
            ),
          ],
        ),
      ),
    );
  }
}
