import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LLavesService {
  static const String _collectionName = 'configuracion';
  static const String _documentName = 'chatbot';

  static const String _defaultProvider = 'groq';
  static const String _defaultGroqModel = 'llama-3.1-8b-instant';

  /// Obtiene una configuración válida del chatbot.
  ///
  /// Firestore:
  /// configuracion/chatbot
  ///
  /// Campos esperados:
  /// provider: "groq"
  /// model: "llama-3.1-8b-instant"
  /// api_keys: ["LLAVE_REAL_1", "LLAVE_REAL_2"]
  static Future<Map<String, String>> getChatbotConfig() async {
    final List<Map<String, String>> configuraciones = await getChatbotConfigs();

    if (configuraciones.isEmpty) {
      throw StateError(
        'No existe ninguna configuración válida para el chatbot.',
      );
    }

    return configuraciones.first;
  }

  /// Obtiene todas las llaves válidas en orden aleatorio.
  ///
  /// Este método permite que chat.dart pruebe otra llave
  /// cuando una llave devuelve 401 o 429.
  static Future<List<Map<String, String>>> getChatbotConfigs() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(_collectionName)
              .doc(_documentName)
              .get();

      if (!snapshot.exists) {
        throw StateError(
          'No existe el documento '
          '$_collectionName/$_documentName en Firestore.',
        );
      }

      final Map<String, dynamic>? data = snapshot.data();

      if (data == null) {
        throw StateError(
          'El documento del chatbot existe, pero está vacío.',
        );
      }

      final String provider = _normalizeProvider(
        data['provider'],
      );

      final String model = _normalizeModel(
        provider: provider,
        value: data['model'],
      );

      final List<String> keys = _extractValidKeys(
        value: data['api_keys'],
        provider: provider,
      );

      // Permite también un campo individual llamado api_key.
      if (keys.isEmpty && data['api_key'] != null) {
        final String singleKey = _normalizeKey(
          data['api_key'].toString(),
        );

        if (_isValidKey(singleKey)) {
          keys.add(singleKey);
        }
      }

      if (keys.isEmpty) {
        throw StateError(
          'Firestore no contiene llaves válidas en '
          '"api_keys" ni en "api_key".',
        );
      }

      // Evita modificar accidentalmente la lista original.
      final List<String> shuffledKeys = List<String>.from(keys);

      shuffledKeys.shuffle(Random.secure());

      debugPrint(
        'LLavesService: ${shuffledKeys.length} llave(s) válida(s) '
        'cargada(s). Proveedor: $provider. Modelo: $model.',
      );

      return shuffledKeys
          .map(
            (String key) => <String, String>{
              'key': key,
              'provider': provider,
              'model': model,
            },
          )
          .toList(growable: false);
    } on FirebaseException catch (e) {
      debugPrint(
        'LLavesService FirebaseException: '
        'code=${e.code}, message=${e.message}',
      );

      throw Exception(
        'No fue posible leer la configuración del chatbot '
        'desde Firestore. Código Firebase: ${e.code}.',
      );
    } on StateError {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
        'LLavesService error inesperado: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      throw Exception(
        'No fue posible obtener una llave válida '
        'para el chatbot.',
      );
    }
  }

  static String _normalizeProvider(dynamic value) {
    final String provider =
        (value ?? _defaultProvider).toString().trim().toLowerCase();

    if (provider != 'groq' && provider != 'openrouter') {
      throw StateError(
        'Proveedor no soportado: "$provider". '
        'Utiliza "groq" u "openrouter".',
      );
    }

    return provider;
  }

  static String _normalizeModel({
    required String provider,
    required dynamic value,
  }) {
    final String model = value?.toString().trim() ?? '';

    if (model.isNotEmpty) {
      return model;
    }

    if (provider == 'groq') {
      return _defaultGroqModel;
    }

    throw StateError(
      'Debes configurar el campo "model" '
      'cuando el proveedor es OpenRouter.',
    );
  }

  static List<String> _extractValidKeys({
    required dynamic value,
    required String provider,
  }) {
    if (value is! List) {
      return <String>[];
    }

    final Set<String> uniqueKeys = <String>{};

    for (final dynamic rawValue in value) {
      if (rawValue == null) {
        continue;
      }

      final String key = _normalizeKey(
        rawValue.toString(),
      );

      if (_isValidKey(key)) {
        uniqueKeys.add(key);
      } else {
        debugPrint(
          'LLavesService: se ignoró una llave inválida '
          'o de prueba para el proveedor $provider.',
        );
      }
    }

    return uniqueKeys.toList();
  }

  static String _normalizeKey(String value) {
    String key = value.trim();

    // Elimina Bearer si fue guardado por error.
    key = key.replaceFirst(
      RegExp(
        r'^Bearer\s+',
        caseSensitive: false,
      ),
      '',
    );

    // Elimina comillas colocadas dentro del valor.
    if (key.length >= 2) {
      final bool hasDoubleQuotes = key.startsWith('"') && key.endsWith('"');

      final bool hasSingleQuotes = key.startsWith("'") && key.endsWith("'");

      if (hasDoubleQuotes || hasSingleQuotes) {
        key = key.substring(
          1,
          key.length - 1,
        );
      }
    }

    return key.trim();
  }

  static bool _isValidKey(String key) {
    if (key.isEmpty) {
      return false;
    }

    if (key.contains(RegExp(r'\s'))) {
      return false;
    }

    if (key.length < 20) {
      return false;
    }

    final String upperKey = key.toUpperCase();

    const List<String> invalidWords = <String>[
      'LLAVE_FALSA',
      'SIN_LLAVE',
      'TU_CLAVE',
      'API_KEY_AQUI',
      'REEMPLAZAR',
      'REEMPLAZA',
      'EJEMPLO',
      'EXAMPLE',
      'PRUEBA',
      'TEST_KEY',
    ];

    for (final String invalidWord in invalidWords) {
      if (upperKey.contains(invalidWord)) {
        return false;
      }
    }

    return true;
  }
}
