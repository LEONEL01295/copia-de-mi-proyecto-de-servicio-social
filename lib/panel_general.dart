import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'usage_monitor.dart';
import 'mqtt_placas_service.dart';

// ── Paleta de Colores ──────────────────────────────────
const Color kBg = Color(0xFF081014);
const Color kPanel = Color(0xFF11222C);
const Color kCyanN = Color(0xFF00EAFF);
const Color kGreenN = Color(0xFF00FF88);
const Color kRedN = Color(0xFFFF3366);
const Color kBorderN = Color(0xFF1A3644);
const Color kText = Color(0xFFC5D1D8);
const Color kAudit = Color(0xFFFFAA00);
const Color kMuted = Color(0xFF64748B);

class PanelGeneralScreen extends StatefulWidget {
  const PanelGeneralScreen({super.key});

  @override
  State<PanelGeneralScreen> createState() => _PanelGeneralScreenState();
}

class _PanelGeneralScreenState extends State<PanelGeneralScreen> {
  String _mode = 'manual';
  String _executionType = 'general'; // 'general', 'placa1', 'placa2'
  final TextEditingController _piezasController = TextEditingController(text: '1');
  int _piezasTerminadas = 0;
  bool _isCycleRunning = false;
  
  final List<Map<String, dynamic>> _logs = [
    {
      "time": "17:56:53",
      "role": "Ingeniero",
      "message": "Configuración cambiada a Modo: manual",
      "color": kAudit
    }
  ];
  final ScrollController _logScroll = ScrollController();

