import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// --- Packages info sistem ---
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_info2/system_info2.dart';

// Import halaman lain
import 'nik_check.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'partner_page.dart';
import 'moderator_page.dart';
import 'dev_page.dart';
import 'pemula_page.dart';
import 'control_panel.dart';
import 'global_chat_page.dart';
import 'widgets/custom_popup.dart';

const String baseUrl = "http://127.0.0.1:3143";

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;
  final String? uid;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
    this.uid,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  // --- State Variabel ---
  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, String>> listBug;
  late List<Map<String, String>> listDoos;
  late List<dynamic> newsList;
  late String? uid;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const Placeholder();

  int onlineUsers = 0;
  int activeConnections = 0;

  // --- Pengaturan Online Users (bisa di-set user) ---
  bool _showOnlineCard = true;
  int _refreshIntervalSec = 10;
  Timer? _refreshTimer;

  // --- Variabel Banner/News ---
  late PageController _newsPageController;
  double _currentNewsPage = 0.0;
  Timer? _newsTimer;
  VideoPlayerController? _videoController;
  VideoPlayerController? _bgVideoController;
  bool _bgVideoReady = false;

  // --- TEMA WARNA PREMIUM: HITAM + BIRU TUA ---
  static const Color bgMain         = Color(0xFF030508);
  static const Color bgSurface      = Color(0xFF090C12);
  static const Color bgCard         = Color(0xFF0A0D14);
  static const Color textMain       = Colors.white;
  static const Color textSub        = Color(0xFF90CAF9);
  static const Color accentBlue     = Color(0xFF1E88E5);
  static const Color accentDarkBlue = Color(0xFF0D47A1);
  static const Color borderLight    = Color(0xFF1565C0);
  static const Color borderGlass    = Color(0xFF1A237E);
  // Icon colors premium
  static const Color iconRole    = Color(0xFFFFC107);  // amber
  static const Color iconExpired = Color(0xFFFF7043);  // deep orange
  static const Color iconOnline  = Color(0xFF4CAF50);  // hijau
  static const Color iconDevice  = Color(0xFF42A5F5);  // biru muda
  static const Color iconBattery = Color(0xFF66BB6A);  // hijau muda
  static const Color iconNetwork = Color(0xFF00B4D8);  // cyan
  static const Color iconRam     = Color(0xFF1E88E5);  // biru tua
  static const Color iconStorage = Color(0xFF1565C0);  // biru gelap
  static const Color iconSystem  = Color(0xFF90CAF9);  // biru muda
  static const Color iconSession = Color(0xFF42A5F5);  // biru terang
  static const Color iconConn    = Color(0xFF4CAF50);  // hijau
  static const Color iconTime    = Color(0xFF00B4D8);  // cyan

  // --- Prefs key ---
  static const String PREFS_SHOW_ONLINE = 'showOnlineCard';
  static const String PREFS_REFRESH_INTERVAL = 'refreshInterval';

  // --- Data sistem (baru) ---
  String deviceModel = 'Unknown';
  String ramTotal = '0MB';
  String ramUsed = '0MB';
  String batteryLevel = '0%';
  String batteryStatus = '';
  String storageTotal = '0GB';
  String storageUsed = '0GB';
  String networkType = 'Unknown';
  String networkSignal = '';
  String systemApi = '0';
  String currentTime = '--:--';
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();

    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug.cast<Map<String, String>>();
    listDoos = widget.listDoos.cast<Map<String, String>>();
    newsList = widget.news;
    uid = widget.uid;

    _videoController = VideoPlayerController.asset('assets/videos/bug.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController?.setVolume(1.0);
        _videoController?.setLooping(true);
        _videoController?.play();
      });

    // BG VIDEO DASHBOARD
    _bgVideoController = VideoPlayerController.asset('assets/videos/dasbordbegron.mp4')
      ..initialize().then((_) {
        setState(() => _bgVideoReady = true);
        _bgVideoController?.setVolume(0.0);
        _bgVideoController?.setLooping(true);
        _bgVideoController?.play();
      });

    _initNewsBanner();
    _selectedPage = _buildNewsPage();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _loadPreferences();
    _initAndroidIdAndConnect();
    _loadProfileImage();
    _loadDeviceInfo();       // <-- Ambil data sistem
    _startTimeUpdate();      // <-- Update waktu setiap detik
  }

  // ===================== LOAD PREFERENSI =====================
  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showOnlineCard = prefs.getBool(PREFS_SHOW_ONLINE) ?? true;
      _refreshIntervalSec = prefs.getInt(PREFS_REFRESH_INTERVAL) ?? 10;
    });
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    if (_refreshIntervalSec > 0) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshIntervalSec),
        (_) => _requestStats(),
      );
    }
  }

  void _requestStats() {
    channel.sink.add(jsonEncode({"type": "stats"}));
  }

  // ===================== INFORMASI SISTEM (BARU - DIPERBAIKI) =====================
  Future<void> _loadDeviceInfo() async {
    try {
      // Device & API
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      deviceModel = deviceInfo.model;
      systemApi = deviceInfo.version.sdkInt.toString();

      // RAM (pakai system_info2 -> class SysInfo, method sync bukan async)
      final totalRamBytes = SysInfo.getTotalPhysicalMemory();
      final freeRamBytes = SysInfo.getFreePhysicalMemory();
      final usedRamBytes = totalRamBytes - freeRamBytes;
      ramTotal = _formatBytes(totalRamBytes);
      ramUsed = _formatBytes(usedRamBytes);

      // STORAGE (disk_space_plus itu instance-based, bukan static)
      final diskSpacePlus = DiskSpacePlus();
      final totalStorageMb = (await diskSpacePlus.getTotalDiskSpace) ?? 0;
      final freeStorageMb = (await diskSpacePlus.getFreeDiskSpace) ?? 0;
      final totalStorageBytes = (totalStorageMb * 1024 * 1024).toInt();
      final usedStorageBytes =
          ((totalStorageMb - freeStorageMb) * 1024 * 1024).toInt();
      storageTotal = _formatBytes(totalStorageBytes, unit: 'GB');
      storageUsed = _formatBytes(usedStorageBytes, unit: 'GB');

      // Battery
      final battery = Battery();
      final level = await battery.batteryLevel;
      batteryLevel = '$level%';
      final batteryState = await battery.batteryState;
      switch (batteryState) {
        case BatteryState.charging:
          batteryStatus = 'Charging';
          break;
        case BatteryState.full:
          batteryStatus = 'Full';
          break;
        case BatteryState.discharging:
          batteryStatus = 'Discharging';
          break;
        default:
          batteryStatus = '';
      }

      // Network
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      networkType = _getNetworkType(result);

      // network_info_plus tidak menyediakan signal strength (RSSI) di semua
      // platform, jadi bagian ini dikosongkan saja daripada dipaksakan.
      networkSignal = '';

      setState(() {});
    } catch (e) {
      // Biarkan default
    }
  }

  String _formatBytes(int bytes, {String unit = 'MB'}) {
    if (unit == 'GB') {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(0)}GB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)}MB';
    }
  }

  String _getNetworkType(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      default:
        return 'Unknown';
    }
  }

  void _startTimeUpdate() {
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          currentTime = '$hour:$minute';
        });
      }
    });
  }

  // ===================== WEBSOCKET & SESSION =====================
  void _initNewsBanner() {
    _newsPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9,
    );

    _newsPageController.addListener(() {
      if (_newsPageController.hasClients &&
          _newsPageController.page != null) {
        _currentNewsPage = _newsPageController.page!;
      }
    });

    if (newsList.isNotEmpty) {
      _newsTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_newsPageController.hasClients) {
          int targetIndex = (_currentNewsPage + 1).round() % newsList.length;
          _newsPageController.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:3143'),
    );
    channel.sink.add(
      jsonEncode({
        "type": "validate",
        "key": sessionKey,
        "androidId": androidId,
      }),
    );
    channel.sink.add(jsonEncode({"type": "stats"}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession(
                "Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession(
                "Key is not valid. Please login again.");
          }
        }
      }
      if (data['type'] == 'stats') {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    CustomPopup.show(
      context,
      title: "Session Expired",
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.redAccent,
      confirmText: "OK",
      onConfirm: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      },
    );
  }

  void _showGlobalChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalChatPage(
          sessionKey: sessionKey,
          username: username,
          role: role,
          androidId: androidId,
        ),
      ),
    );
  }

  // ===================== BOTTOM NAV =====================
  void _onBottomNavTapped(int index) {
    if (index == 1) {
      _showWhatsAppMenu();
      return;
    }
    setState(() {
      _bottomNavIndex = index;
      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 2) {
        _selectedPage = InfoPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = ToolsPage(
          sessionKey: sessionKey,
          userRole: role,
          listDoos: listDoos,
        );
      } else if (index == 4) {
        _selectedPage = const ControlPanelPage();
      }
    });
  }

  // ===================== WHATSAPP HUB MENU (NEBULA STYLE) =====================
  void _showWhatsAppMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => _NebulaHubSheet(
        onCrash: () {
          Navigator.pop(ctx);
          setState(() {
            _bottomNavIndex = 1;
            _selectedPage = HomePage(
              username: username,
              password: password,
              listBug: listBug.cast<Map<String, dynamic>>(),
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            );
          });
        },
        onSender: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => BugSenderPage(sessionKey: sessionKey, username: username, role: role),
          ));
        },
        onChat: () {
          Navigator.pop(ctx);
          _showGlobalChat();
        },
        onRat: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ControlPanelPage(),
          ));
        },
        accent: accentBlue,
      ),
    );
  }

  // stub - digantikan _NebulaHubSheet
  Widget _buildWhatsAppOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) => const SizedBox.shrink();

  // ===================== PREMIUM BOTTOM NAV =====================
  Widget _buildPremiumNav() {
    // 5 item: Beranda(0), Menu/WA(1), RAT tengah(2→index4), Tools(3), Tema/Info(4→index2)
    // Mapping: nav index → app index
    // 0=Beranda, 1=Menu(WA), 2=RAT(tengah), 3=Tools, 4=Info
    const navBg   = Color(0xFFFFFFFF);
    const navBlue = Color(0xFF2D6EC7);

    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'Beranda', 'appIdx': 0},
      {'icon': Icons.dashboard_rounded, 'label': 'Menu', 'appIdx': 1},
      null, // tengah - RAT floating
      {'icon': Icons.build_rounded, 'label': 'Tools', 'appIdx': 3},
      {'icon': Icons.info_outline_rounded, 'label': 'Info', 'appIdx': 2},
    ];

    return SizedBox(
      height: 72,
      child: Stack(clipBehavior: Clip.none, children: [
        // BACKGROUND BAR
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(children: [
              // KIRI: Beranda + Menu
              ...navItems.sublist(0, 2).map((item) {
                final appIdx = item!['appIdx'] as int;
                final isActive = _bottomNavIndex == appIdx;
                return Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onBottomNavTapped(appIdx),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(item['icon'] as IconData, color: isActive ? navBlue : Colors.grey.shade400, size: 24),
                    const SizedBox(height: 3),
                    Text(item['label'] as String, style: TextStyle(color: isActive ? navBlue : Colors.grey.shade400, fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ));
              }),
              // TENGAH: space untuk floating button
              const Expanded(child: SizedBox()),
              // KANAN: Tools + Info
              ...navItems.sublist(3).map((item) {
                final appIdx = item!['appIdx'] as int;
                final isActive = _bottomNavIndex == appIdx;
                return Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onBottomNavTapped(appIdx),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(item['icon'] as IconData, color: isActive ? navBlue : Colors.grey.shade400, size: 24),
                    const SizedBox(height: 3),
                    Text(item['label'] as String, style: TextStyle(color: isActive ? navBlue : Colors.grey.shade400, fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ));
              }),
            ]),
          ),
        ),

        // TOMBOL RAT TENGAH - FLOATING
        Positioned(
          top: -8, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => _onBottomNavTapped(4),
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF2D6EC7), Color(0xFF3B82D4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 22),
                      const Text("RAT", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, fontFamily: 'Orbitron', letterSpacing: 0.5)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ===================== SIDEBAR DRAWER =====================
  void _onSidebarTabSelected(int index) {
    setState(() {
      if (index == 1) {
        _selectedPage = SellerPage(keyToken: sessionKey);
      } else if (index == 2) {
        _selectedPage = AdminPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = OwnerPage(sessionKey: sessionKey, username: username);
      } else if (index == 4) {
        _selectedPage = PartnerPage(sessionKey: sessionKey, username: username);
      } else if (index == 5) {
        _selectedPage = ModeratorPage(
          sessionKey: sessionKey,
          username: username,
        );
      }
    });
    Navigator.pop(context);
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: bgMain,
      width: MediaQuery.of(context).size.width * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentBlue.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        username.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: accentBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getRoleColor(role).withOpacity(0.35)),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(role),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: bgMain,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  if (role == "reseller")
                    _buildDrawerMenuItem(
                      icon: Icons.storefront,
                      label: "Seller Page",
                      onTap: () => _onSidebarTabSelected(1),
                    ),
                  if (role == "admin")
                    _buildDrawerMenuItem(
                      icon: Icons.admin_panel_settings,
                      label: "Admin Page",
                      onTap: () => _onSidebarTabSelected(2),
                    ),
                  if (role == "partner")
                    _buildDrawerMenuItem(
                      icon: FontAwesomeIcons.handshake,
                      label: "Partner Page",
                      onTap: () => _onSidebarTabSelected(4),
                    ),
                  if (role == "moderator")
                    _buildDrawerMenuItem(
                      icon: FontAwesomeIcons.userShield,
                      label: "Moderator Page",
                      onTap: () => _onSidebarTabSelected(5),
                    ),
                  if (role == "owner")
                    _buildDrawerMenuItem(
                      icon: Icons.workspace_premium,
                      label: "Owner Page",
                      onTap: () => _onSidebarTabSelected(3),
                    ),
                  if (role == "dev")
                    _buildDrawerMenuItem(
                      icon: Icons.code_rounded,
                      label: "Buat User",
                      badge: "DEV",
                      badgeColor: const Color(0xFFFF6B35),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DevPage(sessionKey: sessionKey)));
                      },
                    ),
                  if (role == "pemula")
                    _buildDrawerMenuItem(
                      icon: Icons.manage_accounts_rounded,
                      label: "Buat User",
                      badge: "PEMULA",
                      badgeColor: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PemulaPage(sessionKey: sessionKey)));
                      },
                    ),
                  _buildDrawerMenuItem(
                    icon: Icons.history_rounded,
                    label: "Riwayat Aktivitas",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiwayatPage(
                            sessionKey: sessionKey,
                            role: role,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.chat_bubble_outline,
                    label: "Chat Global",
                    onTap: () {
                      Navigator.pop(context);
                      _showGlobalChat();
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerMenuItem(
                    icon: Icons.logout,
                    label: "Log Out",
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isLogout
            ? LinearGradient(
                colors: [
                  Colors.redAccent.withOpacity(0.15),
                  Colors.redAccent.withOpacity(0.05),
                ],
              )
            : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout
                ? Colors.redAccent.withOpacity(0.1)
                : (badgeColor?.withOpacity(0.1) ??
                    Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isLogout
                ? Colors.redAccent
                : (badgeColor ?? Colors.white70),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isLogout ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? accentBlue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (badgeColor ?? accentBlue).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? accentBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isLogout
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.white24,
          size: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
      ),
    );
  }

  // ===================== INFO CHIP =====================
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accentBlue, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String r) {
    switch (r.toLowerCase()) {
      case 'owner':
        return const Color(0xFFFFD700);
      case 'dev':
        return const Color(0xFFFF6B35);
      case 'pemula':
        return const Color(0xFF9C27B0);
      case 'admin':
        return accentBlue;
      case 'moderator':
        return const Color(0xFF81C784);
      case 'partner':
        return const Color(0xFFBA68C8);
      case 'reseller':
        return const Color(0xFFFF8A65);
      case 'vip':
        return const Color(0xFFFFB74D);
      default:
        return Colors.white54;
    }
  }

  // ===================== DIALOG SETTING ONLINE =====================
  void _showOnlineSettingsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool localShow = _showOnlineCard;
          int localInterval = _refreshIntervalSec;
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: accentBlue.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.settings_rounded,
                              color: accentBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "ONLINE USERS SETTINGS",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      value: localShow,
                      onChanged: (val) => setStateDialog(() => localShow = val),
                      title: const Text(
                        "Tampilkan Card Online Users",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      activeColor: accentBlue,
                      secondary: Icon(
                        localShow ? Icons.visibility : Icons.visibility_off,
                        color: accentBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          "Interval Refresh (detik)",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accentBlue.withOpacity(0.3)),
                          ),
                          child: DropdownButton<int>(
                            value: localInterval,
                            dropdownColor: const Color(0xFF1C1C1E),
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox(),
                            items: [5, 10, 15, 30, 60]
                                .map((e) => DropdownMenuItem<int>(
                                      value: e,
                                      child: Text("$e detik"),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setStateDialog(() => localInterval = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Batal",
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(PREFS_SHOW_ONLINE, localShow);
                              await prefs.setInt(PREFS_REFRESH_INTERVAL, localInterval);
                              setState(() {
                                _showOnlineCard = localShow;
                                _refreshIntervalSec = localInterval;
                              });
                              _startRefreshTimer();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Simpan",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== DASHBOARD GRID (SESUAI FOTO) =====================
  Widget _buildDashboardGrid() {
    final ramProgress = (() {
      try {
        final used = double.tryParse(ramUsed.replaceAll('MB', '')) ?? 0;
        final total = double.tryParse(ramTotal.replaceAll('MB', '')) ?? 1;
        return (used / total).clamp(0.0, 1.0);
      } catch (_) { return 0.0; }
    })();
    final storProgress = (() {
      try {
        final used = double.tryParse(storageUsed.replaceAll('GB', '')) ?? 0;
        final total = double.tryParse(storageTotal.replaceAll('GB', '')) ?? 1;
        return (used / total).clamp(0.0, 1.0);
      } catch (_) { return 0.0; }
    })();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(
              children: [
                const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text(
                  "DASHBOARD",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: accentBlue, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: accentBlue, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "PERMANENT",
                        style: TextStyle(
                          color: accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // REMAINING TIME BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Remaining Time",
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                Text("PERMANENT",
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // GRID 3 KOLOM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.35,
              children: [
                // ROW 1
                _buildGridCard(
                  icon: Icons.workspace_premium,
                  iconColor: iconRole,
                  label: "ROLE",
                  value: role.toUpperCase(),
                ),
                _buildGridCard(
                  icon: Icons.calendar_month,
                  iconColor: iconExpired,
                  label: "EXPIRED",
                  value: "PERMANENT",
                ),
                _buildGridCard(
                  icon: Icons.people,
                  iconColor: iconOnline,
                  label: "ONLINE",
                  value: "$onlineUsers Users",
                ),
                // ROW 2
                _buildGridCard(
                  icon: Icons.phone_android,
                  iconColor: iconDevice,
                  label: "DEVICE",
                  value: deviceModel,
                  smallText: true,
                ),
                _buildGridCard(
                  icon: Icons.battery_charging_full,
                  iconColor: iconBattery,
                  label: "BATTERY",
                  value: "$batteryLevel${batteryStatus.isNotEmpty ? ' $batteryStatus' : ''}",
                  smallText: true,
                ),
                _buildGridCard(
                  icon: Icons.wifi,
                  iconColor: iconNetwork,
                  label: "NETWORK",
                  value: networkType,
                  smallText: true,
                ),
                // ROW 3 - RAM & STORAGE punya progress bar
                _buildGridCard(
                  icon: Icons.memory,
                  iconColor: iconRam,
                  label: "RAM",
                  value: "$ramUsed / $ramTotal",
                  progress: ramProgress,
                  progressColor: iconRam,
                  smallText: true,
                ),
                _buildGridCard(
                  icon: Icons.storage,
                  iconColor: iconStorage,
                  label: "STORAGE",
                  value: "$storageUsed / $storageTotal",
                  progress: storProgress,
                  progressColor: iconStorage,
                  smallText: true,
                ),
                _buildGridCard(
                  icon: Icons.computer,
                  iconColor: iconSystem,
                  label: "SYSTEM",
                  value: "APi $systemApi",
                ),
                // ROW 4
                _buildGridCard(
                  icon: Icons.vpn_key,
                  iconColor: iconSession,
                  label: "SESSION",
                  value: sessionKey.length >= 8 ? sessionKey.substring(0, 8).toUpperCase() : sessionKey.toUpperCase(),
                ),
                _buildGridCard(
                  icon: Icons.hub,
                  iconColor: iconConn,
                  label: "CONN",
                  value: "$activeConnections Active",
                ),
                _buildGridCard(
                  icon: Icons.access_time_rounded,
                  iconColor: iconTime,
                  label: "TIME",
                  value: currentTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    double? progress,
    Color? progressColor,
    bool smallText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: smallText ? 11 : 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? iconColor),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== BUILD INFO ITEM (UNTUK CARD SISTEM) =====================
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: accentBlue, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== NEWS PAGE (HALAMAN UTAMA) =====================
  Widget _buildNewsPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          // ─── INFO PANEL DENGAN VIDEO BACKGROUND ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0.9, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: accentBlue.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_videoController != null &&
                              _videoController!.value.isInitialized)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          else
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.black.withOpacity(0.3),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: accentBlue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: accentBlue.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        "WELCOME",
                                        style: TextStyle(
                                          color: accentBlue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.0,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedContainer(
                                            duration:
                                                const Duration(seconds: 1),
                                            curve: Curves.easeInOut,
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Online",
                                            style: TextStyle(
                                              color: Colors.green.shade300,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Welcome Back,",
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontFamily: 'ShareTechMono',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                username.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Orbitron',
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration:
                                                    const BoxDecoration(
                                                  color: accentBlue,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildInfoChip(
                                            icon: Icons.shield,
                                            label: "ROLE",
                                            value: role.toUpperCase(),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 30,
                                            color: Colors.white
                                                .withOpacity(0.1),
                                          ),
                                          _buildInfoChip(
                                            icon: Icons.timer,
                                            label: "EXPIRES",
                                            value: expiredDate,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── DASHBOARD INFO GRID (SESUAI FOTO) ───
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildDashboardGrid(),
          ),

          // Online users sudah masuk dalam grid dashboard

          const SizedBox(height: 28),

          // ─── COMMUNITY HUB ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF121212)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentBlue.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentBlue.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.telegram,
                          color: accentBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          "COMMUNITY HUB",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Orbitron',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Stay connected with the POP PROJECT community. Get real-time updates, access exclusive payloads, and participate in discussions with other members.",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [accentBlue, accentDarkBlue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        FontAwesomeIcons.telegram,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: const Text(
                        "Join Telegram Channel",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _openUrl("https://t.me/popcomity"),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2D)],
                      ),
                      border: Border.all(
                        color: accentBlue.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: accentBlue,
                        size: 22,
                      ),
                      label: const Text(
                        "Global Chat",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _showGlobalChat,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ─── NEWS SECTION ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.newspaper,
                    color: accentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "LATEST UPDATES",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Text(
              "Keep yourself informed about recent system maintenance, newly added tools, and important announcements from the administration.",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _newsPageController,
                  itemCount: newsList.length,
                  itemBuilder: (context, index) {
                    final item = newsList[index];
                    return TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 400),
                      tween: Tween<double>(begin: 0.9, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: bgCard,
                              border: Border.all(
                                color: accentBlue.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (item['image'] != null &&
                                      item['image'].toString().isNotEmpty)
                                    NewsMedia(url: item['image'])
                                  else
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF1A1A1A),
                                            Color(0xFF0A0A0A),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.newspaper,
                                          color: Colors.white24,
                                          size: 60,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 28,
                                    left: 20,
                                    right: 16,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accentBlue.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "NEWS",
                                            style: TextStyle(
                                              color: accentBlue,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.0,
                                              fontFamily: 'Orbitron',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item['title'] ?? 'No Title',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['desc'] ?? '',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _newsPageController,
                    builder: (context, child) {
                      double currentPage = 0.0;
                      if (_newsPageController.hasClients &&
                          _newsPageController.page != null) {
                        currentPage = _newsPageController.page!;
                      } else {
                        currentPage = _currentNewsPage;
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(newsList.length, (index) {
                          double diff = (index - currentPage).abs();
                          double width = 6.0;
                          double opacity = 0.3;
                          if (diff < 1) {
                            width = 24.0 - (diff * 18.0);
                            opacity = 1.0 - (diff * 0.7);
                          }
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: width,
                            height: 4,
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ===================== DIALOG CREATE USER =====================
  void _showCreateUserDialog({required bool canCreatePemula}) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final expiredCtrl = TextEditingController();
    String selectedCreateRole = "member";

    final List<Map<String, dynamic>> devRoles = [
      {"value": "owner", "label": "Owner", "color": const Color(0xFFFFD700)},
      {"value": "admin", "label": "Admin", "color": accentBlue},
      {"value": "moderator", "label": "Moderator", "color": const Color(0xFF81C784)},
      {"value": "reseller", "label": "Reseller", "color": const Color(0xFFFF8A65)},
      {"value": "partner", "label": "Partner", "color": const Color(0xFFBA68C8)},
      {"value": "vip", "label": "VIP", "color": const Color(0xFFFFB74D)},
      {"value": "member", "label": "Member", "color": Colors.white54},
    ];

    final List<Map<String, dynamic>> pemulaRoles = [
      {"value": "dev", "label": "Dev", "color": const Color(0xFFFF6B35)},
      ...devRoles,
    ];

    final availableRoles = canCreatePemula ? pemulaRoles : devRoles;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accentBlue.withOpacity(0.2)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_rounded,
                              color: accentBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "BUAT USER BARU",
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              canCreatePemula ? "Akses: PEMULA" : "Akses: DEV",
                              style: TextStyle(
                                color: canCreatePemula
                                    ? const Color(0xFF9C27B0)
                                    : const Color(0xFFFF6B35),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDialogField(
                        usernameCtrl, "Username", Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildDialogField(passwordCtrl, "Password", Icons.lock_outline,
                        isPassword: true),
                    const SizedBox(height: 12),
                    _buildDialogField(expiredCtrl, "Expired (e.g. 30d)",
                        Icons.timer_outlined),
                    const SizedBox(height: 16),
                    const Text(
                      "PILIH ROLE",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentBlue.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCreateRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1C1C1E),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white54),
                          items: availableRoles
                              .map((r) => DropdownMenuItem<String>(
                                    value: r['value'] as String,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: r['color'] as Color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(r['label'] as String),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => selectedCreateRole = v ?? 'member'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Batal",
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final uname = usernameCtrl.text.trim();
                              final pass = passwordCtrl.text.trim();
                              final exp = expiredCtrl.text.trim();
                              if (uname.isEmpty || pass.isEmpty || exp.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Isi semua field!")),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              try {
                                final days = int.tryParse(
                                    RegExp(r"\d+").firstMatch(exp)?.group(0) ?? "",
                                  ) ?? 0;
                                  if (days <= 0) {
                                    if (mounted) {
                                      CustomPopup.show(
                                        context,
                                        title: "❌ Gagal",
                                        message: "Expired harus berupa jumlah hari, contoh 30d.",
                                      );
                                    }
                                    return;
                                  }
                                  final uri = Uri.parse("$baseUrl/userAdd").replace(
                                    queryParameters: {
                                      "key": sessionKey,
                                      "username": uname,
                                      "password": pass,
                                      "day": days.toString(),
                                      "role": selectedCreateRole,
                                    },
                                  );
                                  final res = await http.get(uri);
                                final data = jsonDecode(res.body);
                                if (mounted) {
                                  CustomPopup.show(
                                    context,
                                    title: data['valid'] == true
                                        ? "✅ Berhasil"
                                        : "❌ Gagal",
                                    message: data['message'] ??
                                        (data['valid'] == true
                                            ? "User $uname berhasil dibuat!"
                                            : "Gagal membuat user."),
                                    icon: data['valid'] == true
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    iconColor: data['valid'] == true
                                        ? Colors.green
                                        : Colors.redAccent,
                                    confirmText: "OK",
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  CustomPopup.show(
                                    context,
                                    title: "❌ Error",
                                    message: "Gagal koneksi ke server.",
                                    icon: Icons.error_outline,
                                    iconColor: Colors.redAccent,
                                    confirmText: "OK",
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Buat User",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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

  Widget _buildDialogField(
      TextEditingController ctrl, String hint, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(icon, color: accentBlue.withOpacity(0.6), size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentBlue.withOpacity(0.15),
                ),
              ),
              child: const Text(
                "POP",
                style: TextStyle(
                  color: accentBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'Orbitron',
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              "PROJECT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontFamily: 'Orbitron',
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.35),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.headset_mic_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              tooltip: 'Customer Service',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactPage()),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FontAwesomeIcons.userCircle,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              tooltip: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    username: username,
                    password: password,
                    role: role,
                    expiredDate: expiredDate,
                    sessionKey: sessionKey,
                    uid: uid,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(children: [
        // ── VIDEO BACKGROUND ──
        if (_bgVideoReady && _bgVideoController != null)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _bgVideoController!.value.size.width,
                height: _bgVideoController!.value.size.height,
                child: VideoPlayer(_bgVideoController!),
              ),
            ),
          )
        else
          Positioned.fill(child: Container(color: const Color(0xFF030508))),
        // ── DARK OVERLAY supaya konten tetap terbaca ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.40),
                  Colors.black.withOpacity(0.60),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // ── KONTEN UTAMA ──
        Positioned.fill(
          child: SafeArea(
            child: FadeTransition(
              opacity: _animation,
              child: _selectedPage,
            ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildPremiumNav(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _bgVideoController?.dispose();
    _newsTimer?.cancel();
    _refreshTimer?.cancel();
    _timeTimer?.cancel();
    _newsPageController.dispose();
    channel.sink.close(status.goingAway);
    _controller.dispose();
    super.dispose();
  }
}

// ===================== NEBULA HUB SHEET (SYAMRAT STYLE) =====================
class _NebulaHubSheet extends StatefulWidget {
  final VoidCallback onCrash;
  final VoidCallback onSender;
  final VoidCallback onChat;
  final VoidCallback onRat;
  final Color accent;
  const _NebulaHubSheet({required this.onCrash, required this.onSender, required this.onChat, required this.onRat, required this.accent});
  @override
  State<_NebulaHubSheet> createState() => _NebulaHubSheetState();
}

class _NebulaHubSheetState extends State<_NebulaHubSheet> with TickerProviderStateMixin {
  final PageController _pc = PageController(viewportFraction: 0.88);
  int _cur = 0;

  // WARNA SESUAI FOTO SYAMRAT - PUTIH + BIRU
  static const Color _bg     = Color(0xFFF0F4FF);
  static const Color _blue   = Color(0xFF2D6EC7);
  static const Color _blueBri = Color(0xFF3B82D4);
  static const Color _blueCard = Color(0xFFDEEAF8);
  static const Color _text   = Color(0xFF1A2744);

  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      {'icon': Icons.bug_report_rounded, 'label': 'NEBULA BUG', 'sub': 'Hanya Bug', 'desc': 'Gunakan langsung dengan cepat', 'tags': ['Mudah digunakan', 'Function terbaru', 'All work gacor'], 'badge': 'RECOMMENDED', 'onTap': widget.onCrash},
      {'icon': Icons.devices_rounded, 'label': 'MANAGE SENDER', 'sub': 'Multi Device', 'desc': 'Pair device & kelola sesi sender', 'tags': ['Multi device', 'Session aktif', 'Auto reconnect'], 'badge': 'STABLE', 'onTap': widget.onSender},
      {'icon': Icons.chat_bubble_rounded, 'label': 'GLOBAL CHAT', 'sub': 'Real-time', 'desc': 'Chat dengan semua user online', 'tags': ['Real-time', 'All users', 'Encrypted'], 'badge': 'LIVE', 'onTap': widget.onChat},
      {'icon': Icons.wifi_tethering_rounded, 'label': 'RAT CONTROL', 'sub': 'Remote Access', 'desc': 'Kontrol device target dari jarak jauh', 'tags': ['Remote access', 'Multi device', 'Real-time'], 'badge': 'ADVANCED', 'onTap': widget.onRat},
    ];
  }

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  void _next() {
    if (_cur < _items.length - 1) {
      _pc.animateToPage(_cur + 1, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _prev() {
    if (_cur > 0) {
      _pc.animateToPage(_cur - 1, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, -10))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // HANDLE
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        // STATUS CHIP + TITLE ROW
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50))),
                const SizedBox(width: 7),
                const Text("POP PROJECT", style: TextStyle(color: _text, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close_rounded, size: 14, color: _text),
                  SizedBox(width: 4),
                  Text("Tutup", style: TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // TITLE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Pilih Menu", style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 28, height: 1.1)),
            const SizedBox(height: 4),
            Text("${_items.length} menu tersedia", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 18),

        // CARD CAROUSEL
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _cur = i),
            itemCount: _items.length,
            itemBuilder: (_, i) => _buildCard(_items[i], i == _cur),
          ),
        ),
        const SizedBox(height: 12),

        // DOTS
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_items.length, (i) =>
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _cur == i ? 20 : 7, height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _cur == i ? _blue : Colors.grey.shade300,
            ),
          ),
        )),
        const SizedBox(height: 16),

        // SELECTED ITEM INFO ROW
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _blueCard, borderRadius: BorderRadius.circular(12)),
                child: Icon(_items[_cur]['icon'] as IconData, color: _blue, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_items[_cur]['label'] as String, style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 14)),
                Text(_items[_cur]['desc'] as String, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ])),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // TOMBOL LANJUTKAN/KEMBALI + BUKA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            // LANJUTKAN / KEMBALI ROW
            Row(children: [
              if (_cur > 0) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: _prev,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text("KEMBALI", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (_cur < _items.length - 1)
                Expanded(
                  child: GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("LANJUTKAN", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),

            // BUKA MENU (BIRU) 
            GestureDetector(
              onTap: _items[_cur]['onTap'] as VoidCallback,
              child: Container(
                width: double.infinity, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2D6EC7), Color(0xFF3B82D4)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Buka ${(_items[_cur]['label'] as String).split(' ').first}", style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, bool isActive) {
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isActive ? _blue.withOpacity(0.3) : Colors.grey.shade200, width: isActive ? 1.5 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isActive ? 0.08 : 0.03), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // TOP ROW
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: _blueCard, borderRadius: BorderRadius.circular(16)),
                  child: Icon(item['icon'] as IconData, color: _blue, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item['badge'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 18),
              // LARGE CIRCLE DECO (background)
              Stack(children: [
                Positioned(right: -10, top: -40,
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: _blueCard.withOpacity(0.5)))),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['label'] as String, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 22, fontFamily: 'Orbitron', letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(item['sub'] as String, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  const SizedBox(height: 10),
                  Container(width: 30, height: 2, decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 10),
                  Text(item['desc'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 14),
                  // TAGS
                  Wrap(spacing: 8, runSpacing: 6, children: (item['tags'] as List<String>).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_outline, color: Colors.grey.shade500, size: 12),
                      const SizedBox(width: 5),
                      Text(t, style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5)),
                    ]),
                  )).toList()),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


class NewsMedia extends StatelessWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.endsWith(".mp4") ||
        url.endsWith(".webm") ||
        url.endsWith(".mov")) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.grey,
            size: 50,
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1C1C1E),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
