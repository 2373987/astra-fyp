import 'dart:math';

import 'package:flutter/material.dart';

import '../models/trusted_contact.dart';
import '../services/contact_storage.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  // Screen state
  bool _loading = true;
  List<TrustedContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Load contacts from local storage (so they persist between app runs)
  Future<void> _loadContacts() async {
    setState(() => _loading = true);

    final items = await ContactStorage.load();

    if (!mounted) return;
    setState(() {
      _contacts = items;
      _loading = false;
    });
  }

  // Open dialog to add a new contact or edit an existing one
  Future<void> _openAddOrEditDialog({TrustedContact? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? "");
    final phoneCtrl = TextEditingController(text: existing?.phone ?? "");

    final saved = await showDialog<TrustedContact>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? "Add Trusted Contact" : "Edit Trusted Contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contact name
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),

              // Phone number
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  hintText: "e.g. +44 7xxx xxxxxx",
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Saved locally. SOS uses these details when sharing the alert.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;

                // Keep existing id when editing, generate when adding
                final id = existing?.id ??
                    "c_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}";

                Navigator.pop(ctx, TrustedContact(id: id, name: name, phone: phone));
              },
              child: Text(existing == null ? "Add" : "Save"),
            ),
          ],
        );
      },
    );

    if (saved == null) return;

    // Save changes to storage
    if (existing == null) {
      await ContactStorage.add(saved);
    } else {
      await ContactStorage.update(saved);
    }

    // Refresh screen list
    await _loadContacts();
  }

  // Confirm + delete a contact
  Future<void> _deleteContact(TrustedContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove contact?"),
        content: Text("Delete ${c.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ContactStorage.remove(c.id);
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trusted Contacts"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // Add contact button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),

      // Body: loading / empty / list
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 46),
                        const SizedBox(height: 12),
                        const Text(
                          "No trusted contacts yet.",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Add at least 1 contact so SOS can include who to alert.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _openAddOrEditDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text("Add trusted contact"),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final c = _contacts[i];

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: "Edit",
                              onPressed: () => _openAddOrEditDialog(existing: c),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: "Delete",
                              onPressed: () => _deleteContact(c),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
