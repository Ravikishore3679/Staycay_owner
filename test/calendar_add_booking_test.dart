import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/data/repositories/account_profile_repository.dart';
import 'package:heavenrock_registry/data/repositories/registry_repository.dart';
import 'package:heavenrock_registry/domain/models/booking.dart';
import 'package:heavenrock_registry/domain/models/expense.dart';
import 'package:heavenrock_registry/presentation/viewmodels/auth_view_model.dart';
import 'package:heavenrock_registry/presentation/viewmodels/registry_view_model.dart';
import 'package:heavenrock_registry/presentation/views/registry_home_page.dart';
import 'package:heavenrock_registry/services/auth_service.dart';

class _Repository implements RegistryRepository {
  Booking? added;
  Expense? addedExpense;
  String? savedHouseRules;
  String? websiteUrl = 'https://heavenrock.netlify.app';
  bool failWebsiteSave = false;
  final _websiteChanges = StreamController<String?>.broadcast();

  @override
  Future<void> addBooking(Booking booking) async => added = booking;

  @override
  Future<void> addExpense(Expense expense) async => addedExpense = expense;

  @override
  Future<void> saveHouseRules(String houseRules) async =>
      savedHouseRules = houseRules;

  @override
  Stream<String?> watchWebsiteUrl() async* {
    yield websiteUrl;
    yield* _websiteChanges.stream;
  }

