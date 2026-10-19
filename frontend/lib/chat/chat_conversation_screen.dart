import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_send_receive.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatApiClient api;
  final Map<String, dynamic> conversation;

  const ChatConversationScreen({
    super.key,
    required this.api,
    required this.conversation,
  });

  @override
  State<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

 Timer? _pollTimer;
  Timer? _presenceTimer;

  bool _isOnline = false;
  String _availabilityStatus = 'available';
  String? _lastSeenAt;
  bool _isFetchingPresence = false; 
  List<Map<String, dynamic>> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;
  bool _isFetchingMessages = false;
  bool _isBlockedByMe = false;
  bool _hasBlockedMe = false;
  bool _isLoadingBlockStatus = true;
  bool _isFetchingBlockStatus = false;

  // Invalidates older requests after a message is edited or deleted.
  int _messageRequestId = 0;

  String get _conversationId =>
      widget.conversation['id']?.toString() ?? '';

  String get _studentName =>
      (widget.conversation['student_name'] ??
              widget.conversation['other_user_name'] ??
              widget.conversation['name'] ??
              'Student')
          .toString();

  @override
  void initState() {
    super.initState();

    _isOnline = widget.conversation['is_online'] == true;
    _lastSeenAt = widget.conversation['last_seen_at']?.toString();
    _availabilityStatus =
        (widget.conversation['availability_status'] ?? 'available')
            .toString()
            .toLowerCase();

    _loadMessages();
    _loadBlockStatus();
    _loadPresence();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _loadMessages(silent: true);
        _loadBlockStatus();
      },
    );

    _presenceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadPresence(),
    );
  }

  Future<void> _loadBlockStatus() async {
    if (_conversationId.isEmpty || _isFetchingBlockStatus) return;

    _isFetchingBlockStatus = true;
    try {
      final status = await widget.api.getBlockStatus(_conversationId);
      if (!mounted) return;

      setState(() {
        _isBlockedByMe = status['is_blocked_by_me'] == true;
        _hasBlockedMe = status['has_blocked_me'] == true;
        _isLoadingBlockStatus = false;
      });
    } catch (e) {
      debugPrint('Failed to load block status: $e');
      if (mounted) {
        setState(() => _isLoadingBlockStatus = false);
      }
    } finally {
      _isFetchingBlockStatus = false;
    }
  }

  Future<void> _confirmBlockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this student?'),
        content: Text(
          'You will no longer be able to exchange messages with $_studentName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.api.blockUser(_conversationId);
      await _loadBlockStatus();
      if (!mounted) return;
      _showSnackBar('Student blocked.');
    } catch (e) {
      if (mounted) _showSnackBar('Unable to block student: $e');
    }
  }

  Future<void> _unblockUser() async {
    try {
      await widget.api.unblockUser(_conversationId);
      await _loadBlockStatus();
      if (!mounted) return;
      _showSnackBar('Student unblocked.');
    } catch (e) {
      if (mounted) _showSnackBar('Unable to unblock student: $e');
    }
  }

  Future<void> _confirmHideConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide conversation?'),
        content: const Text(
          'This conversation will disappear from your chat list. '
          'The other student can still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.api.hideConversation(_conversationId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnackBar('Unable to hide conversation: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_conversationId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    if (_isFetchingMessages) return;

    _isFetchingMessages = true;
    final requestId = ++_messageRequestId;

    try {
      if (!silent && mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }

      final fetchedMessages = await widget.api.getMessages(_conversationId);

      if (!mounted || requestId != _messageRequestId) return;

      final oldCount = _messages.length;
      final changed = _messagesChanged(_messages, fetchedMessages);

      if (changed) {
        setState(() {
          _messages = fetchedMessages;
          _isLoading = false;
          _hasError = false;
        });

        if (fetchedMessages.length > oldCount) {
          _scrollToBottom();
        }

        try {
          await widget.api.markConversationRead(_conversationId);
        } catch (e) {
          debugPrint('Failed to mark conversation as read: $e');
        }
      } else if (_isLoading || _hasError) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } on AuthExpiredException {
      if (!mounted || requestId != _messageRequestId) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } catch (e) {
      if (!mounted || requestId != _messageRequestId) return;

      debugPrint('Failed to load messages: $e');

      setState(() {
        _isLoading = false;
        if (_messages.isEmpty) {
          _hasError = true;
        }
      });
    } finally {
      _isFetchingMessages = false;
    }
  }

  bool _messagesChanged(
    List<Map<String, dynamic>> oldMessages,
    List<Map<String, dynamic>> newMessages,
  ) {
    if (oldMessages.length != newMessages.length) {
      return true;
    }

    for (int i = 0; i < oldMessages.length; i++) {
      final oldMessage = oldMessages[i];
      final newMessage = newMessages[i];

      if (oldMessage['id']?.toString() != newMessage['id']?.toString() ||
          oldMessage['content'] != newMessage['content'] ||
          oldMessage['created_at'] != newMessage['created_at'] ||
          oldMessage['read_at'] != newMessage['read_at'] ||
          oldMessage['is_reported_by_me'] !=
              newMessage['is_reported_by_me']) {
        return true;
      }
    }

    return false;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _isSending || _isBlockedByMe || _hasBlockedMe) return;

    setState(() => _isSending = true);

    try {
      await widget.api.sendMessage(_conversationId, content);

      if (!mounted) return;

      _messageController.clear();

      // If polling is already in progress, the next poll will retrieve
      // the new message.
      await _loadMessages();
      _scrollToBottom();
    } on AuthExpiredException {
      if (!mounted) return;

      _showSnackBar('Your session has expired. Please log in again.');
    } catch (error) {
      if (!mounted) return;

      _showSnackBar('Unable to send message: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    final controller = TextEditingController(
      text: message['content']?.toString() ?? '',
    );

    try {
      final updatedContent = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit message'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 5000,
              decoration: const InputDecoration(
                hintText: 'Enter your message',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final content = controller.text.trim();
                  if (content.isEmpty) return;
                  Navigator.pop(dialogContext, content);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || updatedContent == null) return;

      if (updatedContent.trim() ==
          message['content']?.toString().trim()) {
        return;
      }

      await widget.api.editMessage(
        _conversationId,
        messageId,
        updatedContent,
      );

      if (!mounted) return;

      // Invalidate any request that started before the edit.
      _messageRequestId++;

      // Update the message immediately without reloading the whole list.
      setState(() {
        _messages = _messages.map((item) {
          if (item['id']?.toString() == messageId) {
            return {
              ...item,
              'content': updatedContent,
            };
          }
          return item;
        }).toList();
      });
    } on AuthExpiredException {
      if (!mounted) return;
      _showSnackBar('Your session has expired. Please log in again.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to edit message: $e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDeleteMessage(
    Map<String, dynamic> message,
  ) async {
    final messageId = message['id']?.toString();

    if (messageId == null || messageId.isEmpty) {
      _showSnackBar('Unable to delete this message.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'Are you sure you want to delete this message? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.api.deleteMessage(
        _conversationId,
        messageId,
      );

      if (!mounted) return;

      // Invalidate older requests so deleted messages cannot reappear
      // because of a response that started before the deletion.
      _messageRequestId++;

      // Remove the message immediately instead of waiting for a reload.
      setState(() {
        _messages.removeWhere(
          (item) => item['id']?.toString() == messageId,
        );
      });

      // A running request is allowed to finish. The next poll will
      // retrieve the latest server state.
      _loadMessages(silent: true);
    } on AuthExpiredException {
      if (!mounted) return;
      _showSnackBar('Your session has expired. Please log in again.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to delete message: $error');
    }
  }

  bool _isReported(Map<String, dynamic> message) {
    return message['is_reported_by_me'] == true;
  }

  Future<void> _reportMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    const reasons = [
      'Harassment or bullying',
      'Hate or abusive content',
      'Sexual or inappropriate content',
      'Threats or violence',
      'Spam or scam',
      'Other',
    ];

    String selectedReason = reasons.first;
    final detailsController = TextEditingController();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Report message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this message?'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  isExpanded: true,
                  items: reasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedReason = value);
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Provide more information',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final details = detailsController.text.trim();
                  final reason = selectedReason == 'Other'
                      ? details
                      : details.isEmpty
                          ? selectedReason
                          : '$selectedReason: $details';

                  if (reason.trim().isEmpty) return;
                  Navigator.pop(dialogContext, reason);
                },
                child: const Text('Submit report'),
              ),
            ],
          ),
        ),
      );

      if (!mounted || reason == null) return;

      await widget.api.reportMessage(
        _conversationId,
        messageId,
        reason,
      );

      _messageRequestId++; // Ignore older in-flight message requests.

      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere(
          (m) => m['id'].toString() == messageId,
        );

        if (index != -1) {
          _messages[index]['is_reported_by_me'] = true;
        }
      });

      _showSnackBar('Message reported successfully.');
    } on AuthExpiredException {
      if (mounted) {
        _showSnackBar('Your session has expired. Please log in again.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to report message: $e');
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _unreportMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    try {
      await widget.api.unreportMessage(_conversationId, messageId);

      _messageRequestId++; // Ignore older in-flight message requests.

      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere(
          (m) => m['id'].toString() == messageId,
        );

        if (index != -1) {
          _messages[index]['is_reported_by_me'] = false;
        }
      });

      _showSnackBar('Report removed successfully.');
    } on AuthExpiredException {
      if (mounted) {
        _showSnackBar('Your session has expired. Please log in again.');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to remove report: $e');
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMine = _isMine(message);
    final isReported = _isReported(message);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              if (isMine) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit message'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Delete message',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeleteMessage(message);
                  },
                ),
              ] else
                ListTile(
                  leading: Icon(
                    isReported
                        ? Icons.flag
                        : Icons.flag_outlined,
                    color: isReported ? Colors.orange : Colors.grey.shade700,
                  ),
                  title: Text(
                    isReported ? 'Unreport message' : 'Report message',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (isReported) {
                      _unreportMessage(message);
                    } else {
                      _reportMessage(message);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  String _value(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  bool _isMine(Map<String, dynamic> message) {
    final value = message['is_mine'];

    if (value is bool) return value;
    if (value != null) {
      return value.toString().toLowerCase() == 'true';
    }

    return false;
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    _studentName.isNotEmpty
                        ? _studentName[0].toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _availabilityStatus == 'busy'
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
                            color: _isOnline ? Colors.green : Colors.grey,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_availabilityStatus == 'busy')
                    Text(
                      'Busy',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      _isOnline ? 'Online' : _formatLastSeen(_lastSeenAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isOnline ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _confirmBlockUser();
                  break;
                case 'unblock':
                  _unblockUser();
                  break;
                case 'hide':
                  _confirmHideConversation();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_isBlockedByMe)
                const PopupMenuItem(
                  value: 'unblock',
                  child: Text('Unblock student'),
                )
              else if (!_hasBlockedMe)
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block student'),
                ),
              const PopupMenuItem(
                value: 'hide',
                child: Text('Hide conversation'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isLoadingBlockStatus)
            const LinearProgressIndicator(minHeight: 2)
          else if (_isBlockedByMe || _hasBlockedMe)
            _buildBlockedNotice()
          else
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('Unable to load messages.'),
            TextButton(
              onPressed: () => _loadMessages(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No messages yet. Say hello!',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = _isMine(message);
        final content = _value(message['content']);
        final time = _formatTime(message['created_at']);
        final isReported = _isReported(message);
        final sender = isMine
            ? 'You'
            : _value(message['sender_name'], 'Student');

        return Align(
          alignment:
              isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showMessageOptions(message),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMine ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isMine
                                ? Colors.white
                                : Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          content,
                          style: TextStyle(
                            color: isMine ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isReported) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'You reported this message',
                          child: Icon(
                            Icons.flag,
                            size: 16,
                            color: isMine ? Colors.white70 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEAEAEA)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.shade200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedNotice() {
    final blockedByMe = _isBlockedByMe;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEAEAEA)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              color: Colors.grey.shade700,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              blockedByMe
                  ? 'You blocked this user'
                  : 'You cannot message this user because they blocked you',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (blockedByMe) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _unblockUser,
                child: const Text('Unblock'),
              ),
            ],
          ],
        ),
      ),
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

  Future<void> _loadPresence() async {
    if (_conversationId.isEmpty || _isFetchingPresence) return;

    _isFetchingPresence = true;

    try {
      final conversations = await widget.api.getConversations();

      if (!mounted) return;

      final currentConversation = conversations.firstWhere(
        (item) => item['id']?.toString() == _conversationId,
        orElse: () => <String, dynamic>{},
      );

      if (currentConversation.isEmpty) return;

      final isOnline = currentConversation['is_online'] == true;
      final lastSeenAt =
          currentConversation['last_seen_at']?.toString();
      final availabilityStatus =
          (currentConversation['availability_status'] ?? 'available')
              .toString()
              .toLowerCase();

      if (_isOnline != isOnline ||
          _lastSeenAt != lastSeenAt ||
          _availabilityStatus != availabilityStatus) {
        setState(() {
          _isOnline = isOnline;
          _lastSeenAt = lastSeenAt;
          _availabilityStatus = availabilityStatus;
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh presence: $e');
    } finally {
      _isFetchingPresence = false;
    }
  }
}