import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/notification_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../applications/presentation/providers/application_providers.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import 'providers/notification_providers.dart';
import 'widgets/inbox_filter_sheet.dart';
import 'widgets/notification_tile.dart';
import 'widgets/snooze_sheet.dart';

/// The notification inbox: search, filter, snooze, archive and delete.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(inboxFilterProvider).query;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(inboxFilterProvider.notifier).setQuery('');
  }

  /// Resets the search text and every filter, as the "Clear all" button does.
  void _clearAll() {
    _searchController.clear();
    ref.read(inboxFilterProvider.notifier).reset();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      ref.read(inboxProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(inboxFilterProvider);
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final matching = ref.watch(filteredCountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            tooltip: 'Snoozed notifications',
            onPressed: () => context.push(Routes.snoozed),
            icon: const Icon(Icons.snooze_rounded),
          ),
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: unread == 0
                ? null
                : () => ref.read(inboxProvider.notifier).markAllAsRead(),
            icon: const Icon(Icons.done_all_rounded),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filters',
                onPressed: () => InboxFilterSheet.show(context),
                icon: const Icon(Icons.filter_list_rounded),
              ),
              if (filter.activeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filter.activeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search notifications',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _clearSearch,
                      ),
              ),
              onChanged: (value) =>
                  ref.read(inboxFilterProvider.notifier).setQuery(value),
            ),
          ),
          if (matching != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    '$matching notification${matching == 1 ? '' : 's'}'
                    '${filter.isActive ? ' match your filters' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (filter.isActive)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Clear all'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: inbox.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(inboxProvider),
              ),
              data: (state) => _InboxList(
                items: state.items,
                isLoadingMore: state.isLoadingMore,
                scrollController: _scrollController,
                searchQuery: filter.query,
                // A filter other than the search text. The search text has its
                // own empty state, so it is left out of this check.
                hasActiveFilters: filter.copyWith(query: '').isActive,
                onClearSearch: _clearSearch,
                onClearFilters: _clearAll,
                onRefresh: () => ref.read(inboxProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  const _InboxList({
    required this.items,
    required this.isLoadingMore,
    required this.scrollController,
    required this.searchQuery,
    required this.hasActiveFilters,
    required this.onClearSearch,
    required this.onClearFilters,
    required this.onRefresh,
  });

  /// Longest query echoed back in the empty-state title, before an ellipsis.
  ///
  /// A pasted paragraph would otherwise push the title over several lines and
  /// bury the message underneath it. Counted in grapheme clusters, so this is
  /// 20 characters as a reader would count them, in any script.
  static const int _maxQueryInTitle = 20;

  final List<NotificationItem> items;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final String searchQuery;

  /// Whether a package, priority, category, date, unread or archived
  /// constraint is applied, not counting the search text.
  final bool hasActiveFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;

  /// Trims [query] to [_maxQueryInTitle] characters so it fits in a title.
  ///
  /// Cuts on grapheme clusters rather than UTF-16 code units. `substring`
  /// would slice a surrogate pair in half and leave the user looking at a
  /// replacement character inside their own search term.
  static String _shortenForTitle(String query) {
    final chars = query.characters;
    return chars.length <= _maxQueryInTitle
        ? query
        : '${chars.take(_maxQueryInTitle)}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      // Three different situations, and they need different words. Nothing
      // captured yet is a first-run state. A search or a filter that matched
      // nothing is not: the inbox may be full, so telling that user the inbox
      // is empty reads as data loss, and offering Refresh invites them to
      // re-fetch something that was never missing.
      //
      // When both a query and a filter are active, the query wins: it is the
      // constraint the user changed most recently, and its action only has to
      // undo that.
      final query = searchQuery.trim();
      if (query.isEmpty && hasActiveFilters) {
        return EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'No notifications match your filters',
          message: 'Try removing a filter, or widen the date range.',
          action: OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Clear filters'),
          ),
        );
      }
      if (query.isEmpty) {
        return EmptyState(
          icon: Icons.inbox_rounded,
          title: 'Your inbox is empty',
          message: 'Captured notifications will appear here.',
          action: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        );
      }

      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for "${_shortenForTitle(query)}"',
        message: 'No notification title or body contains this text.',
        action: OutlinedButton.icon(
          onPressed: onClearSearch,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Clear search'),
        ),
      );
    }

    final labels = ref.watch(appLabelsProvider).valueOrNull ?? const {};
    final categories =
        ref.watch(categoriesByIdProvider).valueOrNull ?? const {};
    final hidePreview = ref.watch(settingsProvider).hidePreviewContent;
    final rows = _buildRows(items);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        itemCount: rows.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final row = rows[index];
          if (row is _HeaderRow) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                row.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final item = (row as _ItemRow).item;
          return Dismissible(
            key: ValueKey('notification-${item.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Icon(Icons.archive_outlined),
            ),
            onDismissed: (_) {
              ref.read(inboxProvider.notifier).archive(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification archived')),
              );
            },
            child: NotificationTile(
              item: item,
              appLabel: labels[item.packageName] ?? item.packageName,
              category: categories[item.categoryId],
              hidePreview: hidePreview,
              onTap: () {
                ref.read(inboxProvider.notifier).setRead(item.id);
                context.push(Routes.notificationDetail(item.id));
              },
              onLongPress: () => _showActions(context, ref, item),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
  ) async {
    final notifier = ref.read(inboxProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                item.isRead
                    ? Icons.mark_email_unread_outlined
                    : Icons.mark_email_read_outlined,
              ),
              title: Text(item.isRead ? 'Mark as unread' : 'Mark as read'),
              onTap: () {
                notifier.setRead(item.id, isRead: !item.isRead);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.snooze_rounded),
              title: const Text('Snooze'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final duration = await SnoozeSheet.show(context);
                if (duration != null) {
                  await notifier.snooze(item.id, duration);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () {
                notifier.archive(item.id);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () {
                notifier.delete(item.id);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Inserts a date header before each new day.
  static List<_Row> _buildRows(List<NotificationItem> items) {
    final rows = <_Row>[];
    String? currentDay;
    for (final item in items) {
      final day = item.postedAt.dayKey;
      if (day != currentDay) {
        currentDay = day;
        rows.add(_HeaderRow(_headerLabel(item.postedAt)));
      }
      rows.add(_ItemRow(item));
    }
    return rows;
  }

  static String _headerLabel(DateTime date) {
    if (date.isToday) return 'Today';
    if (date.isYesterday) return 'Yesterday';
    return date.relativeLabel;
  }
}

sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.label);

  final String label;
}

class _ItemRow extends _Row {
  const _ItemRow(this.item);

  final NotificationItem item;
}
