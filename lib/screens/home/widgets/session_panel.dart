import 'package:flutter/material.dart';

class SessionPanel extends StatelessWidget {
  final String currentSearchQuery;
  final int sessionAbstractCount;
  final String currentSessionFile;

  const SessionPanel({
    super.key,
    required this.currentSearchQuery,
    required this.sessionAbstractCount,
    required this.currentSessionFile,
  });

  @override
  Widget build(BuildContext context) {
    if (currentSearchQuery.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SESSION", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(currentSearchQuery, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            "Abstracts: $sessionAbstractCount",
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            currentSessionFile,
            style: const TextStyle(fontSize: 10),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
