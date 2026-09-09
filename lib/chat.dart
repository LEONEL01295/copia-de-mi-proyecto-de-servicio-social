import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


// ============================================================
// CONFIGURACIÓN DE PROVEEDORES
// ============================================================
//
// La clave se proporciona al ejecutar el proyecto:
//
// flutter run -d windows \
//   --dart-define="GROQ_API_KEY=TU_NUEVA_CLAVE"
//
// Opcionalmente:
//
// --dart-define="GROQ_MODEL=llama-3.3-70b-versatile"
// --dart-define="OLLAMA_MODEL=llama3.2"
// --dart-define="OLLAMA_BASE_URL=http://localhost:11434"
//
// IMPORTANTE:
// No vuelvas a escribir directamente la clave dentro de este archivo.
// La clave que compartiste anteriormente debe ser revocada.

const String _groqApiKey = String.fromEnvironment(
  'GROQ_API_KEY',
);

const String _groqModel = String.fromEnvironment(
  'GROQ_MODEL',
  defaultValue: 'llama-3.3-70b-versatile',
);

const String _ollamaModel = String.fromEnvironment(
  'OLLAMA_MODEL',
  defaultValue: 'llama3.2',
);

const String _ollamaBaseUrl = String.fromEnvironment(
  'OLLAMA_BASE_URL',
  defaultValue: 'http://localhost:11434',
);

const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

// ============================================================
// COLORES
// ============================================================

const Color _kBg = Color(0xFF0D1321);
const Color _kCard = Color(0xFF131D2E);
const Color _kBorder = Color(0xFF1E2D45);
const Color _kGreen = Color(0xFF00E676);
const Color _kBlue = Color(0xFF2979FF);
const Color _kText = Color(0xFFE2E8F0);
const Color _kMuted = Color(0xFF8B9CBD);

// ============================================================
// MODELOS
// ============================================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _Metricas {
  final Map<String, dynamic> sensores;
  final Map<String, int> alarmasPorModulo;
  final Map<String, int> logsPorModulo;
  final int totalAlarmas;
  final int totalLogs;
  final Map<String, dynamic> produccion;

  const _Metricas({
    required this.sensores,
    required this.alarmasPorModulo,
    required this.logsPorModulo,
    required this.totalAlarmas,
    required this.totalLogs,
    required this.produccion,
  });
}

