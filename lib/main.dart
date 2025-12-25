import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/service_locator.dart';
import 'core/services/wizard_service.dart';
import 'features/contacts/presentation/notifiers/contact_notifier.dart';
import 'features/blackbox/presentation/notifiers/blackbox_notifier.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await setupServiceLocator();
  } catch (e) {
    print('⚠️ Service locator setup failed: $e');
    // Continue anyway - app will handle missing services gracefully
  }
  runApp(const BeaconApp());
}

class BeaconApp extends StatelessWidget {
  const BeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<ContactNotifier>()),
        ChangeNotifierProvider(create: (_) => getIt<BlackBoxNotifier>()),
      ],
      child: MaterialApp(
        title: 'Beacon SOS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        home: const AppInitializer(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Initializes app with first-time user detection
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WizardService.shouldShowWizard(),
      builder: (context, snapshot) {
        // Handle errors gracefully
        if (snapshot.hasError) {
          print('⚠️ AppInitializer error: ${snapshot.error}');
          return const HomeScreen();
        }

        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Beacon SOS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Initializing...'),
                ],
              ),
            ),
          );
        }

        // For now, show HomeScreen regardless of first-time status
        // TODO: Show OnboardingWizardScreen when first-time user
        return const HomeScreen();
      },
    );
  }
}
