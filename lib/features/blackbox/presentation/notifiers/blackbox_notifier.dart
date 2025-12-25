import 'package:flutter/foundation.dart';
import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/features/blackbox/data/blackbox_repository.dart';

class BlackBoxNotifier extends ChangeNotifier {
  final BlackBoxRepository _repository;
  List<SOSEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  BlackBoxNotifier(this._repository);

  List<SOSEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get eventCount => _events.length;

  /// Load all SOS events from database
  Future<void> loadEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _repository.getAllEvents();
      _error = null;
    } catch (e) {
      _error = 'Failed to load events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load recent events (last N)
  Future<void> loadRecentEvents(int limit) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _repository.getRecentEvents(limit);
      _error = null;
    } catch (e) {
      _error = 'Failed to load recent events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load events for a specific date
  Future<void> loadEventsByDate(DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _repository.getEventsByDate(date);
      _error = null;
    } catch (e) {
      _error = 'Failed to load events by date: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new SOS event to the BlackBox
  Future<void> addEvent(SOSEvent event) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.addEvent(event);
      _events.insert(0, event); // Add to top of list (newest first)
      _error = null;
    } catch (e) {
      _error = 'Failed to add event: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a specific SOS event
  Future<void> deleteEvent(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.deleteEvent(id);
      _events.removeWhere((e) => e.id == id);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete event: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing SOS event
  Future<void> updateEvent(SOSEvent event) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateEvent(event);
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to update event: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all SOS events (BlackBox purge with confirmation)
  Future<void> clearAllEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.clearAllEvents();
      _events.clear();
      _error = null;
    } catch (e) {
      _error = 'Failed to clear events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get total count of SOS events
  Future<int> getEventCount() async {
    try {
      return await _repository.getEventCount();
    } catch (e) {
      _error = 'Failed to get event count: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Get a specific event by ID
  Future<SOSEvent?> getEvent(String id) async {
    try {
      return await _repository.getEvent(id);
    } catch (e) {
      _error = 'Failed to get event: $e';
      notifyListeners();
      return null;
    }
  }

  /// Clear error message
  Future<void> clearError() async {
    _error = null;
    notifyListeners();
  }

  /// Get formatted event status
  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳ Pending';
      case 'sent':
        return '✅ Sent';
      case 'failed':
        return '❌ Failed';
      case 'cancelled':
        return '⊘ Cancelled';
      default:
        return '❓ Unknown';
    }
  }
}
