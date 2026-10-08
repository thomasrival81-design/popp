import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  late AnimationController _glowCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;

  static const Color _bg     = Color(0xFF030508);
  static const Color _blue   = Color(0xFF1565C0);
  static const Color _blueBri = Color(0xFF1E88E5);
  static const Color _blueAcc = Color(0xFF42A5F5);
  static const Color _cyan   = Color(0xFF00B4D8);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _videoController = VideoPlayerController.asset('assets/videos/background.mp4')
      ..initialize().then((_) {
        setState(() => _videoInitialized = true);
        _videoController.play();
        _videoController.setVolume(1.0);
        _videoController.setLooping(false);
        _fadeCtrl.forward();

      }).catchError((_) => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _videoController.dispose();
    _glowCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // VIDEO BG
        if (_videoInitialized)
          SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: _videoController.value.size.width, height: _videoController.value.size.height,
              child: VideoPlayer(_videoController))))
        else
          Container(color: _bg),
        // OVERLAY
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.6), _bg.withOpacity(0.85)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        // GLOW ORBS
        AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Stack(children: [
          Positioned(top: -100, left: -80, child: _orb(300, _blue.withOpacity(0.18 * _glowAnim.value))),
          Positioned(bottom: -60, right: -80, child: _orb(240, _cyan.withOpacity(0.12 * _glowAnim.value))),
        ])),
        // CENTER CONTENT
        FadeTransition(opacity: _fadeAnim, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // LOGO
          AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFF1565C0), Color(0xFF030508)]),
              border: Border.all(color: _blueBri.withOpacity(0.5 + 0.4 * _glowAnim.value), width: 2.5),
              boxShadow: [
                BoxShadow(color: _blueBri.withOpacity(0.5 * _glowAnim.value), blurRadius: 50, spreadRadius: 6),
                BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 20),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 48),
          )),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF90CAF9), Colors.white, Color(0xFF42A5F5)]).createShader(r),
            child: const Text("POP PROJECT", style: TextStyle(fontFamily: 'Orbitron', fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _blueBri.withOpacity(0.25)),
            ),
            child: const Text("LOADING SYSTEM...", style: TextStyle(color: Color(0xFF90CAF9), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w600, fontFamily: 'Orbitron')),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 160,
            child: AnimatedBuilder(animation: _glowAnim, builder: (_, __) => LinearProgressIndicator(
              backgroundColor: _blue.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(Color.lerp(_blue, _blueAcc, _glowAnim.value)!),
              minHeight: 3,
            )),
          ),
        ]))),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])));
}

// ===== ALIAS CLASS: SplashVideoPage =====
class SplashVideoPage extends StatefulWidget {
  final Widget nextPage;
  const SplashVideoPage({super.key, required this.nextPage});
  @override
  State<SplashVideoPage> createState() => _SplashVideoPageState();
}

class _SplashVideoPageState extends State<SplashVideoPage> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  late AnimationController _glowCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;

  static const Color _bg      = Color(0xFF030508);
  static const Color _blue    = Color(0xFF1565C0);
  static const Color _blueBri = Color(0xFF1E88E5);
  static const Color _blueAcc = Color(0xFF42A5F5);
  static const Color _cyan    = Color(0xFF00B4D8);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _videoController = VideoPlayerController.asset('assets/videos/background.mp4')
      ..initialize().then((_) {
        setState(() => _videoInitialized = true);
        _videoController.play();
        _videoController.setVolume(1.0);
        _videoController.setLooping(false);
        _fadeCtrl.forward();

        _videoController.addListener(() {
          if (!_videoController.value.isInitialized) return;

          final position = _videoController.value.position;
          final duration = _videoController.value.duration;

          if (duration > Duration.zero &&
              position >= duration &&
              !_videoController.value.isPlaying) {
            _goNext();
          }
        });
      }).catchError((_) {
        _fadeCtrl.forward();
        _goNext();
      });

  }

  void _goNext() {
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextPage));
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _glowCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        if (_videoInitialized)
          SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: _videoController.value.size.width, height: _videoController.value.size.height,
              child: VideoPlayer(_videoController))))
        else
          Container(color: _bg),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.55), _bg.withOpacity(0.82)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Stack(children: [
          Positioned(top: -100, left: -80, child: _orb(300, _blue.withOpacity(0.18 * _glowAnim.value))),
          Positioned(bottom: -60, right: -80, child: _orb(240, _cyan.withOpacity(0.12 * _glowAnim.value))),
        ])),
        FadeTransition(opacity: _fadeAnim, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFF1565C0), Color(0xFF030508)]),
              border: Border.all(color: _blueBri.withOpacity(0.5 + 0.4 * _glowAnim.value), width: 2.5),
              boxShadow: [
                BoxShadow(color: _blueBri.withOpacity(0.5 * _glowAnim.value), blurRadius: 50, spreadRadius: 6),
                BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 20),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 48),
          )),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF90CAF9), Colors.white, Color(0xFF42A5F5)]).createShader(r),
            child: const Text("POP PROJECT", style: TextStyle(fontFamily: 'Orbitron', fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _blueBri.withOpacity(0.25)),
            ),
            child: const Text("ENTERING SYSTEM...", style: TextStyle(color: Color(0xFF90CAF9), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w600, fontFamily: 'Orbitron')),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 160,
            child: AnimatedBuilder(animation: _glowAnim, builder: (_, __) => LinearProgressIndicator(
              backgroundColor: _blue.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(Color.lerp(_blue, _blueAcc, _glowAnim.value)!),
              minHeight: 3,
            )),
          ),
        ]))),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])));
}
