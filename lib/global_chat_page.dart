import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'main.dart';


class ChatRoomPage extends StatefulWidget {
  final String username;

  const ChatRoomPage({
    super.key,
    required this.username,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final FocusNode focusNode = FocusNode();

  List<Map<String, dynamic>> chats = [];
  bool loading = true;
  bool isSending = false;
  bool showSendButton = false;
  bool showScrollButton = false;
  final GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey<RefreshIndicatorState>();

  final Color primaryColor = const Color(0xFF6366F1);
  final Color secondaryColor = const Color(0xFF1F2937);
  final Color backgroundColor = const Color(0xFF111827);
  final Color bubbleOutgoing = const Color(0xFF6366F1);
  final Color bubbleIncoming = const Color(0xFF374151);
  final Color accentColor = const Color(0xFF8B5CF6);
  final Color textColor = Colors.white;
  final Color subtitleColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _loadChats();
    focusNode.addListener(_onFocusChange);
    scrollCtrl.addListener(_scrollListener);
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChange);
    scrollCtrl.removeListener(_scrollListener);
    focusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final offset = scrollCtrl.offset;
    final maxScroll = scrollCtrl.position.maxScrollExtent;
    
    if (maxScroll - offset > 300 && !showScrollButton) {
      setState(() => showScrollButton = true);
    } else if (maxScroll - offset <= 300 && showScrollButton) {
      setState(() => showScrollButton = false);
    }
  }

  void _onFocusChange() {
    if (focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    }
  }

  Future<void> _loadChats() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:3143/chatroom'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          chats = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      print("Error memuat pesan: $e");
      setState(() => loading = false);
    }
  }

  Future<void> _refreshChats() async {
    await _loadChats();
  }

  Future<void> _sendMessage() async {
    final msg = msgCtrl.text.trim();
    if (msg.isEmpty || isSending) return;

    setState(() {
      isSending = true;
      showSendButton = false;
    });

    final newMessage = {
      "from": widget.username,
      "message": msg,
      "time": DateTime.now().millisecondsSinceEpoch,
      "status": "mengirim",
    };

    msgCtrl.clear();

    setState(() {
      chats.add(newMessage);
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:3143/chatroom'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "from": widget.username,
          "message": msg,
        }),
      );

      if (response.statusCode == 200) {
        final int lastIndex = chats.length - 1;
        setState(() {
          chats[lastIndex]["status"] = "terkirim";
        });
      } else {
        setState(() {
          chats[chats.length - 1]["status"] = "gagal";
        });
      }
    } catch (e) {
      print("Error mengirim: $e");
      setState(() {
        chats[chats.length - 1]["status"] = "gagal";
      });
    } finally {
      setState(() => isSending = false);
    }
  }

  void _scrollToBottom() {
    if (scrollCtrl.hasClients) {
      scrollCtrl.animateTo(
        scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final today = DateTime.now();
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return "Hari Ini";
    } else if (date.year == today.year && date.month == today.month && date.day == today.day - 1) {
      return "Kemarin";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Widget _buildMessageStatus(String status) {
    switch (status) {
      case "mengirim":
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.grey[400]!),
          ),
        );
      case "terkirim":
        return Icon(Icons.check, size: 16, color: Colors.grey[400]);
      case "diterima":
        return Icon(Icons.done_all, size: 16, color: Colors.grey[400]);
      case "dibaca":
        return Icon(Icons.done_all, size: 16, color: primaryColor);
      case "gagal":
        return Icon(Icons.error_outline, size: 16, color: Colors.red[400]);
      default:
        return Icon(Icons.check, size: 16, color: Colors.grey[400]);
    }
  }

  Widget _buildAvatar(String username, {bool isOnline = true}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    color: Colors.black26,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: backgroundColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green[400]!.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> item, bool isMe) {
    final isFirstInSequence = chats.indexOf(item) == 0 || 
        chats[chats.indexOf(item) - 1]['from'] != item['from'];
    
    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInSequence ? 8 : 2,
        left: 12,
        right: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AnimatedOpacity(
              opacity: isFirstInSequence ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildAvatar(item['from']),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstInSequence)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      item['from'],
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? bubbleOutgoing : bubbleIncoming,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['message'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(item['time']),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              _buildMessageStatus(item['status'] ?? 'terkirim'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey[700],
              thickness: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: secondaryColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Text(
                date,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey[700],
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [backgroundColor, secondaryColor.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 28),
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      _buildAvatar("Global"),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Obrolan Global",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${chats.length} pesan • ${chats.map((c) => c['from']).toSet().length} peserta",
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search_rounded, size: 24),
                        color: Colors.white,
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded, size: 24),
                        color: Colors.white,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: loading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(primaryColor),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Memuat percakapan...",
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        key: refreshKey,
                        backgroundColor: backgroundColor,
                        color: primaryColor,
                        onRefresh: _refreshChats,
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: chats.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildDateSeparator("Hari Ini");
                            }
                            final item = chats[index - 1];
                            final isMe = item['from'] == widget.username;
                            
                            if (index > 1) {
                              final prevItem = chats[index - 2];
                              final currentDate = _formatDate(item['time']);
                              final prevDate = _formatDate(prevItem['time']);
                              
                              if (currentDate != prevDate) {
                                return Column(
                                  children: [
                                    _buildDateSeparator(currentDate),
                                    _buildMessageBubble(item, isMe),
                                  ],
                                );
                              }
                            }
                            
                            return _buildMessageBubble(item, isMe);
                          },
                        ),
                      ),
              ),

              if (isSending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleIncoming,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(primaryColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Mengirim...",
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.emoji_emotions_outlined, size: 24),
                        color: Colors.grey[400],
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.attach_file_rounded, size: 24),
                        color: Colors.grey[400],
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: msgCtrl,
                          focusNode: focusNode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          maxLines: null,
                          onChanged: (value) {
                            setState(() {
                              showSendButton = value.trim().isNotEmpty;
                            });
                          },
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: "Ketik pesan...",
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            suffixIcon: showSendButton
                                ? IconButton(
                                    icon: Icon(
                                      Icons.send_rounded,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                    onPressed: _sendMessage,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (!showSendButton) ...[
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.mic_rounded, size: 24),
                          color: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: showScrollButton
            ? FloatingActionButton.small(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward_rounded, size: 20),
              )
            : null,
      ),
    );
  }
}
// ===== ALIAS: GlobalChatPage =====
class GlobalChatPage extends StatelessWidget {
  final String sessionKey;
  final String username;
  final String role;
  final String androidId;

  const GlobalChatPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
    required this.androidId,
  });

  @override
  Widget build(BuildContext context) {
    return ChatRoomPage(username: username);
  }
}
