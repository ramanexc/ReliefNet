import 'package:flutter/material.dart';
import 'package:reliefnet/services/gemini_service.dart';

class MahiAiAssistant extends StatefulWidget {
  const MahiAiAssistant({super.key});

  @override
  State<MahiAiAssistant> createState() => _MahiAiAssistantState();
}

class _MahiAiAssistantState extends State<MahiAiAssistant> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isChatOpen = false;
  bool _showCloud = true;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  final List<String> _quickQuestions = [
    "🚨 How can I report an emergency?",
    "🏠 Where is the nearest shelter or relief camp?",
    "🏥 Where can I get medical assistance nearby?",
    "📍 How can I share my location with responders?",
    "👤 How do I report a missing person?",
    "🌊 What should I do during a flood?",
    "🌍 What should I do during an earthquake?",
    "🙋 How can I volunteer and help others?",
  ];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _hoverAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    // Auto-hide cloud after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showCloud) {
        setState(() => _showCloud = false);
      }
    });
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) _showCloud = false;
    });
    if (_isChatOpen) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? predefinedText}) async {
    final text = predefinedText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      if (predefinedText == null) _controller.clear();
    });
    _scrollToBottom();

    try {
      final prompt = """You are Mahi, the specialized AI assistant for ReliefNet. 
Your personality: Empathetic, highly efficient, and expert in disaster relief protocols.
Your Goal: Help field agents and victims with immediate, actionable advice and platform navigation.

Specific Knowledge:
- If asked about medical emergencies, emphasize finding the nearest hospital via the Home screen's 'Nearby Hospitals' tool.
- For first aid, provide clear, step-by-step instructions.
- For disaster protocols (Fire, Flood, Earthquake), give immediate safety steps.
- Keep responses concise and formatted for mobile reading.

User asks: $text""";
      final response = await GeminiService.mahiChat(prompt);
      
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response ?? "Sorry, I'm having trouble connecting right now."});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': "Error: $e"});
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Chat Window
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              bottom: (90) + bottomInset,
              right: 20,
              child: IgnorePointer(
                ignoring: !_isChatOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isChatOpen ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: _isChatOpen ? 1.0 : 0.8,
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      constraints: const BoxConstraints(maxWidth: 400),
                      height: 450,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: Theme.of(context).primaryColor,
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.face, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Mahi",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          "ReliefNet Assistant",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                    onPressed: _toggleChat,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            // Chat Messages
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isUser = msg['role'] == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? Theme.of(context).primaryColor
                                            : Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                                          bottomRight: Radius.circular(isUser ? 0 : 16),
                                        ),
                                      ),
                                      child: Text(
                                        msg['content']!,
                                        style: TextStyle(
                                          color: isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_isLoading)
                              LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor.withOpacity(0.5)),
                                minHeight: 2,
                              ),
                            // Quick Questions
                            if (_messages.isEmpty && !_isLoading)
                              Container(
                                height: 160,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _quickQuestions.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => _sendMessage(predefinedText: _quickQuestions[index]),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _quickQuestions[index],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            else if (!_isLoading)
                              SizedBox(
                                height: 45,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  itemCount: _quickQuestions.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: ActionChip(
                                        label: Text(
                                          _quickQuestions[index],
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onPressed: () => _sendMessage(predefinedText: _quickQuestions[index]),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Input Area
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: "Ask Mahi...",
                                        hintStyle: const TextStyle(fontSize: 14),
                                        isDense: true,
                                        filled: true,
                                        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: IconButton(
                                      onPressed: _sendMessage,
                                      icon: const Icon(Icons.send, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // FAB and Cloud
            Positioned(
              bottom: 20 + bottomInset,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_showCloud && !_isChatOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, right: 4),
                      child: AnimatedOpacity(
                        opacity: _showCloud ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Chat with AI Mahi",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: _hoverAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -_hoverAnimation.value),
                        child: child,
                      );
                    },
                    child: FloatingActionButton(
                      elevation: 8,
                      onPressed: _toggleChat,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _isChatOpen ? Icons.close : Icons.face_retouching_natural_rounded,
                          key: ValueKey(_isChatOpen),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

