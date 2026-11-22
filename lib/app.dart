import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data/repositories/firestore_registry_repository.dart';
import 'data/repositories/account_profile_repository.dart';
import 'data/repositories/guest_house_profile_repository.dart';
import 'presentation/theme/app_colors.dart';
import 'presentation/viewmodels/auth_view_model.dart';
import 'presentation/viewmodels/registry_view_model.dart';
import 'presentation/views/login_screen.dart';
import 'presentation/views/account_profile_screen.dart';
import 'presentation/views/registry_home_page.dart';
import 'services/auth_service.dart';

class GuestHouseRegistryApp extends StatefulWidget {
  const GuestHouseRegistryApp({
    super.key,
    this.registryViewModel,
    this.authViewModel,
    this.guestHouseProfileRepository,
    this.accountProfileRepository,
  });

  final RegistryViewModel? registryViewModel;
  final AuthViewModel? authViewModel;
  final GuestHouseProfileRepository? guestHouseProfileRepository;
  final AccountProfileRepository? accountProfileRepository;

  @override
  State<GuestHouseRegistryApp> createState() => _GuestHouseRegistryAppState();
}

class _GuestHouseRegistryAppState extends State<GuestHouseRegistryApp> {
  String _guestHouseName = 'Guest House Registry';
  String _guestHouseAddress = '';
  Uint8List? _guestHousePhotoBytes;
  bool _isProfileLoading = false;
  bool _needsAccountSetup = false;
  String? _profileLoadError;
  Stream<AccountProfile?>? _accountProfileStream;

  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;
  late final GuestHouseProfileRepository _guestHouseProfileRepository;
  late final AccountProfileRepository _accountProfileRepository;
  int _profileLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _registryViewModel =
        widget.registryViewModel ??
        RegistryViewModel(repository: FirestoreRegistryRepository());
    _guestHouseProfileRepository =
        widget.guestHouseProfileRepository ?? GuestHouseProfileRepository();
    _accountProfileRepository =
        widget.accountProfileRepository ?? FirestoreAccountProfileRepository();
    _authViewModel =
        widget.authViewModel ?? AuthViewModel(authService: AuthService());
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
      _isProfileLoading = false;
      _needsAccountSetup = false;
      _profileLoadError = null;
      _accountProfileStream = null;
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
      _profileLoadError = null;
    });

    try {
      final profile = await _guestHouseProfileRepository.loadProfile(
        uid: user.uid,
      );
      final accountProfile = profile == null
          ? await _accountProfileRepository.watchProfile(user.uid).first
          : null;

      if (!mounted || loadToken != _profileLoadToken) return;

      setState(() {
        if (profile == null) {
          _guestHouseName = 'Guest House Registry';
          _guestHouseAddress = '';
          _guestHousePhotoBytes = null;
        } else {
          _guestHouseName = profile.name;
          _guestHouseAddress = profile.address;
          _guestHousePhotoBytes = profile.photoBytes;
        }
        _needsAccountSetup = profile == null && accountProfile == null;
        _accountProfileStream = _accountProfileRepository.watchProfile(user.uid);

        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted || loadToken != _profileLoadToken) return;

      setState(() {
        _profileLoadError = 'Unable to load guest house details: $e';
        _isProfileLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.authViewModel == null) _authViewModel.dispose();
    if (widget.registryViewModel == null) _registryViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _guestHouseName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: AppColors.brandPrimary,
              brightness: Brightness.light,
            ).copyWith(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              secondary: AppColors.revenueDark,
              surface: Colors.white,
              onSurface: AppColors.textStrong,
              onSurfaceVariant: const Color(0xFF64748B),
            ),
        scaffoldBackgroundColor: AppColors.appBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textStrong,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8FAFC),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.brandPrimary, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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

          if (_profileLoadError != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_profileLoadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadGuestHouseProfile,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await _authViewModel.signOut();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sign-out failed: $e')),
                            );
                          }
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (_needsAccountSetup) {
            return AccountProfileScreen(
              user: user,
              repository: _accountProfileRepository,
              authViewModel: _authViewModel,
              onboarding: true,
              onComplete: () => setState(() => _needsAccountSetup = false),
            );
          }

          return StreamBuilder<AccountProfile?>(
            key: ValueKey(user.uid),
            stream: _accountProfileStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Unable to load account profile: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadGuestHouseProfile,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await _authViewModel.signOut();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sign-out failed: $e')),
                                );
                              }
                            },
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final name = snapshot.data?.guestHouseName.trim() ?? '';
              return RegistryHomePage(
                guestHouseName: name.isEmpty ? _guestHouseName : name,
                guestHouseAddress:
                    snapshot.data?.guestHouseAddress ?? _guestHouseAddress,
                guestHousePhotoBytes: _guestHousePhotoBytes,
                registryViewModel: _registryViewModel,
                authViewModel: _authViewModel,
                accountProfileRepository: _accountProfileRepository,
              );
            },
          );
        },
      ),
    );
  }
}
