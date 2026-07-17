import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this.authService});

  final AuthService authService;
  StreamSubscription<User?>? _authSub;

  User? _user;
  String? _errorMessage;

  User? get user => _user;
  String? get errorMessage => _errorMessage;

  Stream<User?> authStateChanges() => authService.authStateChanges();

  void startListening({void Function(String uid)? onUserChanged}) {
    _authSub?.cancel();
    _user = authService.currentUser;

    _authSub = authService.authStateChanges().listen((user) {
      final previousUid = _user?.uid;
      _user = user;
      _errorMessage = null;
      notifyListeners();

      final currentUid = user?.uid;
      if (currentUid != null && currentUid != previousUid) {
        onUserChanged?.call(currentUid);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      await authService.signInWithGoogle();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Google sign-in failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOutToAnonymous() async {
    try {
      await authService.signOutToAnonymous();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sign-out failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
