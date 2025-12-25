import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beacon/features/contacts/presentation/notifiers/contact_notifier.dart';
import 'package:beacon/features/contacts/presentation/screens/add_edit_contact_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  @override
  void initState() {
    super.initState();
    // Load contacts on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactNotifier>().loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ContactNotifier>(
        builder: (context, contactNotifier, _) {
          if (contactNotifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contactNotifier.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${contactNotifier.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => contactNotifier.loadContacts(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (contactNotifier.contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contact_phone_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No contacts added yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddContact(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Contact'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: contactNotifier.contacts.length,
            itemBuilder: (context, index) {
              final contact = contactNotifier.contacts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: contact.isPrimary
                        ? Colors.red
                        : Colors.grey,
                    child: Text(
                      contact.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(contact.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.phone),
                      if (contact.isPrimary)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Primary',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Edit'),
                        onTap: () => _navigateToEditContact(context, contact),
                      ),
                      PopupMenuItem(
                        child: const Text('Set Primary'),
                        onTap: () =>
                            contactNotifier.setPrimaryContact(contact.id),
                      ),
                      PopupMenuItem(
                        child: const Text('Delete'),
                        onTap: () =>
                            _confirmDelete(context, contact.id, contact.name),
                      ),
                    ],
                  ),
                  onTap: () => _navigateToEditContact(context, contact),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => _navigateToAddContact(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddContact(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddEditContactScreen()),
    );
  }

  void _navigateToEditContact(BuildContext context, dynamic contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditContactScreen(contact: contact),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ContactNotifier>().deleteContact(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
