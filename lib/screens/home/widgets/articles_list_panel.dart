import 'package:flutter/material.dart';

import '../../../models/article.dart';
import 'article_card.dart';
import 'pagination_bar.dart';

class ArticlesListPanel extends StatelessWidget {
  final bool showPagination;
  final int currentPage;
  final int totalPages;
  final bool canGoPrevious;
  final bool canGoNext;
  final List<Article> pagedArticles;
  final Set<String> selectedArticlePmids;
  final Widget Function(Article article) badgesBuilder;
  final String Function(String abstractText) previewBuilder;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final void Function(Article article) onOpenAbstract;
  final void Function(Article article, bool? isSelected) onToggleSelected;
  final void Function(Article article) onOpenPubMed;

  const ArticlesListPanel({
    super.key,
    required this.showPagination,
    required this.currentPage,
    required this.totalPages,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.pagedArticles,
    required this.selectedArticlePmids,
    required this.badgesBuilder,
    required this.previewBuilder,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onOpenAbstract,
    required this.onToggleSelected,
    required this.onOpenPubMed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showPagination)
          PaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
          ),
        Expanded(
          child: ListView.builder(
            itemCount: pagedArticles.length,
            itemBuilder: (context, index) {
              final article = pagedArticles[index];

              return ArticleCard(
                article: article,
                isSelected: selectedArticlePmids.contains(article.pmid),
                previewText: previewBuilder(article.abstractText),
                badges: badgesBuilder(article),
                onOpenAbstract: () => onOpenAbstract(article),
                onSelectionChanged: (value) => onToggleSelected(article, value),
                onOpenPubMed: () => onOpenPubMed(article),
              );
            },
          ),
        ),
      ],
    );
  }
}
