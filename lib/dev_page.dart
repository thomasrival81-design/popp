import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'widgets/custom_popup.dart';

const String _baseUrl = "http://127.0.0.1:3143";

class DevPage extends StatefulWidget {
  final String sessionKey;
  const DevPage({super.key, required this.sessionKey});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> with SingleTickerProviderStateMixin {
  // DEV bisa create: owner, admin, moderator, reseller, partner, vip, member
  // DEV TIDAK BISA create: pemula
  final List<String> roleOptions = [
    'owner', 'admin', 'moderator', 'reseller', 'partner', 'vip', 'member'
  ];

  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];
  String selectedFilterRole = 'member';
  int currentPage = 1;
  int itemsPerPage = 25;
  bool isLoading = false;

  String newUserRole = 'member';
  final createUsernameCtrl = TextEditingController();
  final createPasswordCtrl = TextEditingController();
  final createDayCtrl = TextEditingController();
  final deleteCtrl = TextEditingController();
  final editUsernameCtrl = TextEditingController();
  final editDayCtrl = TextEditingController();

  // Warna tema (hitam + biru, SAMA DENGAN BASE)
  static const Color bgMain = Color(0xFF000000);
  static const Color bgCard = Color(0xFF1C1C1E);
  static const Color bgSection = Color(0xFF1A1A1A);
  static const Color accentBlue = Color(0xFF4FC3F7);
  static const Color accentDarkBlue = Color(0xFF0288D1);

