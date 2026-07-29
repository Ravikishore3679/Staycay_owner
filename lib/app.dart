import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data/repositories/firestore_registry_repository.dart';
import 'data/repositories/guest_house_profile_repository.dart';
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
  bool _isProfileLoading = false;

  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;
  late final GuestHouseProfileRepository _guestHouseProfileRepository;
  int _profileLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _registryViewModel = RegistryViewModel(
      repository: FirestoreRegistryRepository(),
    );
    _guestHouseProfileRepository = GuestHouseProfileRepository();
    _authViewModel = AuthViewModel(authService: AuthService());
    _authViewModel.startListening(
      onUserChanged: (_) {
        _registryViewModel.loadData();
        _loadGuestHouseProfile();
      },
      onSignedOut: _resetGuestHouseProfile,
    );
  }

  void _resetGuestHouseProfile() {
    setState(() {
      _guestHouseName = 'Guest House Registry';
      _guestHouseAddress = '';
      _guestHousePhotoBytes = null;
      _isProfileCompleted = false;
      _isProfileLoading = false;
      _profileLoadToken++;
    });
  }

  Future<void> _loadGuestHouseProfile() async {
    final user = _authViewModel.user;
    if (user == null) return;

    final loadToken = ++_profileLoadToken;
    if (!mounted) return;

    setState(() {
      _isProfileLoading = true;
    });

    try {
      final profile = await _guestHouseProfileRepository.loadProfile(
        uid: user.uid,
      );

      if (!mounted || loadToken != _profileLoadToken) return;

      setState(() {
        if (profile == null) {
          _guestHouseName = 'Guest House Registry';
          _guestHouseAddress = '';
          _guestHousePhotoBytes = null;
          _isProfileCompleted = false;
        } else {
          _guestHouseName = profile.name;
          _guestHouseAddress = profile.address;
          _guestHousePhotoBytes = profile.photoBytes;
          _isProfileCompleted = true;
        }

        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted || loadToken != _profileLoadToken) return;

      setState(() {
        _guestHouseName = 'Guest House Registry';
        _guestHouseAddress = '';
        _guestHousePhotoBytes = null;
        _isProfileCompleted = false;
        _isProfileLoading = false;
      });
    }
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
            return LoginScreen(authViewModel: _authViewModel);
          }

          if (_isProfileLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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
                final currentUser = _authViewModel.user;
                if (currentUser == null) return;

                await _guestHouseProfileRepository.saveProfile(
                  uid: currentUser.uid,
                  name: name,
                  address: address,
                  photoBytes: photoBytes,
                  email: currentUser.email,
                );

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
            onGuestHouseNameChanged: (value) async {
              final currentUser = _authViewModel.user;
              if (currentUser == null) return;

              final currentPhotoBytes = _guestHousePhotoBytes;
              if (currentPhotoBytes == null) {
                throw StateError('Guest house photo is missing.');
              }

              await _guestHouseProfileRepository.saveProfile(
                uid: currentUser.uid,
                name: value,
                address: _guestHouseAddress,
                photoBytes: currentPhotoBytes,
                email: currentUser.email,
              );

              if (!mounted) return;
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
