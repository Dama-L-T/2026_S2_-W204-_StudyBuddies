
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
    await future;
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
                            style: Theme.of(context).textTheme.labelSmall,
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
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
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

class _ChatConversationScreenState
    extends State<ChatConversationScreen> {
  late Future<List<ChatMessage>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _loadMessages();
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

  Future<List<ChatMessage>> _loadMessages() async {
    // Mark incoming messages as read before displaying the chat.
    await _markConversationRead();

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
      return comparison != 0
          ? comparison
          : a.id.compareTo(b.id);
    });

    return messages;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: widget.conversation.studentName,
        showBackButton: true,
      ),
      body: FutureBuilder<List<ChatMessage>>(
        future: _messages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ChatMessage(
              icon: Icons.error_outline,
              title: 'Could not load messages',
              message: 'Please try again.',
              action: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _messages = _loadMessages();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            );
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return const _ChatMessage(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              message: 'Previous messages will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];

              return _MessageBubble(message: message);
            },
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

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
              _formatTime(
                message.createdAt?.toIso8601String(),
              ),
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

  final yesterday = local.year == now.subtract(
    const Duration(days: 1),
  ).year &&
      local.month == now.subtract(
        const Duration(days: 1),
      ).month &&
      local.day == now.subtract(
        const Duration(days: 1),
      ).day;

  String twoDigits(int number) => number.toString().padLeft(2, '0');

  if (sameDay) {
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  if (yesterday) return 'Yesterday';

  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
}