  Color _roleColor(String r) {
    switch (r) {
      case 'owner': return const Color(0xFFFFD700);
      case 'admin': return accentBlue;
      case 'moderator': return const Color(0xFF81C784);
      case 'reseller': return const Color(0xFFFF8A65);
      case 'partner': return const Color(0xFFBA68C8);
      case 'vip': return const Color(0xFFFFB74D);
      default: return Colors.white54;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    createUsernameCtrl.dispose();
    createPasswordCtrl.dispose();
    createDayCtrl.dispose();
    deleteCtrl.dispose();
    editUsernameCtrl.dispose();
    editDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/listUsers?key=${widget.sessionKey}'));
      final data = jsonDecode(res.body);
      if (data['valid'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _alert("Info", data['message'] ?? 'Gagal memuat user.');
      }
    } catch (_) {
      _alert("Error", "Gagal terhubung ke server.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList
          .where((u) => u['role'] == selectedFilterRole)
          .toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = start + itemsPerPage;
    return filteredList.sublist(
        start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => filteredList.isEmpty
      ? 1
      : (filteredList.length / itemsPerPage).ceil();

  Future<void> _createUser() async {
    final u = createUsernameCtrl.text.trim();
    final p = createPasswordCtrl.text.trim();
    final d = createDayCtrl.text.trim();
    if (u.isEmpty || p.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/userAdd?key=${widget.sessionKey}&username=$u&password=$p&day=$d&role=$newUserRole'));
      final data = jsonDecode(res.body);
      if (data['created'] == true) {
        _alert("✅ Sukses", "Akun $u berhasil dibuat sebagai ${newUserRole.toUpperCase()}.");
        createUsernameCtrl.clear();
        createPasswordCtrl.clear();
        createDayCtrl.clear();
        setState(() => newUserRole = 'member');
        _fetchUsers();
      } else {
        _alert("❌ Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _alert("❌ Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _editUser() async {
    final u = editUsernameCtrl.text.trim();
    final d = editDayCtrl.text.trim();
    if (u.isEmpty || d.isEmpty) {
      _alert("Peringatan", "Semua field wajib diisi.");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/editUser?key=${widget.sessionKey}&username=$u&addDays=$d'));
      final data = jsonDecode(res.body);
      _alert(
        data['edited'] == true ? "✅ Sukses" : "❌ Gagal",
        data['message'] ?? (data['edited'] == true ? 'Durasi berhasil ditambah.' : 'Gagal edit user.'),
      );
      if (data['edited'] == true) {
        editUsernameCtrl.clear();
        editDayCtrl.clear();
        _fetchUsers();
      }
    } catch (_) {
      _alert("❌ Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _deleteUser() async {
    final u = deleteCtrl.text.trim();
    if (u.isEmpty) {
      _alert("Peringatan", "Masukkan username yang ingin dihapus.");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/deleteUser?key=${widget.sessionKey}&username=$u'));
      final data = jsonDecode(res.body);
      _alert(
        data['deleted'] == true ? "✅ Sukses" : "❌ Gagal",
        data['message'] ?? (data['deleted'] == true ? 'User berhasil dihapus.' : 'Gagal hapus user.'),
      );
      if (data['deleted'] == true) {
        deleteCtrl.clear();
        _fetchUsers();
      }
    } catch (_) {
      _alert("❌ Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _alert(String title, String msg) {
    if (!mounted) return;
    CustomPopup.show(
      context,
      title: title,
      message: msg,
      icon: title.contains("✅") ? Icons.check_circle_outline : Icons.error_outline,
      iconColor: title.contains("✅") ? Colors.green : Colors.redAccent,
      confirmText: "OK",
    );
  }

  // ─── POPUP CREATE ───
  void _showCreatePopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accentBlue.withOpacity(0.25)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(FontAwesomeIcons.userPlus, color: accentBlue, size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Text("BUAT AKUN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Text("ROLE: DEV", style: TextStyle(color: Color(0xFFFF6B35), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 20),
                    _buildField(createUsernameCtrl, "Username", Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildField(createPasswordCtrl, "Password", Icons.lock_outline, isPassword: true),
                    const SizedBox(height: 12),
                    _buildField(createDayCtrl, "Durasi (Hari)", Icons.timer_outlined, type: TextInputType.number),
                    const SizedBox(height: 12),
                    // Role dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgSection,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentBlue.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: newUserRole,
                          isExpanded: true,
                          dropdownColor: bgCard,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          icon: const Icon(Icons.keyboard_arrow_down, color: accentBlue),
                          items: roleOptions.map((r) => DropdownMenuItem(
                            value: r,
                            child: Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _roleColor(r), shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text(r.toUpperCase()),
                            ]),
                          )).toList(),
                          onChanged: (v) => setS(() => newUserRole = v ?? 'member'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: () { Navigator.pop(ctx); _createUser(); },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text("BUAT AKUN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
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

  // ─── POPUP EDIT DURASI ───
  void _showEditPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(FontAwesomeIcons.clock, color: Colors.blue, size: 26),
                ),
                const SizedBox(height: 14),
                const Text("TAMBAH DURASI", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                const SizedBox(height: 20),
                _buildField(editUsernameCtrl, "Username Target", Icons.person_outline),
                const SizedBox(height: 12),
                _buildField(editDayCtrl, "Tambah Hari", Icons.calendar_today_outlined, type: TextInputType.number),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _editUser(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("TAMBAH HARI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── POPUP DELETE ───
  void _showDeletePopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(FontAwesomeIcons.userSlash, color: Colors.redAccent, size: 26),
                ),
                const SizedBox(height: 14),
                const Text("HAPUS AKUN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                const SizedBox(height: 20),
                _buildField(deleteCtrl, "Username Target", Icons.person_outline),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _deleteUser(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("HAPUS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon,
      {bool isPassword = false, TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: bgSection,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(icon, color: accentBlue.withOpacity(0.6), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.06), Colors.transparent],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Orbitron')),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map user) {
    final uRole = user['role'] ?? 'member';
    final roleColor = _roleColor(uRole);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.person_outline, color: roleColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(uRole.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Text("EXP: ${user['expiredDate'] ?? '-'}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontFamily: 'ShareTechMono')),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () {
              deleteCtrl.text = user['username'] ?? '';
              _showDeletePopup();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 8, runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(totalPages, (i) {
        final p = i + 1;
        final sel = currentPage == p;
        return GestureDetector(
          onTap: () => setState(() => currentPage = p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? accentBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? accentBlue : Colors.white.withOpacity(0.15)),
            ),
            child: Text("$p", style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: SafeArea(
        child: isLoading && fullUserList.isEmpty
            ? const Center(child: CircularProgressIndicator(color: accentBlue))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── HEADER ───
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF6B35).withOpacity(0.08), Colors.transparent],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.code_rounded, color: Color(0xFFFF6B35), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("DEV PANEL", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Orbitron')),
                              Text("User Management", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontFamily: 'ShareTechMono')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── INFO BADGE ───
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFFF6B35), size: 16),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Role DEV dapat membuat akun: Owner, Admin, Moderator, Reseller, Partner, VIP, Member. Tidak bisa membuat role Pemula.",
                              style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── 3 ACTION CARDS ───
                    _buildActionCard(icon: FontAwesomeIcons.userPlus, color: accentBlue, title: "BUAT AKUN", subtitle: "Tambah user baru", onTap: _showCreatePopup),
                    const SizedBox(height: 12),
                    _buildActionCard(icon: FontAwesomeIcons.clock, color: Colors.blue, title: "TAMBAH DURASI", subtitle: "Extend expired user", onTap: _showEditPopup),
                    const SizedBox(height: 12),
                    _buildActionCard(icon: FontAwesomeIcons.userSlash, color: Colors.redAccent, title: "HAPUS AKUN", subtitle: "Delete user dari sistem", onTap: _showDeletePopup),
                    const SizedBox(height: 28),

                    // ─── USER LIST ───
                    const Text("USER DIRECTORY", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1.0)),
                    const SizedBox(height: 14),

                    // Filter role dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentBlue.withOpacity(0.25)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFilterRole,
                          isExpanded: true,
                          dropdownColor: bgCard,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          icon: const Icon(Icons.keyboard_arrow_down, color: accentBlue),
                          items: roleOptions.map((r) => DropdownMenuItem(
                            value: r,
                            child: Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _roleColor(r), shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text(r.toUpperCase()),
                            ]),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() { selectedFilterRole = v; _filterAndPaginate(); });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isLoading && fullUserList.isNotEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: accentBlue))),

                    if (filteredList.isEmpty && !isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(children: [
                            const Icon(Icons.people_outline, color: Colors.white24, size: 50),
                            const SizedBox(height: 10),
                            Text("Belum ada user dengan role ${selectedFilterRole.toUpperCase()}", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                          ]),
                        ),
                      ),

                    ..._getCurrentPageData().map((u) => _buildUserItem(u as Map)).toList(),
                    const SizedBox(height: 16),
                    Center(child: _buildPagination()),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
