import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'widgets/custom_popup.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _pulseController;
  late PageController _bugPageController;
  int _selectedBugIndex = 0;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  String _selectedBugMode = "number";
  String _senderMode = "private";
  int _privateSenderCount = 0;
  int _globalSenderCount = 0;
  bool _isSending = false;

  // WARNA SESUAI FOTO
  static const Color _bgLight    = Color(0xFFF0F4FF);
  static const Color _blue       = Color(0xFF1565C0);
  static const Color _blueBri    = Color(0xFF1E88E5);
  static const Color _blueCard   = Color(0xFF1976D2);
  static const Color _blueDark   = Color(0xFF0D47A1);
  static const Color _cardWhite  = Color(0xFFFFFFFF);
  static const Color _cardBlue   = Color(0xFFE3EEFF);
  static const Color _textDark   = Color(0xFF0D1B3E);
  static const Color _gold       = Color(0xFFD4A853);

  bool get _canUseGlobalSender =>
      widget.role == 'owner' || widget.role == 'vip' ||
      widget.role == 'pemula' || widget.role == 'dev';
  bool get _canManageGlobalSender => widget.role == 'pemula';

  List<Map<String, dynamic>> _getFilteredBugs() {
    if (_selectedBugMode == "group") {
      return widget.listBug.where((b) => b['bug_id'].contains('_group')).toList();
    } else {
      return widget.listBug.where((b) => !b['bug_id'].contains('_group')).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _bugPageController = PageController(viewportFraction: 0.72);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    _videoController = VideoPlayerController.asset('assets/videos/bug.mp4')
      ..initialize().then((_) {
        setState(() => _videoReady = true);
        _videoController?.setVolume(1.0);
        _videoController?.setLooping(true);
        _videoController?.play();
      });

    if (widget.listBug.isNotEmpty) {
      final bugs = _getFilteredBugs();
      if (bugs.isNotEmpty) _selectedBugIndex = 0;
    }
    _fetchSenderStats();
  }

  Future<void> _fetchSenderStats() async {
    try {
      final res = await http.get(Uri.parse(
          "http://127.0.0.1:3143/getSenderStats?key=${widget.sessionKey}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          setState(() {
            _privateSenderCount = data['private'] ?? 0;
            _globalSenderCount = data['global'] ?? 0;
          });
        }
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pulseController.dispose();
    _bugPageController.dispose();
    targetController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) =>
      input.contains('chat.whatsapp.com') && input.contains('https://');

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showAlert("Invalid Number", "Gunakan nomor internasional (misal: +62, 1, 44).");
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert("Invalid Link", "Masukkan link group WA yang valid.");
        return;
      }
    }

    final bugs = _getFilteredBugs();
    if (bugs.isEmpty) { _showAlert("Error", "Tidak ada bug tersedia."); return; }
    final selectedBugId = bugs[_selectedBugIndex.clamp(0, bugs.length - 1)]['bug_id'];

    setState(() => _isSending = true);
    final effectiveSenderMode = _canUseGlobalSender ? _senderMode : 'private';

    try {
      final res = await http.get(Uri.parse(
          "http://127.0.0.1:3143/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderMode=$effectiveSenderMode"));
      final data = jsonDecode(res.body);
      if (data["cooldown"] == true) {
        _showAlert("⏳ Cooldown", "Tunggu beberapa saat sebelum mengirim lagi.");
      } else if (data["valid"] == false) {
        _showAlert("❌ Key Invalid", "Sesi Anda tidak valid. Silakan login ulang.");
      } else if (data["sended"] == false) {
        _showAlert("⚠️ Gagal", "Server sedang maintenance.");
      } else {
        _showAlert("✅ Berhasil", "Bug sukses dikirim ke target!");
        targetController.clear();
        _fetchSenderStats();
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan. Coba lagi nanti.");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showAlert(String title, String msg) {
    if (!mounted) return;
    CustomPopup.show(context, title: title, message: msg,
      icon: title.contains("✅") ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: title.contains("✅") ? Colors.green : Colors.redAccent,
      confirmText: "Close");
  }

  void _showTargetTypePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBottomSheet(
        title: "PILIH TARGET",
        children: [
          _sheetOption(Icons.phone_android_rounded, _blue, "BUG NOMOR", "Target individual WA number", () {
            setState(() { _selectedBugMode = "number"; targetController.clear(); _selectedBugIndex = 0; });
            Navigator.pop(context);
          }),
          const SizedBox(height: 12),
          _sheetOption(Icons.group_add, _blue, "BUG GROUP", "Target WA group via link", () {
            setState(() { _selectedBugMode = "group"; targetController.clear(); _selectedBugIndex = 0; });
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  void _showSenderTypePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBottomSheet(
        title: "PILIH SENDER",
        children: [
          _sheetOption(Icons.person_outline, _blue, "PRIVATE SENDER", "$_privateSenderCount sender aktif milik kamu", () {
            setState(() => _senderMode = 'private');
            Navigator.pop(context);
          }),
          const SizedBox(height: 12),
          _sheetOption(Icons.public, Colors.green, "GLOBAL SENDER", "$_globalSenderCount sender global tersedia", () {
            setState(() => _senderMode = 'global');
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  void _showManagePrivateSenderPopup() {
    final phoneCtrl = TextEditingController();
    bool isAdding = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _buildBottomSheet(title: "SENDER PRIVATE", children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _blue.withOpacity(0.3))),
            child: TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: _textDark),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+628xxxxxxxxxx",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.phone_outlined, color: _blue, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: isAdding ? null : () async {
                final phone = phoneCtrl.text.trim();
                if (phone.isEmpty) return;
                setS(() => isAdding = true);
                try {
                  final res = await http.post(Uri.parse("http://127.0.0.1:3143/addSender"), body: {"key": widget.sessionKey, "phone": phone});
                  final data = jsonDecode(res.body);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showAlert(data['valid'] == true ? "✅ Berhasil" : "❌ Gagal", data['message'] ?? "");
                  _fetchSenderStats();
                } catch (_) { if (ctx.mounted) Navigator.pop(ctx); _showAlert("❌ Error", "Gagal koneksi."); }
                setS(() => isAdding = false);
              },
              icon: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(isAdding ? "Menambahkan..." : "Tambah Sender", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      )),
    );
  }

  void _showManageGlobalSenderPopup() {
    final phoneCtrl = TextEditingController();
    bool isAdding = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _buildBottomSheet(title: "SENDER GLOBAL", children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: _textDark),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+628xxxxxxxxxx (Global)",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.public, color: Colors.green, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: isAdding ? null : () async {
                final phone = phoneCtrl.text.trim();
                if (phone.isEmpty) return;
                setS(() => isAdding = true);
                try {
                  final res = await http.post(Uri.parse("http://127.0.0.1:3143/addGlobalSender"), body: {"key": widget.sessionKey, "phone": phone});
                  final data = jsonDecode(res.body);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showAlert(data['valid'] == true ? "✅ Berhasil" : "❌ Gagal", data['message'] ?? "");
                  _fetchSenderStats();
                } catch (_) { if (ctx.mounted) Navigator.pop(ctx); _showAlert("❌ Error", "Gagal koneksi."); }
                setS(() => isAdding = false);
              },
              icon: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(isAdding ? "Menambahkan..." : "Tambah Global Sender", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildBottomSheet({required String title, required List<Widget> children}) {
    return Container(
      decoration: const BoxDecoration(color: _bgLight, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Text(title, style: const TextStyle(color: _textDark, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }

  Widget _sheetOption(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.4), size: 14),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bugs = _getFilteredBugs();
    final selectedBugId = bugs.isNotEmpty ? bugs[_selectedBugIndex.clamp(0, bugs.length - 1)]['bug_id'] : '';

    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(children: [
        // ── HEADER BIRU (SYAM BUG style) ──
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_blueDark, _blue, _blueBri], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_rounded, color: _blue, size: 18),
                  const SizedBox(width: 8),
                  const Text("POP BUG", style: TextStyle(color: _blue, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchSenderStats,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                ),
              ),
            ]),
          )),
        ),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── VIDEO PLAYER (SYAM BUG STYLE) ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_blueDark, _blue, _blueBri], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _videoReady && _videoController != null
                    ? VideoPlayer(_videoController!)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_blueDark.withOpacity(0.8), _blue.withOpacity(0.6)]),
                        ),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 14),
                          const Text("POP BUG", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 2)),
                        ])),
                      ),
                ),
              ),
            ),

            // ── PANEL BIRU (Nomor target + pilih bug) ──
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _blueBri], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // NOMOR TARGET
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    const Text("NOMOR TARGET", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: targetController,
                      style: const TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w600),
                      keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                      decoration: InputDecoration(
                        hintText: _selectedBugMode == "number" ? "62xxxxxxxxxx" : "https://chat.whatsapp.com/...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(_selectedBugMode == "number" ? Icons.language : Icons.link, color: Colors.grey.shade400, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PILIH BUG
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    const Text("PILIH BUG", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.5))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent)),
                        const SizedBox(width: 5),
                        const Text("Engine lokal aktif", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat, color: Colors.white.withOpacity(0.5), size: 12), // <-- FIX: Icons.whatsapp diganti Icons.chat
                        const SizedBox(width: 4),
                        Text("WA belum connect", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // BUG CARDS HORIZONTAL
                  if (bugs.isNotEmpty) ...[
                    SizedBox(
                      height: 140,
                      child: PageView.builder(
                        controller: _bugPageController,
                        onPageChanged: (i) => setState(() => _selectedBugIndex = i),
                        itemCount: bugs.length,
                        itemBuilder: (_, i) {
                          final bug = bugs[i];
                          final isSelected = i == _selectedBugIndex;
                          return AnimatedScale(
                            scale: isSelected ? 1.0 : 0.92,
                            duration: const Duration(milliseconds: 250),
                            child: GestureDetector(
                              onTap: () {
                                _bugPageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                setState(() => _selectedBugIndex = i);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18),
                                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)] : null,
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _cardBlue : Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.shield_rounded, color: isSelected ? _blue : Colors.white, size: 18),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                      ),
                                  ]),
                                  const Spacer(),
                                  Text(
                                    bug['bug_name'] ?? 'Bug',
                                    style: TextStyle(
                                      color: isSelected ? _textDark : Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _blue.withOpacity(0.1) : Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      bug['bug_id'] ?? '',
                                      style: TextStyle(color: isSelected ? _blue : Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // DOT INDICATOR
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ...List.generate(bugs.length.clamp(0, 8), (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _selectedBugIndex ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _selectedBugIndex ? Colors.white : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                      if (bugs.length > 8) ...[
                        const SizedBox(width: 4),
                        Text("...+${bugs.length - 8}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                      ]
                    ]),
                  ] else
                    Center(child: Text("Tidak ada bug tersedia.", style: TextStyle(color: Colors.white.withOpacity(0.6)))),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            // ── TOMBOL TARGET TYPE & SENDER MODE ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                // TARGET TYPE
                _buildSelectRow(
                  icon: Icons.phone_android_rounded,
                  label: "TARGET TYPE",
                  value: _selectedBugMode == "number" ? "BUG NOMOR" : "BUG GROUP",
                  onTap: _showTargetTypePopup,
                ),
                const SizedBox(height: 10),
                if (_canUseGlobalSender) ...[
                  _buildSelectRow(
                    icon: Icons.person_outline,
                    label: "SENDER MODE",
                    value: _senderMode == 'private' ? "PRIVATE SENDER" : "GLOBAL SENDER",
                    onTap: _showSenderTypePopup,
                  ),
                  const SizedBox(height: 10),
                ],
                // KELOLA SENDER PRIVATE
                _buildActionRow(Icons.person_add_outlined, "Kelola Sender Private", _privateSenderCount, _blue, _showManagePrivateSenderPopup),
                if (_canManageGlobalSender) ...[
                  const SizedBox(height: 10),
                  _buildActionRow(Icons.public, "Kelola Sender Global", _globalSenderCount, Colors.green, _showManageGlobalSenderPopup),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ── TOMBOL KIRIM BUG (GOLD) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => GestureDetector(
                  onTap: _isSending ? null : _sendBug,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD4A853),
                          Color.lerp(const Color(0xFFD4A853), const Color(0xFFF0C060), _pulseController.value * 0.5)!,
                          const Color(0xFFBF8A30),
                        ],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: _gold.withOpacity(0.45 * _pulseController.value), blurRadius: 24, offset: const Offset(0, 8)),
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
                      ],
                    ),
                    child: _isSending
                      ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 14),
                          const Text("KIRIM BUG", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2.5)),
                        ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }

  Widget _buildSelectRow({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _blue.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _cardBlue, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _blue, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w800)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: _blue.withOpacity(0.4), size: 14),
        ]),
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Text("$count aktif", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 13),
        ]),
      ),
    );
  }
}