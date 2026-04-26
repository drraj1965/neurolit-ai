import 'package:flutter/material.dart';

import '../../../models/ai_provider_profile.dart';

class DoctorOutputPanel extends StatelessWidget {
  final String postFilterTextAvailability;
  final ValueChanged<String?> onPostFilterTextAvailabilityChanged;
  final List<Map<String, dynamic>> recentSearches;
  final Future<void> Function(Map<String, dynamic> entry) onApplyRecentSearch;
  final Future<void> Function() onShowMoreRecentSearches;
  final String outputMode;
  final List<AiProviderProfile> availableRunProviders;
  final String? selectedRunProviderId;
  final ValueChanged<String?> onRunProviderChanged;
  final ValueChanged<String?> onOutputModeChanged;
  final bool hasGeneratedReview;
  final int selectedCount;
  final int collectionsCount;
  final bool showSelectedOnly;
  final Future<void> Function() onGenerateSummary;
  final Future<void> Function() onGenerateSlides;
  final Future<void> Function() onGenerateFromFolder;
  final Future<void> Function() onGenerateFromSelection;
  final Future<void> Function() onShowCollectionManager;
  final VoidCallback onToggleShowSelectedOnly;
  final VoidCallback onClearSelection;

  const DoctorOutputPanel({
    super.key,
    required this.postFilterTextAvailability,
    required this.onPostFilterTextAvailabilityChanged,
    required this.recentSearches,
    required this.onApplyRecentSearch,
    required this.onShowMoreRecentSearches,
    required this.outputMode,
    required this.availableRunProviders,
    required this.selectedRunProviderId,
    required this.onRunProviderChanged,
    required this.onOutputModeChanged,
    required this.hasGeneratedReview,
    required this.selectedCount,
    required this.collectionsCount,
    required this.showSelectedOnly,
    required this.onGenerateSummary,
    required this.onGenerateSlides,
    required this.onGenerateFromFolder,
    required this.onGenerateFromSelection,
    required this.onShowCollectionManager,
    required this.onToggleShowSelectedOnly,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: postFilterTextAvailability,
          decoration: const InputDecoration(labelText: "Filter Results"),
          items: const [
            DropdownMenuItem(value: "any", child: Text("All Results")),
            DropdownMenuItem(
              value: "abstract",
              child: Text("Abstract Available"),
            ),
            DropdownMenuItem(
              value: "free_full_text",
              child: Text("Free Full Text"),
            ),
          ],
          onChanged: onPostFilterTextAvailabilityChanged,
        ),
        if (recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Recent Searches",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...recentSearches.take(3).map((entry) {
                  final query = (entry['query'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () async {
                        await onApplyRecentSearch(entry);
                      },
                      child: Text(
                        query,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
                if (recentSearches.length > 3)
                  TextButton(
                    onPressed: () async {
                      await onShowMoreRecentSearches();
                    },
                    child: const Text("More"),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            value: outputMode,
            decoration: const InputDecoration(labelText: "Output mode"),
            items: const [
              DropdownMenuItem(value: "review", child: Text("Review")),
              DropdownMenuItem(
                value: "teaching",
                child: Text("Teaching Synopsis"),
              ),
            ],
            onChanged: onOutputModeChanged,
          ),
        ),
        const SizedBox(height: 8),
        _buildProviderBanner(),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedRunProviderId ?? '',
          decoration: const InputDecoration(
            labelText: "Run provider",
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(_defaultProviderLabel()),
            ),
            ...availableRunProviders.map(
              (profile) => DropdownMenuItem(
                value: profile.id,
                child: Text('${profile.label} (${profile.type.displayName})'),
              ),
            ),
          ],
          onChanged: (value) {
            onRunProviderChanged(
              value == null || value.isEmpty ? null : value,
            );
          },
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "Selected: $selectedCount",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildActionButton(
              label: "Generate AI Summary",
              onPressed: () async {
                await onGenerateSummary();
              },
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: hasGeneratedReview
                  ? "Generate Slides"
                  : "Generate Slides (Review Needed)",
              onPressed: hasGeneratedReview
                  ? () async {
                      await onGenerateSlides();
                    }
                  : null,
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: "Review from Folder",
              onPressed: () async {
                await onGenerateFromFolder();
              },
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: "Review Selected",
              onPressed: () async {
                await onGenerateFromSelection();
              },
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: "Collections ($collectionsCount)",
              onPressed: () async {
                await onShowCollectionManager();
              },
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: showSelectedOnly
                  ? "Show All Articles"
                  : "Show Selected Only",
              onPressed: onToggleShowSelectedOnly,
            ),
            const SizedBox(height: 6),
            _buildActionButton(
              label: "Clear Selection",
              onPressed: onClearSelection,
              backgroundColor: Colors.grey.shade400,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12),
          backgroundColor: backgroundColor,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildProviderBanner() {
    final activeProfile = _activeProfile();
    final selectedProfile = _selectedProfile();
    final isOverrideSelected = selectedProfile != null;
    final primary = isOverrideSelected ? selectedProfile : activeProfile;

    if (primary == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Active default provider: not configured yet.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final text = isOverrideSelected
        ? 'This run will use ${primary.label} (${primary.type.displayName}). Active default provider: ${activeProfile?.label ?? 'not set'}.'
        : 'Active default provider: ${primary.label} (${primary.type.displayName}).';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String _defaultProviderLabel() {
    final activeProfile = _activeProfile();
    if (activeProfile != null) {
      return 'Default (Active: ${activeProfile.label})';
    }

    return 'Default (Active Provider)';
  }

  AiProviderProfile? _activeProfile() {
    for (final profile in availableRunProviders) {
      if (profile.isActive) {
        return profile;
      }
    }

    return null;
  }

  AiProviderProfile? _selectedProfile() {
    if (selectedRunProviderId == null || selectedRunProviderId!.isEmpty) {
      return null;
    }

    for (final profile in availableRunProviders) {
      if (profile.id == selectedRunProviderId) {
        return profile;
      }
    }

    return null;
  }
}
