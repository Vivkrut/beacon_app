import 'package:flutter/foundation.dart';
import 'package:beacon/core/models/contact.dart';
import 'package:beacon/features/contacts/data/contact_repository.dart';

class ContactNotifier extends ChangeNotifier {
  final ContactRepository _repository;
  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  ContactNotifier(this._repository);

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _repository.getAllContacts();
      _error = null;
    } catch (e) {
      _error = 'Failed to load contacts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addContact(Contact contact) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.addContact(contact);
      _contacts.add(contact);
      _error = null;
    } catch (e) {
      _error = 'Failed to add contact: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateContact(Contact contact) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateContact(contact);
      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _contacts[index] = contact;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to update contact: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.deleteContact(id);
      _contacts.removeWhere((c) => c.id == id);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete contact: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPrimaryContact(String id) async {
    try {
      await _repository.setPrimaryContact(id);
      // Update local list using copyWith
      _contacts = _contacts
          .map((contact) => contact.copyWith(isPrimary: contact.id == id))
          .toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set primary contact: $e';
      notifyListeners();
    }
  }

  Future<Contact?> getPrimaryContact() async {
    try {
      return await _repository.getPrimaryContact();
    } catch (e) {
      _error = 'Failed to get primary contact: $e';
      notifyListeners();
      return null;
    }
  }

  int get contactCount => _contacts.length;

  Future<void> clearError() async {
    _error = null;
    notifyListeners();
  }
}
