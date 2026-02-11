import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';
import 'trusted_contacts_screen.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  // Default UK emergency numbers (easy to swap later if you want other countries)
  static const List<EmergencyContact> _ukContacts = [
    EmergencyContact(
      title: "Emergency (Police / Ambulance / Fire)",
      number: "999",
      note: "24/7",
    ),
    EmergencyContact(title: "Police (non-emergency)", number: "101"),
    EmergencyContact(title: "NHS (non-emergency)", number: "111"),
    EmergencyContact(
      title: "Samaritans",
      number: "116123",
      note: "24/7 emotional support",
    ),
    EmergencyContact(
      title: "Domestic Abuse Helpline",
      number: "08082000247",
      note: "24/7",
    ),
    EmergencyContact(title: "Rape Crisis (England & Wales)", number: "08085002222"),
  ];

  // Opens the phone dialer using tel: (works on mobile; browser support can vary)
  Future<void> _call(String number, BuildContext context) async {
    final uri = Uri.parse("tel:$number");

    final ok = await canLaunchUrl(uri);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Calling is not supported on this device/browser."),
        ),
      );
      return;
    }

    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            "Local Emergency Contacts",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Quick-call official helplines for your area.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Main list: local emergency contacts
          ..._ukContacts.map((c) {
            final subtitle = c.note.isEmpty ? c.number : "${c.number} • ${c.note}";

            return Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: Text(c.title),
                subtitle: Text(subtitle),
                trailing: IconButton(
                  tooltip: "Call",
                  icon: const Icon(Icons.call),
                  onPressed: () => _call(c.number, context),
                ),
              ),
            );
          }),

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),

          // Link to the trusted contacts feature (for SOS / quick sharing)
          const Text(
            "Trusted Contacts",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            "Add people you trust so you can share SOS quickly.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrustedContactsScreen()),
                );
              },
              icon: const Icon(Icons.people, color: Colors.white),
              label: const Text(
                "Manage Trusted Contacts",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
