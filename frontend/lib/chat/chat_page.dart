
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/app_bar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  final String apiBaseUrl;
  final String accessToken;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<List<ChatConversation>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _loadConversations();
  }

  Future<List<ChatConversation>> _loadConversations() async {
    final response = await http.get(
      Uri.parse('${widget.apiBaseUrl}/chat/conversations'),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Could not load conversations');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Unexpected conversations response');
    }

    final conversations = decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList();

    conversations.sort((a, b) {
      final aTime = DateTime.tryParse(a.lastMessageAt ?? '');
      final bTime = DateTime.tryParse(b.lastMessageAt ?? '');

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  Future<void> _refresh() async {
    final future = _loadConversations();

    setState(() {
      _conversations = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the error state.
    }
  }

  Future<void> _openConversation(
    ChatConversation conversation,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: widget.accessToken,
          conversation: conversation,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _conversations = _loadConversations();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Chat'),
      body: FutureBuilder<List<ChatConversation>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ChatMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load conversations',
              message: 'Check your connection and try again.',
              action: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _conversations = _loadConversations();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const _ChatMessage(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'Your conversations with matched students '
                  'will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 84),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final unread = conversation.unreadCount > 0;

                return Material(
                  color: unread
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35)
                      : Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      child: Text(
                        _initials(conversation.studentName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      conversation.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        conversation.lastMessage.isEmpty
                            ? 'No messages yet'
                            : conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: unread
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                    ),
                    trailing: SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(conversation.lastMessageAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall,
                          ),
                          if (unread) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    onTap: () => _openConversation(conversation),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.studentName,
    required this.lastMessage,
    required this.unreadCount,
    this.lastMessageAt,
  });

  final String id;
  final String studentName;
  final String lastMessage;
  final String? lastMessageAt;
  final int unreadCount;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageAt: json['last_message_at']?.toString(),
      unreadCount:
          int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String senderName;
  final String content;
  final DateTime? createdAt;
  final bool isMine;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Student',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ),
      isMine: json['is_mine'] == true,
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.conversation,
  });

  final String apiBaseUrl;
  final String accessToken;
  final ChatConversation conversation;

  @override
  State<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  List<ChatMessage> _messages = [];

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  Timer? _messagePollingTimer;

  bool _isLoadingMessages = true;
  bool _hasMessageError = false;
  bool _isRefreshingMessages = false;
  bool _isSending = false;

  String? _sendError;

  @override
  void initState() {
    super.initState();

    _loadInitialMessages();

    // Poll for incoming messages without recreating the message list.
    _messagePollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshMessages(),
    );
  }

  @override
  void dispose() {
    _messagePollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markConversationRead() async {
    final response = await http.post(
      Uri.parse(
        '${widget.apiBaseUrl}/chat/conversations/'
        '${Uri.encodeComponent(widget.conversation.id)}/read',
      ),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Could not mark conversation as read');
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      await _markConversationRead();
      final messages = await _fetchMessages();

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
        _hasMessageError = false;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMessages = false;
        _hasMessageError = true;
      });
    }
  }

  Future<List<ChatMessage>> _fetchMessages() async {
    final response = await http.get(
      Uri.parse(
        '${widget.apiBaseUrl}/chat/conversations/'
        '${Uri.encodeComponent(widget.conversation.id)}/messages',
      ),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Could not load messages');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Unexpected messages response');
    }

    final messages = decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();

    messages.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return -1;
      if (b.createdAt == null) return 1;

      final comparison = a.createdAt!.compareTo(b.createdAt!);
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });

    return messages;
  }

  bool _messagesChanged(List<ChatMessage> incoming) {
    if (incoming.length != _messages.length) return true;

    for (var i = 0; i < incoming.length; i++) {
      final oldMessage = _messages[i];
      final newMessage = incoming[i];

      if (oldMessage.id != newMessage.id ||
          oldMessage.content != newMessage.content ||
          oldMessage.isMine != newMessage.isMine ||
          oldMessage.senderName != newMessage.senderName ||
          oldMessage.createdAt != newMessage.createdAt) {
        return true;
      }
    }

    return false;
  }

  Future<void> _refreshMessages() async {
    if (!mounted || _isSending || _isRefreshingMessages) return;

    _isRefreshingMessages = true;

    try {
      final messages = await _fetchMessages();

      if (!mounted) return;

      if (!_messagesChanged(messages)) return;

      // Record whether the user is already near the latest message.
      final wasNearBottom = _scrollController.hasClients &&
          (_scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels <
              100);

      setState(() {
        _messages = messages;
        _hasMessageError = false;
      });

      // Only scroll automatically when the user was near the bottom.
      if (wasNearBottom) {
        _scrollToBottom();
      }
    } catch (_) {
      // Keep current messages visible if polling fails.
    } finally {
      _isRefreshingMessages = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '${widget.apiBaseUrl}/chat/conversations/'
          '${Uri.encodeComponent(widget.conversation.id)}/messages',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception('Could not send message');
      }

      _messageController.clear();

      // Fetch immediately so the sent message appears without waiting
      // for the next polling interval.
      await _refreshMessages();

      // If polling was skipped because sending was still in progress,
      // fetch and update the messages now.
      final messages = await _fetchMessages();

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _hasMessageError = false;
      });

      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendError = 'Message could not be sent. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: widget.conversation.studentName,
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasMessageError
                    ? _ChatMessage(
                        icon: Icons.error_outline,
                        title: 'Could not load messages',
                        message: 'Please try again.',
                        action: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoadingMessages = true;
                              _hasMessageError = false;
                            });
                            _loadInitialMessages();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'No messages yet. Say hello!',
                            ),
                          )
                        : ListView.builder(
                            key: PageStorageKey(
                              'chat-${widget.conversation.id}',
                            ),
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _MessageBubble(
                                message: _messages[index],
                              );
                            },
                          ),
          ),

          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _sendError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization:
                          TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(24),
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMine = message.isMine;

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMine ? 'You' : message.senderName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 5),
            Text(message.content),
            const SizedBox(height: 5),
            Text(
              _formatTime(message.createdAt?.toIso8601String()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));

  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _formatTime(String? value) {
  if (value == null || value.isEmpty) return '';

  final date = DateTime.tryParse(value);
  if (date == null) return '';

  final local = date.toLocal();
  final now = DateTime.now();

  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  final yesterdayDate = now.subtract(const Duration(days: 1));

  final yesterday = local.year == yesterdayDate.year &&
      local.month == yesterdayDate.month &&
      local.day == yesterdayDate.day;

  String twoDigits(int number) =>
      number.toString().padLeft(2, '0');

  if (sameDay) {
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  if (yesterday) return 'Yesterday';

  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
}