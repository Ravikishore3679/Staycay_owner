import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/app.dart';
import 'package:heavenrock_registry/data/repositories/account_profile_repository.dart';
import 'package:heavenrock_registry/data/repositories/guest_house_profile_repository.dart';
import 'package:heavenrock_registry/data/repositories/registry_repository.dart';
import 'package:heavenrock_registry/presentation/viewmodels/auth_view_model.dart';
import 'package:heavenrock_registry/presentation/viewmodels/registry_view_model.dart';
import 'package:heavenrock_registry/presentation/views/registry_home_page.dart';
import 'package:heavenrock_registry/services/auth_service.dart';

class _User implements User {
  @override
  String get uid => 'user-1';
  @override
  String? get displayName => 'Owner';
  @override
  String? get email => 'owner@example.com';
  @override
  String? get phoneNumber => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthViewModel {
  _Auth() : super(authService: _AuthService());
  final User _user = _User();

  @override
  User? get user => _user;
  @override
  Stream<User?> authStateChanges() => Stream.value(_user);
  @override
  void startListening({
    void Function(String uid)? onUserChanged,
    VoidCallback? onSignedOut,
  }) {
    onUserChanged?.call(_user.uid);
  }
}

class _RegistryRepository implements RegistryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Registry extends RegistryViewModel {
  _Registry() : super(repository: _RegistryRepository());
  @override
  Future<void> loadData() async {}
}

class _GuestHouse implements GuestHouseProfileRepository {
  GuestHouseProfileData? profile;
  bool fail = false;
  @override
  Future<GuestHouseProfileData?> loadProfile({required String uid}) async {
    if (fail) throw StateError('offline');
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements AccountProfileRepository {
  final changes = StreamController<AccountProfile?>.broadcast();
  AccountProfile? profile;
  bool failSave = false;
  @override
  Stream<AccountProfile?> watchProfile(String uid) async* {
    yield profile;
    yield* changes.stream;
  }

  @override
  Future<void> saveProfile(String uid, AccountProfile value) async {
    if (failSave) throw StateError('save failed');
    profile = value;
    changes.add(value);
  }

  @override
  Future<void> createProfileIfAbsent(String uid, AccountProfile value) async {
    if (failSave) throw StateError('save failed');
    profile ??= value;
    changes.add(profile);
  }
}

void main() {
  late _Auth auth;
  late _Registry registry;
  late _GuestHouse guestHouse;
  late _Accounts accounts;

  setUp(() {
    auth = _Auth();
    registry = _Registry();
    guestHouse = _GuestHouse();
    accounts = _Accounts();
  });
  tearDown(() {
    auth.dispose();
    registry.dispose();
    accounts.changes.close();
  });

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      GuestHouseRegistryApp(
        authViewModel: auth,
        registryViewModel: registry,
        guestHouseProfileRepository: guestHouse,
        accountProfileRepository: accounts,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('new users can skip profile setup and return to it later', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('Guest House Profile'), findsNothing);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.name, 'Owner');
    expect(find.text('Guest House Registry'), findsOneWidget);
    await tester.tap(find.byTooltip('My profile'));
    await tester.pumpAndSettle();
    expect(find.text('My profile'), findsOneWidget);
  });

  testWidgets('new users can save profile before Home', (tester) async {
    await start(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'New Owner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house name'),
      'Sunrise House',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house address'),
      '12 Green Road',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.name, 'New Owner');
    expect(accounts.profile?.guestHouseName, 'Sunrise House');
    expect(accounts.profile?.guestHouseAddress, '12 Green Road');
    expect(find.text('Sunrise House'), findsOneWidget);
    expect(find.text('12 Green Road'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await start(tester);
    expect(find.text('Sunrise House'), findsOneWidget);
    expect(find.text('12 Green Road'), findsOneWidget);
  });

  testWidgets('failed skip stays on setup and saved profiles bypass it', (
    tester,
  ) async {
    accounts.failSave = true;
    await start(tester);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to continue'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    accounts.failSave = false;
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await start(tester);
    expect(find.text('Guest House Registry'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('existing guest house details remain on Home', (tester) async {
    guestHouse.profile = GuestHouseProfileData(
      name: 'Existing house',
      address: 'Existing address',
      photoBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
    );
    await start(tester);
    expect(find.text('Existing house'), findsOneWidget);
    expect(find.text('Existing address'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CircleAvatar),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('My profile'));
    await tester.pumpAndSettle();
    expect(find.text('Existing house'), findsWidgets);
    expect(find.text('Existing address'), findsWidgets);
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Guest house name'),
          )
          .controller
          ?.text,
      'Existing house',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Guest house address'),
          )
          .controller
          ?.text,
      'Existing address',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house name'),
      'Renamed House',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house address'),
      '45 New Road',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(accounts.profile?.guestHouseName, 'Renamed House');
    expect(accounts.profile?.guestHouseAddress, '45 New Road');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Renamed House'), findsOneWidget);
    expect(find.text('45 New Road'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add booking'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BookingsScreen>(find.byType(BookingsScreen)).guestHouseName,
      'Renamed House',
    );
    expect(
      tester
          .widget<BookingsScreen>(find.byType(BookingsScreen))
          .guestHouseAddress,
      '45 New Road',
    );
    await tester.tap(find.byTooltip('My profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house name'),
      '',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Guest house address'),
      '',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Existing house'), findsOneWidget);
    expect(find.text('Existing address'), findsNothing);
    expect(find.text('45 New Road'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await start(tester);
    expect(find.text('Existing address'), findsNothing);
  });

  testWidgets('profile loading errors are shown and retry succeeds', (
    tester,
  ) async {
    guestHouse.fail = true;
    await start(tester);
    expect(
      find.textContaining('Unable to load guest house details'),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsOneWidget);
    guestHouse.fail = false;
    accounts.profile = const AccountProfile(
      name: 'Owner',
      phone: '',
      email: '',
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Guest House Registry'), findsOneWidget);
  });
}
