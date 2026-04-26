import 'package:flutter/material.dart';
import '../../models/ai_provider_profile.dart';
import '../../models/article.dart';
import '../../services/layman/layman_service.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class LaymanPanel extends StatefulWidget {
  final List<Article> selectedArticles;
  final String topic;
  final LaymanService service;
  final List<AiProviderProfile> availableRunProviders;
  final String? selectedRunProviderId;
  final ValueChanged<String?> onRunProviderChanged;
  final Future<bool> Function({String? providerOverrideId})
      ensureAiProviderReady;
  final Future<String> Function({String? providerOverrideId})
      resolveProviderCacheKey;
  final Function(String json)? onGeneratePpt;

  const LaymanPanel({
    super.key,
    required this.selectedArticles,
    required this.topic,
    required this.service,
    required this.availableRunProviders,
    required this.selectedRunProviderId,
    required this.onRunProviderChanged,
    required this.ensureAiProviderReady,
    required this.resolveProviderCacheKey,
    this.onGeneratePpt,
  });

  @override
  State<LaymanPanel> createState() => _LaymanPanelState();
}

class _LaymanPanelState extends State<LaymanPanel> {
  String mode = "quick";
  bool loading = false;

  Future<void> run() async {
    if (widget.selectedArticles.isEmpty) return;
    final selectedProviderId = widget.selectedRunProviderId;
    if (!await widget.ensureAiProviderReady(
      providerOverrideId: selectedProviderId,
    )) {
      return;
    }

    setState(() => loading = true);

    try {
      final providerCacheKey = await widget.resolveProviderCacheKey(
        providerOverrideId: selectedProviderId,
      );
      final result = await widget.service.generate(
        articles: widget.selectedArticles,
        mode: mode,
        topic: widget.topic,
        providerCacheKey: providerCacheKey,
        providerOverrideId: selectedProviderId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result["reused"]
                ? "Loaded existing output"
                : "Layman output saved successfully",
          ),
        ),
      );

      final content = result["content"];
      final File file = result["file"];

      if (mode == "ppt") {
        try {
          final dir = await Directory(
            "${Directory.systemTemp.path}/NeuroLit_Layman",
          ).create(recursive: true);

          final file = File(
            "${dir.path}/layman_${DateTime.now().millisecondsSinceEpoch}.json",
          );

          await file.writeAsString(content);

          print("✅ Layman JSON saved at: ${file.path}");

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("JSON saved: ${file.path}")),
          );

          await widget.onGeneratePpt?.call(file.path);
        } catch (e) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("PPT Error"),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            ),
          );
        }

        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(result["reused"] ? "Reused Output" : "Layman Output"),
          content: SizedBox(
            width: 600,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(content),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied to clipboard")),
                );
              },
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () async {
                await Process.start('explorer', [file.path]);
              },
              child: const Text("Open File"),
            ),
            TextButton(
              onPressed: () async {
                await Process.start('explorer', [file.parent.path]);
              },
              child: const Text("Open Folder"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProviderBanner(),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: widget.selectedRunProviderId ?? '',
          decoration: const InputDecoration(labelText: "Run provider"),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(_defaultProviderLabel()),
            ),
            ...widget.availableRunProviders.map(
              (profile) => DropdownMenuItem(
                value: profile.id,
                child: Text('${profile.label} (${profile.type.displayName})'),
              ),
            ),
          ],
          onChanged: (value) {
            widget.onRunProviderChanged(
              value == null || value.isEmpty ? null : value,
            );
          },
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: mode,
          items: const [
            DropdownMenuItem(value: "quick", child: Text("Quick Summary")),
            DropdownMenuItem(value: "detailed", child: Text("Detailed")),
            DropdownMenuItem(value: "ppt", child: Text("Layman PPT")),
          ],
          onChanged: (v) => setState(() => mode = v!),
        ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: loading ? null : run,
          child: loading
              ? const CircularProgressIndicator()
              : const Text("Generate Layman"),
        ),
      ],
    );
  }

  String _defaultProviderLabel() {
    final activeProfile = _activeProfile();
    if (activeProfile != null) {
      return 'Default (Active: ${activeProfile.label})';
    }

    return 'Default (Active Provider)';
  }

  Widget _buildProviderBanner() {
    final activeProfile = _activeProfile();
    final selectedProfile = _selectedProfile();
    final isOverrideSelected = selectedProfile != null;
    final primary = isOverrideSelected ? selectedProfile : activeProfile;

    if (primary == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Active default provider: not configured yet.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final text = isOverrideSelected
        ? 'This run will use ${primary.label} (${primary.type.displayName}). Active default provider: ${activeProfile?.label ?? 'not set'}.'
        : 'Active default provider: ${primary.label} (${primary.type.displayName}).';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  AiProviderProfile? _activeProfile() {
    for (final profile in widget.availableRunProviders) {
      if (profile.isActive) {
        return profile;
      }
    }

    return null;
  }

  AiProviderProfile? _selectedProfile() {
    if (widget.selectedRunProviderId == null ||
        widget.selectedRunProviderId!.isEmpty) {
      return null;
    }

    for (final profile in widget.availableRunProviders) {
      if (profile.id == widget.selectedRunProviderId) {
        return profile;
      }
    }

    return null;
  }
}
