import 'package:flutter/material.dart';

import '../../../models/literature_mode.dart';

class SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isRelatedMode;
  final String? currentTopic;
  final VoidCallback onSearch;
  final ValueChanged<bool?> onRelatedModeChanged;
  final LiteratureMode literatureMode;
  final ValueChanged<LiteratureMode> onModeChanged;

  const SearchSection({
    super.key,
    required this.controller,
    required this.isRelatedMode,
    required this.currentTopic,
    required this.onSearch,
    required this.onRelatedModeChanged,
    required this.literatureMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Medical'),
              selected: literatureMode == LiteratureMode.medical,
              onSelected: (_) => onModeChanged(LiteratureMode.medical),
            ),
            ChoiceChip(
              label: const Text('Engineering'),
              selected: literatureMode == LiteratureMode.engineering,
              onSelected: (_) => onModeChanged(LiteratureMode.engineering),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          literatureMode == LiteratureMode.medical
              ? 'Medical mode searches PubMed.'
              : 'Engineering mode searches CORE, DOAJ, and arXiv.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            hintText: literatureMode.searchHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearch,
            ),
          ),
          onSubmitted: (_) => onSearch(),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Checkbox(
                value: isRelatedMode,
                onChanged: onRelatedModeChanged,
              ),
              const Text("Related searches"),
              if (currentTopic != null)
                SizedBox(
                  width: 120,
                  child: Text(
                    "Topic: $currentTopic",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
