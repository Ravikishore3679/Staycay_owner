import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'data/repositories/firestore_registry_repository.dart';
import 'presentation/theme/app_colors.dart';
import 'presentation/viewmodels/auth_view_model.dart';
import 'presentation/viewmodels/registry_view_model.dart';
import 'presentation/views/login_screen.dart';
import 'presentation/views/Profile_screen.dart';
import 'presentation/views/registry_home_page.dart';
import 'services/auth_service.dart';

class GuestHouseRegistryApp extends StatefulWidget {
  const GuestHouseRegistryApp({super.key});

  @override
  State<GuestHouseRegistryApp> createState() => _GuestHouseRegistryAppState();
}

class _GuestHouseRegistryAppState extends State<GuestHouseRegistryApp> {
  String _guestHouseName = 'Guest House Registry';
  String _guestHouseAddress = '';
  Uint8List? _guestHousePhotoBytes;
  bool _isProfileCompleted = false;

  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _registryViewModel = RegistryViewModel(
      repository: FirestoreRegistryRepository(),
    );
    _authViewModel = AuthViewModel(authService: AuthService());
    _authViewModel.startListening(
      onUserChanged: (_) {
        _registryViewModel.loadData();
      },
    );
  }

  @override
  void dispose() {
    _authViewModel.dispose();
    _registryViewModel.dispose();
    super.dispose();
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
        ).copyWith(
          primary: AppColors.brandPrimary,
          surface: AppColors.dashboardCard,
          onSurface: AppColors.dashboardText,
        ),
        scaffoldBackgroundColor: AppColors.appBackground,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.dashboardCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: _authViewModel,
        builder: (context, _) {
          final user = _authViewModel.user;

          if (user == null) {
            _isProfileCompleted = false;
            return LoginScreen(authViewModel: _authViewModel);
          }

          if (!_isProfileCompleted) {
            return ProfileScreen(
              initialName: _guestHouseName == 'Guest House Registry'
                  ? ''
                  : _guestHouseName,
              initialAddress: _guestHouseAddress,
              initialPhotoBytes: _guestHousePhotoBytes,
              onContinue: ({
                required String name,
                required String address,
                required Uint8List photoBytes,
              }) async {
                if (!mounted) return;
                setState(() {
                  _guestHouseName = name;
                  _guestHouseAddress = address;
                  _guestHousePhotoBytes = photoBytes;
                  _isProfileCompleted = true;
                });
              },
            );
          }

          return RegistryHomePage(
            guestHouseName: _guestHouseName,
            guestHouseAddress: _guestHouseAddress,
            guestHousePhotoBytes: _guestHousePhotoBytes,
            onGuestHouseNameChanged: (value) {
              setState(() {
                _guestHouseName = value;
              });
            },
            registryViewModel: _registryViewModel,
            authViewModel: _authViewModel,
          );
        },
      ),
    );
  }
}