// ============================================================
// PANTALLA
// ============================================================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _loadingMetrics = false;

  _Metricas? _metricas;

  String _motorActivo = 'Modo automático';

  // Identifica la sesión actual del chatbot.
  final String _sessionId =
      DateTime.now().microsecondsSinceEpoch.toString();

  int _numeroConsulta = 0;

  // ==========================================================
  // CICLO DE VIDA
  // ==========================================================

  @override
  void initState() {
    super.initState();

    debugPrint(
      'ChatScreen activo | GROQ_API_KEY configurada: '
      '${_groqApiKey.trim().isNotEmpty} | longitud: ${_groqApiKey.trim().length}',
    );

    _loadMetricas();

    _messages.add(
      ChatMessage(
        text: '¡Hola! Soy el asistente inteligente SCADA de '
            'Hitech Ingenium.\n\n'
            'Puedo utilizar Groq AI cuando existe conexión, '
            'Ollama local cuando está disponible y un modo '
            'de respuestas internas cuando los otros motores '
            'no responden.\n\n'
            'También puedo analizar las métricas reales '
            'registradas en Firebase.\n\n'
            '¿En qué te ayudo?',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================================
  // MÉTRICAS DE FIREBASE
  // ==========================================================

  Future<void> _loadMetricas() async {
    if (mounted) {
      setState(() {
        _loadingMetrics = true;
      });
    }

    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;

      const List<String> plataformas = [
        'app_escritorio',
        'app_movil',
      ];

      const List<String> modulos = [
        'neumatico',
        'robot',
        'maquinados',
        'prensado',
      ];

      final Map<String, dynamic> sensores = {};
      final Map<String, int> alarmasPorModulo = {};
      final Map<String, int> logsPorModulo = {};
      final Map<String, dynamic> produccion = {};

      int totalAlarmas = 0;
      int totalLogs = 0;

      for (final String plataforma in plataformas) {
        for (final String modulo in modulos) {
          final String key = '$plataforma/$modulo';

          // --------------------------------------------------
          // SENSORES Y PRODUCCIÓN
          // --------------------------------------------------

          try {
            final DocumentSnapshot<Map<String, dynamic>> sensorSnapshot =
                await db
                    .collection(plataforma)
                    .doc('sensores')
                    .collection(modulo)
                    .doc('estado_actual')
                    .get();

            if (sensorSnapshot.exists) {
              final Map<String, dynamic> data = sensorSnapshot.data() ?? {};

              sensores[key] = data;

              if (data.containsKey('piezas')) {
                produccion[key] = data['piezas'];
              }

              if (data.containsKey('cicloActivo')) {
                produccion['${key}_cicloActivo'] = data['cicloActivo'];
              }

              if (data.containsKey('estado')) {
                produccion['${key}_estado'] = data['estado'];
              }
            }
          } catch (e) {
            debugPrint(
              'Error leyendo sensores de $key: $e',
            );
          }

          // --------------------------------------------------
          // ALARMAS
          // --------------------------------------------------

          try {
            final QuerySnapshot<Map<String, dynamic>> alarmasSnapshot = await db
                .collection(plataforma)
                .doc('alarmas')
                .collection(modulo)
                .get();

            final int cantidad = alarmasSnapshot.docs.length;

            alarmasPorModulo[key] = cantidad;
            totalAlarmas += cantidad;
          } catch (e) {
            debugPrint(
              'Error leyendo alarmas de $key: $e',
            );

            alarmasPorModulo[key] = 0;
          }

          // --------------------------------------------------
          // LOGS
          // --------------------------------------------------

          try {
            final QuerySnapshot<Map<String, dynamic>> logsSnapshot = await db
                .collection(plataforma)
                .doc('logs')
                .collection(modulo)
                .get();

            final int cantidad = logsSnapshot.docs.length;

            logsPorModulo[key] = cantidad;
            totalLogs += cantidad;
          } catch (e) {
            debugPrint(
              'Error leyendo logs de $key: $e',
            );

            logsPorModulo[key] = 0;
          }
        }
      }

      final _Metricas nuevasMetricas = _Metricas(
        sensores: sensores,
        alarmasPorModulo: alarmasPorModulo,
        logsPorModulo: logsPorModulo,
        totalAlarmas: totalAlarmas,
        totalLogs: totalLogs,
        produccion: produccion,
      );

      if (!mounted) return;

      setState(() {
        _metricas = nuevasMetricas;
        _loadingMetrics = false;
      });
    } catch (e) {
      debugPrint(
        'Error general cargando métricas: $e',
      );

      if (!mounted) return;

      setState(() {
        _loadingMetrics = false;
      });
    }
  }

  int _obtenerTotalPiezas(_Metricas? metricas) {
    if (metricas == null) return 0;

    return metricas.produccion.values.whereType<num>().fold<int>(
          0,
          (int acumulado, num valor) => acumulado + valor.toInt(),
        );
  }

  int _calcularOeeEstimado(_Metricas metricas) {
    final int penalizacion = metricas.totalAlarmas * 2;

    return (95 - penalizacion).clamp(0, 95).toInt();
  }

  double _calcularTasaFallas(_Metricas metricas) {
    if (metricas.totalLogs == 0) {
      return metricas.totalAlarmas > 0 ? 100 : 0;
    }

    return (metricas.totalAlarmas / metricas.totalLogs) * 100;
  }

  String _obtenerModuloConMasAlarmas(
    _Metricas metricas,
  ) {
    if (metricas.alarmasPorModulo.isEmpty) {
      return 'No disponible';
    }

    final List<MapEntry<String, int>> entradas =
        metricas.alarmasPorModulo.entries.toList()
          ..sort(
            (
              MapEntry<String, int> a,
              MapEntry<String, int> b,
            ) =>
                b.value.compareTo(a.value),
          );

    final MapEntry<String, int> mayor = entradas.first;

    if (mayor.value == 0) {
      return 'Ningún módulo presenta alarmas';
    }

    return '${mayor.key}, con ${mayor.value} alarmas';
  }

  // ==========================================================
  // PROMPT DEL SISTEMA
  // ==========================================================

  String _buildSystemPrompt() {
    final _Metricas? m = _metricas;

    String metricasStr = 'Las métricas todavía no están disponibles.';

    if (m != null) {
      final String produccionLineas = m.produccion.entries
          .map(
            (MapEntry<String, dynamic> entrada) => '  ${entrada.key}: '
                '${entrada.value}',
          )
          .join('\n');

      final String alarmasLineas = m.alarmasPorModulo.entries
          .map(
            (MapEntry<String, int> entrada) => '  ${entrada.key}: '
                '${entrada.value} alarmas',
          )
          .join('\n');

      final String logsLineas = m.logsPorModulo.entries
          .map(
            (MapEntry<String, int> entrada) => '  ${entrada.key}: '
                '${entrada.value} eventos',
          )
          .join('\n');

      final String sensoresLineas = m.sensores.entries
          .map(
            (MapEntry<String, dynamic> entrada) => '  ${entrada.key}: '
                '${jsonEncode(entrada.value)}',
          )
          .join('\n');

      final int totalPiezas = _obtenerTotalPiezas(m);

      final int modulosActivos = m.sensores.values.where((dynamic valor) {
        return valor is Map && valor['cicloActivo'] == true;
      }).length;

      final int oee = _calcularOeeEstimado(m);

      final double tasaFallas = _calcularTasaFallas(m);

      final String moduloConMasAlarmas = _obtenerModuloConMasAlarmas(m);

      metricasStr = '''
PRODUCCIÓN POR MÓDULO:
$produccionLineas

Total de piezas producidas: $totalPiezas

ALARMAS POR MÓDULO:
$alarmasLineas

Total de alarmas registradas: ${m.totalAlarmas}

LOGS Y EVENTOS POR MÓDULO:
$logsLineas

Total de eventos registrados: ${m.totalLogs}

ESTADO ACTUAL DE LOS SENSORES:
$sensoresLineas

RESUMEN OPERATIVO:
Módulos con ciclo activo: $modulosActivos
Total de alarmas: ${m.totalAlarmas}
Total de piezas: $totalPiezas
OEE aproximado: $oee%
Tasa aproximada de fallas: ${tasaFallas.toStringAsFixed(2)}%
Módulo con más alarmas: $moduloConMasAlarmas

ACLARACIÓN:
El OEE mostrado es una estimación interna basada principalmente
en la cantidad de alarmas registradas. No debe considerarse un
OEE industrial exacto si no existen datos separados de
disponibilidad, rendimiento y calidad.
''';
    }

    return '''
Eres el asistente de inteligencia artificial del sistema
SCADA Master de Hitech Ingenium Labs.

PERSONALIDAD:
Respondes siempre en español.
Eres preciso, técnico, profesional y fácil de comprender.
Puedes responder preguntas generales y preguntas industriales.
No inventas métricas que no aparezcan en el contexto.
Cuando una métrica no esté disponible, debes indicarlo.
No utilizas asteriscos ni encabezados en formato Markdown.
Respondes con texto plano y natural.

MÓDULOS DEL SISTEMA:
Centro Neumático: presión, actuadores y electroválvulas.
Robot de 3 Ejes: ejes X, Y, Z, gripper y ciclos Pick and Place.
Centro de Maquinados: banda, fresadora, taladradora y empujadores.
Centro de Prensado: sistema hidráulico, molde y fuerza en kN.

MÉTRICAS RECUPERADAS DE FIREBASE:
$metricasStr

CAPACIDADES:
Puedes analizar producción total y por módulo.
Puedes analizar alarmas y eventos.
Puedes estimar la tasa de fallas.
Puedes comparar módulos.
Puedes explicar el estado general de la planta.
Puedes generar recomendaciones de mantenimiento.
Puedes explicar conceptos como SCADA, PLC, HMI, MQTT,
Firebase, Flutter, Industria 4.0, neumática e hidráulica.

INSTRUCCIONES:
Cuando te soliciten métricas, usa únicamente los datos anteriores.
Cuando te soliciten controlar un módulo, explica que debe
utilizarse el panel específico del módulo.
No afirmes haber accionado físicamente una máquina.
No inventes alarmas, sensores, producción ni estados.
Distingue claramente entre valores reales y valores estimados.
''';
  }

  // ==========================================================
  // CONVERSACIÓN PARA LOS MODELOS
  // ==========================================================

  List<Map<String, dynamic>> _buildProviderMessages(
    String currentUserMessage,
  ) {
    final List<Map<String, dynamic>> messages = [
      {
        'role': 'system',
        'content': _buildSystemPrompt(),
      },
    ];

    for (final ChatMessage message in _messages) {
      messages.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': message.text,
      });
    }

    // Evita duplicar el mensaje actual.
    final bool currentMessageAlreadyIncluded = _messages.isNotEmpty &&
        _messages.last.isUser &&
        _messages.last.text == currentUserMessage;

    if (!currentMessageAlreadyIncluded) {
      messages.add({
        'role': 'user',
        'content': currentUserMessage,
      });
    }

    return messages;
  }

  // ==========================================================
  // GROQ
  // ==========================================================

  Future<String> _sendToGroq(
    String userMessage,
  ) async {
    final String cleanApiKey = _groqApiKey.trim();

    if (cleanApiKey.isEmpty) {
      throw Exception(
        'No se configuró GROQ_API_KEY.',
      );
    }

    await _loadMetricas();

    final List<Map<String, dynamic>> messages =
        _buildProviderMessages(userMessage);

    final Map<String, dynamic> body = {
      'model': _groqModel,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 2048,
      'top_p': 0.95,
    };

    final http.Response response = await http
        .post(
      Uri.parse(_groqUrl),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $cleanApiKey',
      },
      body: jsonEncode(body),
    )
        .timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw TimeoutException(
          'Groq tardó demasiado en responder.',
        );
      },
    );

    final String responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Groq devolvió un formato inválido.',
        );
      }

      final dynamic choices = decoded['choices'];

      if (choices is! List || choices.isEmpty) {
        throw Exception(
          'Groq no devolvió opciones de respuesta.',
        );
      }

      final dynamic firstChoice = choices.first;

      if (firstChoice is! Map<String, dynamic>) {
        throw Exception(
          'La estructura de respuesta de Groq '
          'es incorrecta.',
        );
      }

      final dynamic message = firstChoice['message'];

      if (message is! Map<String, dynamic>) {
        throw Exception(
          'Groq no devolvió el mensaje esperado.',
        );
      }

      final String content = message['content']?.toString().trim() ?? '';

      if (content.isEmpty) {
        throw Exception(
          'Groq devolvió una respuesta vacía.',
        );
      }

      return content;
    }

    throw Exception(
      'Groq HTTP ${response.statusCode}: '
      '${_extractApiError(responseBody)}',
    );
  }

  // ==========================================================
  // OLLAMA
  // ==========================================================

  Uri get _ollamaChatUri => Uri.parse(
        '$_ollamaBaseUrl/api/chat',
      );

  Uri get _ollamaTagsUri => Uri.parse(
        '$_ollamaBaseUrl/api/tags',
      );

  Future<bool> _isOllamaRunning() async {
    try {
      final http.Response response = await http.get(_ollamaTagsUri).timeout(
            const Duration(seconds: 3),
          );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint(
        'Ollama no está disponible: $e',
      );

      return false;
    }
  }

  Future<String> _sendToOllama(
    String userMessage,
  ) async {
    final List<Map<String, dynamic>> messages =
        _buildProviderMessages(userMessage);

    final Map<String, dynamic> body = {
      'model': _ollamaModel,
      'messages': messages,
      'stream': false,
      'options': {
        'temperature': 0.7,
        'num_predict': 1024,
      },
    };

    final http.Response response = await http
        .post(
      _ollamaChatUri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    )
        .timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw TimeoutException(
          'Ollama tardó demasiado en responder.',
        );
      },
    );

    final String responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Ollama devolvió un formato inválido.',
        );
      }

      final dynamic message = decoded['message'];

      if (message is! Map<String, dynamic>) {
        throw Exception(
          'Ollama no devolvió el mensaje esperado.',
        );
      }

      final String content = message['content']?.toString().trim() ?? '';

      if (content.isEmpty) {
        throw Exception(
          'Ollama devolvió una respuesta vacía.',
        );
      }

      return content;
    }

    throw Exception(
      'Ollama HTTP ${response.statusCode}: '
      '${_extractApiError(responseBody)}',
    );
  }

  String _extractApiError(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return 'El proveedor no devolvió detalles.';
    }

    try {
      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final dynamic error = decoded['error'];

        if (error is Map<String, dynamic>) {
          return error['message']?.toString() ?? responseBody;
        }

        if (error != null) {
          return error.toString();
        }

        final dynamic message = decoded['message'];

        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      // La respuesta no es JSON.
    }

    return responseBody;
  }

  // ==========================================================
  // RESPUESTAS SIN IA
  // ==========================================================

  String _offlineReply(String question) {
    final _Metricas? m = _metricas;
    final String ql = question.toLowerCase().trim();

    final int totalPiezas = _obtenerTotalPiezas(m);

    if (ql.contains('oee') || ql.contains('eficiencia')) {
      if (m == null) {
        return 'No existen métricas suficientes '
            'para estimar el OEE en este momento.';
      }

      final int oee = _calcularOeeEstimado(m);

      return 'El OEE aproximado de la planta es '
          '$oee%. Esta estimación utiliza '
          '${m.totalAlarmas} alarmas registradas. '
          'Para calcular un OEE industrial exacto '
          'se necesitan disponibilidad, rendimiento '
          'y calidad.';
    }

    if (ql.contains('pieza') ||
        ql.contains('produccion') ||
        ql.contains('producción')) {
      return 'El total registrado es de '
          '$totalPiezas piezas producidas. '
          'La información se obtuvo de los módulos '
          'encontrados en Firebase.';
    }

    if (ql.contains('alarma') || ql.contains('falla') || ql.contains('error')) {
      if (m == null) {
        return 'No hay datos de alarmas disponibles '
            'en este momento.';
      }

      final String detalle = m.alarmasPorModulo.entries
          .map(
            (MapEntry<String, int> entrada) => '${entrada.key}: '
                '${entrada.value}',
          )
          .join(', ');

      return 'El sistema registra un total de '
          '${m.totalAlarmas} alarmas. '
          'Detalle por módulo: $detalle.';
    }

    if (ql.contains('metrica') ||
        ql.contains('métrica') ||
        ql.contains('reporte') ||
        ql.contains('resumen')) {
      if (m == null) {
        return 'Las métricas no están disponibles. '
            'Verifica la conexión con Firebase.';
      }

      final int oee = _calcularOeeEstimado(m);

      final double tasa = _calcularTasaFallas(m);

      return 'Resumen de la planta: '
          '$totalPiezas piezas producidas, '
          '${m.totalAlarmas} alarmas registradas, '
          '${m.totalLogs} eventos y un OEE '
          'aproximado de $oee%. '
          'La tasa estimada de fallas es de '
          '${tasa.toStringAsFixed(2)}%.';
    }

    if (ql.contains('neumatico') || ql.contains('neumático')) {
      final List<MapEntry<String, dynamic>> datos = m?.sensores.entries
              .where(
                (
                  MapEntry<String, dynamic> entrada,
                ) =>
                    entrada.key.contains(
                  'neumatico',
                ),
              )
              .toList() ??
          [];

      if (datos.isEmpty) {
        return 'No existen datos disponibles del '
            'módulo neumático.';
      }

      return 'Estado del módulo neumático: '
          '${jsonEncode(datos.first.value)}';
    }

    if (ql.contains('robot')) {
      final List<MapEntry<String, dynamic>> datos = m?.sensores.entries
              .where(
                (
                  MapEntry<String, dynamic> entrada,
                ) =>
                    entrada.key.contains(
                  'robot',
                ),
              )
              .toList() ??
          [];

      if (datos.isEmpty) {
        return 'No existen datos disponibles del '
            'Robot de 3 Ejes.';
      }

      return 'Estado del Robot de 3 Ejes: '
          '${jsonEncode(datos.first.value)}';
    }

    if (ql.contains('maquinado')) {
      final List<MapEntry<String, dynamic>> datos = m?.sensores.entries
              .where(
                (
                  MapEntry<String, dynamic> entrada,
                ) =>
                    entrada.key.contains(
                  'maquinados',
                ),
              )
              .toList() ??
          [];

      if (datos.isEmpty) {
        return 'No existen datos disponibles del '
            'Centro de Maquinados.';
      }

      return 'Estado del Centro de Maquinados: '
          '${jsonEncode(datos.first.value)}';
    }

    if (ql.contains('prensado') || ql.contains('prensa')) {
      final List<MapEntry<String, dynamic>> datos = m?.sensores.entries
              .where(
                (
                  MapEntry<String, dynamic> entrada,
                ) =>
                    entrada.key.contains(
                  'prensado',
                ),
              )
              .toList() ??
          [];

      if (datos.isEmpty) {
        return 'No existen datos disponibles del '
            'Centro de Prensado.';
      }

      return 'Estado del Centro de Prensado: '
          '${jsonEncode(datos.first.value)}';
    }

    if (ql.contains('plc')) {
      return 'Un PLC es un Controlador Lógico '
          'Programable utilizado para controlar '
          'maquinaria y procesos industriales '
          'mediante una lógica previamente '
          'programada.';
    }

    if (ql.contains('scada')) {
      return 'SCADA significa Supervisory Control '
          'and Data Acquisition. Es un sistema '
          'utilizado para supervisar, registrar '
          'y controlar procesos industriales '
          'en tiempo real.';
    }

    if (ql.contains('sensor')) {
      return 'Los sensores detectan variables '
          'físicas como presión, temperatura, '
          'posición, fuerza o velocidad y las '
          'convierten en señales que pueden ser '
          'procesadas por un sistema de control.';
    }

    if (ql.contains('actuador')) {
      return 'Los actuadores convierten una señal '
          'de control en una acción física. Algunos '
          'ejemplos son motores, cilindros '
          'neumáticos, pistones hidráulicos y '
          'electroválvulas.';
    }

    if (ql.contains('neumatica') || ql.contains('neumática')) {
      return 'La neumática utiliza aire comprimido '
          'para producir movimiento y fuerza. '
          'Normalmente emplea compresores, válvulas, '
          'mangueras y cilindros.';
    }

    if (ql.contains('hidraulic')) {
      return 'La hidráulica utiliza fluidos '
          'presurizados para transmitir grandes '
          'cantidades de fuerza. Es común en '
          'prensas, elevadores y maquinaria pesada.';
    }

    if (ql.contains('fresadora') || ql.contains('fresado')) {
      return 'La fresadora mecaniza materiales '
          'mediante una herramienta rotativa. '
          'Puede realizar ranuras, superficies, '
          'perfiles y diferentes operaciones '
          'de corte.';
    }

    if (ql.contains('taladro') || ql.contains('taladradora')) {
      return 'La taladradora realiza perforaciones '
          'mediante una herramienta giratoria. '
          'En una línea automatizada puede trabajar '
          'con sensores de posición y actuadores.';
    }

    if (ql.contains('firebase')) {
      return 'Firebase es una plataforma de Google '
          'que proporciona servicios como '
          'autenticación, base de datos, hosting '
          'y almacenamiento. Firestore es su '
          'base de datos NoSQL.';
    }

    if (ql.contains('flutter') || ql.contains('dart')) {
      return 'Flutter es un framework para crear '
          'aplicaciones multiplataforma utilizando '
          'el lenguaje Dart. Permite desarrollar '
          'para Android, Windows, web y otras '
          'plataformas.';
    }

    if (ql.contains('mqtt')) {
      return 'MQTT es un protocolo ligero de '
          'mensajería basado en publicación y '
          'suscripción. Es ampliamente utilizado '
          'en IoT y automatización industrial.';
    }

    if (ql.contains('pid')) {
      return 'Un controlador PID utiliza acciones '
          'proporcional, integral y derivativa '
          'para mantener una variable de proceso '
          'cerca de su valor de referencia.';
    }

    if (ql.contains('hmi')) {
      return 'Una HMI es una Interfaz Humano-Máquina '
          'que permite al operador observar y '
          'controlar un proceso industrial.';
    }

    if (ql.contains('electrovalvula') || ql.contains('electroválvula')) {
      return 'Una electroválvula controla el paso '
          'de aire o líquido mediante una señal '
          'eléctrica. Es utilizada para dirigir '
          'el movimiento de cilindros y actuadores.';
    }

    if (ql.contains('banda') || ql.contains('conveyor')) {
      return 'Las bandas transportadoras desplazan '
          'materiales o piezas entre diferentes '
          'estaciones de una línea de producción.';
    }

    if (ql.contains('automatizacion') || ql.contains('automatización')) {
      return 'La automatización industrial utiliza '
          'sistemas de control, sensores, actuadores '
          'y software para ejecutar procesos con '
          'poca intervención humana.';
    }

    if (ql.contains('industria 4') || ql.contains('industry 4')) {
      return 'La Industria 4.0 integra automatización, '
          'IoT, inteligencia artificial, análisis '
          'de datos, computación en la nube y '
          'sistemas ciberfísicos.';
    }

    if (ql.contains('iot')) {
      return 'IoT conecta dispositivos físicos '
          'a una red para intercambiar información, '
          'supervisar variables y realizar acciones '
          'remotas.';
    }

    if (ql.contains('mantenimiento') || ql.contains('mtto')) {
      return 'El mantenimiento puede ser correctivo, '
          'preventivo o predictivo. El registro de '
          'alarmas y sensores permite anticipar '
          'fallas y planificar intervenciones.';
    }

    if (ql.contains('inteligencia artificial') ||
        ql.contains('machine learning') ||
        ql == 'ia' ||
        ql.startsWith('ia ')) {
      return 'La inteligencia artificial permite '
          'que los sistemas analicen información, '
          'identifiquen patrones y generen '
          'respuestas o recomendaciones.';
    }

    if (ql.contains('programacion') || ql.contains('programación')) {
      return 'La programación consiste en crear '
          'instrucciones que una computadora puede '
          'interpretar para ejecutar tareas.';
    }

    if (ql.contains('base de datos') || ql.contains('database')) {
      return 'Una base de datos permite almacenar, '
          'organizar, consultar y actualizar '
          'información de forma estructurada.';
    }

    if (ql.contains('wifi') ||
        ql.contains('internet') ||
        ql.contains('red informática')) {
      return 'Una red informática conecta '
          'dispositivos para intercambiar datos '
          'y compartir servicios.';
    }

    if (ql.contains('electricidad') ||
        ql.contains('voltaje') ||
        ql.contains('corriente')) {
      return 'El voltaje representa una diferencia '
          'de potencial eléctrico y la corriente '
          'representa el flujo de carga eléctrica. '
          'En automatización es común utilizar '
          '24 VDC para señales de control.';
    }

    if (ql.contains('motor')) {
      return 'Un motor eléctrico transforma energía '
          'eléctrica en energía mecánica. Puede '
          'utilizarse para mover bandas, bombas, '
          'ventiladores y mecanismos industriales.';
    }

    if (ql.contains('quien eres') ||
        ql.contains('quién eres') ||
        ql.contains('que eres') ||
        ql.contains('qué eres') ||
        ql.contains('quien te creo') ||
        ql.contains('quién te creó')) {
      return 'Soy el asistente de inteligencia '
          'artificial integrado en el sistema '
          'SCADA Master de Hitech Ingenium. '
          'Puedo analizar métricas, explicar '
          'conceptos industriales y apoyar al '
          'operador.';
    }

    if (ql.contains('hitech') || ql.contains('ingenium')) {
      return 'Hitech Ingenium es el nombre del '
          'proyecto asociado con este sistema '
          'SCADA y su asistente inteligente.';
    }

    if (ql.contains('hola') ||
        ql.contains('hello') ||
        ql.contains('buenas') ||
        ql.contains('buenos dias') ||
        ql.contains('buenos días')) {
      return 'Hola. Actualmente estoy utilizando '
          'el modo interno. Puedo ayudarte con '
          'métricas de la planta y conceptos '
          'de automatización industrial.';
    }

    if (ql.contains('gracias') || ql.contains('thanks')) {
      return 'Con gusto. Estoy disponible para '
          'ayudarte con el sistema SCADA.';
    }

    if (ql.contains('adios') ||
        ql.contains('adiós') ||
        ql.contains('hasta luego') ||
        ql.contains('bye')) {
      return 'Hasta luego. El sistema SCADA '
          'continuará supervisando la planta.';
    }

    return 'Estoy utilizando el modo interno porque '
        'Groq y Ollama no se encuentran disponibles. '
        'Puedo responder preguntas sobre métricas, '
        'producción, alarmas, OEE, PLC, SCADA, '
        'sensores, actuadores, neumática, hidráulica, '
        'automatización, Industria 4.0, Firebase, '
        'Flutter y otros conceptos técnicos.';
  }


  // ==========================================================
  // HISTORIAL DEL CHAT EN FIRESTORE
  // ==========================================================

  Map<String, dynamic> _crearResumenMetricas() {
    final _Metricas? metricas = _metricas;

    if (metricas == null) {
      return <String, dynamic>{
        'disponibles': false,
      };
    }

    return <String, dynamic>{
      'disponibles': true,
      'piezas': _obtenerTotalPiezas(metricas),
      'alarmas': metricas.totalAlarmas,
      'eventos': metricas.totalLogs,
      'oeeEstimado': _calcularOeeEstimado(metricas),
      'tasaFallas': _calcularTasaFallas(metricas),
    };
  }

  Future<DocumentReference<Map<String, dynamic>>?> _registrarPregunta(
    String pregunta,
  ) async {
    try {
      final User? usuario = FirebaseAuth.instance.currentUser;
      final DocumentReference<Map<String, dynamic>> registro =
          FirebaseFirestore.instance
              .collection('chatbot_consultas')
              .doc();

      _numeroConsulta++;

      await registro.set({
        'registroId': registro.id,
        'sesionId': _sessionId,
        'numeroConsulta': _numeroConsulta,
        'pregunta': pregunta,
        'respuesta': '',
        'motor': 'Pendiente',
        'estado': 'procesando',
        'usuarioId': usuario?.uid,
        'usuarioCorreo': usuario?.email,
        'usuarioNombre': usuario?.displayName,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaCreacionLocal': DateTime.now().toIso8601String(),
        'aplicacion': 'SCADA Master',
        'metricasAlPreguntar': _crearResumenMetricas(),
      });

      debugPrint(
        'Consulta guardada en Firebase: ${registro.id}',
      );

      return registro;
    } catch (e) {
      // El chatbot continúa funcionando aunque Firestore no permita
      // guardar el historial o no exista conexión.
      debugPrint(
        'No se pudo guardar la pregunta en Firebase: $e',
      );
      return null;
    }
  }

  Future<void> _finalizarRegistroChat({
    required DocumentReference<Map<String, dynamic>>? registro,
    required String respuesta,
    required String motor,
    required List<String> erroresProveedores,
    String estado = 'completado',
  }) async {
    if (registro == null) return;

    try {
      await registro.update({
        'respuesta': respuesta,
        'motor': motor,
        'estado': estado,
        'erroresProveedores': erroresProveedores,
        'fechaRespuesta': FieldValue.serverTimestamp(),
        'fechaRespuestaLocal': DateTime.now().toIso8601String(),
        'metricasAlResponder': _crearResumenMetricas(),
      });

      debugPrint(
        'Respuesta guardada en Firebase: ${registro.id}',
      );
    } catch (e) {
      debugPrint(
        'No se pudo guardar la respuesta en Firebase: $e',
      );
    }
  }

  Future<void> _mostrarYGuardarRespuesta({
    required DocumentReference<Map<String, dynamic>>? registro,
    required String respuesta,
    required String motor,
    required List<String> erroresProveedores,
  }) async {
    if (!mounted) return;

    setState(() {
      _motorActivo = motor;
    });

    _addBotMessage(respuesta);

    await _finalizarRegistroChat(
      registro: registro,
      respuesta: respuesta,
      motor: motor,
      erroresProveedores: erroresProveedores,
    );
  }

  // ==========================================================
  // ENVÍO DE MENSAJES
  // ==========================================================

  void _addBotMessage(String text) {
    if (!mounted) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: false,
        ),
      );
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final String text = _inputController.text.trim();

    if (text.isEmpty || _isLoading) {
      return;
    }

    _inputController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _isLoading = true;
      _motorActivo = 'Buscando proveedor...';
    });

    _scrollToBottom();

    // La pregunta se guarda inmediatamente. Después, el mismo
    // documento se actualiza con la respuesta y el motor utilizado.
    final DocumentReference<Map<String, dynamic>>? registro =
        await _registrarPregunta(text);

    final List<String> erroresProveedores = <String>[];

    try {
      // ------------------------------------------------------
      // MOTOR 1: GROQ
      // ------------------------------------------------------

      if (_groqApiKey.trim().isNotEmpty) {
        try {
          final String response = await _sendToGroq(text);

          await _mostrarYGuardarRespuesta(
            registro: registro,
            respuesta: response,
            motor: 'Groq AI',
            erroresProveedores: erroresProveedores,
          );
          return;
        } catch (e) {
          final String errorGroq = 'Groq: $e';
          erroresProveedores.add(errorGroq);
          debugPrint('Groq no disponible: $e');

          if (e.toString().contains('401') ||
              e.toString().toLowerCase().contains('invalid api key')) {
            debugPrint(
              'La clave de Groq es inválida o fue revocada. '
              'Detén la aplicación y vuelve a ejecutarla con '
              '--dart-define=GROQ_API_KEY=TU_CLAVE_NUEVA',
            );
          }
        }
      } else {
        erroresProveedores.add(
          'Groq: GROQ_API_KEY no configurada.',
        );

        debugPrint(
          'Groq omitido porque GROQ_API_KEY '
          'no está configurada.',
        );
      }

      // ------------------------------------------------------
      // MOTOR 2: OLLAMA
      // ------------------------------------------------------

      try {
        final bool ollamaDisponible = await _isOllamaRunning();

        if (ollamaDisponible) {
          final String response = await _sendToOllama(text);

          await _mostrarYGuardarRespuesta(
            registro: registro,
            respuesta: response,
            motor: 'Ollama local',
            erroresProveedores: erroresProveedores,
          );
          return;
        }

        erroresProveedores.add(
          'Ollama: servicio local no disponible.',
        );
      } catch (e) {
        erroresProveedores.add('Ollama: $e');

        debugPrint(
          'Ollama no disponible: $e',
        );
      }

      // ------------------------------------------------------
      // MOTOR 3: RESPUESTA INTERNA
      // ------------------------------------------------------

      final String respuestaInterna = _offlineReply(text);

      await _mostrarYGuardarRespuesta(
        registro: registro,
        respuesta: respuestaInterna,
        motor: 'Modo interno',
        erroresProveedores: erroresProveedores,
      );
    } catch (e) {
      debugPrint(
        'Error general del chatbot: $e',
      );

      erroresProveedores.add('Error general: $e');

      final String respuestaInterna = _offlineReply(text);

      await _mostrarYGuardarRespuesta(
        registro: registro,
        respuesta: respuestaInterna,
        motor: 'Modo interno',
        erroresProveedores: erroresProveedores,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ==========================================================
  // INTERFAZ: SUGERENCIAS
  // ==========================================================

  Widget _buildSuggestions() {
    const List<String> suggestions = [
      '¿Cuál es el OEE de la planta?',
      'Muéstrame las métricas de producción',
      '¿Qué módulo tiene más alarmas?',
      '¿Cuántas piezas se han producido?',
      'Análisis de fallas del sistema',
      '¿Cuál es el módulo más eficiente?',
      'Reporte general de la planta',
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        itemCount: suggestions.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    _inputController.text = suggestions[index];

                    _sendMessage();
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kBlue.withOpacity(0.30),
                ),
              ),
              child: Text(
                suggestions[index],
                style: const TextStyle(
                  fontSize: 12,
                  color: _kText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // INTERFAZ: PANEL DE MÉTRICAS
  // ==========================================================

  Widget _buildMetricasPanel() {
    if (_loadingMetrics) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          0,
        ),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kBorder,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kGreen,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando métricas de Firebase...',
              style: TextStyle(
                color: _kMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final _Metricas? m = _metricas;

    if (m == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          0,
        ),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kBorder,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Colors.orange,
              size: 17,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No fue posible cargar las métricas '
                'de Firebase.',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final int totalPiezas = _obtenerTotalPiezas(m);

    final int oee = _calcularOeeEstimado(m);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        0,
      ),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: _kGreen,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Text(
                'Métricas en tiempo real',
                style: TextStyle(
                  color: _kGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar métricas',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: _kMuted,
                  size: 18,
                ),
                onPressed: () async {
                  await _loadMetricas();

                  _addBotMessage(
                    'Las métricas fueron '
                    'actualizadas desde Firebase.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metricChip(
                'Piezas',
                '$totalPiezas',
                _kGreen,
              ),
              const SizedBox(width: 8),
              _metricChip(
                'Alarmas',
                '${m.totalAlarmas}',
                m.totalAlarmas > 0 ? Colors.orange : _kGreen,
              ),
              const SizedBox(width: 8),
              _metricChip(
                'Eventos',
                '${m.totalLogs}',
                _kBlue,
              ),
              const SizedBox(width: 8),
              _metricChip(
                'OEE est.',
                '$oee%',
                m.totalAlarmas == 0 ? _kGreen : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 5,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.30),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // INTERFAZ: MENSAJES
  // ==========================================================

  Widget _buildMessage(ChatMessage message) {
    final bool isUser = message.isUser;

    final String hora = '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kGreen.withOpacity(0.40),
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: _kGreen,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 760,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser ? _kBlue.withOpacity(0.20) : _kCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(
                    isUser ? 16 : 4,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 4 : 16,
                  ),
                ),
                border: Border.all(
                  color: isUser ? _kBlue.withOpacity(0.35) : _kBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: const TextStyle(
                      color: _kText,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hora,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kBlue.withOpacity(0.40),
                ),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 18,
                color: _kBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: _kGreen.withOpacity(0.40),
              ),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: _kGreen,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: _kBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Procesando: $_motorActivo',
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(
                left: 8,
              ),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kGreen.withOpacity(0.40),
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 20,
                color: _kGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SCADA Assistant',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  ),
                  Text(
                    'Groq AI • Ollama local • '
                    'Motor: $_motorActivo',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: _kMuted,
              size: 20,
            ),
            tooltip: 'Actualizar métricas',
            onPressed: () async {
              await _loadMetricas();

              _addBotMessage(
                'Las métricas fueron '
                'actualizadas. Tengo los datos '
                'más recientes disponibles.',
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _kMuted,
              size: 20,
            ),
            tooltip: 'Limpiar conversación',
            onPressed: () {
              setState(() {
                _messages.clear();
              });

              _addBotMessage(
                'Conversación limpiada. '
                '¿En qué te puedo ayudar?',
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: _kBorder,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMetricasPanel(),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: _kGreen.withOpacity(0.30),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          const Text(
                            'Pregúntame sobre '
                            'métricas o automatización',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        if (_isLoading && index == _messages.length) {
                          return _buildTypingIndicator();
                        }

                        return _buildMessage(
                          _messages[index],
                        );
                      },
                    ),
            ),
            Container(
              color: _kBg,
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ),
              child: _buildSuggestions(),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12,
              ),
              decoration: const BoxDecoration(
                color: _kCard,
                border: Border(
                  top: BorderSide(
                    color: _kBorder,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isLoading,
                      style: const TextStyle(
                        color: _kText,
                        fontSize: 14,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (String value) {
                        _sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre métricas, '
                            'producción o fallas...',
                        hintStyle: const TextStyle(
                          color: _kMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: _kBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _kBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _kBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _kGreen,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _kBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isLoading ? _kMuted.withOpacity(0.20) : _kGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isLoading
                            ? Icons.hourglass_empty_rounded
                            : Icons.send_rounded,
                        color: _isLoading ? _kMuted : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

