import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'usage_monitor.dart';

import 'nube.dart' show CloudSyncDashboard;
import 'analytics.dart' show AnalyticsDashboard;
import 'usuarios.dart' show UsuariosScreen;
import 'historialylogs.dart' show LogsScreen;
import 'conexiones_tablas.dart' show ConexionesScreen;
import 'diagnostico_conexiones.dart' show DiagnosticoScreen;
import 'scada_neumatico.dart' show ScadaNeumaticoBoard;
import 'main_robot_3_ejes.dart' show ScadaRobotDashboard;
import 'main_maquinados.dart' show ScadaMaquinadosDashboard;
import 'main_prensado.dart' show ScadaPrensadoScreen;
import 'panel_general.dart' show PanelGeneralScreen;
import 'chat.dart' show ChatScreen;
import 'horarios.dart' show HorariosScreen;
import 'perfil.dart' show PerfilScreen;

const Color kBgDark = Color(0xFF0F172A);
const Color kPanelBg = Color(0xFF1E293B);
const Color kSidebar = Color(0xFF0B1120);
const Color kCyan = Color(0xFF38BDF8);
const Color kGreen = Color(0xFF10B981);
const Color kRed = Color(0xFFF43F5E);
const Color kPurple = Color(0xFFA855F7);
const Color kOrange = Color(0xFFF59E0B);
const Color kTeal = Color(0xFF14B8A6);
const Color kIndigo = Color(0xFF6366F1);
const Color kPink = Color(0xFFEC4899);
const Color kTextMain = Color(0xFFF8FAFC);
const Color kTextMuted = Color(0xFF94A3B8);
const Color kBorder = Color(0xFF334155);

enum _Layout { mobile, tablet, desktop }

_Layout _getLayout(double w) {
  if (w > 900) return _Layout.desktop;
  if (w > 600) return _Layout.tablet;
  return _Layout.mobile;
}

enum AppView {
  dashboard,
  panelGeneral,
  neumatico,
  robot,
  maquinado,
  prensado,
  diagnosticoConexiones,
  historial,
  usuarios,
  horarios,
  chatbot,
  nube,
  perfil,
}

class ScadaMasterHome extends StatefulWidget {
  const ScadaMasterHome({super.key});

  @override
  State<ScadaMasterHome> createState() => _ScadaMasterHomeState();
}

