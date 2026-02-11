// Simple model representing a public emergency contact
class EmergencyContact {
  // Display name (e.g. Police, Ambulance, Fire, etc.)
  final String title;

  // Phone number to dial
  final String number;

  // Optional extra info (e.g. 24/7, non-emergency, etc.)
  final String note;

  const EmergencyContact({
    required this.title,
    required this.number,
    this.note = "",
  });
}
