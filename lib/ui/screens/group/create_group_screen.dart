import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:semya/domain/entities/user.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/providers/providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();

  final List<AppUser> _selectedMembers = [];
  List<AppUser> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    try {
      final userRepo = ref.read(firestoreUserRepositoryProvider);
      final results = await userRepo.searchUsersByEmail(query.trim());
      // Filter out the current user.
      final uid = ref.read(authProvider).user?.uid;
      final filtered = results.where((u) => u.id != uid).toList();
      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSearch = false);
      }
    }
  }

  void _toggleMember(AppUser user) {
    setState(() {
      if (_selectedMembers.any((m) => m.id == user.id)) {
        _selectedMembers.removeWhere((m) => m.id == user.id);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  bool _isMemberSelected(AppUser user) {
    return _selectedMembers.any((m) => m.id == user.id);
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final conversationService = ref.read(conversationServiceProvider);
      final memberIds = _selectedMembers.map((m) => m.id).toList();
      final conversationId = await conversationService.createGroupConversation(
        _groupNameController.text.trim(),
        memberIds,
      );

      if (mounted) {
        context.go('/chat/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToCreateGroup(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newGroup),
        actions: [
          if (_selectedMembers.isNotEmpty)
            TextButton(
              onPressed: _isCreating ? null : _createGroup,
              child: Text(l10n.create),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group name section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // Group avatar placeholder
                  GestureDetector(
                    onTap: () {
                      // Photo picker — wired later.
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.group,
                            color: colorScheme.onSecondaryContainer,
                            size: 28,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.camera_alt,
                                color: colorScheme.onPrimary,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Group name field
                  Expanded(
                    child: TextFormField(
                      controller: _groupNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      enabled: !_isCreating,
                      maxLength: 32,
                      decoration: InputDecoration(
                        labelText: l10n.groupNameLabel,
                        hintText: l10n.groupNameHint,
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.groupNameEmpty;
                        }
                        if (value.trim().length < 2) {
                          return l10n.groupNameTooShort;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Selected members chips
            if (_selectedMembers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  l10n.membersCount(_selectedMembers.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = _selectedMembers[index];
                    final name = member.displayName ?? l10n.unknown;
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      label: Text(name),
                      onDeleted: () => _toggleMember(member),
                    );
                  },
                ),
              ),
            ],

            const Divider(height: 16),

            // Contact search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                enabled: !_isCreating,
                decoration: InputDecoration(
                  hintText: l10n.searchByEmail,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            const SizedBox(height: 8),

            // Results / placeholder
            Expanded(
              child: _isSearching
                  ? _isLoadingSearch
                        ? const Center(child: CircularProgressIndicator())
                        : _searchResults.isEmpty
                        ? _NoResultsState()
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final isSelected = _isMemberSelected(user);
                              return _ContactTile(
                                user: user,
                                isSelected: isSelected,
                                onTap: () => _toggleMember(user),
                              );
                            },
                          )
                  : _SearchPromptState(),
            ),

            // Bottom action bar
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: (_isCreating || _selectedMembers.isEmpty)
                      ? null
                      : _createGroup,
                  child: _isCreating
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          _selectedMembers.isEmpty
                              ? l10n.addMembersToContinue
                              : l10n.createGroup,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact tile
// ---------------------------------------------------------------------------

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final AppUser user;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = user.displayName ?? l10n.unknown;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.primary
            : colorScheme.primaryContainer,
        child: isSelected
            ? Icon(Icons.check, color: colorScheme.onPrimary)
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Text(name),
      subtitle: Text(user.email ?? user.phoneNumber),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : Icon(Icons.circle_outlined, color: colorScheme.outline),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

class _SearchPromptState extends StatelessWidget {
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
            Icon(
              Icons.person_search_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.searchForFamilyMembers,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
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
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noUsersFoundInstallApp,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
