import 'package:flutter/material.dart';
import 'package:beacon/core/models/contact.dart';

class PostSOSScreen extends StatefulWidget {
  final Contact? primaryContact;
  final VoidCallback onCallNow;
  final VoidCallback onSirenToggle;
  final bool sirenActive;

  const PostSOSScreen({
    Key? key,
    this.primaryContact,
    required this.onCallNow,
    required this.onSirenToggle,
    this.sirenActive = false,
  }) : super(key: key);

  @override
  State<PostSOSScreen> createState() => _PostSOSScreenState();
}

class _PostSOSScreenState extends State<PostSOSScreen> {
  late bool _sirenActive;

  @override
  void initState() {
    super.initState();
    _sirenActive = widget.sirenActive;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        appBar: AppBar(
          title: const Text(
            'SOS ACTIVATED',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          backgroundColor: Colors.red,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ✅ Status Icon
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const SizedBox(height: 24),

                // Status Text
                const Text(
                  'SOS ALERT SENT',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Emergency contacts have been notified',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 40),

                // Primary Contact Info Card
                if (widget.primaryContact != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PRIMARY CONTACT CALLED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.shade100,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.primaryContact!.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.primaryContact!.phone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.shade100,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: const Text(
                      '⚠️ No primary contact set. Please add a contact in Settings.',
                      style: TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 60),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // CALL NOW Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onCallNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.phone, size: 28),
                          label: const Text(
                            'CALL NOW',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // SIREN Toggle Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _sirenActive = !_sirenActive;
                            });
                            widget.onSirenToggle();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sirenActive
                                ? Colors.orange
                                : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: Icon(
                            _sirenActive ? Icons.volume_up : Icons.volume_off,
                            size: 28,
                          ),
                          label: Text(
                            _sirenActive ? 'SIREN ON' : 'SIREN OFF',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Return to Home Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('RETURN TO HOME'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey, width: 2),
                        foregroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
