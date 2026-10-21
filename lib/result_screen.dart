import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'openai_service.dart';
import 'prompt_builder.dart';

/// Pantalla de resultado: muestra el flyer, permite guardarlo, compartirlo
/// y pedir correcciones (que se envían junto con la imagen anterior).
class ResultScreen extends StatefulWidget {
  final Uint8List image;
  final String prompt;
  final OpenAIService service;

  const ResultScreen({
    super.key,
    required this.image,
    required this.prompt,
    required this.service,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Uint8List _image = widget.image;
  late String _prompt = widget.prompt;
  final _history = <Uint8List>[];
  final _fixCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    try {
      await Gal.putImageBytes(_image, name: 'flyer_${DateTime.now().millisecondsSinceEpoch}');
      _toast('Flyer guardado en Fotos');
    } catch (e) {
      _toast('No se pudo guardar: $e');
    }
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/flyer_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(_image);
    await Share.shareXFiles([XFile(f.path)], text: 'Flyer');
  }

  Future<void> _correct() async {
    final instruction = _fixCtrl.text.trim();
    if (instruction.isEmpty) return;
    setState(() => _busy = true);
    try {
      final prompt = PromptBuilder.correction(instruction);
      final out = await widget.service.generate(
        prompt: prompt,
        references: [RefImage(_image, 'flyer.png')],
      );
      setState(() {
        _history.add(_image);
        _image = out;
        _prompt = prompt;
        _fixCtrl.clear();
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _image = _history.removeLast());
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showPrompt() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, c) => SingleChildScrollView(
          controller: c,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: SelectableText(_prompt,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu flyer'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
                tooltip: 'Deshacer corrección',
                onPressed: _undo,
                icon: const Icon(Icons.undo)),
          IconButton(
              tooltip: 'Ver prompt',
              onPressed: _showPrompt,
              icon: const Icon(Icons.code)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_image, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Corrigiendo…',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fixCtrl,
                          enabled: !_busy,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _correct(),
                          decoration: const InputDecoration(
                            hintText:
                                'Corregir: "cambia la fecha a sábado 1", "más oscuro"…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _busy ? null : _correct,
                        icon: const Icon(Icons.auto_fix_high),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.download),
                          label: const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Compartir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
