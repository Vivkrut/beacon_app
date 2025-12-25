import 'package:get_it/get_it.dart';
import '../services/wizard_service.dart';
import '../../features/contacts/data/contact_repository.dart';
import '../../features/contacts/presentation/notifiers/contact_notifier.dart';
import '../../features/blackbox/data/blackbox_repository.dart';
import '../../features/blackbox/presentation/notifiers/blackbox_notifier.dart';

final getIt = GetIt.instance;

/// Initialize all services and repositories
Future<void> setupServiceLocator() async {
  // Initialize WizardService
  await WizardService.init();

  // Register repositories
  getIt.registerSingleton<ContactRepository>(ContactRepository());
  getIt.registerSingleton<BlackBoxRepository>(BlackBoxRepository());

  // Register notifiers
  getIt.registerSingleton<ContactNotifier>(
    ContactNotifier(getIt<ContactRepository>()),
  );
  getIt.registerSingleton<BlackBoxNotifier>(
    BlackBoxNotifier(getIt<BlackBoxRepository>()),
  );

  // TODO: Register additional services
  // getIt.registerSingleton<SOSManager>(...);
}
