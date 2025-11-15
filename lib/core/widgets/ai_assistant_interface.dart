import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AIAssistantInterface extends ConsumerStatefulWidget {
  const AIAssistantInterface({super.key});

  @override
  ConsumerState<AIAssistantInterface> createState() => _AIAssistantInterfaceState();
}

class _AIAssistantInterfaceState extends ConsumerState<AIAssistantInterface>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

  List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    ));

    // Add welcome message
    _addMessage(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Hello! I\'m your AI cultivation assistant. I can help you with plant care, troubleshooting, and growing advice. What can I help you with today?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.secondary.withOpacity(0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Cultivation Assistant',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online • Ready to help',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showChatInfo,
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
          ),

          // Quick Suggestions
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(suggestion['icon'], size: 16),
                    label: Text(suggestion['text']),
                    onPressed: () => _handleQuickSuggestion(suggestion['text']),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),

          // Messages List
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  final message = _messages[index];
                  return ChatBubble(
                    message: message,
                    onAnimation: (index == _messages.length - 1),
                  );
                },
              ),
            ),
          ),

          // Message Input
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _attachImage,
                  icon: Icon(
                    Icons.image_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: _attachFile,
                  icon: Icon(
                    Icons.attach_file,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about your plants...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (text) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _recordVoice,
                  icon: Icon(
                    Icons.mic_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimation,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(0),
                    const SizedBox(width: 4),
                    _buildDot(1),
                    const SizedBox(width: 4),
                    _buildDot(2),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        final delay = index * 0.2;
        final animationValue = (_typingAnimation.value - delay).clamp(0.0, 1.0);
        final scale = 0.5 + (0.5 * animationValue);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    _messageController.clear();

    // Show typing indicator
    setState(() {
      _isTyping = true;
    });
    _typingController.forward();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Simulate AI response
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isTyping = false;
      });
      _typingController.reverse();

      _addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: _generateAIResponse(text),
        isUser: false,
        timestamp: DateTime.now(),
      ));

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _generateAIResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('water') || lowerMessage.contains('watering')) {
      return 'Based on your current soil moisture levels (45%), I recommend watering in the next 30 minutes. Your plants are showing slight signs of underwatering. Use pH-balanced water (6.0-6.5) and water until you see about 10% runoff.';
    } else if (lowerMessage.contains('nutrient') || lowerMessage.contains('feed')) {
      return 'Your plants are in the vegetative stage and would benefit from a balanced nutrient solution. I recommend an N-P-K ratio of 3-1-2 with micronutrients. Start at 1/4 strength and gradually increase over the next week.';
    } else if (lowerMessage.contains('light') || lowerMessage.contains('lighting')) {
      return 'Your current light intensity is at 75% and schedule is 18/6 for vegetative growth. This looks good! Make sure to maintain 18-24 inches distance from canopy to prevent light burn.';
    } else if (lowerMessage.contains('temperature') || lowerMessage.contains('temp')) {
      return 'Your temperature is currently 23.5°C which is optimal for vegetative growth. Keep it between 20-26°C during the day and 18-22°C at night for best results.';
    } else if (lowerMessage.contains('yellow') || lowerMessage.contains('deficiency')) {
      return 'Yellowing leaves can indicate several issues: nitrogen deficiency (older leaves first), overwatering, or pH problems. Check your pH levels first, then consider nitrogen feeding if pH is optimal.';
    } else {
      return 'I\'d be happy to help with your cultivation! Based on your current sensor readings, your environment looks well-balanced. Is there a specific plant issue or growing question I can assist you with?';
    }
  }

  void _handleQuickSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage();
  }

  void _attachImage() {
    // Handle image attachment
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach Image'),
        content: const Text('Take a photo or select from gallery to analyze your plant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Camera logic
            },
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Gallery logic
            },
            child: const Text('Gallery'),
          ),
        ],
      ),
    );
  }

  void _attachFile() {
    // Handle file attachment
  }

  void _recordVoice() {
    // Handle voice recording
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About AI Assistant'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I\'m your AI cultivation assistant, trained to help you with:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Plant health diagnosis'),
            Text('• Growing advice and troubleshooting'),
            Text('• Nutrient recommendations'),
            Text('• Environmental optimization'),
            Text('• Harvest timing guidance'),
            SizedBox(height: 16),
            Text(
              'I learn from your specific growing conditions to provide personalized advice.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _quickSuggestions = [
    {'icon': Icons.eco, 'text': 'Check plant health'},
    {'icon': Icons.water_drop, 'text': 'Watering advice'},
    {'icon': Icons.grain, 'text': 'Nutrient questions'},
    {'icon': Icons.thermostat, 'text': 'Temperature issues'},
    {'icon': Icons.lightbulb, 'text': 'Lighting setup'},
    {'icon': Icons.bug_report, 'text': 'Pest problems'},
  ];
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool onAnimation;

  const ChatBubble({
    super.key,
    required this.message,
    this.onAnimation = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.message.isUser ? 0.3 : -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.onAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: widget.message.isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (!widget.message.isUser) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.message.isUser
                            ? colorScheme.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.message.text,
                            style: TextStyle(
                              color: widget.message.isUser
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(widget.message.timestamp),
                            style: TextStyle(
                              color: widget.message.isUser
                                  ? Colors.white70
                                  : Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.message.isUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}