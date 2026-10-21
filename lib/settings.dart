import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes persistentes de la app (API key, modelo, calidad, proxy).
class Settings {
  static const _kApiKey = 'openai_api_key';
  static const _kModel = 'model';
  static const _kQuality = 'quality';
  static const _kProxyUrl = 'proxy_url';

  static const defaultModel = 'gpt-image-2';
  static const models = ['gpt-image-2', 'gpt-image-1.5', 'gpt-image-1-mini'];
  static const qualities = ['low', 'medium', 'high'];

  /// Siempre vertical: formato flyer / historia.
  static const size = '1024x1536';

  String apiKey;
  String model;
  String quality;
  String proxyUrl;

  Settings({
    required this.apiKey,
    required this.model,
    required this.quality,
    required this.proxyUrl,
  });

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return Settings(
      apiKey: p.getString(_kApiKey) ?? '',
      model: p.getString(_kModel) ?? defaultModel,
      quality: p.getString(_kQuality) ?? 'medium',
      proxyUrl: p.getString(_kProxyUrl) ?? '',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kApiKey, apiKey.trim());
    await p.setString(_kModel, model);
    await p.setString(_kQuality, quality);
    await p.setString(_kProxyUrl, proxyUrl.trim());
  }

  bool get isConfigured => apiKey.isNotEmpty || proxyUrl.isNotEmpty;
}
