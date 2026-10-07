import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:intl/intl.dart';

const String _wsUrlPrivate = 'ws://127.0.0.1:3143';

// ─── WARNA TEMA ───
const Color _bgMain    = Color(0xFF000000);
const Color _bgCard    = Color(0xFF1C1C1E);
const Color _bgSection = Color(0xFF1A1A1A);
const Color _accent    = Color(0xFF4FC3F7);
const Color _accentDark = Color(0xFF0288D1);

class PrivateChatPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;
  final String androidId;
  final String targetUsername;

  const PrivateChatPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
    required this.androidId,
    required this.targetUsername,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  late WebSocketChannel _channel;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl  = ScrollController();
  final FocusNode _focusNode           = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _connected  = false;
  bool _isLoading  = true;
  bool _targetOnline = false;

  Map<String, dynamic>? _replyTo;

  Color _roleColor(String r) {
    switch (r.toLowerCase()) {
      case 'owner':     return const Color(0xFFFFD700);
      case 'dev':       return const Color(0xFFFF6B35);
      case 'pemula':    return const Color(0xFF9C27B0);
      case 'admin':     return _accent;
      case 'moderator': return const Color(0xFF81C784);
      case 'partner':   return const Color(0xFFBA68C8);
      case 'reseller':  return const Color(0xFFFF8A65);
      case 'vip':       return const Color(0xFFFFB74D);
      default:          return Colors.white.withOpacity(0.54);
    }
  }

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrlPrivate));

      _channel.sink.add(jsonEncode({
        'type': 'auth',
        'key': widget.sessionKey,
        'androidId': widget.androidId,
      }));

      Future.delayed(const Duration(milliseconds: 600), () {
        // Minta history private chat dengan target
        _channel.sink.add(jsonEncode({
          'type': 'getMessages',
          'with': widget.targetUsername,
        }));
        // Cek siapa yang online
        _channel.sink.add(jsonEncode({'type': 'getUserList'}));
      });

      _channel.stream.listen(_onMessage,
          onDone: () => setState(() => _connected = false),
          onError: (_) => setState(() => _connected = false));

      setState(() { _connected = true; _isLoading = false; });
    } catch (_) {
      setState(() { _connected = false; _isLoading = false; });
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String);
      final type = data['type'];

      // History pesan private
      if (type == 'messages') {
        final with_ = data['with'];
        if (with_ == widget.targetUsername) {
          final List msgs = data['messages'] ?? [];
          setState(() {
            _messages = msgs.map((m) => Map<String, dynamic>.from(m as Map)).toList();
          });
          _scrollToBottom();
        }
      }

      // Pesan baru masuk
      if (type == 'chat') {
        final msg = Map<String, dynamic>.from(data['message'] as Map);
        final from = msg['from'] ?? '';
        final to   = msg['to'] ?? '';
        if (from == widget.targetUsername || to == widget.targetUsername) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      }

      // Update status online
      if (type == 'userList') {
        final List users = data['users'] ?? [];
        setState(() => _targetOnline = users.contains(widget.targetUsername));
      }

      if (type == 'userOnline') {
        if (data['username'] == widget.targetUsername) {
          setState(() => _targetOnline = true);
        }
      }

      if (type == 'userOffline') {
        if (data['username'] == widget.targetUsername) {
          setState(() => _targetOnline = false);
        }
      }
    } catch (_) {}
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_connected) return;

    _channel.sink.add(jsonEncode({
      'type': 'chat',
      'to': widget.targetUsername,
      'message': text,
      if (_replyTo != null) 'replyTo': _replyTo!['from'],
      if (_replyTo != null) 'replyMessage': _replyTo!['message'],
    }));

    _msgCtrl.clear();
    setState(() => _replyTo = null);
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(ts).toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _channel.sink.close(ws_status.goingAway);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMain,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
          ),
          if (_replyTo != null) _buildReplyBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── APP BAR ───
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bgCard,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    widget.targetUsername[0].toUpperCase(),
                    style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              // Status online dot
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: _targetOnline ? Colors.greenAccent : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgCard, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.targetUsername.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
              ),
              Text(
                _targetOnline ? '● Online' : '○ Offline',
                style: TextStyle(
                  color: _targetOnline ? Colors.greenAccent : Colors.white.withOpacity(0.38),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  // ─── EMPTY STATE ───
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_outlined, size: 48, color: _accent.withOpacity(0.3)),
          ),
          const SizedBox(height: 16),
          Text('Mulai obrolan dengan\n${widget.targetUsername}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white.withOpacity(0.30), fontSize: 14)),
        ],
      ),
    );
  }

  // ─── BUBBLE CHAT ───
  Widget _buildBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['fromMe'] == true || msg['from'] == widget.username;
    final String from = msg['from'] ?? '';
    final String text = msg['message'] ?? '';
    final String time = _formatTime(msg['time']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(from[0].toUpperCase(),
                    style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.lightImpact();
                setState(() => _replyTo = msg);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? _accent.withOpacity(0.2) : _bgCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isMe ? _accent.withOpacity(0.3) : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply preview
                    if (msg['replyTo'] != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: _accent, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('↩ @${msg['replyTo']}',
                                style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(msg['replyMessage'] ?? '',
                                style: const TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],

                    Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: const TextStyle(color: Colors.white.withOpacity(0.30), fontSize: 9)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all_rounded, color: _accent, size: 12),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ─── REPLY BAR ───
  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSection,
        border: Border(
          top: BorderSide(color: _accent.withOpacity(0.2)),
          left: BorderSide(color: _accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('↩ Balas @${_replyTo!['from'] ?? ''}',
                    style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(_replyTo!['message'] ?? '',
                    style: const TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.38), size: 18),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  // ─── INPUT BAR ───
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: _bgSection,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Pesan ke ${widget.targetUsername}...',
                  hintStyle: const TextStyle(color: Colors.white.withOpacity(0.30)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, _accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
