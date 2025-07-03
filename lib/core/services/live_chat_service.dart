import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logger_service.dart';

enum ChatStatus {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

enum MessageType {
  text,
  image,
  file,
  system,
  typing,
}

enum UserRole {
  user,
  agent,
  system,
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: UserRole.values.firstWhere(
        (role) => role.name == map['senderRole'],
        orElse: () => UserRole.user,
      ),
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
      'isRead': isRead,
    };
  }
}

class ChatSession {
  final String id;
  final String userId;
  final String userName;
  final String? agentId;
  final String? agentName;
  final DateTime startTime;
  final DateTime? endTime;
  final ChatStatus status;
  final String topic;
  final int priority;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const ChatSession({
    required this.id,
    required this.userId,
    required this.userName,
    this.agentId,
    this.agentName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.topic,
    this.priority = 1,
    this.tags = const [],
    this.metadata = const {},
  });

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      agentId: map['agentId'],
      agentName: map['agentName'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: map['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      status: ChatStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ChatStatus.disconnected,
      ),
      topic: map['topic'] ?? '',
      priority: map['priority'] ?? 1,
      tags: List<String>.from(map['tags'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'agentId': agentId,
      'agentName': agentName,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'status': status.name,
      'topic': topic,
      'priority': priority,
      'tags': tags,
      'metadata': metadata,
    };
  }
}

class LiveChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  ChatSession? _currentSession;
  ChatStatus _status = ChatStatus.disconnected;
  final List<ChatMessage> _messages = [];
  Timer? _simulationTimer;
  StreamSubscription? _messageSubscription;
  
  // Getters
  ChatStatus get status => _status;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _status == ChatStatus.connected;
  bool get hasActiveSession => _currentSession != null;

