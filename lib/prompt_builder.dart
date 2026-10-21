/// La "receta" de prompts de Flyer GPTetal.
///
/// Aquí vive el valor de la app: convierte el formulario del modo automático
/// (o el texto libre del modo manual) en un prompt consistente que siempre
/// devuelve un flyer vertical, con los textos escritos exactamente como se
/// ingresaron.

class EventForm {
  String eventType; // Fiesta / Discoteca / Bar / Karaoke / After / Cumpleaños...
  String eventName;
  String date; // texto libre: "Sábado 25 de octubre"
  String time; // "23:00 hrs"
  String venue; // nombre del local
  String address;
  String concept; // concepto / estilo visual
  String lineup; // DJs, uno por línea
  String extras; // karaoke, show en vivo, barra libre...
  String promos; // 2x1, cover gratis hasta las 00:00...
  String contact; // Instagram, WhatsApp, reservas
  bool textByAI; // true: la IA escribe los textos; false: arte sin texto
  bool hasReference; // se adjuntó imagen de referencia

  EventForm({
    this.eventType = 'Fiesta en discoteca',
    this.eventName = '',
    this.date = '',
    this.time = '',
    this.venue = '',
    this.address = '',
    this.concept = '',
    this.lineup = '',
    this.extras = '',
    this.promos = '',
    this.contact = '',
    this.textByAI = true,
    this.hasReference = false,
  });
}

class PromptBuilder {
  static const eventTypes = [
    'Fiesta en discoteca',
    'Noche de bar / restobar',
    'Karaoke',
    'Fiesta temática',
    'After / after office',
    'Cumpleaños / celebración',
    'Show en vivo',
    'Evento privado',
  ];

  /// Estilos visuales preconfigurados (se pueden mezclar con el concepto).
  static const styles = <String, String>{
    'Neón / club':
        'estética de club nocturno, luces de neón magenta y cian, humo, destellos de láser, fondo oscuro con profundidad, tipografía grande y contundente',
    'Elegante / premium':
        'estética elegante y premium, negro con dorado, texturas de mármol o terciopelo, tipografía serif fina con mucho aire, luces cálidas suaves',
    'Urbano / reggaetón':
        'estética urbana y callejera, colores saturados, grafiti, cromados, texturas de concreto, tipografía bold y rebelde, energía alta',
    'Retro / old school':
        'estética retro años 90-2000, colores cálidos, grano de película, tipografía chunky, elementos nostálgicos (casetes, vinilos, VHS)',
    'Tropical / verano':
        'estética tropical y veraniega, palmeras, atardecer naranja y violeta, agua, tipografía redondeada y fresca',
    'Minimal / tipográfico':
        'estética minimalista centrada en tipografía, uno o dos colores, mucho espacio negativo, composición limpia',
  };

  /// Reglas fijas que se agregan a TODOS los prompts.
  static String get baseRules => '''
FORMATO: flyer vertical para redes sociales (historia de Instagram / afiche), composición pensada para verse en el celular, con margen de seguridad en los bordes.
CALIDAD: diseño profesional de agencia, iluminación y composición cuidadas, sin texto deformado, sin marcas de agua, sin logos de terceros, sin personas reales reconocibles.
JERARQUÍA: el nombre del evento es lo más grande; luego fecha y lugar; luego line-up; la información secundaria (promos, contacto) va pequeña al pie.''';

  static String get textRules => '''
TEXTO: escribe los textos EXACTAMENTE como se indican entre comillas, en español, sin agregar palabras, sin cambiar la ortografía, sin traducir. Todos los textos deben ser perfectamente legibles.''';

  static String get noTextRules => '''
TEXTO: NO incluyas ningún texto, letra, número ni logo en la imagen. Genera solo el arte de fondo y los elementos gráficos, dejando zonas limpias y oscuras/claras en el tercio superior y en el pie para colocar texto después.''';

  /// Prompt del modo automático.
  static String fromForm(EventForm f, {String? styleKey}) {
    final b = StringBuffer();
    b.writeln('Diseña un flyer para: ${f.eventType.toLowerCase()}.');

    final style = styleKey != null ? styles[styleKey] : null;
    final concept = [
      if (style != null) style,
      if (f.concept.trim().isNotEmpty) f.concept.trim(),
    ].join('. ');
    if (concept.isNotEmpty) b.writeln('ESTILO VISUAL: $concept.');

    if (f.hasReference) {
      b.writeln(
          'REFERENCIA: usa la imagen adjunta como referencia de estilo, composición, paleta y tipo de tipografía. No copies sus textos; reemplázalos por los de este evento.');
    }

    if (f.textByAI) {
      b.writeln(textRules);
      b.writeln('TEXTOS A INCLUIR:');
      if (f.eventName.trim().isNotEmpty) {
        b.writeln('- Título principal (muy grande): "${f.eventName.trim()}"');
      }
      final when = [f.date.trim(), f.time.trim()]
          .where((s) => s.isNotEmpty)
          .join(' · ');
      if (when.isNotEmpty) b.writeln('- Fecha y hora: "$when"');
      final where = [f.venue.trim(), f.address.trim()]
          .where((s) => s.isNotEmpty)
          .join(' — ');
      if (where.isNotEmpty) b.writeln('- Lugar: "$where"');
      final djs = f.lineup
          .split(RegExp(r'[\n,]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (djs.isNotEmpty) {
        b.writeln('- Line-up (en bloque, uno bajo otro): ${djs.map((d) => '"$d"').join(', ')}');
      }
      if (f.extras.trim().isNotEmpty) {
        b.writeln('- Destacado: "${f.extras.trim()}"');
      }
      if (f.promos.trim().isNotEmpty) {
        b.writeln('- Promoción (en una cinta o sello llamativo): "${f.promos.trim()}"');
      }
      if (f.contact.trim().isNotEmpty) {
        b.writeln('- Contacto al pie (pequeño): "${f.contact.trim()}"');
      }
    } else {
      b.writeln(noTextRules);
      // Aun sin texto, el concepto del evento guía el arte.
      if (f.eventName.trim().isNotEmpty) {
        b.writeln('El arte debe evocar el evento "${f.eventName.trim()}" sin escribir su nombre.');
      }
    }

    b.writeln(baseRules);
    return b.toString().trim();
  }

  /// Prompt del modo manual: el texto del usuario + las reglas fijas.
  static String fromManual(String userPrompt, {required bool hasImages}) {
    final b = StringBuffer();
    b.writeln(userPrompt.trim());
    b.writeln();
    if (hasImages) {
      b.writeln(
          'Usa las imágenes adjuntas como referencia o como base a corregir, según indica el pedido.');
    }
    b.writeln(textRules);
    b.writeln(baseRules);
    return b.toString().trim();
  }

  /// Prompt de corrección sobre un flyer ya generado (se envía con la imagen anterior).
  static String correction(String instruction) {
    return '''
Corrige el flyer adjunto según esta indicación, manteniendo todo lo demás igual (estilo, composición, textos que no se mencionan):
${instruction.trim()}
$textRules
$baseRules'''
        .trim();
  }
}
