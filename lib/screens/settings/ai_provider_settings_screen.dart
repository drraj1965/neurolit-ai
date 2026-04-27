import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/ai_provider_profile.dart';
import '../../models/app_update_models.dart';
import '../../services/ai/ai_model_catalog.dart';
import '../../services/ai/ai_provider_router.dart';
import '../../services/ai/ai_provider_store.dart';
import '../../services/storage/neuro_lit_path_service.dart';
import '../../services/update_service.dart';
import '../../services/token/token_service.dart';
import 'ai_provider_edit_screen.dart';
import 'widgets/data_folder_settings_card.dart';
import 'widgets/update_settings_card.dart';

class AiProviderSettingsScreen extends StatefulWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  State<AiProviderSettingsScreen> createState() =>
      _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState extends State<AiProviderSettingsScreen> {
  final AiProviderStore _store = AiProviderStore();
  late final AiProviderRouter _router = AiProviderRouter(
    store: _store,
    tokenService: TokenService(),
  );
  final UpdateService _updateService = UpdateService();
  final NeuroLitPathService _pathService = NeuroLitPathService();

  bool _loading = true;
  bool _checkingForUpdates = false;
  bool _changingDataFolder = false;
  List<AiProviderProfile> _profiles = const [];
  UpdateSettings _updateSettings = const UpdateSettings(
    frequency: UpdateFrequency.weekly,
  );
  UpdateCheckResult? _latestUpdateResult;
  String _activeDataFolderPath = '';
  String _defaultDataFolderPath = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openAddProvider,
        icon: const Icon(Icons.add),
        label: const Text('Add Provider'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        UpdateSettingsCard(
          settings: _updateSettings,
          isChecking: _checkingForUpdates,
          latestResult: _latestUpdateResult,
          onFrequencyChanged: _changeUpdateFrequency,
          onCheckPressed: _checkForUpdates,
          onInstallPressed: _installUpdate,
        ),
        const SizedBox(height: 16),
        DataFolderSettingsCard(
          activeFolderPath: _activeDataFolderPath,
          defaultFolderPath: _defaultDataFolderPath,
          isBusy: _changingDataFolder,
          onChooseFolder: _chooseDataFolder,
          onOpenFolder: _openDataFolder,
          onResetToDefault: _resetDataFolder,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Text(
            'OpenAI, Gemini, and Sarvam profiles can be used by the current generation workflow. Set any saved profile as active to route new AI runs through that provider.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        if (_profiles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'No AI providers saved yet. Add one to prepare local provider profiles.',
            ),
          )
        else
          ..._profiles.map(_buildProfileCard),
      ],
    );
  }

  Widget _buildProfileCard(AiProviderProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (profile.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Provider: ${profile.type.displayName}'),
            Text('Model: ${_modelLine(profile)}'),
            if ((profile.baseUrl ?? '').trim().isNotEmpty)
              Text('Base URL: ${profile.baseUrl}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: profile.isActive
                      ? null
                      : () => _setActive(profile.id),
                  child: const Text('Set Active'),
                ),
                OutlinedButton(
                  onPressed: () => _openEditProvider(profile),
                  child: const Text('Edit'),
                ),
                OutlinedButton(
                  onPressed: profile.type.supportsValidation
                      ? () => _testProfile(profile)
                      : null,
                  child: const Text('Test'),
                ),
                OutlinedButton(
                  onPressed: () => _deleteProfile(profile),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
    });

    final profiles = await _store.getProfiles();
    final updateSettings = await _updateService.loadSettings();
    final activeDataFolderPath = await _pathService.getActiveRootPath();
    final defaultDataFolderPath = await _pathService.getDefaultRootPath();

    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _updateSettings = updateSettings;
      _activeDataFolderPath = activeDataFolderPath;
      _defaultDataFolderPath = defaultDataFolderPath;
      _loading = false;
    });
  }

  Future<void> _openAddProvider() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AiProviderEditScreen(),
      ),
    );

    if (changed == true) {
      await _loadProfiles();
    }
  }

  Future<void> _openEditProvider(AiProviderProfile profile) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AiProviderEditScreen(initialProfile: profile),
      ),
    );

    if (changed == true) {
      await _loadProfiles();
    }
  }

  Future<void> _setActive(String profileId) async {
    await _store.setActiveProfile(profileId);
    await _loadProfiles();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Active provider updated')),
    );
  }

  Future<void> _deleteProfile(AiProviderProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Provider'),
        content: Text('Delete "${profile.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _store.deleteProfile(profile.id);
    await _loadProfiles();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Provider deleted')),
    );
  }

  Future<void> _testProfile(AiProviderProfile profile) async {
    final apiKey = await _store.readApiKey(profile.id);
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This profile has no stored API key')),
      );
      return;
    }

    try {
      await _router.validateProfile(profile: profile, apiKey: apiKey);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection successful')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _modelLine(AiProviderProfile profile) {
    final rawModel = profile.model.trim();
    if (rawModel.isEmpty) {
      return '(not set)';
    }

    final displayLabel = AiModelCatalog.displayLabelFor(profile.type, rawModel);
    if (displayLabel == rawModel) {
      return rawModel;
    }

    return '$displayLabel ($rawModel)';
  }

  Future<void> _changeUpdateFrequency(UpdateFrequency? frequency) async {
    if (frequency == null) return;

    await _updateService.saveFrequency(frequency);
    final latest = await _updateService.loadSettings();

    if (!mounted) return;
    setState(() {
      _updateSettings = latest;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Update frequency set to ${frequency.displayLabel}')),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
    });

    try {
      final result = await _updateService.checkForUpdates(ignoreSchedule: true);
      if (!mounted) return;
      setState(() {
        _latestUpdateResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update check failed: $e')),
      );
    } finally {
      if (mounted) {
        final latest = await _updateService.loadSettings();
        setState(() {
          _updateSettings = latest;
          _checkingForUpdates = false;
        });
      }
    }
  }

  Future<void> _installUpdate(UpdateInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Install Update'),
        content: Text(
          'Download and launch version ${info.latestVersion}? The installer will start after the current app closes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Install'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _updateService.launchInstaller(info);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Update downloaded. Close the app and the installer will launch automatically.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to launch update: $e')),
      );
    }
  }

  Future<void> _chooseDataFolder() async {
    setState(() {
      _changingDataFolder = true;
    });

    try {
      final selectedPath = await _pathService.chooseFolderPath();
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        return;
      }

      final directory = Directory(selectedPath);
      await _pathService.ensureDirectoryExists(directory);
      await _pathService.setOverridePath(directory.path);
      await _loadProfiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NeuroLit data folder updated')),
      );
    } catch (e) {
      if (!mounted) return;
      await _showStorageErrorDialog(
        'Unable to use the selected folder',
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingDataFolder = false;
        });
      }
    }
  }

  Future<void> _openDataFolder() async {
    setState(() {
      _changingDataFolder = true;
    });

    try {
      await _pathService.openFolderPath(_activeDataFolderPath);
    } catch (e) {
      if (!mounted) return;
      await _showStorageErrorDialog(
        'Unable to open the NeuroLit data folder',
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingDataFolder = false;
        });
      }
    }
  }

  Future<void> _resetDataFolder() async {
    setState(() {
      _changingDataFolder = true;
    });

    try {
      await _pathService.setOverridePath(null);
      await _pathService.getRootFolder(create: true);
      await _loadProfiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NeuroLit data folder reset to default')),
      );
    } catch (e) {
      if (!mounted) return;
      await _showStorageErrorDialog(
        'Unable to reset the NeuroLit data folder',
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingDataFolder = false;
        });
      }
    }
  }

  Future<void> _showStorageErrorDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
