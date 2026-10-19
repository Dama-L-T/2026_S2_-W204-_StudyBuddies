import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../chat/chat_send_receive.dart';
import '../widgets/app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.refreshToken,
  });

  final String apiBaseUrl;
  final String accessToken;
  final String refreshToken;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final ChatApiClient _api;

  bool loginOtpEnabled = false;
  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();

    _api = ChatApiClient(
      apiBaseUrl: widget.apiBaseUrl,
      accessToken: widget.accessToken,
      refreshToken: widget.refreshToken,
      storage: _storage,
    );

    _loadLoginOtpSetting();
  }

  Future<void> _loadLoginOtpSetting() async {
    try {
      final data = await _api.getLoginOtpSetting();

      if (!mounted) return;

      setState(() {
        loginOtpEnabled = data['enabled'] == true;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint('Failed to load OTP setting: $error');
    }
  }

  Future<void> _updateLoginOtpSetting(bool value) async {
    if (isUpdating) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final data = await _api.updateLoginOtpSetting(value);

      if (!mounted) return;

      setState(() {
        loginOtpEnabled = data['enabled'] == true;
        isUpdating = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isUpdating = false;
      });

      debugPrint('Failed to update OTP setting: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: const AppBarWidget(
        title: 'Settings',
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [          
          const Text(
            'Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.block_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Blocked conversations',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'View and unblock students',
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatActionListPage(
                          api: _api,
                          type: ChatActionType.blocked,
                        )
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade800),
                  ListTile(
                    leading: const Icon(
                      Icons.visibility_off_outlined,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Hidden conversations',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'View and restore hidden chats',
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatActionListPage(
                          api: _api,
                          type: ChatActionType.hidden,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Security',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),

                  title: const Text(
                    'Login verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: const Text(
                    'Require a verification code when logging in',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  value: loginOtpEnabled,

                  onChanged: isUpdating
                      ? null
                      : _updateLoginOtpSetting,
                ),
          ),

        ],
      ),
    );
  }
}


enum ChatActionType { blocked, hidden }

class ChatActionListPage extends StatefulWidget {
  final ChatApiClient api;
  final ChatActionType type;

  const ChatActionListPage({
    super.key,
    required this.api,
    required this.type,
  });

  @override
  State<ChatActionListPage> createState() => _ChatActionListPageState();
}

class _ChatActionListPageState extends State<ChatActionListPage> {
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  bool isLoading = true;
  String? error;

  bool get isBlocked => widget.type == ChatActionType.blocked;

  String get title =>
      isBlocked ? 'Blocked conversations' : 'Hidden conversations';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final decoded = isBlocked
          ? await widget.api.getBlockedUsers()
          : await widget.api.getHiddenConversations();

      dynamic list = decoded;

      if (decoded is Map) {
        final keys = isBlocked
            ? ['blocked_users', 'items', 'data']
            : ['hidden_conversations', 'items', 'data'];

        for (final key in keys) {
          if (decoded[key] is List) {
            list = decoded[key];
            break;
          }
        }
      }

      if (list is! List) {
        throw Exception('Invalid response from server.');
      }

      if (!mounted) return;

      final parsedItems = list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        items = parsedItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Chat settings list error: $e');

      if (!mounted) return;

      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _restoreItem(Map<String, dynamic> item) async {
    final id = isBlocked
        ? (item['blocked_user_id'] ?? item['user_id'] ?? item['id'])
        : (item['conversation_id'] ?? item['id']);

    if (id == null || id.toString().isEmpty) {
      _showMessage('Unable to identify this item.');
      return;
    }

    try {
      if (isBlocked) {
        await widget.api.unblockUserById(id.toString());
      } else {
        await widget.api.restoreHiddenConversation(id.toString());
      }

      if (!mounted) return;

      setState(() {
        items.removeWhere((entry) {
          final entryId = isBlocked
              ? (entry['blocked_user_id'] ??
                  entry['user_id'] ??
                  entry['id'])
              : (entry['conversation_id'] ?? entry['id']);

          return entryId?.toString() == id.toString();
        });
      });

      _showMessage(
        isBlocked ? 'Student unblocked.' : 'Conversation restored.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to update: $e');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const AppBarWidget(title: 'Chat settings'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load conversations.',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : items.isEmpty
                  ? Center(
                      child: Text(
                        isBlocked
                            ? 'You have not blocked anyone.'
                            : 'You have no hidden conversations.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];

                        final name = isBlocked
                            ? (item['blocked_user_name'] ??
                                item['user_name'] ??
                                item['name'] ??
                                'Student')
                            : (item['other_user_name'] ??
                                item['student_name'] ??
                                item['name'] ??
                                'Conversation');

                        return Material(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            tileColor: const Color(0xFF1A1A1A),
                            splashColor: Colors.white12,
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(
                                isBlocked ? Icons.block : Icons.visibility_off_outlined,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            title: Text(
                              name.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => _restoreItem(item),
                              child: Text(isBlocked ? 'Unblock' : 'Unhide'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
