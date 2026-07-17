import 'package:flutter/material.dart';

import 'data/repositories/firestore_registry_repository.dart';
import 'presentation/theme/app_colors.dart';
import 'presentation/viewmodels/auth_view_model.dart';
import 'presentation/viewmodels/registry_view_model.dart';
import 'presentation/views/registry_home_page.dart';
import 'services/auth_service.dart';

class GuestHouseRegistryApp extends StatefulWidget {
  const GuestHouseRegistryApp({super.key});

  @override
  State<GuestHouseRegistryApp> createState() => _GuestHouseRegistryAppState();
}

class _GuestHouseRegistryAppState extends State<GuestHouseRegistryApp> {
  String _guestHouseName = 'Guest House Registry';

  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _registryViewModel = RegistryViewModel(
      repository: FirestoreRegistryRepository(),
    );
    _authViewModel = AuthViewModel(authService: AuthService());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _guestHouseName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandPrimary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.appBackground,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: RegistryHomePage(
        guestHouseName: _guestHouseName,
        onGuestHouseNameChanged: (value) {
          setState(() {
            _guestHouseName = value;
          });
        },
        registryViewModel: _registryViewModel,
        authViewModel: _authViewModel,
      ),
    );
  }
}
