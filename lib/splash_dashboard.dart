// splash_dashboard.dart - DENGAN TOMBOL LEWATI
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_page.dart';
import 'catatan_pembuka.dart';

class SplashDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  const SplashDashboardPage({super.key, this.data});

  @override
  State<SplashDashboardPage> createState() => _SplashDashboardPageState();
}

class _SplashDashboardPageState extends State<SplashDashboardPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  late AnimationController _pulseController;
  bool _navigated = false;

  static const Color bgMain     = Color(0xFFDCEEFB);
  static const Color bgCard     = Color(0xFFFFFFFF);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color borderBlue = Color(0xFF42A5F5);
  static const Color textMain   = Colors.black87;
  static const Color textSub    = Colors.black54;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'WELCOME',
      'subtitle': 'Welcome To POP APPS',
      'desc': 'Nikmati pengalaman terbaik bersama kami',
      'badge': 'SELAMAT DATANG',
    },
    {
      'title': 'TERIMA KASIH YA !!',
      'subtitle': 'SETIA DENGAN KAMI',
      'desc': 'terima kasih telah mensupport kami, walaupun terkadang project kami sering ampas / error, tapi kalian hebat selalu setia dengan POP PROJECT',
      'badge': 'TERIMA KASIH',
    },
    {
      'title': 'ARE YOU READY ?!',
      'subtitle': 'ENTER DASHBOARD',
      'desc': 'Putar musiknya rayakan bersama bro!!',
      'badge': 'READY',
    },
  ];

  Future<void> _openTelegram() async {
    final url = Uri.parse('https://t.me/RoomPublicKayy1');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka Telegram')),
      );
    }
  }

  void _goToDashboard() {
    if (_navigated) return;
    _navigated = true;
    final dashboard = DashboardPage(
      username: widget.data!['username'] as String? ?? '',
      password: widget.data!['password'] as String? ?? '',
      role: widget.data!['role'] as String? ?? 'member',
      sessionKey: widget.data!['key'] as String? ?? '',
      expiredDate: widget.data!['expiredDate'] as String? ?? '2099-12-31',
      listBug: List<Map<String, dynamic>>.from(widget.data!['listBug'] ?? []),
      listDoos: List<Map<String, dynamic>>.from(widget.data!['listDoos'] ?? []),
      news: List<Map<String, dynamic>>.from(widget.data!['news'] ?? []),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CatatanPembukaPage(nextPage: dashboard),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    // AUTO MASUK DASHBOARD TANPA PERLU KLIK LEWATI
    Future.delayed(const Duration(milliseconds: 1500), _goToDashboard);
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/splashd.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.play();
        _videoController.setVolume(1.0);
        _videoController.setLooping(true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: Stack(
        children: [
          // ─── VIDEO BACKGROUND ──────────────────────────────
          if (_isVideoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFDCEEFB),
                    const Color(0xFFF0F7FF),
                  ],
                ),
              ),
            ),

          // ─── OVERLAY ────────────────────────────────────────
          Container(
            color: Colors.white.withOpacity(0.15),
          ),

          // ─── PAGE VIEW ──────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final data = _pages[index];
              return _buildPage(data, index);
            },
          ),

          // ─── TOMBOL LEWATI (POJOK KANAN ATAS) ─────────────
          Positioned(
            top: 50,
            right: 16,
            child: GestureDetector(
              onTap: _goToDashboard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: Text(
                  "LEWATI",
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: textMain,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // ─── BOTTOM: DOTS + BUTTON ──────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // ─── DOTS ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: _currentPage == index
                              ? accentBlue
                              : Colors.black.withOpacity(0.18),
                          boxShadow: _currentPage == index
                              ? [
                                  BoxShadow(
                                    color: accentBlue.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── BUTTON ──────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final isLast = _currentPage == _pages.length - 1;
                      final pulse = _pulseController.value;
                      return GestureDetector(
                        onTap: () {
                          if (isLast) {
                            _goToDashboard();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isLast
                                ? Color.lerp(accentBlue, borderBlue, pulse * 0.4)
                                : bgCard,
                            border: Border.all(
                              color: Colors.black,
                              width: 1.5,
                            ),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.black,
                                blurRadius: 0,
                                offset: Offset(4, 4),
                              ),
                              if (isLast)
                                BoxShadow(
                                  color: accentBlue.withOpacity(0.25 + 0.10 * pulse),
                                  blurRadius: 14 + 4 * pulse,
                                  spreadRadius: 0,
                                ),
                            ],
                          ),
                          child: Text(
                            isLast ? 'MULAI SEKARANG' : 'LANJUT',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: isLast ? Colors.white : textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ─── HINT SWIPE ──────────────────────────────────────
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Geser untuk lanjut',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: textSub,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> data, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ─── BADGE ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accentBlue.withOpacity(0.10),
              border: Border.all(color: accentBlue.withOpacity(0.45)),
            ),
            child: Text(
              data['badge'],
              style: const TextStyle(
                fontFamily: 'Orbitron',
                color: accentBlue,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ─── TITLE ──────────────────────────────────────────
          Text(
            data['title'],
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: textMain,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // ─── SUBTITLE ──────────────────────────────────────
          Text(
            data['subtitle'],
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: textSub,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // ─── GARIS PEMBATAS ────────────────────────────────
          Container(
            width: 60,
            height: 1,
            color: Colors.black.withOpacity(0.1),
          ),

          const SizedBox(height: 20),

          // ─── DESCRIPTION ────────────────────────────────────
          Text(
            data['desc'],
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: textSub,
              fontSize: 13,
              height: 1.8,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          // ─── INDIKATOR HALAMAN ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${index + 1} / ${_pages.length}",
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: textSub,
                fontSize: 10.5,
              ),
            ),
          ),

          // ─── TELEGRAM (HANYA DI HALAMAN TERAKHIR) ──────────
          if (index == _pages.length - 1) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _openTelegram,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 0,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      FontAwesomeIcons.telegram,
                      color: accentBlue,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'JOIN TELEGRAM CHANNEL',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: textSub,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}