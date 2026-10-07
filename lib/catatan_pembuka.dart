import 'package:flutter/material.dart';
import 'dart:math' as math;

class CatatanPembukaPage extends StatefulWidget {
  final Widget nextPage;
  const CatatanPembukaPage({super.key, required this.nextPage});
  @override
  State<CatatanPembukaPage> createState() => _CatatanPembukaPageState();
}

class _CatatanPembukaPageState extends State<CatatanPembukaPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const Color _krem    = Color(0xFFF5EDD6);
  static const Color _kremDark = Color(0xFFEDE0C0);
  static const Color _gold    = Color(0xFFD4A853);
  static const Color _text    = Color(0xFF1A1A1A);
  static const Color _textSub = Color(0xFF555555);
  static const Color _black   = Color(0xFF111111);

  void _lanjut() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextPage),
    );
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipPath(
                  clipper: _WavyClipper(),
                  child: Container(
                    color: _krem,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                          // TOP ROW - badge + nama
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: _text.withOpacity(0.4)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text("CATATAN PEMBUKA", style: TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            ),
                            const Text("POP", style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ]),

                          const SizedBox(height: 22),

                          // JUDUL BESAR
                          const Text("APK POP PROJECT", style: TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                          const Text("berbeda dari project lama", style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w500, height: 1.2)),

                          const SizedBox(height: 12),

                          // GARIS GOLD
                          Container(height: 2, decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_gold, Color(0xFFF0C060), Colors.transparent]),
                          )),

                          const SizedBox(height: 18),

                          // PARAGRAF 1
                          const Text(
                            "Karena Pengalaman yang dahulu mengurus vps sendiri — Pembelian banyak vps yang tidak menghasilkan pencapaian maksimal. Yang Ada buang duit dan member terus mengeluh.",
                            style: TextStyle(color: _textSub, fontSize: 14.5, height: 1.75),
                          ),

                          const SizedBox(height: 16),

                          // PARAGRAF 2
                          const Text(
                            "Dan Sekarang POP PROJECT dibangun dengan metode khusus — biar server tetap bisa jalan di Termux, tanpa nuntut VPS yang terus nggak stabil dan ada masalah.",
                            style: TextStyle(color: _textSub, fontSize: 14.5, height: 1.75),
                          ),

                          const SizedBox(height: 18),

                          // KOTAK INFO
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _kremDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _text.withOpacity(0.1)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.phone_android_rounded, color: _text.withOpacity(0.6), size: 20),
                              const SizedBox(width: 12),
                              const Expanded(child: Text(
                                "Dulu: proxy VPS — ribet + sia sia.\nSekarang: jalan di Termux / VPS sendiri.\nMeminimalisir Ketidakstabilan.",
                                style: TextStyle(color: _textSub, fontSize: 13.5, height: 1.7),
                              )),
                            ]),
                          ),

                          const SizedBox(height: 18),

                          // PARAGRAF 3
                          const Text(
                            "POP PROJECT bakal terus disempurnakan — menambah fitur dan benefit biar project ini makin nyaman dipake oleh kalian.",
                            style: TextStyle(color: _textSub, fontSize: 14.5, height: 1.75),
                          ),

                          const SizedBox(height: 28),

                          // TANDA TANGAN + AVATAR
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("— Dev POP PROJECT", style: TextStyle(color: _text, fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text("@hann_xd", style: TextStyle(color: _textSub.withOpacity(0.7), fontSize: 13)),
                            ]),
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(colors: [Color(0xFFF0C060), _gold]),
                                boxShadow: [BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 12)],
                              ),
                              child: const Center(
                                child: Text("P", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          // TOMBOL OKE LANJUT
                          GestureDetector(
                            onTap: _lanjut,
                            child: Container(
                              width: double.infinity, height: 56,
                              decoration: BoxDecoration(
                                color: _black,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text("OKE, LANJUT", style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2.5, fontFamily: 'Orbitron')),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // LEWATI
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 12),
            child: GestureDetector(
              onTap: _lanjut,
              child: Text("Lewati catatan", style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }
}

// CLIPPER BERGELOMBANG KIRI KANAN
class _WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const waveW = 10.0;
    const waveH = 8.0;
    const steps = 20;

    // ATAS - lurus
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    // KANAN - bergelombang turun
    for (int i = 0; i < steps; i++) {
      final y1 = (size.height / steps) * i;
      final y2 = (size.height / steps) * (i + 1);
      final mid = (y1 + y2) / 2;
      final offset = (i % 2 == 0) ? waveW : -waveW * 0.5;
      path.quadraticBezierTo(size.width + offset, mid, size.width, y2);
    }

    // BAWAH - lurus
    path.lineTo(0, size.height);

    // KIRI - bergelombang naik
    for (int i = steps; i > 0; i--) {
      final y1 = (size.height / steps) * i;
      final y2 = (size.height / steps) * (i - 1);
      final mid = (y1 + y2) / 2;
      final offset = (i % 2 == 0) ? -waveW : waveW * 0.5;
      path.quadraticBezierTo(offset, mid, 0, y2);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WavyClipper old) => false;
}