  @override
  Future<void> saveWebsiteUrl(String url) async {
    if (failWebsiteSave) throw StateError('Save failed');
    websiteUrl = url;
    _websiteChanges.add(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountRepository implements AccountProfileRepository {
  @override
  Future<void> createProfileIfAbsent(
    String uid,
    AccountProfile profile,
  ) async {}
  @override
  Stream<AccountProfile?> watchProfile(String uid) => Stream.value(null);

  @override
  Future<void> saveProfile(String uid, AccountProfile profile) async {}
}

class _AuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthViewModel extends AuthViewModel {
  _AuthViewModel() : super(authService: _AuthService());

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

Booking _booking(DateTime date, {bool cancelled = false}) => Booking(
  id: 'existing',
  name: 'Existing Guest',
  phone: '1234567890',
  aadhaar: '',
  checkIn: date,
  checkOut: date.add(const Duration(days: 1)),
  guests: 2,
  totalAmount: 1000,
  advancePaid: 200,
  isCancelled: cancelled,
);

class _RegistryViewModel extends RegistryViewModel {
  _RegistryViewModel(RegistryRepository repository, this.currentBookings)
    : super(repository: repository);

  final List<Booking> currentBookings;

  @override
  List<Booking> get bookings => currentBookings;
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

Finder _calendarDate(DateTime date) => find.byKey(
  ValueKey('calendar-date-${date.year}-${date.month}-${date.day}'),
);

void main() {
  late _Repository repository;
  late _RegistryViewModel controller;
  late _AuthViewModel auth;
  late DateTime target;

  setUp(() {
    final now = DateTime.now();
    target = DateTime(now.year, now.month + 1, 5);
    repository = _Repository();
    controller = _RegistryViewModel(repository, [
      _booking(target),
      _booking(DateTime(target.year, target.month, 7), cancelled: true),
    ]);
    auth = _AuthViewModel();
  });

  tearDown(() {
    controller.dispose();
    auth.dispose();
    repository._websiteChanges.close();
  });

  Future<void> pumpRegistry(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegistryHomePage(
          guestHouseName: 'Test house',
          guestHouseAddress: 'Test address',
          guestHousePhotoBytes: null,
          registryViewModel: controller,
          authViewModel: auth,
          accountProfileRepository: _AccountRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDate(WidgetTester tester, DateTime date) async {
    final cell = _calendarDate(date);
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
  }

  Future<void> openWebsite(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Website'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ManageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty date opens a booking with its check-in selected and can be saved',
    (tester) async {
      await pumpRegistry(tester);
      final emptyDate = DateTime(target.year, target.month, 10);
      await tapDate(tester, emptyDate);
      expect(find.text('Add booking'), findsOneWidget);
      expect(find.text(_dateLabel(emptyDate)), findsOneWidget);
      expect(
        find.text(_dateLabel(DateTime(target.year, target.month, 11))),
        findsOneWidget,
      );
      expect(find.text('Select date'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'New Guest',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'),
        '1234567890',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'No. of Guests'),
        '80',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total Amount'),
        '1000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Advance Paid'),
        '200',
      );
      await tester.ensureVisible(find.text('Add Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Booking'));
      await tester.pumpAndSettle();
      expect(repository.added?.checkIn, emptyDate);
      expect(repository.added?.guests, 80);
      expect(
        repository.added?.checkOut,
        DateTime(target.year, target.month, 11),
      );
      expect(find.text('Booking added successfully'), findsOneWidget);
    },
  );

  testWidgets(
    'occupied dates stay on Home, cancelled and checkout dates open booking',
    (tester) async {
      await pumpRegistry(tester);
      await tapDate(tester, target);
      expect(find.text('Add booking'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Existing Guest'), findsOneWidget);
      final checkout = DateTime(target.year, target.month, 6);
      await tapDate(tester, checkout);
      expect(find.text(_dateLabel(checkout)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final cancelled = DateTime(target.year, target.month, 7);
      await tapDate(tester, cancelled);
      expect(find.text(_dateLabel(cancelled)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapDate(tester, DateTime(target.year, target.month, 8));
      expect(
        find.text(_dateLabel(DateTime(target.year, target.month, 8))),
        findsOneWidget,
      );
    },
  );

  testWidgets('checkout can be changed and follows check-in until customized', (
    tester,
  ) async {
    await pumpRegistry(tester);
    final tenth = DateTime(target.year, target.month, 10);
    await tapDate(tester, tenth);

    Future<void> choose(String current, String day) async {
      await tester.ensureVisible(find.text(current));
      await tester.tap(find.text(current));
      await tester.pumpAndSettle();
      await tester.tap(find.text(day).last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    await choose(_dateLabel(tenth), '12');
    final twelfth = DateTime(target.year, target.month, 12);
    final thirteenth = DateTime(target.year, target.month, 13);
    expect(find.text(_dateLabel(thirteenth)), findsOneWidget);

    await choose(_dateLabel(thirteenth), '18');
    final eighteenth = DateTime(target.year, target.month, 18);
    expect(find.text(_dateLabel(eighteenth)), findsOneWidget);
    await choose(_dateLabel(twelfth), '15');
    final fifteenth = DateTime(target.year, target.month, 15);
    expect(find.text(_dateLabel(eighteenth)), findsOneWidget);
    await choose(_dateLabel(fifteenth), '19');
    expect(
      find.text(_dateLabel(DateTime(target.year, target.month, 20))),
      findsOneWidget,
    );
  });

  testWidgets('normal Add form defaults checkout after choosing check-in', (
    tester,
  ) async {
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add booking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Select date').first);
    await tester.tap(find.text('Select date').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    expect(find.text(_dateLabel(today)), findsOneWidget);
    expect(find.text(_dateLabel(tomorrow)), findsOneWidget);
  });

  testWidgets('checkout rolls into the next month and year', (tester) async {
    final date = DateTime(DateTime.now().year, 12, 31);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingsScreen(
            controller: controller,
            guestHouseName: 'Test house',
            guestHouseAddress: 'Test address',
            guestHousePhotoBytes: null,
            initialCheckIn: date,
          ),
        ),
      ),
    );
    expect(
      find.text(_dateLabel(DateTime(date.year + 1, 1, 1))),
      findsOneWidget,
    );
  });

  testWidgets('calendar preselection does not change the normal Add form', (
    tester,
  ) async {
    await pumpRegistry(tester);
    await tapDate(tester, DateTime(target.year, target.month, 10));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add booking'));
    await tester.pumpAndSettle();
    expect(find.text('Select date'), findsNWidgets(2));
  });

  testWidgets(
    'calendar shortcut does not preserve an unfinished Manage tab booking',
    (tester) async {
      await pumpRegistry(tester);
      await tester.tap(find.text('Manage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add booking'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Existing draft',
      );
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tapDate(tester, DateTime(target.year, target.month, 10));
      expect(find.text('Existing draft'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage').last);
      await tester.pumpAndSettle();
      expect(find.text('Manage records'), findsOneWidget);
      expect(find.text('Existing draft'), findsNothing);
      expect(find.text('Select date'), findsNothing);
    },
  );

  testWidgets('Add expense form saves a new expense without listing records', (
    tester,
  ) async {
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expenditure Title / Category'),
      'Cleaning supplies',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description (optional)'),
      'Supplies',
    );
    await tester.ensureVisible(find.text('Add Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();
    expect(repository.addedExpense?.title, 'Cleaning supplies');
    expect(repository.addedExpense?.amount, 250);
    expect(repository.addedExpense?.description, 'Supplies');
    expect(find.text('Expense added successfully'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Expenditure Title / Category'),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Amount'))
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Description (optional)'),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.widgetWithText(ListTile, 'Cleaning supplies'), findsNothing);
  });

  testWidgets('Manage always opens the manage records page', (tester) async {
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();

    expect(find.text('Manage records'), findsOneWidget);
    expect(find.text('Add booking'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Show expenses'), findsOneWidget);
  });

  testWidgets('Manage screen shows current month expenses', (tester) async {
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses this month'), findsOneWidget);
    expect(find.text('No expenses this month.'), findsOneWidget);
  });

  testWidgets('Manage shows a bottom house rules link and website action', (
    tester,
  ) async {
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Website'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ManageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Show expenses')).dy,
      lessThan(tester.getTopLeft(find.text('Website')).dy),
    );
    expect(
      tester.getBottomRight(find.widgetWithText(TextButton, 'House rules')).dy,
      greaterThan(tester.getBottomRight(find.text('Website')).dy),
    );
    expect(find.widgetWithText(ListTile, 'House rules'), findsNothing);
    expect(find.widgetWithText(TextButton, 'House rules'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.text('House rules'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('houseRulesBody')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('houseRulesBody')),
      'Check in at 2 PM',
    );
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.byKey(const Key('saveHouseRules')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ManageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('saveHouseRules')));
    await tester.pumpAndSettle();
    expect(repository.savedHouseRules, 'Check in at 2 PM');

    await tester.tap(find.byTooltip('Back to manage options'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Website'),
      200,
      scrollable: find.descendant(
        of: find.byType(ManageScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();
    expect(find.text('https://heavenrock.netlify.app'), findsOneWidget);
    expect(find.byKey(const Key('openWebsite')), findsOneWidget);
    expect(find.byKey(const Key('copyWebsiteLink')), findsOneWidget);
    expect(find.byKey(const Key('shareWebsiteLink')), findsOneWidget);
    await tester.tap(find.byTooltip('Back to manage options'));
    await tester.pumpAndSettle();
    expect(find.text('Manage records'), findsOneWidget);
  });

  testWidgets('website can be changed, shared and reloaded', (tester) async {
    String? copied;
    String? shared;
    String? launched;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const launchChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
      return 'success';
    });
    messenger.setMockMethodCallHandler(launchChannel, (call) async {
      launched = (call.arguments as Map<dynamic, dynamic>)['url'] as String?;
      return true;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(launchChannel, null);
    });
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await openWebsite(tester);
    await tester.tap(find.byKey(const Key('editWebsite')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('websiteAddress')),
      'example-resort.com/stays',
    );
    await tester.tap(find.byKey(const Key('saveWebsite')));
    await tester.pumpAndSettle();
    expect(repository.websiteUrl, 'https://example-resort.com/stays');
    expect(find.text('https://example-resort.com/stays'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copyWebsiteLink')));
    await tester.pumpAndSettle();
    expect(copied, 'https://example-resort.com/stays');
    await tester.tap(find.byKey(const Key('openWebsite')));
    await tester.pumpAndSettle();
    expect(launched, 'https://example-resort.com/stays');
    await tester.tap(find.byKey(const Key('shareWebsiteLink')));
    await tester.pumpAndSettle();
    expect(shared, 'https://example-resort.com/stays');

    await tester.tap(find.byTooltip('Back to manage options'));
    await tester.pumpAndSettle();
    await openWebsite(tester);
    expect(find.text('https://example-resort.com/stays'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editWebsite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('websiteAddress')), '');
    await tester.tap(find.byKey(const Key('saveWebsite')));
    await tester.pumpAndSettle();
    expect(repository.websiteUrl, '');
    expect(find.text('No website added'), findsOneWidget);
  });

  testWidgets('website validates input and reports save failures', (
    tester,
  ) async {
    repository.websiteUrl = null;
    await pumpRegistry(tester);
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await openWebsite(tester);
    expect(find.text('No website added'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('openWebsite')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('editWebsite')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('websiteAddress')),
      'ftp://example.com',
    );
    await tester.tap(find.byKey(const Key('saveWebsite')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid HTTP or HTTPS website address'),
      findsOneWidget,
    );
    expect(repository.websiteUrl, isNull);
    await tester.enterText(
      find.byKey(const Key('websiteAddress')),
      'https://example.com',
    );
    repository.failWebsiteSave = true;
    await tester.tap(find.byKey(const Key('saveWebsite')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save website'), findsOneWidget);
    expect(repository.websiteUrl, isNull);
    expect(find.byKey(const Key('websiteAddress')), findsOneWidget);
  });

  testWidgets(
    'preselected dates outside the normal picker range remain editable',
    (tester) async {
      final farDate = DateTime(DateTime.now().year + 8, 6, 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingsScreen(
              controller: controller,
              guestHouseName: 'Test house',
              guestHouseAddress: 'Test address',
              guestHousePhotoBytes: null,
              initialCheckIn: farDate,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text(_dateLabel(farDate)));
      await tester.tap(find.text(_dateLabel(farDate)));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    },
  );
}
