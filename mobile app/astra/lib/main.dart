import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
void main() {
  runApp(const AstraApp());
}

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

class AstraHome extends StatefulWidget {
  const AstraHome({super.key});

  @override
  State<AstraHome> createState() => _AstraHomeState();
}

class _AstraHomeState extends State<AstraHome> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  @override
void initState() {
  super.initState();

  _screens = [
    const HomeScreen(),
    const SosScreen(),
    const SafetyMapScreen(),
    AiCompanionScreen(
      onGoToSOS: () {
        setState(() {
          _selectedIndex = 1; // SOS tab
        });
      },
    ),
    const EmergencyContactsScreen(),
  ];
}
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Safety Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'AI Companion',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone),
            label: 'Local Emergency Contacts',
          ),
        ],
      ),
    );
  }
}
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

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 70, color: Colors.deepPurple),
          const SizedBox(height: 16),
          const Text(
            'Emergency SOS',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap SOS to alert trusted contacts and share your location.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ SOS triggered (demo). Next: send live location link.'),
                  ),
                );
              },
              child: const Text(
                'SOS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color:Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📍 Demo: Live location sharing will be added here.'),
                  ),
                );
              },
              child: const Text('Share Live Location'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('👥 Demo: Trusted contacts screen comes next.'),
                  ),
                );
              },
              child: const Text('Trusted Contacts'),
            ),
          ),
        ],
      ),
    );
  }
}

class SafetyMapScreen extends StatelessWidget {
  const SafetyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Safety Map (next step)'),
    );
  }
}

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Local Emergency Contacts (next step)'),
    );
  }
}
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

  final String _baseUrl = "http://127.0.0.1:8000";

  Future<void> _sendToAstra() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _reply = "Thinking…";
      _emotion = "-";
      _risk = "-";
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
    } catch (e) {
      setState(() {
        _reply = "Could not reach Astra AI service. Is Python running?";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (_risk.toLowerCase() == "high") ...[
  const SizedBox(height: 10),
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3CD), // soft warning
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

          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: "Tell Astra what’s happening…",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _loading ? null : _sendToAstra,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text("Send", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

