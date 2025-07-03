import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/live_chat_service.dart';
import '../../../core/localization/app_localizations.dart';

class LiveChatPage extends ConsumerStatefulWidget {
  const LiveChatPage({super.key});

  @override
  ConsumerState<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends ConsumerState<LiveChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveChatServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _startChat() async {
    try {
      await ref.read(liveChatServiceProvider).startChatSession(
        topic: 'General Support',
        priority: 1,
        tags: ['support', 'general'],
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      _messageController.clear();
      await ref.read(liveChatServiceProvider).sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _endChat() async {
    try {
      await ref.read(liveChatServiceProvider).endChatSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatStatus = ref.watch(chatStatusProvider);
    final messages = ref.watch(chatMessagesProvider);
    final currentSession = ref.watch(currentChatSessionProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.liveChat ?? 'Live Chat'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (currentSession != null)
            IconButton(
              icon: const Icon(Icons.call_end),
              onPressed: _endChat,
              tooltip: 'End Chat',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _getStatusColor(chatStatus),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(chatStatus),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(chatStatus, localizations),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (currentSession?.agentName != null)
                  Text(
                    'Agent: ${currentSession!.agentName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Messages Area
          Expanded(
            child: chatStatus == ChatStatus.disconnected && messages.isEmpty
                ? _buildWelcomeScreen(localizations)
                : _buildMessagesArea(messages),
          ),

          // Input Area
          if (chatStatus == ChatStatus.connected)
            _buildInputArea(localizations),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(AppLocalizations? localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 24),
            Text(
              localizations?.liveChat ?? 'Live Chat Support',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get instant help from our support team.\nWe\'re here to assist you with any questions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FutureBuilder<bool>(
              future: ref.read(liveChatServiceProvider).isChatAvailable(),
              builder: (context, snapshot) {
                final isAvailable = snapshot.data ?? false;
                return Column(
                  children: [
                    if (!isAvailable)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.orange[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Support hours: Monday-Friday, 9 AM - 5 PM',
                                style: TextStyle(color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _startChat,
                      icon: const Icon(Icons.chat),
                      label: Text(localizations?.startChat ?? 'Start Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            FutureBuilder<Duration>(
              future: ref.read(liveChatServiceProvider).getEstimatedWaitTime(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final waitTime = snapshot.data!;
                  return Text(
                    'Estimated wait time: ${waitTime.inMinutes} minutes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesArea(List<ChatMessage> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.senderRole == UserRole.user;
    final isSystem = message.senderRole == UserRole.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(
                Icons.support_agent,
                size: 16,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[600] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.senderName.isNotEmpty)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isUser ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[100],
              child: Icon(
                Icons.person,
                size: 16,
                color: Colors.green[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(AppLocalizations? localizations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.blue[600]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (text) {
                // Handle typing indicator
                if (text.isNotEmpty && !_isTyping) {
                  _isTyping = true;
                  // Send typing indicator
                } else if (text.isEmpty && _isTyping) {
                  _isTyping = false;
                  // Stop typing indicator
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ChatStatus status) {
    switch (status) {
      case ChatStatus.connected:
        return Colors.green;
      case ChatStatus.connecting:
        return Colors.orange;
      case ChatStatus.error:
        return Colors.red;
      case ChatStatus.reconnecting:
        return Colors.amber;
      case ChatStatus.disconnected:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ChatStatus status) {
    switch (status) {
      case ChatStatus.connected:
        return Icons.check_circle;
      case ChatStatus.connecting:
        return Icons.hourglass_empty;
      case ChatStatus.error:
        return Icons.error;
      case ChatStatus.reconnecting:
        return Icons.refresh;
      case ChatStatus.disconnected:
        return Icons.circle;
    }
  }

  String _getStatusText(ChatStatus status, AppLocalizations? localizations) {
    switch (status) {
      case ChatStatus.connected:
        return 'Connected';
      case ChatStatus.connecting:
        return 'Connecting...';
      case ChatStatus.error:
        return 'Connection Error';
      case ChatStatus.reconnecting:
        return 'Reconnecting...';
      case ChatStatus.disconnected:
        return 'Disconnected';
    }
  }
} 