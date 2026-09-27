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
  late Future<List<HistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _historyService.getAll();
  }

  void _refresh() {
    setState(() => _future = _historyService.getAll());
  }

  Future<void> _delete(String id) async {
    await _historyService.delete(id);
    _refresh();
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoryItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No history yet. Scan or generate something!'),
            ),
          );
        }
        return ListView.builder(
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
                leading: Icon(item.type == 'scan' ? Icons.qr_code_scanner : Icons.qr_code_2),
                title: Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_formatTimestamp(item.timestamp)),
                onTap: () => _openDetail(item),
              ),
            );
          },
        );
      },
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

  const _DetailSheet({
    required this.item,
    required this.onDelete,
    required this.onRegenerate,
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
          SelectableText(item.value),
          const SizedBox(height: 20),
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