class _ScadaMasterHomeState extends State<ScadaMasterHome> {
  AppView _view = AppView.dashboard;
  late Timer _clockTimer;
  String? _userName;
  String _userRol = 'Alumno';
  bool _showWelcome = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );

    _checkWelcome();
    _setUserOnlineStatus(true);
  }

  Future<void> _checkWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final bool shouldShow = prefs.getBool('showWelcome') ?? false;

    setState(() {
      _userRol = prefs.getString('userRole') ?? 'Alumno';

      if (_userRol == 'Operador') {
        _userRol = 'Alumno';
      }
    });

    if (shouldShow) {
      setState(() {
        _userName = prefs.getString('userName') ?? 'Usuario';
        _showWelcome = true;
      });

      await prefs.setBool('showWelcome', false);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showWelcome = false);
        }
      });
    }
  }

  Future<void> _setUserOnlineStatus(bool online) async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('userEmail');

    if (email != null) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('usuarios')
            .where(
              'correo',
              isEqualTo: email,
            )
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.update({
            'enLinea': online,
            'ultimoAcceso': DateFormat(
              'dd/MM/yyyy HH:mm:ss',
            ).format(DateTime.now()),
          });
        }
      } catch (e) {
        debugPrint('Error updating online status: $e');
      }
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _setUserOnlineStatus(false);
    super.dispose();
  }

  Future<void> _clearLocalSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    await prefs.remove('showWelcome');
  }

  Future<void> _logout() async {
    if (_isLoggingOut || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    final Future<void> dialogFuture = showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cerrando sesión',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return const _LogoutAnimationOverlay();
      },
      transitionBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.82,
              end: 1.0,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    final Future<void> minimumAnimationTime = Future<void>.delayed(
      const Duration(milliseconds: 2400),
    );

    try {
      await Future.wait<void>([
        _setUserOnlineStatus(false).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              'Tiempo agotado al actualizar el estado en línea.',
            );
          },
        ),
        _clearLocalSession(),
      ]);
    } catch (e) {
      debugPrint('Error al cerrar la sesión: $e');
    }

    await minimumAnimationTime;

    if (!mounted) return;

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop();

    await dialogFuture;

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final layout = _getLayout(w);
    final showSidebar = layout != _Layout.mobile;

    return Scaffold(
      backgroundColor: kBgDark,
      drawer: showSidebar
          ? null
          : Drawer(
              backgroundColor: kSidebar,
              child: SafeArea(
                child: _sidebarContent(layout),
              ),
            ),
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (showSidebar)
                  Container(
                    width: layout == _Layout.tablet ? 200 : 248,
                    decoration: const BoxDecoration(
                      color: kSidebar,
                      border: Border(
                        right: BorderSide(color: kBorder),
                      ),
                    ),
                    child: _sidebarContent(layout),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(_view),
                      child: _buildView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showWelcome)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: _WelcomeToast(
                  name: _userName ?? 'Usuario',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidebarContent(_Layout layout) {
    final compact = layout == _Layout.tablet;
    final monitor = Provider.of<UsageMonitor>(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 16 : 22,
            ),
            child: Column(
              children: [
                Text(
                  'HITECH INGENIUM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kCyan,
                    fontSize: compact ? 13 : 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SCADA MASTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kTextMuted,
                    fontSize: compact ? 9 : 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: kBorder,
            height: 1,
          ),
          const SizedBox(height: 4),
          _sectionLabel(
            'ESTACIONES SCADA',
            compact,
          ),
          _navTile(
            '📊',
            'Dashboard General',
            AppView.dashboard,
            kCyan,
            compact,
            false,
          ),
          _navTile(
            '🎛️',
            'Panel General',
            AppView.panelGeneral,
            kTeal,
            compact,
            monitor.isStationActive('general'),
          ),
          _navTile(
            '⚙️',
            'Centro Neumático',
            AppView.neumatico,
            kCyan,
            compact,
            monitor.isStationActive('neumatico'),
          ),
          _navTile(
            '🤖',
            'Robot 3 Ejes',
            AppView.robot,
            kPurple,
            compact,
            monitor.isStationActive('robot'),
          ),
          _navTile(
            '🛠️',
            'Centro Maquinados',
            AppView.maquinado,
            kGreen,
            compact,
            monitor.isStationActive('maquinados'),
          ),
          _navTile(
            '🛑',
            'Centro de Prensado',
            AppView.prensado,
            kRed,
            compact,
            monitor.isStationActive('prensado'),
          ),
          _navTile(
            '💻',
            'Diagnóstico de Conexiones',
            AppView.diagnosticoConexiones,
            const Color.fromARGB(255, 58, 145, 226),
            compact,
            false,
          ),
          const SizedBox(height: 6),
          const Divider(
            color: kBorder,
            height: 1,
          ),
          const SizedBox(height: 4),
          _sectionLabel(
            'SISTEMA',
            compact,
          ),
          if (_userRol == 'Administrador' || _userRol == 'Ingeniero')
            _navTile(
              '📋',
              'Historial / Logs',
              AppView.historial,
              kOrange,
              compact,
              false,
            ),
          if (_userRol == 'Administrador')
            _navTile(
              '👥',
              'Usuarios',
              AppView.usuarios,
              kPink,
              compact,
              false,
              hasAlert: monitor.pendingUsersCount > 0,
            ),
          if (_userRol == 'Administrador')
            _navTile(
              '📅',
              'Horarios de Uso',
              AppView.horarios,
              Colors.blue,
              compact,
              false,
            ),
          _navTile(
            '🤖',
            'Chatbot AI',
            AppView.chatbot,
            kCyan,
            compact,
            false,
          ),
          if (_userRol == 'Administrador')
            _navTile(
              '☁️',
              'Cloud Sync',
              AppView.nube,
              kCyan,
              compact,
              false,
            ),
          _navTile(
            '👤',
            'Mi Perfil',
            AppView.perfil,
            kCyan,
            compact,
            false,
          ),
          const SizedBox(height: 12),
          const Divider(
            color: kBorder,
            height: 1,
          ),
          const SizedBox(height: 4),
          _logoutTile(compact),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        8,
        0,
        4,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: kTextMuted,
          fontSize: compact ? 8 : 9,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _navTile(
    String em,
    String lbl,
    AppView v,
    Color col,
    bool compact,
    bool isProcessing, {
    bool hasAlert = false,
  }) {
    final active = _view == v;
    final bool showAlert = hasAlert && !active;

    final highlightCol = isProcessing
        ? Colors.yellowAccent
        : active
            ? kCyan
            : showAlert
                ? Colors.orangeAccent
                : col;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:
            active ? highlightCol.withValues(alpha: 0.12) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: active ? highlightCol : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _view = v);

          if (MediaQuery.of(context).size.width <= 600) {
            Navigator.pop(context);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 10 : 13,
          ),
          child: Row(
            children: [
              isProcessing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.yellowAccent,
                        ),
                      ),
                    )
                  : Text(
                      em,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                      ),
                    ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  lbl,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isProcessing
                        ? Colors.yellowAccent
                        : active
                            ? kCyan
                            : showAlert
                                ? Colors.orangeAccent
                                : kTextMuted,
                    fontWeight: active || isProcessing || showAlert
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: compact ? 11 : 13,
                  ),
                ),
              ),
              if (isProcessing) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.settings_suggest,
                  color: Colors.yellowAccent,
                  size: 14,
                ),
              ],
              if (showAlert) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutTile(bool compact) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _isLoggingOut ? 0.55 : 1.0,
      child: InkWell(
        onTap: _isLoggingOut ? null : _logout,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 10 : 13,
          ),
          child: Row(
            children: [
              if (_isLoggingOut)
                SizedBox(
                  width: compact ? 18 : 20,
                  height: compact ? 18 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kRed,
                  ),
                )
              else
                Icon(
                  Icons.logout_rounded,
                  color: kRed,
                  size: compact ? 18 : 20,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isLoggingOut ? 'Cerrando sesión...' : 'Cerrar Sesión',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kRed,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 11 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case AppView.dashboard:
        return const AnalyticsDashboard();

      case AppView.panelGeneral:
        return const PanelGeneralScreen();

      case AppView.neumatico:
        return const ScadaNeumaticoBoard();

      case AppView.robot:
        return const ScadaRobotDashboard();

      case AppView.maquinado:
        return const ScadaMaquinadosDashboard();

      case AppView.prensado:
        return const ScadaPrensadoScreen();

      case AppView.diagnosticoConexiones:
        return const DiagnosticoScreen();

      case AppView.historial:
        return const LogsScreen();

      case AppView.usuarios:
        return const UsuariosScreen();

      case AppView.horarios:
        return const HorariosScreen();

      case AppView.nube:
        return const CloudSyncDashboard();

      case AppView.perfil:
        return const PerfilScreen();

      case AppView.chatbot:
        return const ChatScreen();
    }
  }
}



