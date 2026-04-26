import 'package:flutter/material.dart';

import '../../../models/ai_provider_profile.dart';
import '../../../services/ai/ai_model_catalog.dart';

class ProviderModelSelector extends StatefulWidget {
  final AiProviderType providerType;
  final String modelValue;
  final bool enabled;
  final ValueChanged<String> onModelChanged;

  const ProviderModelSelector({
    super.key,
    required this.providerType,
    required this.modelValue,
    required this.enabled,
    required this.onModelChanged,
  });

  @override
  State<ProviderModelSelector> createState() => _ProviderModelSelectorState();
}

class _ProviderModelSelectorState extends State<ProviderModelSelector> {
  late final TextEditingController _customModelController;

  @override
  void initState() {
    super.initState();
    _customModelController = TextEditingController(text: widget.modelValue.trim());
  }

  @override
  void didUpdateWidget(covariant ProviderModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.modelValue.trim();
    if (_customModelController.text != nextValue) {
      _customModelController.text = nextValue;
    }
  }

  @override
  void dispose() {
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = AiModelCatalog.optionsFor(widget.providerType);
    final trimmedModel = widget.modelValue.trim();
    final isRecommended = AiModelCatalog.contains(
      widget.providerType,
      trimmedModel,
    );
    final dropdownValue = isRecommended
        ? trimmedModel
        : AiModelCatalog.customModelValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
            '${widget.providerType.storageValue}:$dropdownValue',
          ),
          initialValue: dropdownValue,
          decoration: const InputDecoration(labelText: 'Recommended model'),
          items: [
            ...options.map(
              (option) => DropdownMenuItem(
                value: option.id,
                child: Text(option.label),
              ),
            ),
            const DropdownMenuItem(
              value: AiModelCatalog.customModelValue,
              child: Text('Custom model'),
            ),
          ],
          onChanged: !widget.enabled
              ? null
              : (value) {
                  if (value == null) return;
                  if (value == AiModelCatalog.customModelValue) {
                    if (AiModelCatalog.contains(
                      widget.providerType,
                      trimmedModel,
                    )) {
                      widget.onModelChanged('');
                    }
                    return;
                  }
                  widget.onModelChanged(value);
                },
        ),
        const SizedBox(height: 8),
        Text(
          _helperText(widget.providerType, trimmedModel),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
        if (!isRecommended) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customModelController,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Custom model',
              hintText: 'Enter an exact provider model id',
            ),
            onChanged: widget.onModelChanged,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Enter a model name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  String _helperText(AiProviderType type, String currentModel) {
    final option = AiModelCatalog.find(type, currentModel);
    if (option != null) {
      return option.description;
    }

    if (currentModel.isNotEmpty) {
      return 'Using a custom model id for ${type.displayName}.';
    }

    return 'Choose one of the recommended ${type.displayName} models or enter a custom model id.';
  }
}
