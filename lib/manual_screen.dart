import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'openai_service.dart';
import 'prompt_builder.dart';
import 'result_screen.dart';
import 'settings.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final List<RefImage> images;
  final Uint8List? result;
  final String? prompt;
  _Msg.user(this.text, this.images)
      : fromUser = true,
        result = null,
        prompt = null;
  _Msg.flyer(this.result, this.prompt)
      : fromUser = false,
        text = '',
        images = const [];
  _Msg.error(this.text)
      : fromUser = false,
        images = const [],
        result = null,
        prompt = null;
}

/// Modo manual: un chat tipo ChatGPT pero siempre orientado a flyers.
/// Cada mensaje nuevo después de un flyer se trata como corrección de ese
/// flyer (se reenvía la imagen anterior junto con la instrucción).
class ManualScreen extends StatefulWidget {
  final Settings settings;
  const ManualScreen({super.key, required this.settings});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _msgs = <_Msg>[];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _pending = <RefImage>[];
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _attach() async {
    final xs = await _picker.pickMultiImage(maxWidth: 1600);
    for (final x in xs) {
      _pending.add(RefImage(await x.readAsBytes(), x.name));
    }
    setState(() {});
  }

  Uint8List? get _lastFlyer {
    for (final m in _msgs.reversed) {
      if (m.result != null) return m.result;
    }
    return null;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    if (!widget.settings.isConfigured) {
      _toast('Configura tu API key en Ajustes.');
      return;
    }
    final attached = List<RefImage>.from(_pending);
    setState(() {
      _msgs.add(_Msg.user(text, attached));
      _pending.clear();
      _ctrl.clear();
      _busy = true;
    });
    _scrollDown();

    final last = _lastFlyer;
    final refs = <RefImage>[
      ...attached,
      // Si ya hay un flyer en la conversación y no se adjuntó nada nuevo,
      // tratamos el mensaje como corrección de ese flyer.
      if (last != null && attached.isEmpty) RefImage(last, 'flyer_anterior.png'),
    ];
    final prompt = (last != null && attached.isEmpty)
        ? PromptBuilder.correction(text)
        : PromptBuilder.fromManual(text, hasImages: refs.isNotEmpty);

    try {
      final img = await ImageService.from(widget.settings)
          .generate(prompt: prompt, references: refs);
      setState(() => _msgs.add(_Msg.flyer(img, prompt)));
    } catch (e) {
      setState(() => _msgs.add(_Msg.error(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _reset() => setState(() {
        _msgs.clear();
        _pending.clear();
      });

  Widget _bubble(_Msg m) {
    final cs = Theme.of(context).colorScheme;
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.fromLTRB(60, 4, 12, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (m.images.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: m.images
                      .map((i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(i.bytes,
                                width: 72, height: 96, fit: BoxFit.cover),
                          ))
                      .toList(),
                ),
              if (m.images.isNotEmpty && m.text.isNotEmpty)
                const SizedBox(height: 8),
              if (m.text.isNotEmpty) Text(m.text),
            ],
          ),
        ),
      );
    }
    if (m.result != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultScreen(
              image: m.result!,
              prompt: m.prompt ?? '',
              service: ImageService.from(widget.settings),
            ),
          )),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 60, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(m.result!, width: 220),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 60, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(m.text, style: TextStyle(color: cs.onErrorContainer)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: _msgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: cs.outline),
                        const SizedBox(height: 12),
                        Text(
                          'Describe el flyer como se lo pedirías a ChatGPT.\n'
                          'Adjunta referencias, logos o fotos si quieres.\n'
                          'Después puedes pedir correcciones en el mismo chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _msgs.length + (_busy ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Diseñando el flyer…'),
                        ]),
                      );
                    }
                    return _bubble(_msgs[i]);
                  },
                ),
        ),
        if (_pending.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _pending.asMap().entries.map((e) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(e.value.bytes,
                            width: 52, height: 70, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: 0, top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _pending.removeAt(e.key)),
                        child: const CircleAvatar(
                            radius: 10, child: Icon(Icons.close, size: 12)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Adjuntar imágenes',
                  onPressed: _busy ? null : _attach,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: _lastFlyer == null
                          ? 'Flyer para fiesta de Halloween en Templo Bar, sábado 31…'
                          : 'Pide una corrección al último flyer…',
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24))),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.arrow_upward),
                ),
                if (_msgs.isNotEmpty)
                  IconButton(
                    tooltip: 'Nuevo chat',
                    onPressed: _busy ? null : _reset,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
