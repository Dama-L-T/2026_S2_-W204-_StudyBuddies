
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

  const ChatPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late final ChatApiClient _api;
  Timer? _pollTimer;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;

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
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
    if (_value(conversation['id']).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid conversation.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          api: _api,
          conversation: conversation,
        ),
      ),
    );

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

        final time = _formatTime(
          conversation['last_message_at'] ??
              conversation['updated_at'],
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
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              isBlocked ? 'Blocked' : lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isBlocked
                    ? Colors.red.shade700
                    : (unread > 0 ? Colors.black87 : Colors.grey.shade600),
                fontWeight: isBlocked || unread > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
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
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          onTap: () => _openConversation(conversation),
        );
      },
    );
  }
}