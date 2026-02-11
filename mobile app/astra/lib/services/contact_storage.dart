import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trusted_contact.dart';

class ContactStorage {
  // Key used to store trusted contacts in SharedPreferences
  static const String _key = "trusted_contacts_v1";

  // Load all saved contacts from local storage
  static Future<List<TrustedContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    // Nothing saved yet
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List;

      return decoded
          .map((e) => TrustedContact.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } catch (e) {
      // If parsing fails, return empty list instead of crashing
      return [];
    }
  }

  // Save full contact list to storage
  static Future<void> save(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      contacts.map((c) => c.toJson()).toList(),
    );

    await prefs.setString(_key, encoded);
  }

  // Add a new contact
  static Future<void> add(TrustedContact contact) async {
    final list = await load();
    list.add(contact);
    await save(list);
  }

  // Update an existing contact (matched by id)
  static Future<void> update(TrustedContact contact) async {
    final list = await load();

    final index = list.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      list[index] = contact;
      await save(list);
    }
  }

  // Remove a contact by id
  static Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((c) => c.id == id);
    await save(list);
  }

  // Clear everything (not used in UI, but useful for testing/reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
