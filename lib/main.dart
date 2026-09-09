import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'espera.dart';
import 'firebase_options.dart';
import 'formulario.dart';
import 'home.dart';
import 'login.dart';
import 'usage_monitor.dart';
import 'mqtt_placas_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // CONFIGURACIÓN DE VENTANA PARA ESCRITORIO
  // ----------------------------------------------------------

  if (_isDesktopPlatform) {
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(1100, 750),
      center: true,
      backgroundColor: kBgDark,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'SCADA 4.0 · HITECH INGENIUM',
    );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  bool firebaseInicializado = false;
  String? firebaseError;

  // ----------------------------------------------------------
  // INICIALIZACIÓN DE FIREBASE
  // ----------------------------------------------------------

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    firebaseInicializado = true;

    debugPrint('Firebase inicializado correctamente.');

    // Espera a que termine la comprobación del administrador.
    await _createAdminIfNotExist();
  } catch (e, stackTrace) {
    firebaseError = e.toString();

    debugPrint('Error inicializando Firebase: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ----------------------------------------------------------
  // MONITOR GLOBAL DE USO
  // ----------------------------------------------------------

  final UsageMonitor usageMonitor = UsageMonitor();
  usageMonitor.startTracking();

  // ----------------------------------------------------------
  // INICIO DE LA APLICACIÓN
  // ----------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UsageMonitor>.value(
          value: usageMonitor,
        ),
        ChangeNotifierProvider<MqttPlacasService>(
          create: (_) => MqttPlacasService(),
        ),
      ],
      child: MyApp(
        firebaseInicializado: firebaseInicializado,
        firebaseError: firebaseError,
      ),
    ),
  );
}

// ============================================================
// PLATAFORMA
// ============================================================

bool get _isDesktopPlatform {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

// ============================================================
// CREACIÓN DEL ADMINISTRADOR
// ============================================================

Future<void> _createAdminIfNotExist() async {
  try {
    const String adminEmail = 'admin@huetamo.tecnm.mx';

    final QuerySnapshot<Map<String, dynamic>> query =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .where(
              'correo',
              isEqualTo: adminEmail,
            )
            .limit(1)
            .get();

    if (query.docs.isNotEmpty) {
      debugPrint(
        'El usuario administrador ya existe.',
      );
      return;
    }

    await FirebaseFirestore.instance.collection('usuarios').add({
      'nombre': 'Administrador Master',
      'correo': adminEmail,

      /*
       * IMPORTANTE:
       * No guardes contraseñas reales directamente en Firestore.
       *
       * El acceso del administrador debe gestionarse con
       * Firebase Authentication.
       *
       * Se conserva el campo vacío únicamente para evitar
       * almacenar una contraseña visible.
       */
      'passwordHash': '',

      'rol': 'Administrador',
      'matricula': 'ADM-001',
      'carrera': 'Sistemas Computacionales',
      'semestre': '9',
      'estado': 'Activo',
      'perfilCompleto': true,
      'encuestaCompletada': true,
      'enLinea': false,

      // Es preferible usar Timestamp en lugar de texto.
      'fechaRegistro': FieldValue.serverTimestamp(),
      'ultimoAcceso': null,
    });

    debugPrint(
      'Administrador de emergencia registrado correctamente.',
    );
  } catch (e, stackTrace) {
    debugPrint(
      'Error al comprobar o crear el administrador: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );
  }
}

// ============================================================
// COLORES
// ============================================================

const Color kBgDark = Color(0xFF0F172A);

// ============================================================
// APLICACIÓN PRINCIPAL
// ============================================================

class MyApp extends StatelessWidget {
  final bool firebaseInicializado;
  final String? firebaseError;

  const MyApp({
    super.key,
    required this.firebaseInicializado,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SCADA 4.0 · HITECH INGENIUM',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: kBgDark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          error: Color(0xFFF43F5E),
        ),
      ),
      home: firebaseInicializado
          ? const LoginScreen()
          : FirebaseErrorScreen(
              error: firebaseError,
            ),
      routes: {
        '/login': (BuildContext context) => const LoginScreen(),
        '/home': (BuildContext context) => const ScadaMasterHome(),
        '/espera': (BuildContext context) => const EsperaScreen(),
        '/formulario': (BuildContext context) => const FormularioAlumnoScreen(),
        '/encuesta': (BuildContext context) => const EncuestaScadaScreen(),
      },
    );
  }
}

// ============================================================
// PANTALLA DE ERROR DE FIREBASE
// ============================================================

class FirebaseErrorScreen extends StatelessWidget {
  final String? error;

  const FirebaseErrorScreen({
    super.key,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: Center(
        child: Container(
          width: 620,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF43F5E),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFF43F5E),
                size: 58,
              ),
              const SizedBox(height: 18),
              const Text(
                'No fue posible iniciar Firebase',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verifica firebase_options.dart, la conexión '
                'a Internet y la configuración del proyecto Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (error != null && error!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
