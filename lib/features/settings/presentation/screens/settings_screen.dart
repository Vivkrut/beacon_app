import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:beacon/core/constants/app_constants.dart';
import 'package:beacon/features/blackbox/presentation/screens/blackbox_history_screen.dart';
import 'package:beacon/features/contacts/presentation/screens/contact_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _phone3Controller;
  late TextEditingController _emergencyMessageController;
  String _selectedSensitivity = 'MEDIUM';
  int _priorityContactIndex = 0;
  final _formKey = GlobalKey<FormState>();
  bool _hasUnsavedChanges = false;

  // Store contact names from phone book
  String? _contact1Name;
  String? _contact2Name;
  String? _contact3Name;

  // Store original values to detect changes
  String _originalName = '';
  String _originalPhone1 = '';
  String _originalPhone2 = '';
  String _originalPhone3 = '';
  String _originalSensitivity = 'MEDIUM';
  int _originalPriorityIndex = 0;
  String _originalEmergencyMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phone1Controller = TextEditingController();
    _phone2Controller = TextEditingController();
    _phone3Controller = TextEditingController();
    _emergencyMessageController = TextEditingController();

    // Add listeners to detect changes
    _nameController.addListener(() {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = _checkForChanges();
        });
      }
    });
    _phone1Controller.addListener(() {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = _checkForChanges();
        });
      }
    });
    _phone2Controller.addListener(() {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = _checkForChanges();
        });
      }
    });
    _phone3Controller.addListener(() {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = _checkForChanges();
        });
      }
    });
    _emergencyMessageController.addListener(() {
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = _checkForChanges();
        });
      }
    });

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      // Load and normalize phone numbers
      _phone1Controller.text = _normalizePhoneNumber(
        prefs.getString('contact_1_phone') ?? '',
      );
      _phone2Controller.text = _normalizePhoneNumber(
        prefs.getString('contact_2_phone') ?? '',
      );
      _phone3Controller.text = _normalizePhoneNumber(
        prefs.getString('contact_3_phone') ?? '',
      );
      _emergencyMessageController.text =
          prefs.getString('emergency_message') ??
          AppConstants.defaultEmergencyMessage;
      _selectedSensitivity = prefs.getString('shake_sensitivity') ?? 'MEDIUM';
      _priorityContactIndex = prefs.getInt('priority_contact_index') ?? 0;

      // Store original values for change detection
      _originalName = _nameController.text;
      _originalPhone1 = _phone1Controller.text;
      _originalPhone2 = _phone2Controller.text;
      _originalPhone3 = _phone3Controller.text;
      _originalEmergencyMessage = _emergencyMessageController.text;
      _originalSensitivity = _selectedSensitivity;
      _originalPriorityIndex = _priorityContactIndex;
      _hasUnsavedChanges = false;
    });
  }

  bool _checkForChanges() {
    return _nameController.text != _originalName ||
        _phone1Controller.text != _originalPhone1 ||
        _phone2Controller.text != _originalPhone2 ||
        _phone3Controller.text != _originalPhone3 ||
        _emergencyMessageController.text != _originalEmergencyMessage ||
        _selectedSensitivity != _originalSensitivity ||
        _priorityContactIndex != _originalPriorityIndex;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Do you want to save them before leaving?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _phone3Controller.dispose();
    _emergencyMessageController.dispose();
    super.dispose();
  }

  String? _validateIndianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }
    if (RegExp(r'^\+91[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }
    return 'Invalid Indian mobile number';
  }

  String _normalizePhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (!cleaned.startsWith('+91') && cleaned.length == 10) {
      return '+91$cleaned';
    }
    return cleaned.startsWith('+91') ? cleaned : phone;
  }

  bool _isContactValid(TextEditingController controller) {
    return controller.text.isNotEmpty &&
        _validateIndianPhone(controller.text) == null;
  }

  bool _isContact2Enabled() => _isContactValid(_phone1Controller);
  bool _isContact3Enabled() =>
      _isContact2Enabled() && _isContactValid(_phone2Controller);

  void _setPriorityContact(int index) {
    final controllers = [
      _phone1Controller,
      _phone2Controller,
      _phone3Controller,
    ];

    // Block setting priority on an empty contact slot
    if (controllers[index].text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contact ${index + 1} is empty. Add a number first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Toggle: if already primary, unmark; otherwise mark as primary
    setState(() {
      if (_priorityContactIndex == index) {
        // If clicking same contact, unmark it
        _priorityContactIndex = -1;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Priority contact removed'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        // Mark as primary
        _priorityContactIndex = index;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact ${index + 1} set as priority'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _hasUnsavedChanges = _checkForChanges();
    });
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_phone1Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least Contact 1 phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for duplicate phone numbers
    final phones = [
      _normalizePhoneNumber(_phone1Controller.text),
      _normalizePhoneNumber(_phone2Controller.text),
      _normalizePhoneNumber(_phone3Controller.text),
    ];

    final nonEmptyPhones = phones.where((p) => p.isNotEmpty).toList();
    if (nonEmptyPhones.length != nonEmptyPhones.toSet().length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Duplicate phone numbers not allowed. Each contact must be unique.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _saveToPreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings Saved'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final phone1 = _normalizePhoneNumber(_phone1Controller.text);
    final phone2 = _normalizePhoneNumber(_phone2Controller.text);
    final phone3 = _normalizePhoneNumber(_phone3Controller.text);

    int priorityIndex = _priorityContactIndex;
    if (priorityIndex != -1) {
      final controllers = [
        _phone1Controller,
        _phone2Controller,
        _phone3Controller,
      ];
      if (!_isContactValid(controllers[priorityIndex])) {
        priorityIndex = -1;
      }
    }

    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('contact_1_phone', phone1);
    await prefs.setString('contact_2_phone', phone2);
    await prefs.setString('contact_3_phone', phone3);
    await prefs.setString(
      'emergency_message',
      _emergencyMessageController.text,
    );
    await prefs.setString('shake_sensitivity', _selectedSensitivity);
    await prefs.setInt('priority_contact_index', priorityIndex);

    // Update original values after save
    setState(() {
      _originalName = _nameController.text;
      _originalPhone1 = phone1;
      _originalPhone2 = phone2;
      _originalPhone3 = phone3;
      _originalEmergencyMessage = _emergencyMessageController.text;
      _originalSensitivity = _selectedSensitivity;
      _originalPriorityIndex = priorityIndex;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _pickContactFromPhonebook(int contactIndex) async {
    try {
      final picker = FlutterNativeContactPicker();
      final Contact? contact = await picker.selectContact();

      if (contact != null &&
          contact.phoneNumbers != null &&
          contact.phoneNumbers!.isNotEmpty) {
        final phoneNum = contact.phoneNumbers!.first.replaceAll(
          RegExp(r'[\s\-()]'),
          '',
        );
        final normalizedPhoneNum = _normalizePhoneNumber(phoneNum);
        final contactName = contact.fullName ?? 'Contact';
        final controllers = [
          _phone1Controller,
          _phone2Controller,
          _phone3Controller,
        ];

        // Check for duplicate phone number
        for (int i = 0; i < controllers.length; i++) {
          if (i != contactIndex) {
            final existingPhone = _normalizePhoneNumber(controllers[i].text);
            if (existingPhone.isNotEmpty &&
                existingPhone == normalizedPhoneNum) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ This phone number is already added as Contact ${i + 1}',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              return; // Prevent adding duplicate
            }
          }
        }

        final namesList = [
          () => _contact1Name = contactName,
          () => _contact2Name = contactName,
          () => _contact3Name = contactName,
        ];

        setState(() {
          controllers[contactIndex].text = phoneNum;
          namesList[contactIndex]();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Contact ${contactIndex + 1} updated: $contactName',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (_) {
      // Silently handle errors (e.g., permission denied, cancelled)
    }
  }

  void _clearContact(int contactIndex) {
    // Check if this is the primary contact
    if (_priorityContactIndex == contactIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Cannot delete primary contact. Set another contact as primary first.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return; // Don't proceed with deletion
    }

    setState(() {
      final controllers = [
        _phone1Controller,
        _phone2Controller,
        _phone3Controller,
      ];
      final namesList = [
        () => _contact1Name = null,
        () => _contact2Name = null,
        () => _contact3Name = null,
      ];

      // Shift all contacts below up by one
      if (contactIndex == 0) {
        controllers[0].text = controllers[1].text;
        controllers[1].text = controllers[2].text;
        controllers[2].clear();

        _contact1Name = _contact2Name;
        _contact2Name = _contact3Name;
        _contact3Name = null;

        // Adjust priority index if needed
        if (_priorityContactIndex > 0) {
          _priorityContactIndex--;
        }
      } else if (contactIndex == 1) {
        controllers[1].text = controllers[2].text;
        controllers[2].clear();

        _contact2Name = _contact3Name;
        _contact3Name = null;

        // Adjust priority index if needed
        if (_priorityContactIndex > 1) {
          _priorityContactIndex--;
        }
      } else if (contactIndex == 2) {
        controllers[2].clear();
        _contact3Name = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact ${contactIndex + 1} cleared, contacts shifted up',
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _nameController.clear();
                _phone1Controller.clear();
                _phone2Controller.clear();
                _phone3Controller.clear();
                _emergencyMessageController.text =
                    AppConstants.defaultEmergencyMessage;
                _selectedSensitivity = 'MEDIUM';
                _priorityContactIndex = -1;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_checkForChanges()) {
          final shouldSave = await _showUnsavedChangesDialog();
          if (shouldSave) {
            _saveSettings();
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_checkForChanges()) {
                final shouldSave = await _showUnsavedChangesDialog();
                if (shouldSave) {
                  _saveSettings();
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people_alt),
              tooltip: 'Manage Contacts',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactListScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'View SOS Event History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlackBoxHistoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Your Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    if (value.length < 2) {
                      return 'Minimum 2 characters';
                    }
                    if (RegExp(r'\d').hasMatch(value)) {
                      return 'Letters and spaces only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Emergency Contacts'),
                _buildContactField(0, _phone1Controller, 'Contact 1', true),
                const SizedBox(height: 16),
                _buildContactField(
                  1,
                  _phone2Controller,
                  'Contact 2',
                  _isContact2Enabled(),
                ),
                const SizedBox(height: 16),
                _buildContactField(
                  2,
                  _phone3Controller,
                  'Contact 3',
                  _isContact3Enabled(),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Shake Sensitivity'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSensitivity,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: AppConstants.shakeSensitivityLevels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedSensitivity = v;
                          _hasUnsavedChanges = _checkForChanges();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Emergency Message'),
                TextFormField(
                  controller: _emergencyMessageController,
                  decoration: InputDecoration(
                    hintText: 'Enter emergency message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText:
                        '${_emergencyMessageController.text.length}/280 characters',
                  ),
                  maxLines: 2,
                  maxLength: 280,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Emergency message cannot be empty';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saveSettings,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'SAVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'RESET',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildContactField(
    int index,
    TextEditingController controller,
    String label,
    bool enabled,
  ) {
    // Any contact can be marked as primary
    final isPrimary = _priorityContactIndex == index;
    final contactNameList = [_contact1Name, _contact2Name, _contact3Name];
    final contactName = contactNameList[index];
    final hasContact = controller.text.isNotEmpty;

    // Check for duplicate
    bool isDuplicate = false;
    if (hasContact) {
      final normalizedCurrent = _normalizePhoneNumber(controller.text);
      final controllers = [
        _phone1Controller,
        _phone2Controller,
        _phone3Controller,
      ];
      for (int i = 0; i < controllers.length; i++) {
        if (i != index && controllers[i].text.isNotEmpty) {
          final normalizedOther = _normalizePhoneNumber(controllers[i].text);
          if (normalizedCurrent == normalizedOther) {
            isDuplicate = true;
            break;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        // Show contact name from phone book if available
        if (hasContact && contactName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contactName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Show duplicate warning if applicable
        if (isDuplicate)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Duplicate phone number detected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  decoration: InputDecoration(
                    hintText: 'Enter mobile number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDuplicate ? Colors.red : Colors.grey,
                        width: isDuplicate ? 2 : 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDuplicate ? Colors.red : Colors.grey,
                        width: isDuplicate ? 2 : 1,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (!enabled) return null;
                    if (isDuplicate) {
                      return 'Duplicate phone number';
                    }
                    return _validateIndianPhone(value);
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: enabled
                    ? () => _pickContactFromPhonebook(index)
                    : null,
              ),
              IconButton(
                icon: Icon(
                  isPrimary ? Icons.star : Icons.star_border,
                  color: isPrimary ? Colors.amber : Colors.grey,
                ),
                tooltip: isPrimary ? 'Remove as priority' : 'Set as priority',
                onPressed: () => _setPriorityContact(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                onPressed: hasContact ? () => _clearContact(index) : null,
                tooltip: 'Clear contact',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
