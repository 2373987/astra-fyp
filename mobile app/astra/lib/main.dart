import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/emergency_contacts_screen.dart';
import 'screens/safety_map_screen.dart';
import 'screens/sos_screen.dart';

void main() {
  runApp(const AstraApp());
}

/// Root widget of the application
class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Astra',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF7F5FF),
      ),
      home: const AstraHome(),
    );
  }
}

/// Main container that controls bottom navigation
class AstraHome extends StatefulWidget {
  const AstraHome({super.key});

  @override
  State<AstraHome> createState() => _AstraHomeState();
}

class _AstraHomeState extends State<AstraHome> {
  int _selectedIndex = 0; // Tracks selected tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // List of screens used in bottom navigation
    _screens = [
      const HomeScreen(),
      const SosScreen(),
      const SafetyMapScreen(),
      AiCompanionScreen(
        // If AI detects high risk, switch to SOS tab
        onGoToSOS: () => setState(() => _selectedIndex = 1),
      ),
      const EmergencyContactsScreen(),
    ];
  }

  // Updates selected tab
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Astra'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Safety Map'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'AI Companion'),
          BottomNavigationBarItem(icon: Icon(Icons.phone), label: 'Emergency'),
        ],
      ),
    );
  }
}

/// Simple home screen with reassurance message
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'You are safe.\nAstra is with you.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22),
      ),
    );
  }
}

/// AI Companion screen – connects to FastAPI backend
class AiCompanionScreen extends StatefulWidget {
  final VoidCallback onGoToSOS;

  const AiCompanionScreen({super.key, required this.onGoToSOS});

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> {
  final TextEditingController _controller = TextEditingController();

  String _emotion = "-";
  String _risk = "-";
  String _action = "-";
  String _reply = "Hi, I’m Astra. Talk to me — I’m here with you.";
  bool _loading = false;

  // Local FastAPI backend URL
  final String _baseUrl = "http://127.0.0.1:8000";

  /// Sends user message to backend for risk analysis
  Future<void> _sendToAstra() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _reply = "Thinking…";
      _emotion = "-";
      _risk = "-";
      _action = "-";
    });

    try {
      final res = await http.post(
        Uri.parse("$_baseUrl/analyze"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      final data = jsonDecode(res.body);

      setState(() {
        _emotion = (data["emotion"] ?? "-").toString();
        _risk = (data["risk_level"] ?? "-").toString();
        _action = (data["recommended_action"] ?? "-").toString();
        _reply = (data["response_text"] ?? "…").toString();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _reply = "Could not reach Astra AI service. Is Python running?";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskHigh = _risk.toLowerCase() == "high";

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "AI Safety Companion",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text("Emotion: $_emotion | Risk: $_risk | Action: $_action"),

          // If risk is high, show warning box and SOS shortcut
          if (riskHigh) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE69C)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Astra detected higher risk. If you feel unsafe, press SOS.",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onGoToSOS,
                    child: const Text("SOS"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 16),

          // AI response display area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(_reply, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Input field
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: "Tell Astra what’s happening…",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          // Send button
          ElevatedButton(
            onPressed: _loading ? null : _sendToAstra,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text(
              "Send",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
