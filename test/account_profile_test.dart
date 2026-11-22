import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/data/repositories/account_profile_repository.dart';
import 'package:heavenrock_registry/data/repositories/registry_repository.dart';
import 'package:heavenrock_registry/presentation/viewmodels/auth_view_model.dart';
import 'package:heavenrock_registry/presentation/viewmodels/registry_view_model.dart';
import 'package:heavenrock_registry/presentation/views/account_profile_screen.dart';
import 'package:heavenrock_registry/presentation/views/registry_home_page.dart';
import 'package:heavenrock_registry/services/auth_service.dart';

class _User implements User {
  @override
  String get uid => 'user-1';
  @override
  String? get displayName => 'Original Name';
  @override
  String? get email => 'login@example.com';
  @override
  String? get phoneNumber => '+15551234567';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements AccountProfileRepository {
  final changes = StreamController<AccountProfile?>.broadcast();
  AccountProfile? profile;
  bool failSave = false;
  bool failRead = false;
  String? savedUid;

  @override
  Future<void> createProfileIfAbsent(String uid, AccountProfile value) async {
    if (failSave) throw StateError('save failed');
    profile ??= value;
    changes.add(profile);
  }

  @override
  Stream<AccountProfile?> watchProfile(String uid) async* {
    if (failRead) throw StateError('read failed');
    yield profile;
    yield* changes.stream;
  }

  @override
  Future<void> saveProfile(String uid, AccountProfile value) async {
    if (failSave) throw StateError('save failed');
    savedUid = uid;
    profile = value;
    changes.add(value);
  }
}

class _AuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthViewModel {
  _Auth(this.testUser) : super(authService: _AuthService());
  final User testUser;
  bool signedOut = false;

  @override
  Stream<User?> authStateChanges() => Stream.value(testUser);

  @override
  Future<void> signOut() async => signedOut = true;
}

class _RegistryRepository implements RegistryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Accounts accounts;
  late _Auth auth;
  late User user;

  setUp(() {
    accounts = _Accounts();
    user = _User();
    auth = _Auth(user);
  });
  tearDown(() {
    accounts.changes.close();
    auth.dispose();
  });

  Future<void> openPage(
    WidgetTester tester, {
    Future<Uint8List?> Function()? pickPhoto,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountProfileScreen(
          user: user,
          repository: accounts,
          authViewModel: auth,
          pickPhoto: pickPhoto,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('profile avatar opens profile and updates after editing', (
    tester,
  ) async {
    final controller = RegistryViewModel(repository: _RegistryRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RegistryHomePage(
          guestHouseName: 'Test house',
          guestHouseAddress: 'Test address',
          guestHousePhotoBytes: null,
          registryViewModel: controller,
          authViewModel: auth,
          accountProfileRepository: accounts,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test house'), findsOneWidget);
    expect(find.text('Test address'), findsOneWidget);
    expect(find.byTooltip('Edit guest house name'), findsNothing);
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.home_work_outlined)),
      findsNothing,
    );
    expect(
      find.descendant(of: appBar, matching: find.byType(CircleAvatar)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text('Test house')).style?.fontWeight, FontWeight.w700);
    await tester.tap(find.byTooltip('My profile'));
    await tester.pumpAndSettle();
    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('login@example.com'), findsOneWidget);
    expect(find.text('+15551234567'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'New Name',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '+91 9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'contact@example.com',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.savedUid, 'user-1');
    expect(accounts.profile?.name, 'New Name');
    expect(accounts.profile?.phone, '+91 9876543210');
    expect(accounts.profile?.email, 'contact@example.com');
    expect(find.text('contact@example.com'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byTooltip('My profile'),
        matching: find.text('N'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('validates input and preserves edits when saving fails', (
    tester,
  ) async {
    await openPage(tester);
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      'bad',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bad');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(accounts.profile, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Valid Name',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), '');
    accounts.failSave = true;
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save profile'), findsOneWidget);
    expect(find.text('Valid Name'), findsOneWidget);
    accounts.failSave = false;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.name, 'Valid Name');
  });

  testWidgets('photo can be saved and removed', (tester) async {
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    );
    await openPage(tester, pickPhoto: () async => image);
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add photo'));
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.photoBytes, image);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove photo'));
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.photoBytes, isNull);
  });

  testWidgets('read errors can be retried', (tester) async {
    accounts.failRead = true;
    await openPage(tester);
    expect(find.textContaining('Unable to load profile'), findsOneWidget);
    accounts.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Original Name'), findsNWidgets(2));
  });

  testWidgets('rejects oversized photos without losing the form', (
    tester,
  ) async {
    await openPage(tester, pickPhoto: () async => Uint8List(500001));
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add photo'));
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a photo smaller than 500 KB.'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('sign out remains available on the profile page', (tester) async {
    final controller = RegistryViewModel(repository: _RegistryRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RegistryHomePage(
          guestHouseName: 'Test house',
          guestHouseAddress: 'Test address',
          guestHousePhotoBytes: null,
          registryViewModel: controller,
          authViewModel: auth,
          accountProfileRepository: accounts,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
    expect(find.text('My profile'), findsNothing);
  });
}
