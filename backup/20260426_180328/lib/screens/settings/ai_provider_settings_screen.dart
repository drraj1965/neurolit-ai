import 'package:flutter/material.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai/ai_model_catalog.dart';
import '../../services/ai/ai_provider_router.dart';
import '../../services/ai/ai_provider_store.dart';
import '../../services/token/token_service.dart';
import 'ai_provider_edit_screen.dart';

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

  bool _loading = true;
  List<AiProviderProfile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Providers'),
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

    if (!mounted) return;
    setState(() {
      _profiles = profiles;
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
}
