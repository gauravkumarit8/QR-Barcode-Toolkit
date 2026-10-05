import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  final ValueChanged<String> onRegenerate;

  const HistoryScreen({super.key, required this.onRegenerate});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _historyService = HistoryService();
  final _searchController = TextEditingController();

  List<HistoryItem>? _items; // null until first load
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    HistoryService.changes.addListener(_load);
  }

  @override
  void dispose() {
    HistoryService.changes.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _historyService.getAll();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _delete(String id) async {
    // Remove from the visible list synchronously: a swiped Dismissible must
    // be gone from the tree by the end of the frame or Flutter asserts.
    setState(() => _items?.removeWhere((i) => i.id == id));
    await _historyService.delete(id);
  }

  Future<void> _toggleFavorite(HistoryItem item) async {
    // Optimistic local update so the star flips instantly; the service call
    // below persists it and HistoryService.changes will reconcile anyway.
    setState(() {
      final idx = _items?.indexWhere((i) => i.id == item.id) ?? -1;
      if (idx != -1) _items![idx] = item.copyWith(favorite: !item.favorite);
    });
    await _historyService.setFavorite(item.id, !item.favorite);
  }

  void _openDetail(HistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DetailSheet(
        item: item,
        onDelete: () {
          Navigator.pop(context);
          _delete(item.id);
        },
        onRegenerate: () {
          Navigator.pop(context);
          widget.onRegenerate(item.value);
        },
        onToggleFavorite: () => _toggleFavorite(item),
      ),
    );
  }

  /// Case-insensitive match on the content, or on the words "scan" /
  /// "generate" (so you can list only scanned or only generated items),
  /// plus the favorites-only filter chip.
  List<HistoryItem> _filtered(List<HistoryItem> items) {
    var result = items;
    if (_favoritesOnly) {
      result = result.where((i) => i.favorite).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return result;
    return result
        .where((i) =>
            i.value.toLowerCase().contains(q) ||
            (i.type == 'scan' ? 'scanned' : 'generated').contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    if (all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No history yet. Scan or generate something!'),
        ),
      );
    }

    final items = _filtered(all);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search history',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !_favoritesOnly,
                onSelected: (_) => setState(() => _favoritesOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.star, size: 16),
                label: const Text('Favorites'),
                selected: _favoritesOnly,
                onSelected: (_) => setState(() => _favoritesOnly = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_favoritesOnly && _query.isEmpty
                        ? 'No favorites yet — tap the star on any item to save it here'
                        : 'No matches for "${_query.trim()}"'),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => _delete(item.id),
                      child: ListTile(
                        leading: Icon(item.type == 'scan'
                            ? Icons.qr_code_scanner
                            : Icons.qr_code_2),
                        title: Text(item.value,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatTimestamp(item.timestamp)),
                        trailing: IconButton(
                          icon: Icon(
                            item.favorite ? Icons.star : Icons.star_border,
                            color: item.favorite ? Colors.amber : null,
                          ),
                          tooltip: item.favorite ? 'Remove favorite' : 'Add favorite',
                          onPressed: () => _toggleFavorite(item),
                        ),
                        onTap: () => _openDetail(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailSheet extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleFavorite;

  const _DetailSheet({
    required this.item,
    required this.onDelete,
    required this.onRegenerate,
    required this.onToggleFavorite,
  });

  bool get _isUrl {
    final uri = Uri.tryParse(item.value);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SelectableText(item.value)),
              IconButton(
                icon: Icon(
                  item.favorite ? Icons.star : Icons.star_border,
                  color: item.favorite ? Colors.amber : null,
                ),
                tooltip: item.favorite ? 'Remove favorite' : 'Add favorite',
                onPressed: onToggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: item.value));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (_isUrl)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                  onPressed: () async {
                    await launchUrl(Uri.parse(item.value), mode: LaunchMode.externalApplication);
                  },
                ),
              TextButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
                onPressed: () => Share.share(item.value),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Re-generate'),
                onPressed: onRegenerate,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
