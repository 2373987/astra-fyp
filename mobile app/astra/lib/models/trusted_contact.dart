// Model representing a user-added trusted contact
class TrustedContact {
  final String id;     // Unique identifier (used for update/delete)
  final String name;   // Contact name
  final String phone;  // Contact phone number

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  // Convert object → JSON (for saving to local storage)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "phone": phone,
    };
  }

  // Create object from JSON (when loading from storage)
  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: (json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
    );
  }

  // Helper method to create a modified copy (useful if editing fields later)
  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }
}
