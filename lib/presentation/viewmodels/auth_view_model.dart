import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this.authService});

  final AuthService authService;
  StreamSubscription<User?>? _authSub;

  User? _user;
  String? _errorMessage;
  bool _isBusy = false;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  String? _pendingPhoneNumber;
  ConfirmationResult? _webConfirmationResult;

  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;
  bool get isSignedIn => _user != null;
  bool get hasPendingPhoneVerification =>
      _phoneVerificationId != null || _webConfirmationResult != null;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  Stream<User?> authStateChanges() => authService.authStateChanges();

  void startListening({void Function(String uid)? onUserChanged}) {
    _authSub?.cancel();
    _user = authService.currentUser;
    final initialUid = _user?.uid;
    if (initialUid != null) {
      onUserChanged?.call(initialUid);
    }

    _authSub = authService.authStateChanges().listen((user) {
      final previousUid = _user?.uid;
      _user = user;
      _errorMessage = null;
      if (user != null) {
        _clearPhoneState(notify: false);
      }
      notifyListeners();

      final currentUid = user?.uid;
      if (currentUid != null && currentUid != previousUid) {
        onUserChanged?.call(currentUid);
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(
      () => authService.signInWithEmail(email: email, password: password),
      errorPrefix: 'Email sign-in failed',
    );
  }

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(
      () =>
          authService.createAccountWithEmail(email: email, password: password),
      errorPrefix: 'Account creation failed',
    );
  }

  Future<void> signInWithGoogle() async {
    await _runAuthAction(
      authService.signInWithGoogle,
      errorPrefix: 'Google sign-in failed',
    );
  }

  Future<void> sendSmsCode(String phoneNumber) async {
    await _runAuthAction(() async {
      _clearPhoneState(notify: false);
      _pendingPhoneNumber = phoneNumber;

      if (kIsWeb) {
        _webConfirmationResult = await authService.signInWithPhoneNumberWeb(
          phoneNumber,
        );
        notifyListeners();
        return;
      }

      final completer = Completer<void>();

      await authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _phoneResendToken,
        verificationCompleted: (credential) async {
          try {
            await authService.signInWithPhoneCredential(credential);
            _clearPhoneState(notify: false);
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (exception) {
          if (!completer.isCompleted) {
            completer.completeError(exception);
          }
        },
        codeSent: (verificationId, resendToken) {
          _phoneVerificationId = verificationId;
          _phoneResendToken = resendToken;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _phoneVerificationId = verificationId;
          notifyListeners();
        },
      );

      await completer.future;
    }, errorPrefix: 'SMS verification failed');
  }

  Future<void> verifySmsCode(String smsCode) async {
    await _runAuthAction(() async {
      if (kIsWeb) {
        final confirmationResult = _webConfirmationResult;
        if (confirmationResult == null) {
          throw StateError('Request an SMS code before verifying it.');
        }
        await confirmationResult.confirm(smsCode);
      } else {
        final verificationId = _phoneVerificationId;
        if (verificationId == null) {
          throw StateError('Request an SMS code before verifying it.');
        }
        await authService.signInWithSmsCode(
          verificationId: verificationId,
          smsCode: smsCode,
        );
      }

      _clearPhoneState(notify: false);
    }, errorPrefix: 'SMS sign-in failed');
  }

  Future<void> signOut() async {
    await _runAuthAction(authService.signOut, errorPrefix: 'Sign-out failed');
  }

  void resetPhoneVerification() {
    _clearPhoneState();
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    required String errorPrefix,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(errorPrefix, e);
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _formatError(String errorPrefix, Object error) {
    if (error is FirebaseAuthException) {
      final message = error.message;
      return message == null || message.isEmpty
          ? errorPrefix
          : '$errorPrefix: $message';
    }

    return '$errorPrefix: $error';
  }

  void _clearPhoneState({bool notify = true}) {
    _phoneVerificationId = null;
    _phoneResendToken = null;
    _pendingPhoneNumber = null;
    _webConfirmationResult = null;

    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
