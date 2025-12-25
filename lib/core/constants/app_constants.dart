/// App-wide constants for Beacon SOS
class AppConstants {
  // SOS Manager
  static const int sosRateLimitMinutes = 5;
  static const int preOverlayCountdownSeconds = 10;
  static const int sosRequestTimeoutSeconds = 30;

  // Shake Detection
  static const int shakeLowSensitivity = 3;
  static const int shakeMediumSensitivity = 4;
  static const int shakeHighSensitivity = 6;

  // GPS
  static const int gpsTimeoutSeconds = 10;
  static const String unknownLocationPlaceholder = 'Unknown Location';

  // Database
  static const String contactsTableName = 'contacts';
  static const String sosEventsTableName = 'sos_events';

  // SharedPreferences Keys
  static const String prefKeyShakeSensitivity = 'shake_sensitivity';
  static const String prefKeyTestMode = 'test_mode_enabled';
  static const String prefKeyWizardCompleted = 'wizard_completed';
  static const String prefKeyWizardStep1 = 'wizard_step1_add_contact';
  static const String prefKeyWizardStep2 = 'wizard_step2_set_priority';
  static const String prefKeyWizardStep3 = 'wizard_step3_test_sos';

  // SMS
  static const int smsMaxRetries = 3;
  static const int smsRetryDelayMs = 2000;

  // Settings Defaults
  static const String defaultShakeSensitivity = 'MEDIUM';
  static const String defaultEmergencyMessage =
      'EMERGENCY: I need help! Please reach ASAP! [LOCATION]';

  // Shake Sensitivity Levels
  static final Map<String, String> shakeSensitivityLevels = {
    'LOW': 'LOW: 3 Shakes',
    'MEDIUM': 'MEDIUM: 4 Shakes (Recommended)',
    'HIGH': 'HIGH: 6 Shakes',
  };
}
