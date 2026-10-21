import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes persistentes de la app (proveedor, keys, modelo, calidad, proxy).
class Settings {
  static const _kProvider = 'provider';
  static const _kApiKey = 'openai_api_key';
  static const _kFalKey = 'fal_api_key';
  static const _kFalModel = 'fal_model';
  static const _kModel = 'model';
  static const _kQuality = 'quality';
  static const _kProxyUrl = 'proxy_url';

  static const providers = ['openai', 'fal'];

  static const defaultModel = 'gpt-image-2';
  static const models = ['gpt-image-2', 'gpt-image-1.5', 'gpt-image-1-mini'];
  static const qualities = ['low', 'medium', 'high'];

  /// Modelos de fal.ai para generar desde texto. Las correcciones con imagen
  /// usan siempre Flux Kontext (ver FalService).
  static const falModels = <String, String>{
    'fal-ai/flux-pro/v1.1': 'Flux Pro 1.1 — mejor texto, ~4 ¢',
    'fal-ai/flux/dev': 'Flux Dev — más barato, ~2,5 ¢',
    'fal-ai/flux/schnell': 'Flux Schnell — borradores rápidos, ~0,3 ¢',
  };
  static const defaultFalModel = 'fal-ai/flux-pro/v1.1';

  /// Siempre vertical: formato flyer / historia.
  static const size = '1024x1536';
  static const width = 1024;
  static const height = 1536;

  String provider;
  String apiKey;
  String falKey;
  String falModel;
  String model;
  String quality;
  String proxyUrl;

  Settings({
    required this.provider,
    required this.apiKey,
    required this.falKey,
    required this.falModel,
    required this.model,
    required this.quality,
    required this.proxyUrl,
  });

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return Settings(
      provider: p.getString(_kProvider) ?? 'openai',
      apiKey: p.getString(_kApiKey) ?? '',
      falKey: p.getString(_kFalKey) ?? '',
      falModel: p.getString(_kFalModel) ?? defaultFalModel,
      model: p.getString(_kModel) ?? defaultModel,
      quality: p.getString(_kQuality) ?? 'medium',
      proxyUrl: p.getString(_kProxyUrl) ?? '',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProvider, provider);
    await p.setString(_kApiKey, apiKey.trim());
    await p.setString(_kFalKey, falKey.trim());
    await p.setString(_kFalModel, falModel);
    await p.setString(_kModel, model);
    await p.setString(_kQuality, quality);
    await p.setString(_kProxyUrl, proxyUrl.trim());
  }

  bool get isOpenAI => provider == 'openai';

  bool get isConfigured => isOpenAI
      ? (apiKey.isNotEmpty || proxyUrl.isNotEmpty)
      : falKey.isNotEmpty;

  String get providerLabel => isOpenAI ? 'OpenAI · $model' : 'fal.ai · $falModel';
}
