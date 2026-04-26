import 'package:flutter/material.dart';

import '../../models/ai_provider_profile.dart';
import '../../services/ai/ai_model_catalog.dart';
import '../../services/ai/ai_provider_router.dart';
import '../../services/ai/ai_provider_store.dart';
import '../../services/token/token_service.dart';
import 'widgets/provider_model_selector.dart';

class AiProviderEditScreen extends StatefulWidget {
  final AiProviderProfile? initialProfile;

  const AiProviderEditScreen({
    super.key,
    this.initialProfile,
  });

  @override
  State<AiProviderEditScreen> createState() => _AiProviderEditScreenState();
}

class _AiProviderEditScreenState extends State<AiProviderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  final AiProviderStore _store = AiProviderStore();
  late final AiProviderRouter _router = AiProviderRouter(
    store: _store,
    tokenService: TokenService(),
  );

  late AiProviderType _selectedType;
  bool _makeActive = false;
  bool _saving = false;
  bool _testing = false;
  bool _hasStoredApiKey = false;

  bool get _isEditing => widget.initialProfile != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialProfile?.type ?? AiProviderType.openai;
    _labelController.text = widget.initialProfile?.label ?? '';
    _modelController.text = widget.initialProfile?.model.isNotEmpty == true
        ? widget.initialProfile!.model
        : _selectedType.defaultModel;
    _baseUrlController.text = widget.initialProfile?.baseUrl ?? '';
    _makeActive = widget.initialProfile?.isActive ?? true;

    if (_labelController.text.isEmpty) {
      _labelController.text = _selectedType.displayName;
    }

    _loadStoredApiKeyPresence();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Provider' : 'Add Provider'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSupportCard(),
              const SizedBox(height: 16),
              DropdownButtonFormField<AiProviderType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: AiProviderType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _saving || _testing
                    ? null
                    : (value) {
                        if (value == null) return;

                        final currentModel = _modelController.text.trim();
                        final previousDefault = _selectedType.defaultModel;
                        final previousDisplayName = _selectedType.displayName;
                        final shouldResetModel = currentModel.isEmpty ||
                            currentModel == previousDefault ||
                            AiModelCatalog.contains(_selectedType, currentModel);

                        setState(() {
                          _selectedType = value;
                          if (shouldResetModel) {
                            _modelController.text = value.defaultModel;
                          }
                          if (_labelController.text.trim().isEmpty ||
                              _labelController.text.trim() ==
                                  previousDisplayName) {
                            _labelController.text = value.displayName;
                          }
                        });
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: _validateLabel,
              ),
              const SizedBox(height: 12),
              ProviderModelSelector(
                providerType: _selectedType,
                modelValue: _modelController.text,
                enabled: !(_saving || _testing),
                onModelChanged: (value) {
                  setState(() {
                    _modelController.text = value.trim();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'API key (leave blank to keep current)'
                      : 'API key',
                  helperText: _isEditing
                      ? (_hasStoredApiKey
                          ? 'A key is already stored securely for this profile. Leave this blank to keep it, or paste a new key to replace it.'
                          : 'No saved key has been detected for this profile yet.')
                      : null,
                  suffixIcon: _isEditing && _hasStoredApiKey
                      ? const Icon(Icons.lock_outline)
                      : null,
                ),
                obscureText: true,
                validator: _validateApiKey,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Make this the active provider'),
                value: _makeActive,
                onChanged: _saving || _testing
                    ? null
                    : (value) {
                        setState(() {
                          _makeActive = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving || _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving || _testing ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    final message =
        'This provider can be used by the current generation workflow once it has a valid API key and is set active. Recommended models are listed below, and you can still enter a custom provider model id when needed.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String? _validateLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a provider label';
    }
    return null;
  }

  String? _validateApiKey(String? value) {
    final trimmed = value?.trim() ?? '';
    if (_isEditing && trimmed.isEmpty) return null;
    if (trimmed.isEmpty) {
      return 'Enter an API key';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final profile = _buildProfile();
      final apiKey = _apiKeyController.text.trim();

      if (_isEditing) {
        await _store.updateProfile(
          profile,
          apiKey: apiKey.isEmpty ? null : apiKey,
        );
      } else {
        await _store.saveProfile(profile, apiKey: apiKey);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
    });

    try {
      final profile = _buildProfile();
      final apiKey = await _resolvedApiKeyForValidation();

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('An API key is required to test the connection.');
      }

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
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  AiProviderProfile _buildProfile() {
    final now = DateTime.now();
    final initial = widget.initialProfile;

    return AiProviderProfile(
      id: initial?.id ?? 'provider_${now.microsecondsSinceEpoch}',
      type: _selectedType,
      label: _labelController.text.trim(),
      model: _modelController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? null
          : _baseUrlController.text.trim(),
      isActive: _makeActive,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<String?> _resolvedApiKeyForValidation() async {
    final typed = _apiKeyController.text.trim();
    if (typed.isNotEmpty) return typed;

    if (!_isEditing || widget.initialProfile == null) return null;
    return _store.readApiKey(widget.initialProfile!.id);
  }

  Future<void> _loadStoredApiKeyPresence() async {
    if (!_isEditing || widget.initialProfile == null) {
      return;
    }

    try {
      final apiKey = await _store.readApiKey(widget.initialProfile!.id);
      if (!mounted) return;
      setState(() {
        _hasStoredApiKey = apiKey != null && apiKey.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasStoredApiKey = false;
      });
    }
  }
}