  /// Initialize chat service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing live chat service');
      await _checkExistingSession();
      LoggerService.info('Live chat service initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize live chat service', error: e);
    }
  }

  /// Start a new chat session
  Future<ChatSession> startChatSession({
    required String topic,
    int priority = 1,
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      LoggerService.info('Starting new chat session');

      // Create session in Firestore
      final sessionId = _firestore.collection('chat_sessions').doc().id;
      final session = ChatSession(
        id: sessionId,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Anonymous',
        startTime: DateTime.now(),
        status: ChatStatus.connecting,
        topic: topic,
        priority: priority,
        tags: tags,
        metadata: metadata,
      );

      await _firestore
          .collection('chat_sessions')
          .doc(sessionId)
          .set(session.toMap());

      _currentSession = session;
      _setStatus(ChatStatus.connecting);
      
      // Simulate connection process
      await Future.delayed(const Duration(seconds: 2));
      _setStatus(ChatStatus.connected);
      
      // Send initial system message
      await _sendSystemMessage('Chat session started. An agent will be with you shortly.');
      
      // Simulate agent assignment after 5 seconds
      _simulateAgentAssignment();
      
      LoggerService.info('Chat session started: $sessionId');
      notifyListeners();
      
      return session;
    } catch (e) {
      LoggerService.error('Failed to start chat session', error: e);
      rethrow;
    }
  }

  /// Simulate agent assignment
  void _simulateAgentAssignment() {
    _simulationTimer = Timer(const Duration(seconds: 5), () async {
      if (_currentSession != null) {
        // Update session with agent info
        const agentName = 'Agent Sarah';
        const agentId = 'agent_001';
        
        await _firestore
            .collection('chat_sessions')
            .doc(_currentSession!.id)
            .update({
          'agentId': agentId,
          'agentName': agentName,
        });

        _currentSession = ChatSession(
          id: _currentSession!.id,
          userId: _currentSession!.userId,
          userName: _currentSession!.userName,
          agentId: agentId,
          agentName: agentName,
          startTime: _currentSession!.startTime,
          endTime: _currentSession!.endTime,
          status: _currentSession!.status,
          topic: _currentSession!.topic,
          priority: _currentSession!.priority,
          tags: _currentSession!.tags,
          metadata: _currentSession!.metadata,
        );
        
        await _sendSystemMessage('$agentName has joined the chat');
        
        // Send welcome message from agent
        await Future.delayed(const Duration(seconds: 2));
        await _sendAgentMessage(
          'Hello! I\'m $agentName and I\'ll be helping you today. How can I assist you with your digital certificates?'
        );
        
        notifyListeners();
      }
    });
  }

  /// Send a text message
  Future<void> sendMessage(String content) async {
    try {
      if (_currentSession == null || !isConnected) {
        throw Exception('No active chat session');
      }

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final message = ChatMessage(
        id: _firestore.collection('chat_messages').doc().id,
        chatId: _currentSession!.id,
        senderId: user.uid,
        senderName: user.displayName ?? user.email ?? 'You',
        senderRole: UserRole.user,
        content: content,
        type: MessageType.text,
        timestamp: DateTime.now(),
      );

      // Add to local messages immediately
      _messages.add(message);
      notifyListeners();

      // Save to Firestore
      await _saveMessageToFirestore(message);
      
      // Simulate agent response after a delay
      _simulateAgentResponse(content);
      
    } catch (e) {
      LoggerService.error('Failed to send message', error: e);
      rethrow;
    }
  }

  /// Simulate agent response
  void _simulateAgentResponse(String userMessage) {
    Timer(const Duration(seconds: 2, milliseconds: 500), () async {
      if (_currentSession?.agentId != null) {
        String response = _generateAgentResponse(userMessage);
        await _sendAgentMessage(response);
      }
    });
  }

  /// Generate contextual agent response
  String _generateAgentResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('certificate') || lowerMessage.contains('cert')) {
      return 'I can help you with certificate-related questions. Are you looking to create a new certificate, verify an existing one, or need help with certificate management?';
    } else if (lowerMessage.contains('verify') || lowerMessage.contains('validation')) {
      return 'For certificate verification, you can use our verification page. Do you have a certificate ID or QR code you\'d like me to help you verify?';
    } else if (lowerMessage.contains('create') || lowerMessage.contains('new')) {
      return 'To create a new certificate, you\'ll need to go to the Certificates section and click "Create Certificate". What type of certificate are you looking to create?';
    } else if (lowerMessage.contains('problem') || lowerMessage.contains('issue') || lowerMessage.contains('error')) {
      return 'I\'m sorry to hear you\'re experiencing an issue. Can you please describe the problem in more detail so I can better assist you?';
    } else if (lowerMessage.contains('thank') || lowerMessage.contains('thanks')) {
      return 'You\'re welcome! Is there anything else I can help you with regarding your digital certificates?';
    } else if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! How can I assist you with your digital certificate needs today?';
    } else {
      return 'I understand. Let me help you with that. Could you provide more specific details about what you\'re trying to accomplish?';
    }
  }

  /// Send agent message
  Future<void> _sendAgentMessage(String content) async {
    if (_currentSession?.agentId == null) return;

    final message = ChatMessage(
      id: _firestore.collection('chat_messages').doc().id,
      chatId: _currentSession!.id,
      senderId: _currentSession!.agentId!,
      senderName: _currentSession!.agentName ?? 'Agent',
      senderRole: UserRole.agent,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    _messages.add(message);
    await _saveMessageToFirestore(message);
    notifyListeners();
  }

  /// End chat session
  Future<void> endChatSession() async {
    try {
      if (_currentSession == null) return;

      LoggerService.info('Ending chat session: ${_currentSession!.id}');

      // Update session in Firestore
      await _firestore
          .collection('chat_sessions')
          .doc(_currentSession!.id)
          .update({
        'endTime': DateTime.now().millisecondsSinceEpoch,
        'status': ChatStatus.disconnected.name,
      });

      await _sendSystemMessage('Chat session ended. Thank you for contacting support!');
      
      // Cleanup
      _simulationTimer?.cancel();
      await _messageSubscription?.cancel();
      _currentSession = null;
      _messages.clear();
      _setStatus(ChatStatus.disconnected);
      
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to end chat session', error: e);
    }
  }

  /// Send system message
  Future<void> _sendSystemMessage(String content) async {
    final message = ChatMessage(
      id: _firestore.collection('chat_messages').doc().id,
      chatId: _currentSession?.id ?? '',
      senderId: 'system',
      senderName: 'System',
      senderRole: UserRole.system,
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
    );

    _messages.add(message);
    await _saveMessageToFirestore(message);
    notifyListeners();
  }

  /// Save message to Firestore
  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    try {
      await _firestore
          .collection('chat_messages')
          .doc(message.id)
          .set(message.toMap());
    } catch (e) {
      LoggerService.error('Failed to save message to Firestore', error: e);
    }
  }

  /// Set status and notify listeners
  void _setStatus(ChatStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }

  /// Check for existing active session
  Future<void> _checkExistingSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final query = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: ChatStatus.connected.name)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _currentSession = ChatSession.fromMap(query.docs.first.data());
        await _loadSessionMessages();
        _setStatus(ChatStatus.connected);
        LoggerService.info('Restored active chat session: ${_currentSession!.id}');
      }
    } catch (e) {
      LoggerService.error('Failed to check existing session', error: e);
    }
  }

  /// Load messages for current session
  Future<void> _loadSessionMessages() async {
    if (_currentSession == null) return;

    try {
      final query = await _firestore
          .collection('chat_messages')
          .where('chatId', isEqualTo: _currentSession!.id)
          .orderBy('timestamp', descending: false)
          .get();

      _messages.clear();
      for (final doc in query.docs) {
        _messages.add(ChatMessage.fromMap(doc.data()));
      }
      
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to load session messages', error: e);
    }
  }

  /// Get chat history
  Future<List<ChatSession>> getChatHistory({int limit = 20}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final query = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => ChatSession.fromMap(doc.data()))
          .toList();
    } catch (e) {
      LoggerService.error('Failed to get chat history', error: e);
      return [];
    }
  }

  /// Check if chat is available
  Future<bool> isChatAvailable() async {
    try {
      // Check business hours (9 AM - 5 PM, Monday to Friday)
      final now = DateTime.now();
      final hour = now.hour;
      final weekday = now.weekday;
      
      // Monday = 1, Sunday = 7
      final isWeekday = weekday >= 1 && weekday <= 5;
      final isBusinessHours = hour >= 9 && hour < 17;
      
      return isWeekday && isBusinessHours;
    } catch (e) {
      LoggerService.error('Failed to check chat availability', error: e);
      return false;
    }
  }

  /// Get estimated wait time
  Future<Duration> getEstimatedWaitTime() async {
    try {
      // Simulate getting queue information
      final queueLength = await _getQueueLength();
      
      // Estimate 2 minutes per person in queue
      final waitMinutes = queueLength * 2;
      return Duration(minutes: waitMinutes);
    } catch (e) {
      LoggerService.error('Failed to get wait time', error: e);
      return const Duration(minutes: 5); // Default estimate
    }
  }

  /// Get current queue length
  Future<int> _getQueueLength() async {
    try {
      final query = await _firestore
          .collection('chat_sessions')
          .where('status', isEqualTo: ChatStatus.connecting.name)
          .get();
      
      return query.docs.length;
    } catch (e) {
      return 2; // Default queue length
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}

// Riverpod providers
final liveChatServiceProvider = ChangeNotifierProvider<LiveChatService>((ref) {
  return LiveChatService();
});

final chatStatusProvider = Provider<ChatStatus>((ref) {
  return ref.watch(liveChatServiceProvider).status;
});

final chatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(liveChatServiceProvider).messages;
});

final currentChatSessionProvider = Provider<ChatSession?>((ref) {
  return ref.watch(liveChatServiceProvider).currentSession;
}); 