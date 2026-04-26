import 'package:flutter/material.dart';

import '../../../models/article.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final bool isSelected;
  final String previewText;
  final Widget badges;
  final VoidCallback onOpenAbstract;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback onOpenPubMed;

  const ArticleCard({
    super.key,
    required this.article,
    required this.isSelected,
    required this.previewText,
    required this.badges,
    required this.onOpenAbstract,
    required this.onSelectionChanged,
    required this.onOpenPubMed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: onOpenAbstract,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: onSelectionChanged,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.authors,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${article.journal} • ${article.date}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${article.displayIdentifierLabel}: ${article.displayIdentifierValue}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    badges,
                    const SizedBox(height: 8),
                    Text(
                      previewText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (article.link.trim().isNotEmpty)
                      InkWell(
                        onTap: onOpenPubMed,
                        child: Text(
                          article.openLinkLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
