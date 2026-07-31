import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';


// Globally accessible player instance


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService().clearAnonymousSession();
  
  // Optional: Pre-set a background configuration if needed before app starts
  
  runApp(const GuestHouseRegistryApp());
}
