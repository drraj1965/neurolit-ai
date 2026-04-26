import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/literature_mode.dart';

class SidebarPanel extends StatelessWidget {
  final double width;
  final LiteratureMode literatureMode;
  final String dateFilter;
  final String customRangeLabel;
  final String textAvailability;
  final String articleType;
  final bool autoExpand;
  final int selectedArticlesCount;
  final bool hasActiveCollection;
  final bool isUpdateMode;
  final ValueListenable<int> lastTokenUsageListenable;
  final ValueChanged<String?> onDateFilterChanged;
  final VoidCallback onPickCustomDateRange;
  final ValueChanged<String?> onTextAvailabilityChanged;
  final ValueChanged<String?> onArticleTypeChanged;
  final ValueChanged<bool?> onAutoExpandChanged;
  final Future<void> Function() onClearFilters;
  final VoidCallback onShowSelectionManager;
  final Future<void> Function() onLoadCollectionFromFile;
  final VoidCallback onEnableUpdateMode;
  final Future<void> Function() onSaveUpdatedCollection;
  final Future<void> Function() onShowTokenUsage;

  const SidebarPanel({
    super.key,
    required this.width,
    required this.literatureMode,
    required this.dateFilter,
    required this.customRangeLabel,
    required this.textAvailability,
    required this.articleType,
    required this.autoExpand,
    required this.selectedArticlesCount,
    required this.hasActiveCollection,
    required this.isUpdateMode,
    required this.lastTokenUsageListenable,
    required this.onDateFilterChanged,
    required this.onPickCustomDateRange,
    required this.onTextAvailabilityChanged,
    required this.onArticleTypeChanged,
    required this.onAutoExpandChanged,
    required this.onClearFilters,
    required this.onShowSelectionManager,
    required this.onLoadCollectionFromFile,
    required this.onEnableUpdateMode,
    required this.onSaveUpdatedCollection,
    required this.onShowTokenUsage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filters",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (literatureMode == LiteratureMode.medical) ...[
              DropdownButtonFormField<String>(
                initialValue: dateFilter,
                decoration: const InputDecoration(labelText: "Publication date"),
                items: const [
                  DropdownMenuItem(value: "1w", child: Text("1 Week")),
                  DropdownMenuItem(value: "1m", child: Text("1 Month")),
                  DropdownMenuItem(value: "3m", child: Text("3 Months")),
                  DropdownMenuItem(value: "6m", child: Text("6 Months")),
                  DropdownMenuItem(value: "1y", child: Text("1 Year")),
                  DropdownMenuItem(value: "5y", child: Text("5 Years")),
                  DropdownMenuItem(value: "10y", child: Text("10 Years")),
                  DropdownMenuItem(value: "all", child: Text("All Time")),
                  DropdownMenuItem(value: "custom", child: Text("Custom Range")),
                ],
                onChanged: onDateFilterChanged,
              ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: const Text(
                  "Engineering mode keeps its search workflow separate. Medical-only PubMed search filters are hidden here.",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (literatureMode == LiteratureMode.medical && dateFilter == 'custom') ...[
              const SizedBox(height: 8),
              Text(customRangeLabel),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onPickCustomDateRange,
                child: const Text("Pick Range"),
              ),
            ],
            const SizedBox(height: 12),
            if (literatureMode == LiteratureMode.medical) ...[
              DropdownButtonFormField<String>(
                initialValue: textAvailability,
                decoration: const InputDecoration(labelText: "Text availability"),
                items: const [
                  DropdownMenuItem(value: "any", child: Text("Any")),
                  DropdownMenuItem(value: "abstract", child: Text("Abstract")),
                  DropdownMenuItem(
                    value: "free_full_text",
                    child: Text("Free full text"),
                  ),
                  DropdownMenuItem(value: "full_text", child: Text("Full text")),
                ],
                onChanged: onTextAvailabilityChanged,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: articleType,
                decoration: const InputDecoration(labelText: "Article type"),
                items: const [
                  DropdownMenuItem(value: "any", child: Text("Any")),
                  DropdownMenuItem(
                    value: "clinical_trial",
                    child: Text("Clinical Trial"),
                  ),
                  DropdownMenuItem(
                    value: "meta_analysis",
                    child: Text("Meta-Analysis"),
                  ),
                  DropdownMenuItem(
                    value: "randomized_controlled_trial",
                    child: Text("Randomized Controlled Trial"),
                  ),
                  DropdownMenuItem(value: "review", child: Text("Review")),
                  DropdownMenuItem(
                    value: "systematic_review",
                    child: Text("Systematic Review"),
                  ),
                ],
                onChanged: onArticleTypeChanged,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Auto-expand by 1 year if empty"),
                value: autoExpand,
                onChanged: onAutoExpandChanged,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await onClearFilters();
              },
              child: const Text("Clear filters"),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedArticlesCount == 0
                    ? null
                    : onShowSelectionManager,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text("Manage Selection ($selectedArticlesCount)"),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await onLoadCollectionFromFile();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text("Load Collection"),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasActiveCollection ? onEnableUpdateMode : null,
                child: const Text("Update Collection"),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdateMode
                    ? () async {
                        await onSaveUpdatedCollection();
                      }
                    : null,
                child: const Text("Save Updated Collection"),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: lastTokenUsageListenable,
              builder: (context, lastTokenUsage, _) => Text(
                "Last Tokens: $lastTokenUsage",
                key: ValueKey(lastTokenUsage),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await onShowTokenUsage();
                },
                child: const Text("Token Usage"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
