import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/presentation/viewmodels/auth_view_model.dart';
import 'package:heavenrock_registry/presentation/views/login_screen.dart';
import 'package:heavenrock_registry/services/auth_service.dart';

class _AuthService implements AuthService {
  int creates = 0;
  int signsIn = 0;
  int googleCalls = 0;
  String? email;
  String? password;
  Object? error;
  Completer<void>? pending;

  Future<void> _execute() async {
    if (error != null) throw error!;
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    creates++;
    this.email = email;
    this.password = password;
    await _execute();
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signsIn++;
    this.email = email;
    this.password = password;
    await _execute();
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    await _execute();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _AuthService service;
  late AuthViewModel auth;

  setUp(() {
    service = _AuthService();
    auth = AuthViewModel(authService: service);
  });
  tearDown(() => auth.dispose());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authViewModel: auth)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('creates an email account and prevents duplicate submissions', (
    tester,
  ) async {
    await start(tester);
    await tapVisible(tester, 'Create account with email');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      ' owner@example.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret12',
    );
    service.pending = Completer<void>();
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(service.creates, 1);
    expect(service.email, 'owner@example.com');
    expect(service.password, 'secret12');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Please wait...'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Other sign-in options'),
          )
          .onPressed,
      isNull,
    );
    service.pending!.complete();
    await tester.pumpAndSettle();
    expect(auth.isBusy, isFalse);
  });

  testWidgets('validates account inputs and shows Firebase errors', (
    tester,
  ) async {
    await start(tester);
    await tapVisible(tester, 'Create account with email');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bad');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different',
    );
    await tapVisible(tester, 'Create account');
    expect(service.creates, 0);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret12',
    );
    service.error = FirebaseAuthException(
      code: 'email-already-in-use',
      message: 'Email is already in use',
    );
    await tapVisible(tester, 'Create account');
    expect(
      find.textContaining('Account creation failed: Email is already in use'),
      findsOneWidget,
    );
    await tapVisible(tester, 'Already have an account? Sign in');
    expect(find.textContaining('Account creation failed'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Confirm password'),
      findsNothing,
    );
  });

  testWidgets('existing email accounts and Google can sign in', (tester) async {
    await start(tester);
    await tapVisible(tester, 'Sign in with email');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret12',
    );
    await tapVisible(tester, 'Sign in');
    expect(service.signsIn, 1);
    expect(service.email, 'owner@example.com');
    await tapVisible(tester, 'Other sign-in options');
    await tapVisible(tester, 'Continue with Google');
    expect(service.googleCalls, 1);
  });
}
