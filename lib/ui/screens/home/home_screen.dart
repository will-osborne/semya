import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:semya/config/constants.dart';
import 'package:semya/config/router.dart';
import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/providers/providers.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
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
// New chat bottom sheet — search by phone, start direct or group
// ---------------------------------------------------------------------------

class _NewChatSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

              // Group chat option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.group_add,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(l10n.newGroup),
                subtitle: Text(l10n.createGroupConversation),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.createGroup);
                },
              ),
              const Divider(height: 24),

              // Phone search
              TextField(
                controller: _searchController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: l10n.searchByPhoneNumber,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),

              // Results
              if (_query.trim().isNotEmpty)
                Expanded(
                  child: _SearchResults(
                    query: _query.trim(),
                    scrollController: scrollController,
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.enterPhoneToFind,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.scrollController});

  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(userSearchProvider(query));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.searchFailed(e.toString()))),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              l10n.noUsersFound,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  (user.displayName ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(user.displayName ?? l10n.unknown),
              subtitle: Text(user.phoneNumber),
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
        );
      },
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
      separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
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
    final currentUserId = ref.watch(authProvider).user?.uid;
    final unreadCount = currentUserId == null
        ? 0
        : (conversation.unreadCounts[currentUserId] ?? 0);
    final hasUnread = unreadCount > 0;
    final previewText = conversation.lastMessagePreview?.trim() ?? '';
    final hasPreview = previewText.isNotEmpty;

    // Resolve display title.
    String title;
    if (isGroup) {
      title = conversation.title ?? l10n.group;
    } else {
      // For direct conversations, show the other user's name.
      final uid = ref.watch(authProvider).user?.uid;
      final otherIds = conversation.participantIds
          .where((id) => id != uid)
          .toList();
      title = _resolveDirectTitle(ref, otherIds, l10n);
    }

    String? formattedTime;
    final msgDate = conversation.lastMessageAt;
    if (msgDate != null) {
      final now = DateTime.now();
      if (now.difference(msgDate).inDays == 0) {
        formattedTime = DateFormat.jm().format(msgDate);
      } else if (now.difference(msgDate).inDays < 7) {
        formattedTime = DateFormat.E().format(msgDate);
      } else {
        formattedTime = DateFormat.MMMd().format(msgDate);
      }
    }

    return InkWell(
      onTap: () => context.push('/chat/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isGroup
                  ? colorScheme.secondaryContainer
                  : colorScheme.primaryContainer,
              child: isGroup
                  ? Icon(Icons.group, color: colorScheme.onSecondaryContainer)
                  : Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
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

  /// Resolves the display name for a direct conversation by fetching the other
  /// user from Firestore. Returns a placeholder while loading.
  String _resolveDirectTitle(
    WidgetRef ref,
    List<String> otherIds,
    AppLocalizations l10n,
  ) {
    if (otherIds.isEmpty) return l10n.chat;
    // Use a simple FutureProvider to fetch the other user's name.
    final otherUserAsync = ref.watch(_otherUserNameProvider(otherIds.first));
    return otherUserAsync.when(
      data: (name) => name ?? l10n.unknown,
      loading: () => '...',
      error: (_, __) => l10n.unknown,
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
