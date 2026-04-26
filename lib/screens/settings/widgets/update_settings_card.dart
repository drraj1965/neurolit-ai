import 'package:flutter/material.dart';

import '../../../models/app_update_models.dart';
import '../../../services/app_version_service.dart';

class UpdateSettingsCard extends StatelessWidget {
  const UpdateSettingsCard({
    super.key,
    required this.settings,
    required this.isChecking,
    required this.latestResult,
    required this.onFrequencyChanged,
    required this.onCheckPressed,
    required this.onInstallPressed,
  });

  final UpdateSettings settings;
  final bool isChecking;
  final UpdateCheckResult? latestResult;
  final ValueChanged<UpdateFrequency?> onFrequencyChanged;
  final Future<void> Function() onCheckPressed;
  final Future<void> Function(UpdateInfo info) onInstallPressed;

  @override
  Widget build(BuildContext context) {
    final updateInfo = latestResult?.updateInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Updates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text('Current version: ${AppVersionService.currentVersion}'),
            if (settings.lastCheckedAt != null)
              Text('Last checked: ${_formatDate(settings.lastCheckedAt!)}'),
            const SizedBox(height: 14),
            DropdownButtonFormField<UpdateFrequency>(
              initialValue: settings.frequency,
              decoration: const InputDecoration(
                labelText: 'Update frequency',
                border: OutlineInputBorder(),
              ),
              items: UpdateFrequency.values
                  .map(
                    (frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.displayLabel),
                    ),
                  )
                  .toList(),
              onChanged: onFrequencyChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isChecking ? null : () => onCheckPressed(),
                  icon: isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  label: Text(isChecking ? 'Checking...' : 'Check for Updates'),
                ),
                if (latestResult?.isUpdateAvailable == true && updateInfo != null)
                  OutlinedButton.icon(
                    onPressed: () => onInstallPressed(updateInfo),
                    icon: const Icon(Icons.download),
                    label: Text('Install ${updateInfo.latestVersion}'),
                  ),
              ],
            ),
            if (latestResult != null) ...[
              const SizedBox(height: 12),
              _buildStatusBanner(context, latestResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, UpdateCheckResult result) {
    if (result.wasSkippedBySchedule) {
      return _banner(
        color: Colors.grey.shade100,
        borderColor: Colors.grey.shade300,
        child: const Text(
          'Automatic check skipped because the selected update frequency is not due yet.',
        ),
      );
    }

    if (result.isUpdateAvailable && result.updateInfo != null) {
      return _banner(
        color: Colors.green.shade50,
        borderColor: Colors.green.shade300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update available: ${result.updateInfo!.latestVersion}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (result.updateInfo!.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(result.updateInfo!.releaseNotes),
            ],
          ],
        ),
      );
    }

    return _banner(
      color: Colors.blue.shade50,
      borderColor: Colors.blue.shade300,
      child: const Text('You already have the latest version installed.'),
    );
  }

  Widget _banner({
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}
