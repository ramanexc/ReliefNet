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
      final historyBuffer = StringBuffer();
      for (final msg in _messages.take(_messages.length - 1)) {
        final role = msg['role'] == 'user' ? 'User' : 'Mahi';
        historyBuffer.writeln("$role: ${msg['content']}");
      }

      final prompt = """You are Mahi, the specialized AI assistant for ReliefNet, a disaster response and relief platform.
Your personality: Empathetic, calm, highly structured, and expert in emergency response protocols.
Your Goal: Assist field agents, volunteers, and disaster victims with immediate, actionable safety steps, first aid instructions, and platform navigation.

Formatting Guidelines:
- Keep responses concise, clear, and optimized for mobile reading.
- Use bullet points or numbered lists for step-by-step guides.
- Always double-check markdown syntax (like bold asterisks `**`) and ensure all tags are closed properly (never left dangling).
- Avoid raw technical jargon; use clear, reassuring language.

Platform Navigation Info:
- "Nearby Hospitals": Accessible from the Home screen, lists nearest hospitals with contact info and capacity.
- "Report an Issue": Accessible from the Home screen, allows users to report emergency status, infrastructure damage, and supply needs.
- "Crisis Heat Map": Accessible from the Drawer and Home screen ONLY for active volunteers, shows real-time report concentrations.

Conversation History:
${historyBuffer.toString()}
User asks: $text
Mahi:""";
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
            // Background tap/scroll detector to close chat when clicking/dragging outside
            if (_isChatOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanDown: (_) {
                    if (_isChatOpen) {
                      _toggleChat();
                    }
                  },
                ),
              ),
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
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[850]
                                                : Colors.grey[50],
                                            border: Border.all(
                                              color: Theme.of(context).primaryColor.withOpacity(
                                                Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.2,
                                              ),
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _quickQuestions[index],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : Theme.of(context).primaryColor,
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
                                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[850]
                                            : Colors.grey[100],
                                        side: BorderSide(
                                          color: Theme.of(context).primaryColor.withOpacity(
                                            Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.2,
                                          ),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        label: Text(
                                          _quickQuestions[index],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        onPressed: () => _sendMessage(predefinedText: _quickQuestions[index]),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
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

