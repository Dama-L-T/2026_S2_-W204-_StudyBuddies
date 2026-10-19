import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../Schedule/schedule.page.dart';
import '../matchmaking/matchmaking.page.dart';
import '../matchmaking/matchmaking_api.dart';
import '../Settings/settings.page.dart';
import '../profile/profile.dart';
import '../service/notifications_service.dart';
import '../service/reminder_sync_service.dart';
import '../chat/chat_page.dart';
import '../chat/chat_send_receive.dart';

class AppBottomNavigationBar extends StatefulWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.refreshToken,
    this.initialNotificationPayload,
  });

  final String apiBaseUrl;
  final String accessToken;
  final String refreshToken;
  final String? initialNotificationPayload;

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  final _storage = const FlutterSecureStorage();

  int currentIndex = 0;
  int _schedulePageVersion = 0;
  NotificationTarget? _scheduleNotificationTarget;
  String? _pendingChatConversationId;
  String? _activeChatConversationId;
  late String _accessToken;
  late String _refreshToken;
  late ChatApiClient _chatApi;
  Timer? _chatNotificationTimer;
  Timer? _invitationTimer;
  int _invitationCount = 0;
  final Set<String> _knownInvitationIds = {};
  bool _hasInitialisedInvitations = false;
  bool _openInvitationInbox = false;
  int _matchPageVersion = 0;
  bool _checkingInvitations = false;

  final Set<String> _knownChatMessageIds = {};
  bool _hasInitialisedChatTracking = false;
  bool _isCheckingChatNotifications = false;

  @override
  void initState() {
    super.initState();

    _accessToken = widget.accessToken;
    _refreshToken = widget.refreshToken;

    _chatApi = ChatApiClient(
      apiBaseUrl: widget.apiBaseUrl,
      accessToken: _accessToken,
      refreshToken: _refreshToken,
      storage: _storage,
    );

    _applyNotificationPayload(widget.initialNotificationPayload);
    notificationService.onNotificationTapped = _handleNotificationPayload;

    unawaited(_syncReminderNotifications());
    unawaited(_checkChatNotifications());
    unawaited(_checkInvitations());
    _invitationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkInvitations(),
    );

    _chatNotificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkChatNotifications(),
    );
  }

  @override
  void dispose() {
    _chatNotificationTimer?.cancel();
    _invitationTimer?.cancel();

    if (notificationService.onNotificationTapped ==
        _handleNotificationPayload) {
      notificationService.onNotificationTapped = null;
    }

    super.dispose();
  }

  void _handleNotificationPayload(String? payload) {
    if (!mounted) return;

    setState(() {
      _applyNotificationPayload(payload);
    });
  }

  void _applyNotificationPayload(String? payload) {
    final target = NotificationTarget.parse(payload);
    if (target == null) return;

    if (target.type == NotificationTargetType.invitation) {
      currentIndex = 1;
      _pendingChatConversationId = null;
      _openInvitationInbox = true;
      _matchPageVersion++;
      return;
    }

    _openInvitationInbox = false;
    if (target.type == NotificationTargetType.chat) {
      currentIndex = 2;
      _pendingChatConversationId = target.id;
      return;
    }

    currentIndex = 0;
    _pendingChatConversationId = null;
    _scheduleNotificationTarget = target;
    _schedulePageVersion++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildPage(currentIndex),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 325,
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.calendar_month,
                        label: 'Schedule',
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.people,
                        label: 'Match',
                      ),
                      _buildNavItem(index: 2, icon: Icons.chat, label: 'Chat'),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.person,
                        label: 'Profile',
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.settings,
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (index == 0 || index == 1) {
            await _loadStoredTokens();
          }

          if (!mounted) return;

          setState(() {
            currentIndex = index;
            _openInvitationInbox = false;

            if (index != 2) {
              _pendingChatConversationId = null;
            }

            if (index == 0) {
              _schedulePageVersion++;
            }
          });
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 65,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: index == 1 && _invitationCount > 0,
                  label: Text('$_invitationCount'),
                  child: Icon(icon, color: Colors.black, size: 22),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkInvitations() async {
    if (_checkingInvitations || !mounted) return;
    _checkingInvitations = true;
    MatchmakingApi? api;
    try {
      await _loadStoredTokens();
      api = MatchmakingApi(widget.apiBaseUrl, _accessToken);
      final ids = await api.pendingInvitationIds();
      if (!mounted) return;
      setState(() => _invitationCount = ids.length);
      if (!_hasInitialisedInvitations) {
        _knownInvitationIds.addAll(ids);
        _hasInitialisedInvitations = true;
        return;
      }
      for (final id in ids.where((id) => !_knownInvitationIds.contains(id))) {
        if (!mounted) return;
        await notificationService.showNotification(
          id: notificationService.notificationIdFromText('invitation:$id'),
          title: 'New study invitation',
          body: 'A student has invited you to connect. Tap to respond.',
          payload: notificationService.invitationPayload(id),
        );
        _knownInvitationIds.add(id);
      }
    } catch (_) {
      // Preserve the last successful badge during network/session failures.
    } finally {
      api?.close();
      _checkingInvitations = false;
    }
  }

  Future<void> _loadStoredTokens() async {
    final accessToken = await _storage.read(key: 'access_token');

    final refreshToken = await _storage.read(key: 'refresh_token');

    if (accessToken == null || refreshToken == null) {
      return;
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  Future<void> _checkChatNotifications() async {
    if (_isCheckingChatNotifications || !mounted) return;

    _isCheckingChatNotifications = true;

    try {
      final conversations = await _chatApi.getConversations();
      final currentMessageIds = <String>{};
      final messagesToNotify = <Map<String, String>>[];

      for (final conversation in conversations) {
        final conversationId = conversation['id']?.toString();
        final messageId = conversation['last_message_id']?.toString();
        final senderId = conversation['last_message_sender_id']?.toString();
        final messageText = conversation['last_message']?.toString() ?? '';

        if (conversationId == null ||
            conversationId.isEmpty ||
            messageId == null ||
            messageId.isEmpty ||
            senderId == null ||
            messageText.trim().isEmpty) {
          continue;
        }

        currentMessageIds.add(messageId);

        if (_hasInitialisedChatTracking &&
            !_knownChatMessageIds.contains(messageId) &&
            _chatApi.currentUserId != null &&
            senderId != _chatApi.currentUserId) {
          final senderName =
              (conversation['student_name'] ??
                      conversation['other_user_name'] ??
                      conversation['name'] ??
                      'Student')
                  .toString();

          if (_activeChatConversationId != conversationId) {
            messagesToNotify.add({
              'conversationId': conversationId,
              'messageId': messageId,
              'senderName': senderName,
              'messageText': messageText,
            });
          }
        }
      }

      if (!_hasInitialisedChatTracking) {
        _knownChatMessageIds.addAll(currentMessageIds);
        _hasInitialisedChatTracking = true;
        return;
      }

      _knownChatMessageIds.addAll(currentMessageIds);

      for (final message in messagesToNotify) {
        if (!mounted) return;

        await notificationService.showNotification(
          id: notificationService.notificationIdFromText(
            'chat:${message['conversationId']}:${message['messageId']}',
          ),
          title: 'New message from ${message['senderName']}',
          body: message['messageText']!,
          payload: notificationService.chatPayload(message['conversationId']!),
        );
      }
    } on AuthExpiredException {
      // The session has expired; stop this check and let the
      // app's existing authentication handling manage the session.
    } catch (e) {
      debugPrint('Chat notification check failed: $e');
    } finally {
      _isCheckingChatNotifications = false;
    }
  }

  Future<void> _syncReminderNotifications() async {
    await reminderSyncService.syncUpcomingReminders(
      apiBaseUrl: widget.apiBaseUrl,
      accessToken: _accessToken,
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return SchedulerScreen(
          key: ValueKey(_schedulePageVersion),
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          notificationTarget: _scheduleNotificationTarget,
        );

      case 1:
        return MatchmakingPage(
          key: ValueKey('match-$_matchPageVersion'),
          openInvitationsOnLaunch: _openInvitationInbox,
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
        );

      case 2:
        return ChatPage(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
          initialConversationId: _pendingChatConversationId,
          onActiveConversationChanged: (conversationId) {
            _activeChatConversationId = conversationId;
          },
        );

      case 3:
        return ProfilePage(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          onProfileSaved: () {
            setState(() {
              currentIndex = 0;
              _schedulePageVersion++;
            });
          },
        );

      case 4:
        return SettingsPage(
          apiBaseUrl: widget.apiBaseUrl,
          accessToken: _accessToken,
          refreshToken: _refreshToken,
        );

      default:
        return const Center(child: Text('Page not found'));
    }
  }
}
