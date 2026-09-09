import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Clase que maneja el túnel de datos exclusivo para UNA placa
class PlateHandler extends ChangeNotifier {
  final String ip;
  final int port;
  final String label;

  Socket? _socket;
  bool conectado = false;
  bool conectando = false;
  int sent = 0;
  int received = 0;
  int lost = 0;
  String latencia = '--';
  Map<String, dynamic> telemetry = {};
  Timer? _heartbeat;
  DateTime? _lastPingTime;

  PlateHandler({required this.ip, required this.port, required this.label});

  Future<void> connect() async {
    if (conectado || conectando) return;
    
    _heartbeat?.cancel();
    try { 
      await _socket?.close(); 
      _socket?.destroy(); 
    } catch (_) {}
    _socket = null;

    conectando = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      
      _socket!.listen(
        (data) => _onData(data),
        onDone: () => _onDisconnect(),
        onError: (e) => _onDisconnect(),
        cancelOnError: true,
      );

      conectado = true;
      conectando = false;
      _startPing();
      notifyListeners();
    } catch (e) {
      lost++;
      _onDisconnect();
    }
  }

  void _startPing() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (t) {
      if (conectado && _socket != null) {
        try {
          _lastPingTime = DateTime.now();
          _socket!.write('${jsonEncode({"comando": "ping"})}\n');
          sent++;
        } catch (_) { _onDisconnect(); }
      }
    });
  }

  void _onData(List<int> bytes) {
    received++;
    
    if (_lastPingTime != null) {
      final diff = DateTime.now().difference(_lastPingTime!).inMilliseconds;
      latencia = '$diff ms';
      _lastPingTime = null;
    }

    try {
      final msg = utf8.decode(bytes).trim();
      final lines = msg.split('\n');
      final last = lines.last.trim();
      if (last.startsWith('{') && last.endsWith('}')) {
        telemetry = jsonDecode(last);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onDisconnect() {
    conectado = false;
    conectando = false;
    _socket = null;
    _heartbeat?.cancel();
    notifyListeners();
  }

  void send(String payload) {
    if (!conectado || _socket == null) return;
    try {
      _socket!.write('$payload\n');
      sent++;
      notifyListeners();
    } catch (_) { _onDisconnect(); }
  }

  void disconnect() {
    _heartbeat?.cancel();
    _socket?.destroy();
    _onDisconnect();
  }

  // Alias para compatibilidad con UI
  Future<void> conectar() => connect();
  void deepCleanup() => disconnect();
}

/// Servicio global que orquesta las dos placas
class MqttPlacasService extends ChangeNotifier {
  // CONFIGURACIÓN DE IPS SEGURA (Evita conflictos con la tablet)
  final PlateHandler placa1 = PlateHandler(ip: '192.168.4.1', port: 8080, label: 'PLACA 1');
  final PlateHandler placa2 = PlateHandler(ip: '192.168.4.10', port: 8080, label: 'PLACA 2');

  MqttPlacasService() {
    placa1.addListener(notifyListeners);
    placa2.addListener(notifyListeners);
  }

  bool get conectado => placa1.conectado || placa2.conectado;
  int get paquetesEnviados => placa1.sent + placa2.sent;
  int get paquetesRecibidos => placa1.received + placa2.received;
  int get paquetesPerdidos => placa1.lost + placa2.lost;
  Map<String, dynamic> get telemetry => placa1.telemetry;
  String get latencia => placa1.conectado ? placa1.latencia : (placa2.conectado ? placa2.latencia : '--');

  void enviarComando(String comando, String maqueta, int piezas) {
    final msg = jsonEncode({
      "comando": comando,
      "maqueta": maqueta,
      "piezas": piezas,
      "timestamp": DateTime.now().millisecondsSinceEpoch
    });

    if (maqueta == 'robot' || maqueta == 'prensado') {
      placa1.send(msg);
    } else if (maqueta == 'neumatico' || maqueta == 'maquinados') {
      placa2.send(msg);
    } else {
      placa1.send(msg);
      placa2.send(msg);
    }
  }

  void controlarActuador(String maqueta, int index, bool valor) {
    final msg = jsonEncode({
      "comando": "manual_control",
      "maqueta": maqueta,
      "rele": index,
      "valor": valor
    });

    if (maqueta == 'robot' || maqueta == 'prensado') {
      placa1.send(msg);
    } else {
      placa2.send(msg);
    }
  }

  void stopEmergencia() {
    final msg = jsonEncode({"comando": "emergency_stop"});
    placa1.send(msg);
    placa2.send(msg);
  }

  void restablecerSistema() {
    final msg = jsonEncode({"comando": "reset"});
    placa1.send(msg);
    placa2.send(msg);
  }

  @override
  void dispose() {
    placa1.removeListener(notifyListeners);
    placa2.removeListener(notifyListeners);
    placa1.disconnect();
    placa2.disconnect();
    super.dispose();
  }
}
