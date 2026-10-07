import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'login_page.dart';
import 'widgets/custom_popup.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  static const Color _bg      = Color(0xFF8A9BB5);
  static const Color _bgDark  = Color(0xFF6B7D96);
  static const Color _blue    = Color(0xFF2D6EC7);
  static const Color _blueBri = Color(0xFF3B82D4);
  static const Color _card    = Color(0xFFE8EDF5);
  static const Color _white   = Colors.white;
  static const Color _text    = Color(0xFF1A2744);

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/landingvidio.mp4')
      ..initialize().then((_) {
        setState(() => _videoReady = true);
        _videoController?.setLooping(true);
        _videoController?.setVolume(1.0);
        _videoController?.play();
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // BG GRADIENT
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7A8FA8), Color(0xFF8A9BB5), Color(0xFF95A8BE)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              const SizedBox(height: 20),

              // ── VIDEO / LOGO BESAR ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _videoReady && _videoController != null
                      ? VideoPlayer(_videoController!)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF6B7D96), Color(0xFF8A9BB5)]),
                          ),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── TITLE ──
              const Text(
                "APK POP · FOR YOU",
                style: TextStyle(color: _white, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text("APK Terbaru dengan fitur lengkap",
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14)),

              const SizedBox(height: 24),

              // ── FITUR 3 KOLOM ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _buildFeatureCard(Icons.phone_android_rounded, "TERMUX", "install di HP, langsung jalan"),
                  const SizedBox(width: 10),
                  _buildFeatureCard(Icons.dns_rounded, "VPS", "Server 24/7 stabil"),
                  const SizedBox(width: 10),
                  _buildFeatureCard(Icons.navigation_rounded, "UBOT", "Bot per user"),
                ]),
              ),

              const SizedBox(height: 28),

              // ── TOMBOL MASUK (BIRU) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                  child: Container(
                    width: double.infinity, height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2D6EC7), Color(0xFF3B82D4)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.login_rounded, color: _white, size: 22),
                      SizedBox(width: 12),
                      Text("MASUK", style: TextStyle(color: _white, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2.5)),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── TOMBOL BELI AKSES ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _launch("https://t.me/hann_xd"),
                  child: Container(
                    width: double.infinity, height: 54,
                    decoration: BoxDecoration(
                      color: _card.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shopping_bag_outlined, color: Colors.white.withOpacity(0.85), size: 20),
                      const SizedBox(width: 10),
                      Text("BELI AKSES", style: TextStyle(color: Colors.white.withOpacity(0.85), fontFamily: 'Orbitron', fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 2)),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── TOMBOL HUBUNGI SUPPORT ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _launch("https://t.me/hann_xd"),
                  child: Container(
                    width: double.infinity, height: 54,
                    decoration: BoxDecoration(
                      color: _card.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.headset_mic_rounded, color: Colors.white.withOpacity(0.85), size: 20),
                      const SizedBox(width: 10),
                      Text("HUBUNGI SUPPORT", style: TextStyle(color: Colors.white.withOpacity(0.85), fontFamily: 'Orbitron', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5)),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── SOCIAL + COPYRIGHT ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _socialBtn(FontAwesomeIcons.telegram, "Telegram", "https://t.me/KawakunChan"),
                    const SizedBox(width: 24),
                    _socialBtn(FontAwesomeIcons.tiktok, "TikTok", "https://tiktok.com/@KawakunChan"),
                  ]),
                  const SizedBox(height: 16),
                  Text("© 2026 POP PROJECT", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, letterSpacing: 1)),
                ]),
              ),

              const SizedBox(height: 30),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white.withOpacity(0.85), size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: _white, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _socialBtn(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () => _launch(url),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _card.withOpacity(0.5),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
      ]),
    );
  }
}
