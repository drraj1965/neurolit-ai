import 'package:flutter/material.dart';

class DataFolderSettingsCard extends StatelessWidget {
  const DataFolderSettingsCard({
    super.key,
    required this.activeFolderPath,
    required this.defaultFolderPath,
    required this.isBusy,
    required this.onChooseFolder,
    required this.onOpenFolder,
    required this.onResetToDefault,
  });

  final String activeFolderPath;
  final String defaultFolderPath;
  final bool isBusy;
  final Future<void> Function() onChooseFolder;
  final Future<void> Function() onOpenFolder;
  final Future<void> Function() onResetToDefault;

  @override
  Widget build(BuildContext context) {
    final usesDefault = activeFolderPath == defaultFolderPath;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NeuroLit Data Folder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              usesDefault
                  ? 'Using the default NeuroLit folder.'
                  : 'Using a custom NeuroLit folder.',
            ),
            const SizedBox(height: 10),
            SelectableText(
              activeFolderPath,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Default: $defaultFolderPath',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onChooseFolder(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose Folder'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onOpenFolder(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Folder'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy || usesDefault
                      ? null
                      : () => onResetToDefault(),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to Default'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
