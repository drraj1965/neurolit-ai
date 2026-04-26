import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/article.dart';
import '../collection_service.dart';
import '../token/token_usage_models.dart';
import '../../widgets/token_usage/token_usage_table.dart';

enum CollectionLoadAction {
  generateReview,
  updateCollection,
}

enum ExistingFileChoice {
  openExisting,
  createNew,
}

class ModalDialogAction {
  final String label;
  final FutureOr<void> Function(BuildContext dialogContext) onPressed;

  const ModalDialogAction({
    required this.label,
    required this.onPressed,
  });
}

class ModalOption<T> {
  final String label;
  final T value;

  const ModalOption({
    required this.label,
    required this.value,
  });
}

class ModalService {
  static Future<T?> showOptionDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<ModalOption<T>> options,
    String? cancelLabel = 'Cancel',
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          for (final option in options)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(option.value),
              child: Text(option.label),
            ),
          if (cancelLabel != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel),
            ),
        ],
      ),
    );
  }

  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static Future<bool> showAiSetupRequiredDialog({
    required BuildContext context,
    String title = 'AI Setup Required',
    String message =
        'AI generation needs a configured AI provider before it can run. Search and saving abstracts can still be used without AI setup.',
  }) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: 'Set Up Now',
      cancelLabel: 'Cancel',
    );

    return confirmed == true;
  }

  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> showTextContentDialog({
    required BuildContext context,
    required String title,
    required String text,
    double? width,
    double? height,
    List<ModalDialogAction> actions = const [],
    String closeLabel = 'Close',
    bool includeCloseAction = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget content = SingleChildScrollView(
          child: SelectableText(text),
        );

        if (width != null || height != null) {
          content = SizedBox(
            width: width,
            height: height,
            child: content,
          );
        }

        return AlertDialog(
          title: Text(title),
          content: content,
          actions: [
            ..._buildActionButtons(dialogContext, actions),
            if (includeCloseAction)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(closeLabel),
              ),
          ],
        );
      },
    );
  }

  static Future<void> showPathDialog({
    required BuildContext context,
    required String title,
    required String path,
    required List<ModalDialogAction> actions,
    String introText = 'Saved to:',
    String closeLabel = 'Close',
    bool includeCopyPathAction = true,
    bool closeOnCopy = true,
    Future<void> Function()? onPathTap,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(introText),
              const SizedBox(height: 6),
              InkWell(
                onTap: onPathTap,
                child: Text(
                  path,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (includeCopyPathAction)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (closeOnCopy) {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Copy Path'),
            ),
          ..._buildActionButtons(dialogContext, actions),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(closeLabel),
          ),
        ],
      ),
    );
  }

  static Future<void> showProgressDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  static Future<void> showInvalidJsonDialog(
    BuildContext context,
    String jsonText,
  ) {
    return showTextContentDialog(
      context: context,
      title: 'Invalid JSON',
      text: jsonText,
    );
  }

  static Future<ExistingFileChoice?> showExistingSlidesDialog(
    BuildContext context,
  ) {
    return showOptionDialog<ExistingFileChoice>(
      context: context,
      title: 'Existing Slides Found',
      message: 'Use existing slides JSON?',
      cancelLabel: null,
      options: const [
        ModalOption(
          label: 'Open Existing',
          value: ExistingFileChoice.openExisting,
        ),
        ModalOption(
          label: 'Create New',
          value: ExistingFileChoice.createNew,
        ),
      ],
    );
  }

  static Future<CollectionLoadAction?> showCollectionActionDialog(
    BuildContext context,
  ) {
    return showOptionDialog<CollectionLoadAction>(
      context: context,
      title: 'Select Action',
      message: 'What would you like to do with this collection?',
      options: const [
        ModalOption(
          label: 'Generate Review',
          value: CollectionLoadAction.generateReview,
        ),
        ModalOption(
          label: 'Update Collection',
          value: CollectionLoadAction.updateCollection,
        ),
      ],
    );
  }

  static Future<void> showSelectionManagerDialog({
    required BuildContext context,
    required Map<String, Article> selectedArticles,
    required Set<String> initiallySelectedForCollection,
    required Future<void> Function(Set<String> selectedPmids) onSaveAsCollection,
    required Future<void> Function(Article article) onDeleteArticle,
    required Future<void> Function() onClearAll,
  }) {
    final localArticles = Map<String, Article>.from(selectedArticles);
    final localSelection = Set<String>.from(initiallySelectedForCollection);

    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Selected Articles'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: localArticles.isEmpty
                ? const Center(child: Text('No selected articles'))
                : ListView(
                    children: localArticles.values.map((article) {
                      return CheckboxListTile(
                        value: localSelection.contains(article.pmid),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              localSelection.add(article.pmid);
                            } else {
                              localSelection.remove(article.pmid);
                            }
                          });
                        },
                        title: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'PMID: ${article.pmid}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await onDeleteArticle(article);
                            setDialogState(() {
                              localArticles.remove(article.pmid);
                              localSelection.remove(article.pmid);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: localSelection.isEmpty
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await onSaveAsCollection(Set<String>.from(localSelection));
                    },
              child: const Text('Save as Collection'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await onClearAll();
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showCollectionManagerDialog({
    required BuildContext context,
    required List<SavedCollection> initialCollections,
    required bool initialLoading,
    required Set<String> initialSelectedPaths,
    required Future<List<SavedCollection>> Function() onRefreshCollections,
    required void Function(Set<String> selectedPaths) onSelectionChanged,
    required Future<void> Function(
      SavedCollection collection,
      CollectionLoadAction action,
    ) onLoadCollection,
    required Future<void> Function(SavedCollection collection) onMergeCollection,
    required Future<void> Function(SavedCollection collection) onRenameCollection,
    required Future<void> Function(SavedCollection collection) onDeleteCollection,
    required Future<void> Function(Set<String> selectedPaths) onMergeSelected,
    required Future<void> Function(Set<String> selectedPaths) onSaveMerged,
    required String Function(DateTime? created) dateLabelBuilder,
  }) {
    var collections = List<SavedCollection>.from(initialCollections);
    var selectedPaths = Set<String>.from(initialSelectedPaths);
    var loading = initialLoading;

    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> refreshCollections() async {
            setDialogState(() {
              loading = true;
            });

            final refreshed = await onRefreshCollections();
            final validPaths = refreshed.map((item) => item.file.path).toSet();
            selectedPaths = selectedPaths.where(validPaths.contains).toSet();
            onSelectionChanged(Set<String>.from(selectedPaths));

            setDialogState(() {
              collections = refreshed;
              loading = false;
            });
          }

          return AlertDialog(
            title: const Text('Collection Manager'),
            content: SizedBox(
              width: 760,
              height: 520,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : collections.isEmpty
                      ? const Center(child: Text('No saved collections yet'))
                      : ListView.separated(
                          itemCount: collections.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (itemContext, index) {
                            final collection = collections[index];
                            final isSelected =
                                selectedPaths.contains(collection.file.path);

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedPaths.add(collection.file.path);
                                        } else {
                                          selectedPaths.remove(
                                            collection.file.path,
                                          );
                                        }
                                      });
                                      onSelectionChanged(
                                        Set<String>.from(selectedPaths),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          collection.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${collection.parsedCount} articles'
                                          ' | saved count: ${collection.declaredCount}'
                                          ' | ${dateLabelBuilder(collection.created)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          collection.file.path,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          final action =
                                              await showCollectionActionDialog(
                                            dialogContext,
                                          );
                                          if (action == null) return;
                                          if (!dialogContext.mounted) return;
                                          Navigator.of(dialogContext).pop();
                                          await onLoadCollection(
                                            collection,
                                            action,
                                          );
                                        },
                                        child: const Text('Load'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await onMergeCollection(collection);
                                          if (!dialogContext.mounted) return;
                                          setDialogState(() {});
                                        },
                                        child: const Text('Merge'),
                                      ),
                                      IconButton(
                                        tooltip: 'Rename',
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () async {
                                          await onRenameCollection(collection);
                                          if (!dialogContext.mounted) return;
                                          await refreshCollections();
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          await onDeleteCollection(collection);
                                          if (!dialogContext.mounted) return;
                                          await refreshCollections();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: refreshCollections,
                child: const Text('Refresh'),
              ),
              TextButton(
                onPressed: selectedPaths.isEmpty
                    ? null
                    : () async {
                        await onMergeSelected(Set<String>.from(selectedPaths));
                        if (!dialogContext.mounted) return;
                        setDialogState(() {});
                      },
                child: const Text('Merge Selected'),
              ),
              TextButton(
                onPressed: selectedPaths.length < 2
                    ? null
                    : () async {
                        Navigator.of(dialogContext).pop();
                        await onSaveMerged(Set<String>.from(selectedPaths));
                      },
                child: const Text('Save Merged'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> showArticleDetailsDialog({
    required BuildContext context,
    required Article article,
    required Future<void> Function() onSave,
    required Future<void> Function() onCopy,
    required Future<void> Function() onOpenPubMed,
    required Future<void> Function() onOpenFullTextFolder,
    Future<void> Function()? onDownloadFullText,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(article.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.authors),
              const SizedBox(height: 8),
              Text('${article.journal} • ${article.date}'),
              const SizedBox(height: 8),
              SelectableText(article.abstractText),
              const SizedBox(height: 12),
              InkWell(
                onTap: onOpenPubMed,
                child: Text(
                  article.link,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: onSave,
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: onCopy,
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: onOpenPubMed,
            child: const Text('Open in PubMed'),
          ),
          if (onDownloadFullText != null)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await onDownloadFullText();
              },
              child: const Text('Download Full Text'),
            ),
          TextButton(
            onPressed: onOpenFullTextFolder,
            child: const Text('Open FullText Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> showTokenUsageDialog({
    required BuildContext context,
    required TokenUsageSummary summary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Token Usage'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: TokenUsageTable(summary: summary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> showRecentSearchesDialog({
    required BuildContext context,
    required List<Map<String, dynamic>> recentSearches,
    required Future<void> Function(Map<String, dynamic> entry) onSelect,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recent Searches'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: recentSearches.map((entry) {
              final text = (entry['query'] ?? '').toString();
              return ListTile(
                title: Text(text),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await onSelect(entry);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static Future<void> showSlideStructureDialog({
    required BuildContext context,
    required String jsonText,
    required Future<void> Function() onSave,
    required Future<void> Function() onGeneratePpt,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slide Structure'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(jsonText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: onSave,
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: onGeneratePpt,
            child: const Text('Generate PPT'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> showCollectionFilesDialog({
    required BuildContext context,
    required List<File> files,
    required Future<void> Function(
      File file,
      CollectionLoadAction action,
    ) onSelectAction,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Load Collection'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: files.map((file) {
              return ListTile(
                title: Text(
                  file.path.split('\\').last,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  final action = await showCollectionActionDialog(
                    dialogContext,
                  );
                  if (action == null) return;
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  await onSelectAction(file, action);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static List<Widget> _buildActionButtons(
    BuildContext dialogContext,
    List<ModalDialogAction> actions,
  ) {
    return actions
        .map(
          (action) => TextButton(
            onPressed: () async {
              await action.onPressed(dialogContext);
            },
            child: Text(action.label),
          ),
        )
        .toList();
  }
}
