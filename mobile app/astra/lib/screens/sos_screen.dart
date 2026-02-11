import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trusted_contact.dart';
import '../services/contact_storage.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  // UI state
  bool _sending = false;

  // Last SOS details (for "share again")
  String? _lastLink;
  DateTime? _lastTime;

  // Trusted contacts loaded from local storage
  List<TrustedContact> _contacts = [];
  bool _loadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Load saved trusted contacts from storage (SharedPreferences/json)
  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);

    final list = await ContactStorage.load();

    if (!mounted) return;
    setState(() {
      _contacts = list;
      _loadingContacts = false;
    });
  }

  // Ask for location permission + fetch current position
  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception("Location services are OFF.");
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception("Location permission denied.");
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Build a simple Google Maps link (works across devices)
  String _buildMapsLink(double lat, double lon) {
    return "https://maps.google.com/?q=$lat,$lon";
  }

  // Prepare the SOS message that gets shared via the share sheet
  String _buildMessage({
    required String link,
    required List<TrustedContact> contacts,
  }) {
    final contactList = contacts.isEmpty
        ? "(No trusted contacts added yet)"
        : contacts.map((c) => "${c.name} (${c.phone})").join(", ");

    return [
      "🚨 ASTRA SOS ALERT 🚨",
      "I need help. Please check on me ASAP.",
      "",
      "📍 Live location:",
      link,
      "",
      "Trusted contacts list:",
      contactList,
      "",
      "Sent from Astra Safety App (FYP demo).",
    ].join("\n");
  }

  // Main SOS action: fetch location, build message, open share sheet
  Future<void> _sendSOS() async {
    setState(() => _sending = true);

    try {
      final pos = await _getPosition();
      final link = _buildMapsLink(pos.latitude, pos.longitude);
      final msg = _buildMessage(link: link, contacts: _contacts);

      await Share.share(msg, subject: "Astra SOS Alert");

      if (!mounted) return;
      setState(() {
        _lastLink = link;
        _lastTime = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ SOS shared")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SOS failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Quick action to share the last SOS message again
  Future<void> _shareLastAgain() async {
    if (_lastLink == null) return;

    final msg = _buildMessage(link: _lastLink!, contacts: _contacts);
    await Share.share(msg, subject: "Astra SOS Alert");
  }

  @override
  Widget build(BuildContext context) {
    final hasContacts = _contacts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency SOS"),
        actions: [
          IconButton(
            tooltip: "Reload contacts",
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 70,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            const Text(
              "Emergency SOS",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tap SOS to share your live location via share sheet.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Trusted contacts status (just to show it’s wired up)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: _loadingContacts
                  ? const Text("Loading trusted contacts…")
                  : Text(
                      hasContacts
                          ? "Trusted contacts: ${_contacts.length}"
                          : "Trusted contacts: 0 (add at least 1 for best demo)",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),

            const SizedBox(height: 18),

            // SOS button
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
                onPressed: _sending ? null : _sendSOS,
                child: Text(
                  _sending ? "Sharing…" : "SOS (Share Location)",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Share again button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _lastLink == null ? null : _shareLastAgain,
                icon: const Icon(Icons.share),
                label: const Text("Share last SOS again"),
              ),
            ),

            const SizedBox(height: 16),

            // Debug panel: shows last sent link/time (handy for demo + testing)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _lastLink == null
                        ? "No SOS sent yet."
                        : jsonEncode({
                            "last_shared_at": _lastTime?.toIso8601String(),
                            "maps_link": _lastLink,
                          }),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
