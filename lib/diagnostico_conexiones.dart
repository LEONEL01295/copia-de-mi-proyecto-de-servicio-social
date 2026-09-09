import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mqtt_placas_service.dart';

void main() => runApp(const DiagnosticoApp());

const kBg = Color(0xFF0D1321);
const kCard = Color(0xFF131D2E);
const kBorder = Color(0xFF1E2D45);
const kBlue = Color(0xFF3B82F6);
const kGreen = Color(0xFF22C55E);
const kRed = Color(0xFFEF4444);
const kText = Color(0xFFE2E8F0);
const kMuted = Color(0xFF64748B);
const kMuted2 = Color(0xFF8B9CBD);

// ─── Datos de la tabla (Simulados para UI) ───────────────────────────────────
const _rendimiento = [
  {'nombre': 'Centro Neumático', 'env': 2540, 'rec': 2480, 'per': 60, 'pct': '2.36%', 'lat': '12 ms'},
  {'nombre': 'Centro de Maquinados', 'env': 2320, 'rec': 2270, 'per': 50, 'pct': '2.16%', 'lat': '18 ms'},
  {'nombre': 'Robot 3 Ejes', 'env': 2120, 'rec': 1980, 'per': 140, 'pct': '6.60%', 'lat': '--'},
  {'nombre': 'Centro de Prensado', 'env': 1980, 'rec': 1890, 'per': 90, 'pct': '4.55%', 'lat': '--'},
];

class DiagnosticoApp extends StatelessWidget {
  const DiagnosticoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diagnóstico de Conexiones',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          fontFamily: 'Roboto'),
      home: const DiagnosticoScreen(),
    );
  }
}

class DiagnosticoScreen extends StatelessWidget {
  const DiagnosticoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    MqttPlacasService? mqtt;
    try {
      mqtt = Provider.of<MqttPlacasService>(context);
    } catch (_) {
      mqtt = null;
    }

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(mqtt),
            const SizedBox(height: 22),
            _buildKpis(mqtt),
            const SizedBox(height: 24),
            _buildRendimiento(mqtt),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(MqttPlacasService? mqtt) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 16,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Diagnóstico de conexiones',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: kText)),
          SizedBox(height: 3),
          Text('Monitorea el estado y rendimiento de todas las conexiones',
              style: TextStyle(fontSize: 13, color: kMuted2)),
        ]),
        if (mqtt != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: () => mqtt!.placa1.conectado
                    ? mqtt.placa1.disconnect()
                    : mqtt.placa1.connect(),
                borderRadius: BorderRadius.circular(30),
                child: _buildStatusBadge(
                    'PLACA 1',
                    mqtt.placa1.conectado
                        ? 'Conectado'
                        : (mqtt.placa1.conectando
                            ? 'Buscando...'
                            : 'Tap para Conectar'),
                    mqtt.placa1.conectado
                        ? kGreen
                        : (mqtt.placa1.conectando ? Colors.orange : kRed)),
              ),
              InkWell(
                onTap: () => mqtt!.placa2.conectado
                    ? mqtt.placa2.disconnect()
                    : mqtt.placa2.connect(),
                borderRadius: BorderRadius.circular(30),
                child: _buildStatusBadge(
                    'PLACA 2',
                    mqtt.placa2.conectado
                        ? 'Conectado'
                        : (mqtt.placa2.conectando
                            ? 'Buscando...'
                            : 'Tap para Conectar'),
                    mqtt.placa2.conectado
                        ? kGreen
                        : (mqtt.placa2.conectando ? Colors.orange : kRed)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 10),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: kMuted2,
                      letterSpacing: 0.5)),
              Text(status,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ]),
      ]),
    );
  }

  Widget _buildKpis(MqttPlacasService? mqtt) {
    return LayoutBuilder(builder: (context, constraints) {
      final env = mqtt?.paquetesEnviados ?? 0;
      final rec = mqtt?.paquetesRecibidos ?? 0;
      final per = mqtt?.paquetesPerdidos ?? 0;
      final lat = mqtt?.latencia ?? '--';

      if (constraints.maxWidth < 550) {
        return Column(children: [
          Row(children: [
            Expanded(
                child: _KpiCard(
                    label: 'P. enviados',
                    value: '$env',
                    sub: 'total',
                    valueColor: kText)),
            const SizedBox(width: 12),
            Expanded(
                child: _KpiCard(
                    label: 'P. recibidos',
                    value: '$rec',
                    sub: 'total',
                    valueColor: kText)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _KpiCard(
                    label: 'P. perdidos',
                    value: '$per',
                    sub: '(0.00%)',
                    valueColor: kRed)),
            const SizedBox(width: 12),
            Expanded(
                child: _KpiCard(
                    label: 'Latencia',
                    value: lat,
                    sub: 'actual',
                    valueColor: kGreen)),
          ]),
        ]);
      }

      return Row(children: [
        Expanded(
            child: _KpiCard(
                label: 'P. enviados',
                value: '$env',
                sub: 'total',
                valueColor: kText)),
        const SizedBox(width: 10),
        Expanded(
            child: _KpiCard(
                label: 'P. recibidos',
                value: '$rec',
                sub: 'total',
                valueColor: kText)),
        const SizedBox(width: 10),
        Expanded(
            child: _KpiCard(
                label: 'P. perdidos',
                value: '$per',
                sub: '(0.00%)',
                valueColor: kRed)),
        const SizedBox(width: 10),
        Expanded(
            child: _KpiCard(
                label: 'Latencia',
                value: lat,
                sub: 'actual',
                valueColor: kGreen)),
      ]);
    });
  }

  Widget _buildRendimiento(MqttPlacasService? mqtt) {
    return Container(
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Text('Rendimiento de conexiones',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: kText))),
        const Divider(height: 1, color: kBorder),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(children: const [
              Expanded(flex: 4, child: _TH('Maqueta')),
              Expanded(flex: 2, child: _TH('Enviados', right: true)),
              Expanded(flex: 2, child: _TH('Recibidos', right: true)),
              Expanded(flex: 2, child: _TH('Pérdidos', right: true)),
              Expanded(flex: 2, child: _TH('Pérdida %', right: true)),
              Expanded(flex: 2, child: _TH('Latencia prom.', right: true)),
            ])),
        const Divider(height: 1, color: kBorder),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rendimiento.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
          itemBuilder: (_, i) {
            final r = _rendimiento[i];
            return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(children: [
                  Expanded(
                      flex: 4,
                      child: Text(r['nombre'] as String,
                          style: const TextStyle(fontSize: 13, color: kText))),
                  Expanded(
                      flex: 2,
                      child: Text('${r['env']}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: kMuted2))),
                  Expanded(
                      flex: 2,
                      child: Text('${r['rec']}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: kMuted2))),
                  Expanded(
                      flex: 2,
                      child: Text('${r['per']}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: kMuted2))),
                  Expanded(
                      flex: 2,
                      child: Text(r['pct'] as String,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: kMuted2))),
                  Expanded(
                      flex: 2,
                      child: Text(r['lat'] as String,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kGreen))),
                ]));
          },
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final Color valueColor;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.sub,
      required this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        height: 125,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder)),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: kMuted2,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  child: Center(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(value,
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  color: valueColor))))),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(sub,
                      style: const TextStyle(fontSize: 11, color: kMuted))),
            ]),
      );
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: kMuted2));
}
