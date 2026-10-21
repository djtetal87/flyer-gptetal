import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'openai_service.dart' show ImageService, RefImage, ImageGenException;
import 'settings.dart';

/// Proveedor fal.ai (modelos Flux).
///
/// - Sin imágenes adjuntas → el modelo Flux elegido en Ajustes (texto → imagen).
/// - Con imágenes adjuntas → Flux Kontext (edición guiada por imagen):
///   una imagen: fal-ai/flux-pro/kontext · varias: fal-ai/flux-pro/kontext/max/multi
///
/// Usa la cola de fal (queue.fal.run): envía, consulta estado, baja el resultado.
class FalService implements ImageService {
  final Settings settings;
  FalService(this.settings);

  static const _kontextOne = 'fal-ai/flux-pro/kontext';
  static const _kontextMulti = 'fal-ai/flux-pro/kontext/max/multi';

  Map<String, String> get _headers => {
        'Authorization': 'Key ${settings.falKey}',
        'Content-Type': 'application/json',
      };

  @override
  Future<Uint8List> generate({
    required String prompt,
    List<RefImage> references = const [],
  }) async {
    if (settings.falKey.isEmpty) {
      throw ImageGenException('Falta la API key de fal.ai. Configúrala en Ajustes.');
    }

    String model;
    Map<String, dynamic> body;
    if (references.isEmpty) {
      model = settings.falModel;
      body = {
        'prompt': prompt,
        'image_size': {'width': Settings.width, 'height': Settings.height},
        'num_images': 1,
        'output_format': 'png',
        'enable_safety_checker': false,
      };
    } else if (references.length == 1) {
      model = _kontextOne;
      body = {
        'prompt': prompt,
        'image_url': _dataUri(references.first),
        'aspect_ratio': '2:3',
        'output_format': 'png',
      };
    } else {
      model = _kontextMulti;
      body = {
        'prompt': prompt,
        'image_urls': references.map(_dataUri).toList(),
        'aspect_ratio': '2:3',
        'output_format': 'png',
      };
    }

    // 1) Enviar a la cola.
    final submit = await http
        .post(Uri.parse('https://queue.fal.run/$model'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(minutes: 1));
    // La cola responde 200 o 202 (Accepted) al encolar.
    if (submit.statusCode != 200 && submit.statusCode != 202) {
      throw ImageGenException(_err(submit));
    }
    final sj = jsonDecode(submit.body) as Map<String, dynamic>;
    final statusUrl = sj['status_url'] as String?;
    final responseUrl = sj['response_url'] as String?;
    if (statusUrl == null || responseUrl == null) {
      throw ImageGenException('fal.ai no devolvió request_id.');
    }

    // 2) Esperar a que termine (máx. ~4 min).
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final st = await http.get(Uri.parse(statusUrl), headers: _headers);
      // 200 = completado, 202 = en cola / en proceso.
      if (st.statusCode != 200 && st.statusCode != 202) {
        throw ImageGenException(_err(st));
      }
      final s = (jsonDecode(st.body) as Map<String, dynamic>)['status'];
      if (s == 'COMPLETED') break;
      if (s == 'FAILED' || s == 'CANCELLED') {
        throw ImageGenException('fal.ai: el pedido falló ($s).');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw ImageGenException('fal.ai tardó demasiado. Intenta de nuevo.');
      }
    }

    // 3) Bajar el resultado.
    final res = await http.get(Uri.parse(responseUrl), headers: _headers);
    if (res.statusCode != 200) throw ImageGenException(_err(res));
    final rj = jsonDecode(res.body) as Map<String, dynamic>;
    final images = (rj['images'] as List?) ?? [];
    if (images.isEmpty) throw ImageGenException('fal.ai no devolvió imagen.');
    final url = images.first['url'] as String;
    final img = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
    if (img.statusCode != 200) throw ImageGenException('No se pudo bajar la imagen.');
    return img.bodyBytes;
  }

  static String _dataUri(RefImage r) {
    final lower = r.name.toLowerCase();
    final mime = (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
        ? 'image/jpeg'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/png';
    return 'data:$mime;base64,${base64Encode(r.bytes)}';
  }

  static String _err(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      final d = j['detail'];
      if (d is String) return 'fal.ai: $d';
      if (d is List && d.isNotEmpty) return 'fal.ai: ${d.first['msg'] ?? d.first}';
      if (j['error'] != null) return 'fal.ai: ${j['error']}';
    } catch (_) {}
    return 'fal.ai error ${r.statusCode}';
  }
}
