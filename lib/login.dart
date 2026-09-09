import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

// ================= ANIMATIONS =================
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginY;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.beginY = 1.0,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.beginY),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// ================= ANIMACIÓN DE APERTURA =================
class _LoginOpeningAnimation extends StatefulWidget {
  const _LoginOpeningAnimation({super.key});

  @override
  State<_LoginOpeningAnimation> createState() => _LoginOpeningAnimationState();
}

class _LoginOpeningAnimationState extends State<_LoginOpeningAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _ringRotation;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );

    _logoScale = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.00,
          0.48,
          curve: Curves.elasticOut,
        ),
      ),
    );

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.00,
          0.25,
          curve: Curves.easeOut,
        ),
      ),
    );

    _ringRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.35,
          0.72,
          curve: Curves.easeOut,
        ),
      ),
    );

    _progress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.45,
          1.00,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 600;

    return Center(
      key: const ValueKey<String>('login-opening-animation'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _ringRotation,
                    child: Container(
                      width: compact ? 138 : 168,
                      height: compact ? 138 : 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.45),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.20),
                            blurRadius: 35,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blueAccent,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: compact ? 96 : 116,
                        height: compact ? 96 : 116,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111B2C),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const Icon(
                              Icons.precision_manufacturing_rounded,
                              color: Colors.blueAccent,
                              size: 62,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _textOpacity,
                child: const Column(
                  children: [
                    Text(
                      'SCADA MASTER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Hitech Ingenium · Industrial Control',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.2,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: compact ? 210 : 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _textOpacity,
                child: const Text(
                  'INICIALIZANDO SISTEMA...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================= LOGIN =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool rememberMe = false;
  bool obscure = true;
  bool _isLoading = false;
  bool _showLoginForm = false;
  bool _hideRegisterLink = false; // Nueva variable para ocultar registro

  Timer? _openingTimer;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? emailError;
  String? passwordError;

  @override
  void initState() {
    super.initState();
    _checkExistingAccount(); // Verificar si ya hay cuenta
    emailController.addListener(_validateEmail);
    passwordController.addListener(_validatePassword);

    _openingTimer = Timer(
      const Duration(milliseconds: 2250),
      () {
        if (!mounted) return;
        setState(() {
          _showLoginForm = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _openingTimer?.cancel();
    emailController.removeListener(_validateEmail);
    passwordController.removeListener(_validatePassword);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      emailError =
          (emailController.text.isEmpty || emailController.text.contains('@'))
              ? null
              : 'Correo inválido';
    });
  }

  void _validatePassword() {
    setState(() {
      passwordError = null;
    });
  }

  Future<void> _checkExistingAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('userEmail');
    if (email != null && email.isNotEmpty) {
      setState(() {
        _hideRegisterLink = true;
        emailController.text = email; // Pre-llenar el correo para facilidad
      });
    }
  }

  void submitLogin() async {
    _validateEmail();
    _validatePassword();
    if (emailError != null ||
        passwordError != null ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, rellene todos los campos correctamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. INICIAR SESIÓN CON FIREBASE AUTHENTICATION
      // Esto reconoce automáticamente la nueva contraseña si se usó el enlace de recuperación.
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (userCredential.user != null) {
        // 2. BUSCAR DATOS ADICIONALES EN FIRESTORE
        final querySnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('correo', isEqualTo: emailController.text.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El usuario no tiene un perfil en la base de datos.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        } else {
          final docId = querySnapshot.docs.first.id;
          final userData = querySnapshot.docs.first.data();
          final String rol = userData['rol'] ?? 'Alumno';

          // 3. SINCRONIZAR LA CONTRASEÑA EN FIRESTORE (A petición del usuario)
          // Si el inicio de sesión fue exitoso pero el hash en la DB es viejo, lo actualizamos.
          if (userData['passwordHash'] != passwordController.text) {
            await FirebaseFirestore.instance.collection('usuarios').doc(docId).update({
              'passwordHash': passwordController.text,
            });
          }

          // 4. MANEJO DE SESIÓN LOCAL
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', emailController.text.trim());
          await prefs.setString('userName', userData['nombre'] ?? '');
          await prefs.setString('userRole', rol);
          await prefs.setBool('showWelcome', rol != 'Pendiente');

          if (!mounted) return;

          // REDIRECCIÓN SEGÚN ROL Y PERFIL
          if (rol == 'Pendiente') {
            Navigator.pushReplacementNamed(context, '/espera');
          } else if (rol == 'Alumno' && !(userData['perfilCompleto'] ?? false)) {
            Navigator.pushReplacementNamed(context, '/formulario');
          } else if (!(userData['encuestaCompletada'] ?? false)) {
            Navigator.pushReplacementNamed(context, '/encuesta');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Error al iniciar sesión.";
      if (e.code == 'user-not-found') errorMsg = "No existe una cuenta con este correo.";
      if (e.code == 'wrong-password') errorMsg = "Contraseña incorrecta. Inténtelo de nuevo.";
      if (e.code == 'invalid-credential') errorMsg = "Credenciales inválidas o expiradas.";
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión con el servidor: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLoginForm() {
    return Center(
      key: const ValueKey<String>('login-form'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: .3)),
          ),
          child: Column(
            children: [
              const FadeInSlide(
                child: Icon(Icons.precision_manufacturing,
                    size: 80, color: Colors.blueAccent),
              ),
              const SizedBox(height: 15),
              const FadeInSlide(
                delay: Duration(milliseconds: 100),
                child: Text(
                  'INDUSTRIAL CONTROL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeInSlide(
                delay: const Duration(milliseconds: 200),
                child: TextField(
                  controller: emailController,
                  decoration:
                      inputDecoration('Correo o usuario', Icons.person_outline)
                          .copyWith(
                    errorText: emailError,
                    errorStyle: const TextStyle(color: Colors.orangeAccent),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.orangeAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              FadeInSlide(
                delay: const Duration(milliseconds: 300),
                child: TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: inputDecoration('Contraseña', Icons.lock_outline)
                      .copyWith(
                    errorText: passwordError,
                    errorStyle: const TextStyle(color: Colors.orangeAccent),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.orangeAccent),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              FadeInSlide(
                delay: const Duration(milliseconds: 400),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              FadeInSlide(
                delay: const Duration(milliseconds: 500),
                child: ElevatedButton(
                  onPressed: submitLogin,
                  style: buttonStyle(),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Center(child: Text('Entrar')),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!_hideRegisterLink) // Ocultar si ya hay cuenta en el dispositivo
                FadeInSlide(
                  delay: const Duration(milliseconds: 800),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta? '),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          reverseDuration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (
            Widget child,
            Animation<double> animation,
          ) {
            final Animation<double> scale = Tween<double>(
              begin: 0.96,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            );
          },
          child: _showLoginForm
              ? _buildLoginForm()
              : const _LoginOpeningAnimation(),
        ),
      ),
    );
  }
}

// ================= REGISTER =================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool acceptedTerms = false;
  bool rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefonoController = TextEditingController();
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    setState(() {
      _confirmPasswordError = (_confirmPasswordController.text.isNotEmpty &&
              _passwordController.text != _confirmPasswordController.text)
          ? 'Las contraseñas no coinciden'
          : null;
    });
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _profileImageBytes = result.files.first.bytes;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error picking file: $e");
    }
  }

  void _registrarUsuario() async {
    if (_nombreController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _confirmPasswordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos correctamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_emailController.text.endsWith('@huetamo.tecnm.mx')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No está permitido el registro con el correo ingresado.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. REGISTRAR EN FIREBASE AUTHENTICATION (Para que funcione la recuperación)
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2. GUARDAR IMAGEN LOCAL SI EXISTE
      String? localPath;
      if (_profileImageBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String emailSanitized =
            _emailController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final String fileName = 'profile_$emailSanitized.png';
        final File file = File(p.join(directory.path, fileName));
        await file.writeAsBytes(_profileImageBytes!);
        localPath = file.path;
      }

      // 3. GUARDAR DATOS ADICIONALES EN FIRESTORE
      await FirebaseFirestore.instance.collection('usuarios').add({
        'activo': true,
        'correo': _emailController.text.trim(),
        'fechaRegistro':
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        'nombre': _nombreController.text,
        'numero': _telefonoController.text,
        'passwordHash': _passwordController.text, // Mantenemos para compatibilidad con tu login actual
        'rol': 'Pendiente',
        'perfilCompleto': false,
        'ultimoAcceso':
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
      });

      if (localPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'profileImagePath_${_emailController.text}', localPath);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cuenta creada y vinculada. En espera de aprobación.'),
          backgroundColor: Colors.blueAccent,
        ),
      );

      Navigator.pushReplacementNamed(context, '/espera');
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Error al crear la cuenta.";
      if (e.code == 'email-already-in-use') errorMsg = "Este correo ya está registrado.";
      if (e.code == 'weak-password') errorMsg = "La contraseña es muy débil.";
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar datos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF101725),
        title: const Text('Términos y Condiciones de Uso - SCADA MASTER',
            style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Aceptación de los Términos y Propósito del Sistema\n'
                'Al crear una cuenta y acceder a la aplicación SCADA MASTER, el usuario acepta de manera expresa los presentes términos y condiciones.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              // ... mas términos
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido',
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Crear cuenta',
      profileImage: _profileImageBytes != null
          ? ClipOval(
              child: Image.memory(
                _profileImageBytes!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            )
          : null,
      onIconTap: _pickImage,
      child: Column(
        children: [
          const SizedBox(height: 20),
          FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: TextField(
              controller: _nombreController,
              decoration: inputDecoration('Nombre completo', Icons.person),
            ),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 400),
            child: TextField(
              controller: _telefonoController,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: inputDecoration('Número de Teléfono', Icons.phone),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 600),
            child: TextField(
              controller: _emailController,
              decoration: inputDecoration('Correo', Icons.email),
            ),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 700),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: inputDecoration('Contraseña', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeInSlide(
            delay: const Duration(milliseconds: 700),
            child:
                PasswordStrengthIndicator(password: _passwordController.text),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 800),
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration:
                  inputDecoration('Confirmar contraseña', Icons.lock).copyWith(
                errorText: _confirmPasswordError,
                errorStyle: const TextStyle(color: Colors.orangeAccent),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.orangeAccent),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 900),
            child: Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (v) => setState(() => rememberMe = v!),
                ),
                const Text('Recordar sesión'),
              ],
            ),
          ),
          const SizedBox(height: 15),
          FadeInSlide(
            delay: const Duration(milliseconds: 1000),
            child: Row(
              children: [
                Checkbox(
                  value: acceptedTerms,
                  onChanged: (v) => setState(() => acceptedTerms = v!),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Acepto los ',
                      children: [
                        TextSpan(
                          text: 'términos y condiciones',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showTermsDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeInSlide(
            delay: const Duration(milliseconds: 1100),
            child: ElevatedButton(
              onPressed:
                  (acceptedTerms && !_isLoading) ? _registrarUsuario : null,
              style: buttonStyle(),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Crear cuenta'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 1200),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: buttonStyle().copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.grey),
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('Cancelar')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PASSWORD STRENGTH =================
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});

  double _getStrength() {
    if (password.isEmpty) return 0;
    double s = 0;
    if (password.length >= 8) s += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) s += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) s += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) s += 0.25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s += 0.25;
    return s.clamp(0, 1);
  }

  Color _getColor(double s) {
    if (s < 0.3) return Colors.red;
    if (s < 0.6) return Colors.orange;
    if (s < 0.8) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final s = _getStrength();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 8,
          decoration: BoxDecoration(
            color: _getColor(s).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: s,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: _getColor(s),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s == 0
              ? ''
              : s < 0.3
                  ? 'Débil'
                  : s < 0.6
                      ? 'Aceptable'
                      : s < 0.8
                          ? 'Fuerte'
                          : 'Muy Fuerte',
          style: TextStyle(fontSize: 12, color: _getColor(s)),
        ),
      ],
    );
  }
}

// ================= RECOVERY (SISTEMA SEGURO FIREBASE) =================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Usamos el sistema oficial de Firebase para enviar el link de recuperación
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF101725),
          title: const Text('Correo Enviado', style: TextStyle(color: Colors.blueAccent)),
          content: Text('Hemos enviado un enlace de recuperación a: $email.\n\nPor favor, revisa tu bandeja de entrada y spam.', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Entendido'),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Error al enviar el correo.";
      if (e.toString().contains('user-not-found')) {
        errorMsg = "No existe una cuenta registrada con este correo.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Recuperar contraseña',
      icon: Icons.mark_email_read_outlined,
      child: Column(
        children: [
          const Text(
            'Ingresa tu correo institucional. Te enviaremos un enlace oficial de Firebase para que cambies tu contraseña de forma segura.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 25),
          FadeInSlide(
            child: TextField(
              controller: emailController,
              decoration: inputDecoration('Correo institucional', Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 30),
          FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: buttonStyle().copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.white10),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: buttonStyle(),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar enlace'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TEMPLATE =================
class AuthScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final int? progress;
  final IconData? icon;
  final Widget? profileImage;
  final VoidCallback? onIconTap;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.progress,
    this.icon,
    this.profileImage,
    this.onIconTap,
  });

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  FadeInSlide(
                    beginY: -1,
                    child: GestureDetector(
                      onTap: onIconTap,
                      child: profileImage ??
                          Icon(icon ?? Icons.person,
                              size: 70, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInSlide(
                    beginY: -1,
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 15),
                    FadeInSlide(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress! / 3,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor:
                                const AlwaysStoppedAnimation(Colors.blueAccent),
                          ),
                          const SizedBox(height: 8),
                          Text('Paso $progress de 3'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 25),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= BACKGROUND =================
class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0B1220),
                Color(0xFF101725),
                Color(0xFF0B1220),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Opacity(
          opacity: 0.08,
          child: GridPaper(
            color: Colors.blueAccent,
            interval: 35,
            divisions: 1,
          ),
        ),
        child,
      ],
    );
  }
}

// ================= STYLES =================
InputDecoration inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: Colors.white12,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

ButtonStyle buttonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.blueAccent,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  );
}
