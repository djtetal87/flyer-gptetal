# Flyer GPTetal

Generador de flyers verticales (1024×1536) para discotecas, bares y eventos, usando GPT Image de OpenAI.

- **Automático**: formulario (tipo de evento, nombre, fecha, lugar, estilo, line-up, extras, promos, contacto, referencia opcional) → flyer.
- **Manual**: chat tipo ChatGPT, con adjuntos; cada mensaje después de un flyer se trata como corrección de ese flyer.
- **Resultado**: guardar en Fotos, compartir, corregir (deshacer incluido), ver el prompt usado.
- Switch "La IA escribe los textos": apagado = arte sin letras, para poner el texto con tu propia fuente después.

La receta de prompts está en `lib/prompt_builder.dart`. Ahí se ajusta todo lo que define "cómo se ven" los flyers.

## Proveedores

- **OpenAI (GPT Image)**: por defecto. El más fiel con textos.
- **fal.ai (Flux)**: selector en Ajustes. Texto→imagen con Flux Pro 1.1 / Dev / Schnell; correcciones y referencias con Flux Kontext. Usa la misma key que PhotoTetal.

## 1. Crear el proyecto en el Mac

Necesitas Flutter y Xcode instalados.

```bash
cd ~/Desktop
flutter create --org com.tetal --project-name flyer_gptetal --platforms ios,macos "Flyer GPTetal"
cd "Flyer GPTetal"
```

Copia encima de lo que generó `flutter create`:

- `pubspec.yaml` (reemplaza el generado)
- `lib/` (reemplaza todo)
- `server/` (opcional)

```bash
flutter pub get
```

## 2. Permisos en iOS

Abre `ios/Runner/Info.plist` y agrega dentro del `<dict>` principal:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Para adjuntar flyers de referencia, logos y fotos.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Para guardar los flyers generados en tus Fotos.</string>
<key>CFBundleDisplayName</key>
<string>Flyer GPTetal</string>
```

## 3. Probar

Conecta el iPhone (o abre el simulador) y:

```bash
flutter run
```

En la app: Ajustes (engranaje) → pega tu API key de OpenAI → Guardar. Carga saldo prepago en https://platform.openai.com (mínimo ~USD 5).

## 4. Sacar el .ipa

```bash
flutter build ipa
```

Luego `open build/ios/archive/Runner.xcarchive` → Xcode → **Distribute App** → Ad Hoc / Development (para instalar en tus iPhones) o App Store Connect. El .ipa queda en `build/ios/ipa/`. Para un build sin firma automática: `flutter build ipa --export-method ad-hoc`.

Para el .dmg más adelante: `flutter build macos` y empaquetar `build/macos/Build/Products/Release/Flyer GPTetal.app`.

## 5. Proxy (cuando repartas la app)

Para no incrustar tu key en teléfonos de otras personas:

```bash
cd server
OPENAI_API_KEY=sk-... node index.js
```

Súbelo a cualquier host Node (Railway, Render, Fly, un VPS) y en la app pon la URL en Ajustes → "URL del proxy", dejando la key vacía.

## Costos de referencia (gpt-image-2, imagen vertical)

- Baja: ~USD 0,01–0,02 · Media: ~0,05–0,09 · Alta: ~0,20–0,25
- Cada corrección cuesta como una imagen nueva.

## Pendientes / siguiente versión

- Overlay de texto con fuentes propias (.ttf) sobre el arte sin letras.
- Historial de flyers generados.
- Plantillas por cliente (Templo Bar, etc.) con datos precargados.
