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
  late final _falKey = TextEditingController(text: widget.settings.falKey);
  late final _proxy = TextEditingController(text: widget.settings.proxyUrl);
  late String _provider = widget.settings.provider;
  late String _model = widget.settings.model;
  late String _falModel = widget.settings.falModel;
  late String _quality = widget.settings.quality;
  bool _showKey = false;
  bool _showFalKey = false;

  Future<void> _save() async {
    widget.settings
      ..provider = _provider
      ..apiKey = _key.text
      ..falKey = _falKey.text
      ..falModel = _falModel
      ..proxyUrl = _proxy.text
      ..model = _model
      ..quality = _quality;
    await widget.settings.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _keyField(TextEditingController c, String label, String hint,
      bool show, VoidCallback toggle) {
    return TextField(
      controller: c,
      obscureText: !show,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpenAI = _provider == 'openai';
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Proveedor', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'openai',
                  label: Text('OpenAI'),
                  icon: Icon(Icons.auto_awesome)),
              ButtonSegment(
                  value: 'fal',
                  label: Text('fal.ai (Flux)'),
                  icon: Icon(Icons.bolt)),
            ],
            selected: {_provider},
            onSelectionChanged: (s) => setState(() => _provider = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            isOpenAI
                ? 'GPT Image: el mismo modelo de ChatGPT. El más fiel escribiendo textos.'
                : 'Flux vía fal.ai: más barato y rápido; el texto en la imagen sale algo peor. Correcciones con Flux Kontext.',
            style: const TextStyle(fontSize: 12),
          ),
          const Divider(height: 32),

          // ---------- OpenAI ----------
          if (isOpenAI) ...[
            _keyField(_key, 'API key de OpenAI', 'sk-…', _showKey,
                () => setState(() => _showKey = !_showKey)),
            const SizedBox(height: 6),
            const Text(
              'La key se guarda solo en este teléfono. Si repartes la app a otras personas, usa el proxy (server/) y deja este campo vacío.',
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
                DropdownMenuItem(
                    value: 'low', child: Text('Baja — borradores, ~1 ¢')),
                DropdownMenuItem(
                    value: 'medium', child: Text('Media — uso normal, ~5-6 ¢')),
                DropdownMenuItem(
                    value: 'high', child: Text('Alta — entrega final, ~20-25 ¢')),
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
          ],

          // ---------- fal.ai ----------
          if (!isOpenAI) ...[
            _keyField(_falKey, 'API key de fal.ai', 'xxxxxxxx:xxxxxxxx…',
                _showFalKey, () => setState(() => _showFalKey = !_showFalKey)),
            const SizedBox(height: 6),
            const Text(
              'La misma key que usas en PhotoTetal (fal.ai → Keys).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _falModel,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Modelo Flux (texto → imagen)',
                  border: OutlineInputBorder()),
              items: Settings.falModels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _falModel = v ?? _falModel),
            ),
          ],

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
