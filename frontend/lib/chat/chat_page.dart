
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'chat_conversation_screen.dart';
import 'chat_send_receive.dart';
import '../widgets/app_bar.dart';

class ChatPage extends StatefulWidget {
  final String apiBaseUrl;
  final String? accessToken;
  final String? refreshToken;
  final String? initialConversationId;
  final ValueChanged<String?>? onActiveConversationChanged;

  const ChatPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.refreshToken,
    this.initialConversationId,
    this.onActiveConversationChanged,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late final ChatApiClient _api;
  Timer? _pollTimer;
  Timer? _presenceTimer;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasHandledInitialConversation = false;

  @override
  void initState() {
    super.initState();

    _api = ChatApiClient(
      apiBaseUrl: widget.apiBaseUrl,
      accessToken: widget.accessToken,
      refreshToken: widget.refreshToken,
      storage: _storage,
    );

    _loadConversations();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadConversations(silent: true),
    );

    _sendPresenceHeartbeat();

    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendPresenceHeartbeat(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendPresenceHeartbeat() async {
    try {
      await _api.sendPresenceHeartbeat();
    } catch (_) {
      // Presence is optional; don't interrupt the chat screen.
    }
  }

  Future<void> _openInitialConversation(
    List<Map<String, dynamic>> conversations,
  ) async {
    final conversationId = widget.initialConversationId;

    if (_hasHandledInitialConversation ||
        conversationId == null ||
        conversationId.isEmpty) {
      return;
    }

    final conversationIndex = conversations.indexWhere(
      (conversation) =>
          conversation['id']?.toString() == conversationId,
    );

    if (conversationIndex == -1) {
      return;
    }

    _hasHandledInitialConversation = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _openConversation(conversations[conversationIndex]);
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final conversations = await _api.getConversations();

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _hasError = false;
      });

      await _openInitialConversation(conversations);
    } on AuthExpiredException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (_conversations.isEmpty) {
          _hasError = true;
        }
      });
    }
  }

  String _value(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  int _unreadCount(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';

    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    if (date.year == now.year) {
      return '${date.day}/${date.month}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openConversation(
    Map<String, dynamic> conversation,
  ) async {
    final conversationId = _value(conversation['id']);

    if (conversationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid conversation.')),
      );
      return;
    }

    // Tell the bottom navigation bar which conversation is open.
    widget.onActiveConversationChanged?.call(conversationId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          api: _api,
          conversation: conversation,
        ),
      ),
    );

    // Clear the active conversation when returning to the chat list.
    widget.onActiveConversationChanged?.call(null);

    if (mounted) {
      await _loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppBarWidget(title: 'Chat'),
      body: RefreshIndicator(
        onRefresh: () => _loadConversations(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Unable to load conversations.'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loadConversations,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Icon(
            Icons.chat_bubble_outline,
            size: 52,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No conversations yet.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 76,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];

        final name = _value(
          conversation['student_name'] ??
              conversation['other_user_name'] ??
              conversation['name'],
          'Student',
        );

        final lastMessage = _value(
          conversation['last_message'],
          'Start a conversation',
        );

        final unread = _unreadCount(conversation['unread_count']);

        final isBlocked =
            conversation['is_blocked'] == true ||
            conversation['is_blocked_by_me'] == true ||
            conversation['has_blocked_me'] == true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _value(
                          conversation['availability_status'],
                          'available',
                        ).toLowerCase() == 'busy'
                    ? Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.coffee,
                          size: 12,
                          color: Colors.orange.shade800,
                        ),
                      )
                    : Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: conversation['is_online'] == true
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _value(
                        conversation['availability_status'],
                        'available',
                      ).toLowerCase() == 'busy'
                  ? Text(
                      'Busy',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      conversation['is_online'] == true
                          ? 'Online'
                          : _formatLastSeen(conversation['last_seen_at']),
                      style: TextStyle(
                        fontSize: 11,
                        color: conversation['is_online'] == true
                            ? Colors.green
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  isBlocked ? 'Messaging unavailable' : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(conversation['last_message_at']),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: unread > 0
          ? Container(
              constraints: const BoxConstraints(
                minWidth: 21,
                minHeight: 21,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
          onTap: () => _openConversation(conversation),
        );
      },
    );
  }

  String _formatLastSeen(dynamic value) {
    if (value == null) return 'Activity unavailable';

    final lastSeen = DateTime.tryParse(value.toString())?.toLocal();
    if (lastSeen == null) return 'Activity unavailable';

    final difference = DateTime.now().difference(lastSeen);

    if (difference.inSeconds < 0) return 'Last active just now';
    if (difference.inMinutes < 1) return 'Last active just now';
    if (difference.inMinutes < 60) {
      return 'Last active ${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return 'Last active ${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return 'Last active ${difference.inDays}d ago';
    }

    return 'Last active ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }
}