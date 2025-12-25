import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Manages first-time user wizard state with persistent storage
class WizardService {
  static late SharedPreferences _prefs;
  static bool _initialized = false;

  /// Initialize WizardService (call once at app startup)
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (e) {
      print('⚠️ WizardService init failed: $e');
      _initialized = false;
    }
  }

  /// Check if user should see the onboarding wizard
  static Future<bool> shouldShowWizard() async {
    try {
      // If not initialized, initialize now
      if (!_initialized) {
        await init();
      }
      if (!_initialized) return false;
      return !(_prefs.getBool(AppConstants.prefKeyWizardCompleted) ?? false);
    } catch (e) {
      print('⚠️ shouldShowWizard error: $e');
      return false;
    }
  }

  /// Mark the entire wizard as completed
  static Future<void> completeWizard() async {
    await _prefs.setBool(AppConstants.prefKeyWizardCompleted, true);
  }

  /// Reset wizard state (for development/testing)
  static Future<void> resetWizard() async {
    await _prefs.remove(AppConstants.prefKeyWizardCompleted);
    await _prefs.remove(AppConstants.prefKeyWizardStep1);
    await _prefs.remove(AppConstants.prefKeyWizardStep2);
    await _prefs.remove(AppConstants.prefKeyWizardStep3);
  }

  /// Mark individual step as completed
  static Future<void> completeStep(int stepNumber) async {
    switch (stepNumber) {
      case 1:
        await _prefs.setBool(AppConstants.prefKeyWizardStep1, true);
        break;
      case 2:
        await _prefs.setBool(AppConstants.prefKeyWizardStep2, true);
        break;
      case 3:
        await _prefs.setBool(AppConstants.prefKeyWizardStep3, true);
        break;
    }
  }

  /// Check if a specific step is completed
  static Future<bool> isStepCompleted(int stepNumber) async {
    switch (stepNumber) {
      case 1:
        return _prefs.getBool(AppConstants.prefKeyWizardStep1) ?? false;
      case 2:
        return _prefs.getBool(AppConstants.prefKeyWizardStep2) ?? false;
      case 3:
        return _prefs.getBool(AppConstants.prefKeyWizardStep3) ?? false;
      default:
        return false;
    }
  }
}
