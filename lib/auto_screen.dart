import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'openai_service.dart';
import 'prompt_builder.dart';
import 'result_screen.dart';
import 'settings.dart';

/// Modo automático: formulario → prompt → flyer.
class AutoScreen extends StatefulWidget {
  final Settings settings;
  const AutoScreen({super.key, required this.settings});

  @override
  State<AutoScreen> createState() => _AutoScreenState();
}

class _AutoScreenState extends State<AutoScreen> {
  final _form = EventForm();
  String? _styleKey = 'Neón / club';
  Uint8List? _reference;
  String _referenceName = '';
  bool _busy = false;

  final _picker = ImagePicker();

  Future<void> _pickReference() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _reference = bytes;
      _referenceName = x.name;
      _form.hasReference = true;
    });
  }

  void _clearReference() => setState(() {
        _reference = null;
        _referenceName = '';
        _form.hasReference = false;
      });

  Future<void> _generate() async {
    if (_form.eventName.trim().isEmpty && _form.textByAI) {
      _toast('Ponle al menos el nombre del evento.');
      return;
    }
    final service = ImageService.from(widget.settings);
    if (!widget.settings.isConfigured) {
      _toast('Configura tu API key en Ajustes (ícono de engranaje).');
      return;
    }
    setState(() => _busy = true);
    try {
      final prompt = PromptBuilder.fromForm(_form, styleKey: _styleKey);
      final img = await service.generate(
        prompt: prompt,
        references: _reference == null
            ? const []
            : [RefImage(_reference!, _referenceName.isEmpty ? 'ref.png' : _referenceName)],
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(image: img, prompt: prompt, service: service),
      ));
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _field(String label, String hint, void Function(String) onChanged,
      {int maxLines = 1, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        onChanged: onChanged,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            DropdownButtonFormField<String>(
              value: _form.eventType,
              decoration: const InputDecoration(
                  labelText: 'Tipo de evento', border: OutlineInputBorder()),
              items: PromptBuilder.eventTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _form.eventType = v ?? _form.eventType),
            ),
            const SizedBox(height: 12),
            _field('Nombre del evento', 'Ej: NOCHE NEÓN', (v) => _form.eventName = v,
                icon: Icons.celebration),
            Row(
              children: [
                Expanded(
                    child: _field('Fecha', 'Sáb 25 Oct', (v) => _form.date = v,
                        icon: Icons.calendar_today)),
                const SizedBox(width: 8),
                Expanded(
                    child: _field('Hora', '23:00 hrs', (v) => _form.time = v,
                        icon: Icons.schedule)),
              ],
            ),
            _field('Local', 'Nombre del bar / disco', (v) => _form.venue = v,
                icon: Icons.place),
            _field('Dirección (opcional)', 'Calle y comuna', (v) => _form.address = v),
            const SizedBox(height: 4),
            Text('Estilo visual', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PromptBuilder.styles.keys.map((k) {
                return ChoiceChip(
                  label: Text(k),
                  selected: _styleKey == k,
                  onSelected: (s) => setState(() => _styleKey = s ? k : null),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _field('Concepto del flyer', 'Ej: fiesta de disfraces de Halloween, mucho humo rojo',
                (v) => _form.concept = v,
                maxLines: 2, icon: Icons.palette),
            _field('Line-up', 'DJ Tetal\nDJ Invitado', (v) => _form.lineup = v,
                maxLines: 3, icon: Icons.queue_music),
            _field('Info extra', 'Karaoke, show en vivo, barra libre…',
                (v) => _form.extras = v, icon: Icons.star),
            _field('Promociones', '2x1 hasta las 00:00 · Cover \$5.000',
                (v) => _form.promos = v, icon: Icons.local_offer),
            _field('Contacto', '@templobar · reservas +56 9 …',
                (v) => _form.contact = v, icon: Icons.alternate_email),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('La IA escribe los textos'),
              subtitle: const Text(
                  'Apágalo para recibir solo el arte (sin letras) y poner el texto con tu propia fuente.'),
              value: _form.textByAI,
              onChanged: (v) => setState(() => _form.textByAI = v),
            ),
            const SizedBox(height: 8),
            if (_reference == null)
              OutlinedButton.icon(
                onPressed: _pickReference,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Adjuntar flyer de referencia (opcional)'),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_reference!, width: 48, height: 64, fit: BoxFit.cover),
                ),
                title: const Text('Referencia adjunta'),
                subtitle: Text(_referenceName, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(onPressed: _clearReference, icon: const Icon(Icons.close)),
              ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_busy ? 'Generando flyer…' : 'Generar flyer'),
            ),
          ),
        ),
      ],
    );
  }
}
