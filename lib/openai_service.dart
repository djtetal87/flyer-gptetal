import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'fal_service.dart';
import 'settings.dart';

/// Imagen de referencia adjunta (bytes + nombre).
class RefImage {
  final Uint8List bytes;
  final String name;
  const RefImage(this.bytes, this.name);
}

class ImageGenException implements Exception {
  final String message;
  ImageGenException(this.message);
  @override
  String toString() => message;
}

/// Interfaz común: cada proveedor recibe un prompt (+ referencias opcionales)
/// y devuelve los bytes PNG/JPG de un flyer vertical.
abstract class ImageService {
  Future<Uint8List> generate({
    required String prompt,
    List<RefImage> references = const [],
  });

  /// Elige el proveedor según los ajustes.
  static ImageService from(Settings s) =>
      s.isOpenAI ? OpenAIService(s) : FalService(s);
}

/// Llama a la API de imágenes de OpenAI (o a tu proxy si lo configuraste).
///
/// - Sin imágenes adjuntas → POST /v1/images/generations
/// - Con imágenes adjuntas (referencias o el flyer anterior a corregir)
///   → POST /v1/images/edits (multipart)
class OpenAIService implements ImageService {
  final Settings settings;
  OpenAIService(this.settings);

  String get _base => settings.proxyUrl.isNotEmpty
      ? settings.proxyUrl.replaceAll(RegExp(r'/+$'), '')
      : 'https://api.openai.com';

  Map<String, String> get _authHeaders => settings.proxyUrl.isNotEmpty
      ? {}
      : {'Authorization': 'Bearer ${settings.apiKey}'};

  @override
  Future<Uint8List> generate({
    required String prompt,
    List<RefImage> references = const [],
  }) async {
    if (settings.apiKey.isEmpty && settings.proxyUrl.isEmpty) {
      throw ImageGenException(
          'Falta la API key de OpenAI. Configúrala en Ajustes.');
    }

    http.Response res;
    if (references.isEmpty) {
      res = await http
          .post(
            Uri.parse('$_base/v1/images/generations'),
            headers: {
              ..._authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': settings.model,
              'prompt': prompt,
              'size': Settings.size,
              'quality': settings.quality,
              'n': 1,
            }),
          )
          .timeout(const Duration(minutes: 3));
    } else {
      final req = http.MultipartRequest(
          'POST', Uri.parse('$_base/v1/images/edits'));
      req.headers.addAll(_authHeaders);
      req.fields['model'] = settings.model;
      req.fields['prompt'] = prompt;
      req.fields['size'] = Settings.size;
      req.fields['quality'] = settings.quality;
      req.fields['n'] = '1';
      req.fields['input_fidelity'] = 'high';
      for (final r in references) {
        req.files.add(http.MultipartFile.fromBytes(
          'image[]',
          r.bytes,
          filename: r.name,
        ));
      }
      final streamed = await req.send().timeout(const Duration(minutes: 4));
      res = await http.Response.fromStream(streamed);
    }

    if (res.statusCode != 200) {
      String msg = 'Error ${res.statusCode}';
      try {
        final j = jsonDecode(res.body);
        msg = j['error']?['message']?.toString() ?? msg;
      } catch (_) {}
      throw ImageGenException(msg);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (json['data'] as List?) ?? [];
    if (data.isEmpty) throw ImageGenException('La API no devolvió imagen.');
    final b64 = data.first['b64_json'] as String?;
    if (b64 == null) throw ImageGenException('Respuesta sin b64_json.');
    return base64Decode(b64);
  }
}
