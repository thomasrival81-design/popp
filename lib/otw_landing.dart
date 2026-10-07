// otw_landing.dart - BERGAYA DARK BLUE PREMIUM
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'landing.dart';

class OtwLandingPage extends StatefulWidget {
  const OtwLandingPage({super.key});
  @override
  State<OtwLandingPage> createState() => _OtwLandingPageState();
}

class _OtwLandingPageState extends State<OtwLandingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _navigated = false;

  static const Color _bg     = Color(0xFF030508);
  static const Color _card   = Color(0xFF0A0D14);
  static const Color _blue   = Color(0xFF1565C0);
  static const Color _blueBri = Color(0xFF1E88E5);
  static const Color _blueAcc = Color(0xFF42A5F5);
  static const Color _cyan   = Color(0xFF00B4D8);

  final List<Map<String, dynamic>> _pages = [
    {'title': 'BERGAYA', 'subtitle': 'STYLE WITH ATTITUDE', 'desc': 'Tampil dengan gaya khasmu\nJadilah dirimu sendiri\nTanpa batasan!', 'badge': 'STYLE', 'japanese': 'スタイルを持って', 'icon': Icons.star_rounded},
    {'title': 'NEW RAT CONTROL', 'subtitle': 'ALWAYS ON FIRE', 'desc': 'Selalu gacor setiap saat\nBersama POP PROJECT APPS\nTak terkalahkan!', 'badge': 'GACOR', 'japanese': '常に燃えている', 'icon': Icons.bolt_rounded},
    {'title': 'NEBULA', 'subtitle': 'BEYOND THE STARS', 'desc': 'Jelajahi teknologi terbaru\nBersama POP TEAM\nMasa depan dimulai sekarang!', 'badge': 'POP PROJECT', 'japanese': '星を超えて', 'icon': Icons.auto_awesome_rounded},
    {'title': 'DEV @hann_xd', 'subtitle': 'TOGETHER WE RISE', 'desc': 'Bersama kita kuat\nTEAM @hann_xd\nSolidaritas tanpa batas!', 'badge': 'TEAM', 'japanese': '共に立ち上がる', 'icon': Icons.people_alt_rounded},
  ];

  void _goToLanding() {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandingPage()));
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _videoController = VideoPlayerController.asset('assets/videos/splashd.mp4')
      ..initialize().then((_) {
        setState(() => _isVideoInitialized = true);
        _videoController.play();
        _videoController.setVolume(1.0);
        _videoController.setLooping(true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _pageController.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // VIDEO BACKGROUND
        if (_isVideoInitialized)
          SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: _videoController.value.size.width, height: _videoController.value.size.height,
              child: VideoPlayer(_videoController))))
        else
          Container(color: _bg),
        // DARK OVERLAY
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bg.withOpacity(0.75), Colors.black.withOpacity(0.85)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        // GLOW ORBS
        AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Stack(children: [
          Positioned(top: -80, left: -60, child: _orb(240, _blue.withOpacity(0.15 * _glowAnim.value))),
          Positioned(bottom: -60, right: -80, child: _orb(200, _cyan.withOpacity(0.10 * _glowAnim.value))),
        ])),
        // PAGE VIEW
        PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemCount: _pages.length,
          itemBuilder: (_, i) => _buildPage(_pages[i], i),
        ),
        // TOMBOL LEWATI
        Positioned(top: 52, right: 20,
          child: GestureDetector(onTap: _goToLanding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Text("LEWATI", style: TextStyle(fontFamily: 'Orbitron', color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        // BOTTOM DOTS + BUTTON
        Positioned(bottom: 40, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _currentPage == i ? _blueBri : Colors.white.withOpacity(0.2),
                    boxShadow: _currentPage == i ? [BoxShadow(color: _blueBri.withOpacity(0.6), blurRadius: 8)] : null,
                  ),
                ),
              )),
              const SizedBox(height: 18),
              AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) {
                final isLast = _currentPage == _pages.length - 1;
                final p = _pulseCtrl.value;
                return GestureDetector(
                  onTap: () => isLast ? _goToLanding() : _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: isLast
                          ? [const Color(0xFF0D47A1), Color.lerp(const Color(0xFF1565C0), _blueBri, p * 0.5)!]
                          : [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.12)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: isLast ? _blueBri.withOpacity(0.4 + 0.4 * p) : Colors.white.withOpacity(0.15), width: 1.5),
                      boxShadow: isLast ? [BoxShadow(color: _blue.withOpacity(0.5 * p), blurRadius: 20, offset: const Offset(0, 6))] : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 12),
                      Text(isLast ? "MASUK LANDING" : "LANJUT",
                          style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])));

  Widget _buildPage(Map<String, dynamic> data, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 80),
        // ICON BADGE
        AnimatedBuilder(animation: _glowAnim, builder: (_, __) => Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF1565C0), Color(0xFF030508)]),
            border: Border.all(color: _blueBri.withOpacity(0.4 + 0.4 * _glowAnim.value), width: 2),
            boxShadow: [BoxShadow(color: _blue.withOpacity(0.5 * _glowAnim.value), blurRadius: 30, spreadRadius: 4)],
          ),
          child: Icon(data['icon'] as IconData, color: Colors.white, size: 36),
        )),
        const SizedBox(height: 20),
        // BADGE CHIP
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blueBri.withOpacity(0.35)),
          ),
          child: Text(data['badge'], style: TextStyle(fontFamily: 'Orbitron', color: _blueAcc, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 18),
        // JAPANESE
        Text(data['japanese'], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, letterSpacing: 2)),
        const SizedBox(height: 10),
        // TITLE
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF90CAF9), Colors.white, Color(0xFF42A5F5)]).createShader(r),
          child: Text(data['title'], style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1, height: 1.3), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 10),
        // SUBTITLE
        Text(data['subtitle'], style: TextStyle(fontFamily: 'Orbitron', color: _blueAcc.withOpacity(0.7), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Container(width: 50, height: 1.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, _blueBri, Colors.transparent]))),
        const SizedBox(height: 18),
        // DESC
        Text(data['desc'], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.9, letterSpacing: 0.3), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        // PAGE COUNTER
        Text("${index + 1} / ${_pages.length}", style: TextStyle(fontFamily: 'Orbitron', color: Colors.white.withOpacity(0.25), fontSize: 10.5)),
        const SizedBox(height: 140),
      ]),
    );
  }
}