  void _logAudit(String msg, Color color) {
    final now = DateTime.now();
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _logs.add({"time": time, "role": "Ingeniero", "message": msg, "color": color});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(_logScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _simularCicloGeneral() async {
    if (_isCycleRunning) return;
    final int target = int.tryParse(_piezasController.text) ?? 1;
    if (target <= 0) return;

    setState(() => _isCycleRunning = true);
    final monitor = Provider.of<UsageMonitor>(context, listen: false);
    monitor.setStationActive('general', true);

    String executionMsg = "";
    List<String> stations = [];
    
    if (_executionType == 'general') {
      executionMsg = "EJECUCIÓN GENERAL (Toda la Planta)";
      stations = ['robot', 'prensado', 'neumatico', 'maquinados'];
    } else if (_executionType == 'placa1') {
      executionMsg = "EJECUCIÓN PLACA 1 (Robot + Prensado)";
      stations = ['robot', 'prensado'];
    } else {
      executionMsg = "EJECUCIÓN PLACA 2 (Neumático + Maquinados)";
      stations = ['neumatico', 'maquinados'];
    }

    _logAudit("Iniciando $executionMsg...", kCyanN);

    final mqtt = Provider.of<MqttPlacasService>(context, listen: false);
    
    // El Panel General ahora siempre dispara en Automático
    if (_executionType == 'placa1') {
      mqtt.enviarComando('start', 'placa1', target); 
    } else if (_executionType == 'placa2') {
      mqtt.enviarComando('start', 'placa2', target); 
    } else {
      mqtt.enviarComando('start', 'placa1', target);
      mqtt.enviarComando('start', 'placa2', target);
    }

    for (int i = 0; i < target; i++) {
      if (!_isCycleRunning) break;
      
      // Limpiar auditoría local al iniciar cada nueva pieza para evitar acumulación
      setState(() => _logs.clear());

      _logAudit("--- Procesando ciclo ${i + 1} de $target ---", kAudit);
      
      for (String station in stations) {
        if (!_isCycleRunning) break;
        _logAudit("Activando estación: $station", kCyanN);
        monitor.setStationActive(station, true);
        
        // Simulación de tiempo de proceso por estación
        await Future.delayed(const Duration(seconds: 2));
        
        if (!_isCycleRunning) {
          monitor.setStationActive(station, false);
          break;
        }
        
        monitor.addProduction(station);
        monitor.setStationActive(station, false);
        _logAudit("Estación $station completada", kGreenN);
      }
      
      if (!_isCycleRunning) break;
      setState(() => _piezasTerminadas++);
      monitor.addProduction('general');
      _logAudit("Ciclo $executionMsg pieza ${i+1} completada", kGreenN);
    }

    setState(() => _isCycleRunning = false);
    monitor.setStationActive('general', false);
    _logAudit("Ciclo $executionMsg finalizado", kCyanN);
    monitor.syncStationAuditoria('general');
  }

  void _emergencyStop() {
    setState(() => _isCycleRunning = false);
    final monitor = Provider.of<UsageMonitor>(context, listen: false);
    // Sincronizar PARO DE EMERGENCIA con la placa
    Provider.of<MqttPlacasService>(context, listen: false).stopEmergencia();
    _logAudit("¡PARO DE EMERGENCIA ACTIVADO!", kRedN);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlPanel(),
            const SizedBox(height: 20),
            _buildAuditPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorderN),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // El modo siempre es Automático en Panel General
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kGreenN.withValues(alpha: 0.1),
                  border: Border.all(color: kGreenN),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('MODO AUTOMÁTICO ACTIVO', style: TextStyle(color: kGreenN, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              // Input de Piezas
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Piezas: ', style: TextStyle(color: kText)),
                  SizedBox(
                    width: 50,
                    height: 35,
                    child: TextField(
                      controller: _piezasController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kText),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kBorderN)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kCyanN)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // KPI Piezas Compacto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: kGreenN.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                  color: kGreenN.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Terminadas: ', style: TextStyle(color: kText, fontSize: 11)),
                    Text('$_piezasTerminadas', style: const TextStyle(color: kGreenN, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Modos de Ejecución
          const Text('Modo de Ejecución:', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _modeSelectBtn(
                label: "EJECUCIÓN GENERAL",
                type: "general",
                icon: Icons.all_inclusive_rounded,
              ),
              _modeSelectBtn(
                label: "EJECUCIÓN PLACA 1",
                type: "placa1",
                icon: Icons.looks_one_rounded,
              ),
              _modeSelectBtn(
                label: "EJECUCIÓN PLACA 2",
                type: "placa2",
                icon: Icons.looks_two_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Botones de Acción
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Consumer<MqttPlacasService>(
                builder: (context, mqtt, child) {
                  return _actionBtn(
                    icon: _isCycleRunning ? Icons.stop : Icons.play_arrow,
                    label: _isCycleRunning ? "EJECUTANDO..." : "INICIAR CICLO",
                    color: _isCycleRunning
                        ? kGreenN.withValues(alpha: 0.2)
                        : (mqtt.conectado ? kGreenN : Colors.grey),
                    textColor: _isCycleRunning ? kGreenN : Colors.black,
                    onTap: (!_isCycleRunning && mqtt.conectado)
                        ? _simularCicloGeneral
                        : null,
                  );
                },
              ),
              _actionBtn(
                icon: Icons.warning_amber_rounded,
                label: "PARO EMERGENCIA",
                color: kRedN,
                textColor: Colors.white,
                onTap: _emergencyStop,
              ),
              _actionBtn(
                icon: Icons.refresh,
                label: "RESTABLECER",
                color: kCyanN,
                textColor: Colors.black,
                onTap: () {
                   final monitor = Provider.of<UsageMonitor>(context, listen: false);
                   setState(() => _piezasTerminadas = 0);
                   monitor.resetCyclePieces('general');
                   monitor.syncStationAuditoria('general'); // Sincronizar al reset
                   _logAudit("Sistema restablecido", kCyanN);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeSelectBtn({required String label, required String type, required IconData icon}) {
    final bool active = _executionType == type;
    return InkWell(
      onTap: _isCycleRunning ? null : () {
        setState(() => _executionType = type);
        _logAudit("Cambiado a modo de ejecución: $label", kAudit);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? kCyanN.withValues(alpha: 0.15) : Colors.black26,
          border: Border.all(color: active ? kCyanN : kBorderN),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? kCyanN : kText),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? kCyanN : kText, fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required Color textColor, required VoidCallback? onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildAuditPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorderN),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auditoría (Audit Trail) y Alertas',
                  style: TextStyle(color: kCyanN, fontWeight: FontWeight.bold)),
              if (_logs.isNotEmpty)
                TextButton.icon(
                  onPressed: _isCycleRunning
                      ? null
                      : () => setState(() => _logs.clear()),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('BORRAR', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: kRedN,
                    disabledForegroundColor: kMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBorderN),
            ),
            child: ListView.builder(
              controller: _logScroll,
              itemCount: _logs.length,
              itemBuilder: (context, i) {
                final log = _logs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      children: [
                        TextSpan(text: "[${log['time']}] ", style: const TextStyle(color: kText)),
                        TextSpan(text: "[${log['role']}] - ", style: const TextStyle(color: kCyanN)),
                        TextSpan(text: log['message'], style: TextStyle(color: log['color'])),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
