import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui';
import 'dashboard_page.dart';
import 'splash_video_page.dart';
import 'widgets/custom_popup.dart';

const String baseUrl = "http://127.0.0.1:3143";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _fadeCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _glowAnim;

  // ─── PALETTE: PUTIH VANILLA + BIRU TUA ───
  static const Color bgMain     = Color(0xFFF5F0E8);   // putih vanilla
  static const Color bgCard     = Color(0xFFFFFFFF);   // putih bersih
  static const Color bgInput    = Color(0xFFF0EBE0);   // vanilla muda
  static const Color accent     = Color(0xFF0D47A1);   // biru tua
  static const Color accentBri  = Color(0xFF1565C0);   // biru
  static const Color accentGlow = Color(0xFF1E88E5);   // biru terang
  static const Color border     = Color(0xFF90CAF9);   // biru muda
  static const Color textMain   = Color(0xFF0D0D14);   // hitam
  static const Color textSub    = Color(0xFF1565C0);   // biru tua

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();
    initLogin();
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");
    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse("$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SplashVideoPage(nextPage: DashboardPage(
            username: savedUser, password: savedPass, role: data['role'],
            sessionKey: data['key'], expiredDate: data['expiredDate'],
            listBug: (data['listBug'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            listDoos: (data['listDDoS'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            news: (data['news'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            uid: data['uid'],
          ))));
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    final username = userController.text.trim();
    final password = passController.text.trim();
    setState(() => isLoading = true);
    try {
      final validate = await http.post(Uri.parse("$baseUrl/validate"),
          body: {"username": username, "password": password, "androidId": androidId ?? "unknown_device"});
      final validData = jsonDecode(validate.body);
      if (validData['expired'] == true) {
        _showPopup(title: "Access Expired", message: "Masa akses Anda telah habis.\nSilakan perpanjang akses.", showContact: true);
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") || errorMsg.contains("device") || errorMsg.contains("another")) {
          _showPopup(title: "Sesi Aktif", message: "Akun ini sedang login di perangkat lain.\nSilakan logout di perangkat lama.");
        } else {
          _showPopup(title: "Login Gagal", message: "Username atau password salah.");
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SplashVideoPage(nextPage: DashboardPage(
            username: username, password: password, role: validData['role'],
            sessionKey: validData['key'], expiredDate: validData['expiredDate'],
            listBug: (validData['listBug'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            listDoos: (validData['listDDoS'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            news: (validData['news'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            uid: validData['uid'],
          ))));
        }
      }
    } catch (e) {
      _showPopup(title: "Connection Error", message: "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _showPopup({required String title, required String message, bool showContact = false}) {
    final bool isError = title.toLowerCase().contains("gagal") || title.toLowerCase().contains("expired") || title.toLowerCase().contains("error");
    CustomPopup.show(context, title: title, message: message,
      icon: isError ? Icons.error_outline : Icons.info_outline,
      iconColor: isError ? Colors.redAccent : accentBri,
      cancelText: showContact ? "Contact Admin" : null,
      onCancel: showContact ? () async { await launchUrl(Uri.parse("https://t.me/hann_xd"), mode: LaunchMode.externalApplication); } : null,
      confirmText: "Close");
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
        child: Stack(children: [
          // GRID BACKGROUND
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
          // GLOW ORBS
          AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Stack(children: [
            Positioned(top: -80, left: -60, child: _glowOrb(220, accentBri.withOpacity(0.12 * _glowAnim.value))),
            Positioned(bottom: -60, right: -80, child: _glowOrb(200, accent.withOpacity(0.08 * _glowAnim.value))),
          ])),
          // CONTENT
          SafeArea(child: Center(child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _slideAnim,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 20),
                  _buildLogo(),
                  const SizedBox(height: 32),
                  _buildForm(),
                  const SizedBox(height: 30),
                ]),
              )),
            ),
          ))),
        ]),
      ),
    );
  }

  Widget _glowOrb(double size, Color color) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])));

  Widget _buildLogo() {
    return Column(children: [
      AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [accent, accentBri], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: accentBri.withOpacity(0.35 * _glowAnim.value), blurRadius: 30, spreadRadius: 4),
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
      )),
      const SizedBox(height: 22),
      Text("POP PROJECT", style: TextStyle(fontFamily: 'Orbitron', fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4, color: accent)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentBri.withOpacity(0.3))),
        child: Text("SECURE ACCESS PORTAL", style: TextStyle(color: accentBri, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 12)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10),
        ],
      ),
      child: Form(key: _formKey, child: Column(children: [
        // HEADER FORM
        Row(children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accentBri], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text("LOGIN", style: TextStyle(color: accent, fontFamily: 'Orbitron', fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ]),
            const SizedBox(height: 20),
            _buildTextField(controller: userController, label: "Username", icon: Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _buildTextField(controller: passController, label: "Password", icon: Icons.lock_outline_rounded, isPassword: true),
            const SizedBox(height: 24),
            _buildLoginButton(),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.security, size: 11, color: textSub.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text("Encrypted · Secure Connection", style: TextStyle(color: textSub.withOpacity(0.5), fontSize: 11)),
            ]),
          ])),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.5)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: TextStyle(color: textMain, fontSize: 15),
        cursorColor: accentBri,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accent.withOpacity(0.6), fontSize: 13),
          prefixIcon: Icon(icon, color: accentBri, size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textSub.withOpacity(0.5), size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Masukkan $label' : null,
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: accentBri.withOpacity(0.35 * _glowAnim.value), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : login,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.login_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text("MASUK SISTEM", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2.5, color: Colors.white, fontFamily: 'Orbitron')),
              ]),
      ),
    ));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1565C0).withOpacity(0.04)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_GridPainter old) => false;
}
