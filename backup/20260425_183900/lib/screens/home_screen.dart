import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../models/ai_provider_profile.dart';
import '../models/literature_mode.dart';
import '../services/ai/ai_provider_store.dart';
import '../services/collection_service.dart';
import '../services/export_service.dart';
import '../services/fulltext_service.dart';
import '../services/layman/layman_service.dart';
import '../services/search_service.dart';
import '../services/slide_structure_service.dart';
import '../services/summary_service.dart';
import '../services/token/token_service.dart';
import '../services/ui/modal_service.dart';
import '../widgets/layman/layman_panel.dart';
import 'home/widgets/articles_list_panel.dart';
import 'home/widgets/doctor_output_panel.dart';
import 'home/widgets/home_screen_body.dart';
import 'home/widgets/search_section.dart';
import 'home/widgets/session_panel.dart';
import 'home/widgets/sidebar_panel.dart';
import 'settings/ai_provider_settings_screen.dart';

part 'home/actions/home_collection_actions.dart';
part 'home/actions/home_file_actions.dart';
part 'home/actions/home_review_actions.dart';
part 'home/actions/home_search_actions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? currentTopic;
  bool isRelatedMode = false;
  LiteratureMode literatureMode = LiteratureMode.medical;

  final SearchService searchService = SearchService();
  final AiProviderStore aiProviderStore = AiProviderStore();
  final SummaryService summary = SummaryService();
  final CollectionService collectionService = CollectionService();

  List<Article> articles = [];
  Set<String> selectedPmids = {};
  Map<String, Article> selectedArticlesGlobal = {};
  Set<String> selectedForCollection = {};
  bool showSelectedOnly = false;

  final TextEditingController controller = TextEditingController();
  final FullTextService fullTextService = FullTextService();
  String currentSessionFile = "";
  String currentSearchQuery = "";
  int sessionAbstractCount = 0;
  String dateFilter = "1y";
  bool autoExpand = false;
  late LaymanService laymanService;
  DateTimeRange? customRange;

  bool isUpdateMode = false;
  SavedCollection? activeCollection;
  bool hasCollectionChanged = false;
  String textAvailability = 'any';
  String articleType = 'any';

  String outputMode = "review";

  String? lastGeneratedReview;

  String postFilterTextAvailability = 'any';
  String postFilterArticleType = 'any';

  List<Map<String, dynamic>> recentSearches = [];
  List<SavedCollection> savedCollections = [];
  Set<String> selectedCollectionPaths = {};
  bool collectionsLoading = false;
  List<AiProviderProfile> availableRunProviders = const [];
  String? runProviderOverrideId;

  int currentPage = 0;
  double topPanelWidth = 240;
  double filterPanelWidth = 240;
  final int pageSize = 10;

  @override
  void initState() {
    super.initState();
    laymanService = LaymanService(summary);
    loadRecentSearches();
    loadCollections();
    loadAvailableRunProviders();
  }

  List<Article> get pagedArticles {
    final base = showSelectedOnly
        ? selectedArticlesGlobal.values.toList()
        : articles;

    final filtered = base.where((a) {
      var matchText = true;
      var matchType = true;

      if (postFilterTextAvailability == 'abstract') {
        matchText = a.abstractText.trim().isNotEmpty;
      } else if (postFilterTextAvailability == 'free_full_text') {
        matchText = a.isFree || a.isPMC;
      }

      if (postFilterArticleType == 'review') {
        matchType = a.journal.toLowerCase().contains('review');
      }

      return matchText && matchType;
    }).toList();

    final start = currentPage * pageSize;
    if (start >= filtered.length) return [];

    final end = (start + pageSize) > filtered.length
        ? filtered.length
        : (start + pageSize);

    return filtered.sublist(start, end);
  }

  int get totalPages {
    final base = showSelectedOnly
        ? selectedArticlesGlobal.values.toList()
        : articles;

    final filtered = base.where((a) {
      var matchText = true;
      var matchType = true;

      if (postFilterTextAvailability == 'abstract') {
        matchText = a.abstractText.trim().isNotEmpty;
      } else if (postFilterTextAvailability == 'free_full_text') {
        matchText = a.isFree || a.isPMC;
      }

      if (postFilterArticleType == 'review') {
        matchType = a.journal.toLowerCase().contains('review');
      }

      return matchText && matchType;
    }).toList();

    if (filtered.isEmpty) return 1;

    return ((filtered.length - 1) ~/ pageSize) + 1;
  }

  Widget buildArticleBadges(Article a) {
    final badges = <Widget>[];

    if (a.literatureMode == LiteratureMode.engineering) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _sourceColor(a.displaySource),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(a.displaySource, style: const TextStyle(fontSize: 12)),
        ),
      );

      if (a.hasFullText || a.pdfUrl.trim().isNotEmpty) {
        badges.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Full Text Available",
              style: TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    }

    if (a.isFree) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("Free article", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (a.isPMC) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("PMC", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (a.publicationType.toLowerCase().contains('review')) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("Review", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges
            .map(
              (badge) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: badge,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> showTokenUsage() async {
    final summary = await TokenService().getUsageSummary();
    if (!mounted) return;

    await ModalService.showTokenUsageDialog(
      context: context,
      summary: summary,
    );
  }

  Future<void> openAiProviderSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiProviderSettingsScreen(),
      ),
    );

    await loadAvailableRunProviders();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadAvailableRunProviders() async {
    final profiles = (await aiProviderStore.getProfiles())
        .where((profile) => profile.type.supportsRuntimeToday)
        .toList();

    if (!mounted) return;
    setState(() {
      availableRunProviders = profiles;
      final overrideIsValid = runProviderOverrideId == null ||
          profiles.any((profile) => profile.id == runProviderOverrideId);
      if (!overrideIsValid) {
        runProviderOverrideId = null;
      }
    });
  }

  Future<bool> ensureAiProviderReady({String? providerOverrideId}) async {
    final selectedOverrideId = (providerOverrideId ?? '').trim();
    final selectedProfile = selectedOverrideId.isEmpty
        ? await aiProviderStore.getActiveProfile()
        : await aiProviderStore.getProfile(selectedOverrideId);

    String title = 'AI Setup Required';
    String message =
        'AI generation needs a configured AI provider before it can run. Search and saving abstracts can still be used without AI setup.';

    if (selectedProfile != null) {
      final apiKey = await aiProviderStore.readApiKey(selectedProfile.id);

      if (apiKey != null &&
          apiKey.isNotEmpty &&
          selectedProfile.type.supportsRuntimeToday) {
        return true;
      }

      if (!selectedProfile.type.supportsRuntimeToday) {
        title = 'Provider Not Ready Yet';
        message =
            '${selectedProfile.type.displayName} profiles can be saved now, but this build cannot run that provider yet.';
      } else {
        title = 'AI Provider Update Required';
        message =
            'The selected provider "${selectedProfile.label}" is missing its API key. Update it to continue.';
      }
    } else if (selectedOverrideId.isNotEmpty) {
      title = 'Provider Selection Needs Attention';
      message =
          'The selected run provider is no longer available. Please choose another provider or update your provider settings.';
    }

    if (!mounted) return false;

    final shouldOpenSettings = await ModalService.showAiSetupRequiredDialog(
      context: context,
      title: title,
      message: message,
    );

    if (!shouldOpenSettings) {
      return false;
    }

    await openAiProviderSettings();

    final refreshedProfile = selectedOverrideId.isEmpty
        ? await aiProviderStore.getActiveProfile()
        : await aiProviderStore.getProfile(selectedOverrideId);
    if (refreshedProfile == null || !refreshedProfile.type.supportsRuntimeToday) {
      return false;
    }

    final refreshedApiKey = await aiProviderStore.readApiKey(refreshedProfile.id);
    return refreshedApiKey != null && refreshedApiKey.isNotEmpty;
  }

  void enableUpdateMode() {
    setState(() {
      isUpdateMode = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Update mode enabled")),
    );
  }

  Widget buildFilterPanel() {
    return SidebarPanel(
      width: filterPanelWidth,
      dateFilter: dateFilter,
      customRangeLabel: customRangeLabel(),
      textAvailability: textAvailability,
      articleType: articleType,
      autoExpand: autoExpand,
      selectedArticlesCount: selectedArticlesGlobal.length,
      hasActiveCollection: activeCollection != null,
      isUpdateMode: isUpdateMode,
      lastTokenUsageListenable: TokenService().lastUsageNotifier,
      onDateFilterChanged: (v) {
        if (v == null) return;
        setState(() {
          dateFilter = v;
        });
      },
      onPickCustomDateRange: pickCustomDateRange,
      onTextAvailabilityChanged: (v) {
        if (v == null) return;
        setState(() {
          textAvailability = v;
        });
      },
      onArticleTypeChanged: (v) {
        if (v == null) return;
        setState(() {
          articleType = v;
        });
      },
      onAutoExpandChanged: (v) {
        setState(() {
          autoExpand = v ?? false;
        });
      },
      onClearFilters: clearFilters,
      onShowSelectionManager: showSelectionManager,
      onLoadCollectionFromFile: loadCollectionFromFile,
      onEnableUpdateMode: enableUpdateMode,
      onSaveUpdatedCollection: updateCurrentCollection,
      onShowTokenUsage: showTokenUsage,
    );
  }

  Widget buildSearchSection() {
    return SearchSection(
      controller: controller,
      isRelatedMode: isRelatedMode,
      currentTopic: currentTopic,
      literatureMode: literatureMode,
      onSearch: search,
      onModeChanged: (mode) {
        setState(() {
          literatureMode = mode;
          articles = <Article>[];
          selectedPmids.clear();
          selectedArticlesGlobal.clear();
          showSelectedOnly = false;
          currentPage = 0;
          currentTopic = null;
          currentSearchQuery = '';
          currentSessionFile = '';
          sessionAbstractCount = 0;
          lastGeneratedReview = null;
        });
      },
      onRelatedModeChanged: (v) {
        setState(() {
          isRelatedMode = v ?? false;
          if (!isRelatedMode) currentTopic = null;
        });
      },
    );
  }

  Widget buildTopSection() {
    return DoctorOutputPanel(
      postFilterTextAvailability: postFilterTextAvailability,
      onPostFilterTextAvailabilityChanged: (v) {
        if (v == null) return;
        setState(() {
          postFilterTextAvailability = v;
          currentPage = 0;
        });
      },
      recentSearches: recentSearches,
      onApplyRecentSearch: applyRecentSearch,
      onShowMoreRecentSearches: showMoreRecentSearches,
      outputMode: outputMode,
      availableRunProviders: availableRunProviders,
      selectedRunProviderId: runProviderOverrideId,
      onRunProviderChanged: (providerId) {
        setState(() {
          runProviderOverrideId = providerId;
        });
      },
      onOutputModeChanged: (v) {
        if (v == null) return;
        setState(() {
          outputMode = v;
        });
      },
      hasGeneratedReview:
          lastGeneratedReview != null && lastGeneratedReview!.trim().isNotEmpty,
      selectedCount: selectedArticlesGlobal.length,
      collectionsCount: savedCollections.length,
      showSelectedOnly: showSelectedOnly,
      onGenerateSummary: generateSummary,
      onGenerateSlides: generateSlidesFromReview,
      onGenerateFromFolder: generateFromFolder,
      onGenerateFromSelection: generateFromSelection,
      onShowCollectionManager: showCollectionManager,
      onToggleShowSelectedOnly: () {
        setState(() {
          showSelectedOnly = !showSelectedOnly;
          currentPage = 0;
        });
      },
      onClearSelection: () {
        setState(() {
          selectedPmids.clear();
          selectedArticlesGlobal.clear();
        });
      },
    );
  }

  Widget buildTopSectionWithTabs() {
    return Column(
      children: [
        buildSearchSection(),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "Doctor Output"),
                    Tab(text: "Layman Output"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(child: buildTopSection()),
                      buildLaymanOutputPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLaymanOutputPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LaymanPanel(
        selectedArticles: selectedArticlesGlobal.values.toList(),
        topic: currentTopic ?? "General",
        service: laymanService,
        availableRunProviders: availableRunProviders,
        selectedRunProviderId: runProviderOverrideId,
        onRunProviderChanged: (providerId) {
          setState(() {
            runProviderOverrideId = providerId;
          });
        },
        ensureAiProviderReady: ({providerOverrideId}) =>
            ensureAiProviderReady(providerOverrideId: providerOverrideId),
        resolveProviderCacheKey: ({providerOverrideId}) async {
          final selectedOverrideId = (providerOverrideId ?? '').trim();
          if (selectedOverrideId.isNotEmpty) {
            return selectedOverrideId;
          }

          final activeProfile = await aiProviderStore.getActiveProfile();
          return activeProfile?.id ?? 'active_provider';
        },
        onGeneratePpt: (path) async {
          await generatePptFromSlides(path);
        },
      ),
    );
  }

  Widget buildArticlesList() {
    return ArticlesListPanel(
      showPagination: articles.isNotEmpty,
      currentPage: currentPage,
      totalPages: totalPages,
      canGoPrevious: currentPage > 0,
      canGoNext: currentPage < totalPages - 1,
      pagedArticles: pagedArticles,
      selectedArticlePmids: selectedArticlesGlobal.keys.toSet(),
      badgesBuilder: buildArticleBadges,
      previewBuilder: previewSnippet,
      onPreviousPage: () {
        setState(() {
          currentPage--;
        });
      },
      onNextPage: () {
        setState(() {
          currentPage++;
        });
      },
      onOpenAbstract: openAbstract,
      onToggleSelected: (article, isSelected) {
        setState(() {
          if (isSelected == true) {
            selectedPmids.add(article.selectionKey);
            selectedArticlesGlobal[article.selectionKey] = article;
          } else {
            selectedPmids.remove(article.selectionKey);
            selectedArticlesGlobal.remove(article.selectionKey);
          }
        });
      },
      onOpenPubMed: (article) => openArticleLink(article.link),
    );
  }

  Widget buildSessionPanel() {
    return SessionPanel(
      currentSearchQuery: currentSearchQuery,
      sessionAbstractCount: sessionAbstractCount,
      currentSessionFile: currentSessionFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final filterPanel = buildFilterPanel();

    return Scaffold(
      appBar: AppBar(
        title: const Text("NeuroLit AI"),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () {
                if (!isWide) {
                  Scaffold.of(context).openEndDrawer();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: openAiProviderSettings,
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () {
              if (currentSessionFile.isNotEmpty) {
                Process.start('notepad.exe', [currentSessionFile]);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () async {
              final dir = Directory(
                'C:/Users/${Platform.environment['USERNAME']}/Documents',
              );
              final folderPath = "${dir.path}/NeuroLit";
              await Process.start(
                'explorer.exe',
                [folderPath.replaceAll('/', '\\')],
              );
            },
          ),
        ],
      ),
      endDrawer: isWide ? null : Drawer(child: filterPanel),
      body: HomeScreenBody(
        isWide: isWide,
        filterPanel: isWide ? filterPanel : null,
        topSectionWithTabs: buildTopSectionWithTabs(),
        sessionPanel: buildSessionPanel(),
        articlesList: buildArticlesList(),
        topPanelWidth: topPanelWidth,
        filterPanelWidth: filterPanelWidth,
        onTopPanelWidthChanged: (width) {
          setState(() {
            topPanelWidth = width;
          });
        },
        onFilterPanelWidthChanged: (width) {
          setState(() {
            filterPanelWidth = width;
          });
        },
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'core':
        return Colors.indigo.shade100;
      case 'doaj':
        return Colors.green.shade100;
      case 'arxiv':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