class _LogoutAnimationOverlay extends StatefulWidget {
  const _LogoutAnimationOverlay();

  @override
  State<_LogoutAnimationOverlay> createState() =>
      _LogoutAnimationOverlayState();
}

class _LogoutAnimationOverlayState extends State<_LogoutAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _rotationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.68,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_rotationController);

    _entryController.forward();
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double cardWidth = screenWidth < 430 ? screenWidth - 40 : 360;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: cardWidth,
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                padding: const EdgeInsets.fromLTRB(
                  30,
                  32,
                  30,
                  28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: kCyan.withValues(alpha: 0.38),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kCyan.withValues(alpha: 0.18),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.48),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _rotationAnimation,
                            child: SizedBox(
                              width: 112,
                              height: 112,
                              child: CircularProgressIndicator(
                                value: 0.76,
                                strokeWidth: 4,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.07),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kCyan,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kCyan.withValues(alpha: 0.12),
                              border: Border.all(
                                color: kCyan.withValues(alpha: 0.42),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kCyan.withValues(alpha: 0.22),
                                  blurRadius: 24,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: kCyan,
                              size: 43,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CERRANDO SESIÓN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextMain,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Protegiendo tus datos y finalizando '
                      'la sesión actual...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: 1,
                      ),
                      duration: const Duration(
                        milliseconds: 2200,
                      ),
                      curve: Curves.easeInOutCubic,
                      builder: (
                        BuildContext context,
                        double value,
                        Widget? child,
                      ) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 7,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              kCyan,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: kGreen,
                          size: 16,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Sesión protegida',
                          style: TextStyle(
                            color: kGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeToast extends StatefulWidget {
  final String name;

  const _WelcomeToast({
    required this.name,
  });

  @override
  State<_WelcomeToast> createState() => _WelcomeToastState();
}

class _WelcomeToastState extends State<_WelcomeToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.elasticOut,
      ),
    );

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeIn,
      ),
    );

    _anim.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        _anim.reverse();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: kCyan,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: kCyan.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.waving_hand_rounded,
                color: Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Bienvenido, ${widget.name}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
