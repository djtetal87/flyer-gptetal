import 'package:flutter/material.dart';

import 'settings.dart';

class SettingsScreen extends StatefulWidget {
  final Settings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _key = TextEditingController(text: widget.settings.apiKey);
  late final _proxy = TextEditingController(text: widget.settings.proxyUrl);
  late String _model = widget.settings.model;
  late String _quality = widget.settings.quality;
  bool _showKey = false;

  Future<void> _save() async {
    widget.settings
      ..apiKey = _key.text
      ..proxyUrl = _proxy.text
      ..model = _model
      ..quality = _quality;
    await widget.settings.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key de OpenAI',
              hintText: 'sk-…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'La key se guarda solo en este teléfono. Si más adelante repartes la app a otras personas, usa el proxy (server/) y deja este campo vacío.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _model,
            decoration: const InputDecoration(
                labelText: 'Modelo', border: OutlineInputBorder()),
            items: Settings.models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _model = v ?? _model),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _quality,
            decoration: const InputDecoration(
                labelText: 'Calidad', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Baja — borradores, ~1 centavo')),
              DropdownMenuItem(value: 'medium', child: Text('Media — uso normal, ~5-6 centavos')),
              DropdownMenuItem(value: 'high', child: Text('Alta — entrega final, ~20-25 centavos')),
            ],
            onChanged: (v) => setState(() => _quality = v ?? _quality),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _proxy,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL del proxy (opcional)',
              hintText: 'https://mi-servidor.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
          const SizedBox(height: 32),
          Text('Formato de salida: ${Settings.size} (vertical, siempre).',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
