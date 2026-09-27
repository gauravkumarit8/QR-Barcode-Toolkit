import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace with real data from HistoryService (SharedPreferences-backed)
    final items = <String>[];

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
        return ListTile(
          leading: const Icon(Icons.qr_code),
          title: Text(items[index], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Text(''), // TODO: timestamp
          onTap: () {
            // TODO: open detail view (Copy, Open, Share, Re-generate, Delete)
          },
        );
      },
    );
  }
}
