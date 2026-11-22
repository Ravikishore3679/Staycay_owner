import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/data/repositories/registry_repository.dart';
import 'package:heavenrock_registry/domain/models/booking.dart';
import 'package:heavenrock_registry/domain/models/expense.dart';
import 'package:heavenrock_registry/presentation/theme/app_colors.dart';
import 'package:heavenrock_registry/presentation/viewmodels/registry_view_model.dart';
import 'package:heavenrock_registry/presentation/views/registry_home_page.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

class _PrintPlatform extends PrintingPlatform {
  Uint8List? printed;
  String? jobName;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    jobName = name;
    printed = await onLayout(format);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedRepository implements RegistryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _pdfText(Uint8List bytes) {
  final file = latin1.decode(bytes);
  final output = StringBuffer();
  for (final stream in RegExp(r'stream\r?\n').allMatches(file)) {
    final end = file.indexOf('endstream', stream.end);
    if (end < 0) continue;
    try {
      final content = latin1.decode(
        ZLibDecoder().convert(bytes.sublist(stream.end, end)),
      );
      for (final match in RegExp(
        r'\[\(((?:\\.|[^\\)])*)\)\]TJ',
      ).allMatches(content)) {
        output.write('${match.group(1)} ');
      }
    } on FormatException {
      // Binary resources do not contain compressed page text.
    }
  }
  return output.toString();
}

class _HomeViewModel extends RegistryViewModel {
  _HomeViewModel(this.booking, this.expense)
    : super(repository: _UnusedRepository());

  Booking booking;
  final Expense expense;
  bool failPayment = false;
  bool failCancellation = false;
  bool failRefund = false;
  int paymentCalls = 0;

  @override
  Future<void> updateBooking(Booking updated) async {
    if (booking.isCancelled) throw StateError('Booking is cancelled');
    booking = updated;
    notifyListeners();
  }

  @override
  Future<Booking> cancelBooking(String bookingId) async {
    if (failCancellation) throw StateError('Cancellation failed');
    if (booking.isCancelled) throw StateError('Booking is already cancelled');
    booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'isCancelled': true,
    });
    notifyListeners();
    return booking;
  }

  @override
  Future<Booking> refundBooking(String bookingId) async {
    if (failRefund) throw StateError('Refund failed');
    if (!booking.isCancelled ||
        booking.refundedAmount > 0 ||
        booking.grossPaid <= 0) {
      throw StateError('No refund available');
    }
    booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'refundedAmount': booking.grossPaid,
    });
    notifyListeners();
    return booking;
  }

  @override
  Future<Booking> recordBookingPayment(String bookingId, double amount) async {
    paymentCalls++;
    if (failPayment) throw StateError('Payment could not be saved');
    booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'balancePaid': booking.balancePaid + amount,
    });
    notifyListeners();
    return booking;
  }

  @override
  List<Booking> get bookings => [booking];

  @override
  List<Booking> get topUpcomingBookings => booking.isCancelled ? [] : [booking];

  @override
  List<Booking> bookingsForMonth(int year, int month) => [booking];

  @override
  List<Expense> expensesForMonth(int year, int month) => [expense];
}

void main() {
  late Booking booking;
  late Expense expense;
  late _HomeViewModel controller;

  setUp(() {
    final today = DateUtils.dateOnly(DateTime.now());
    booking = Booking(
      id: 'booking-1',
      name: 'Test Guest',
      phone: '1234567890',
      aadhaar: '',
      checkIn: today,
      checkOut: today.add(const Duration(days: 2)),
      guests: 2,
      totalAmount: 3000,
      advancePaid: 1000,
    );
    expense = Expense(
      id: 'expense-1',
      title: 'Cleaning',
      amount: 500,
      description: 'Supplies for rooms',
      date: today,
    );
    controller = _HomeViewModel(booking, expense);
  });

  tearDown(() => controller.dispose());

  Future<void> pumpHome(
    WidgetTester tester, {
    String houseName = 'Test house',
    String houseAddress = 'Test address',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            controller: controller,
            onAddBookingForDate: (_) {},
            guestHouseName: houseName,
            guestHouseAddress: houseAddress,
            guestHousePhotoBytes: null,
          ),
        ),
      ),
    );
  }

  testWidgets('Home shows calendar without booking or expense summary cards', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Bookings'), findsNothing);
    expect(find.text('Expenses'), findsNothing);
    expect(find.text('Selected month'), findsNothing);
    expect(find.text('Stay calendar'), findsOneWidget);
    expect(find.text('Cancelled bookings'), findsNothing);
    expect(find.text('Recent expenses'), findsNothing);
  });

  testWidgets('calendar and upcoming bookings open full booking details', (
    tester,
  ) async {
    await pumpHome(tester);

    final calendarBooking = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      calendarBooking,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(calendarBooking);
    await tester.pumpAndSettle();
    await tester.tap(calendarBooking);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(find.text('Booking details'), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('1234567890')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Not provided')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Advance paid:')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Rs 1000.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Rs 2000.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Rs 3000.00')),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final upcomingBooking = find.ancestor(
      of: find.byIcon(Icons.event_available_outlined),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      upcomingBooking,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(upcomingBooking);
    await tester.pumpAndSettle();
    await tester.tap(upcomingBooking);
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Rs 1000.00')),
      findsOneWidget,
    );
  });

  testWidgets('reprint uses current payments and cancelled refund details', (
    tester,
  ) async {
    final oldPlatform = PrintingPlatform.instance;
    final printer = _PrintPlatform();
    PrintingPlatform.instance = printer;
    addTearDown(() => PrintingPlatform.instance = oldPlatform);
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reprint receipt'));
    await tester.pumpAndSettle();
    expect(printer.jobName, 'Booking receipt booking-1');
    var content = _pdfText(printer.printed!);
    expect(content, contains('TEST HOUSE'));
    expect(content, contains('Test address'));
    expect(content, contains('Test Guest'));
    expect(content, contains('Balance Paid'));
    expect(content, contains('Rs 500.00'));
    expect(content, contains('Rs 1500.00'));
    expect(content, contains('Active'));

    await tester.tap(find.byTooltip('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record full refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm refund'));
    await tester.pumpAndSettle();
    printer.printed = null;
    await tester.tap(find.byTooltip('Reprint receipt'));
    await tester.pumpAndSettle();
    content = _pdfText(printer.printed!);
    expect(content, contains('Cancelled'));
    expect(content, contains('Refunded'));
    expect(content, contains('Rs 1500.00'));
  });

  testWidgets('reprint errors are visible and can be retried', (tester) async {
    const channel = MethodChannel('net.nfet.printing');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'printer_error',
        message: 'Printer unavailable',
      );
    });

    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reprint receipt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to print receipt'), findsOneWidget);
    expect(find.textContaining('Printer unavailable'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Reprint receipt'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('reprint handles long guest and house details', (tester) async {
    final oldPlatform = PrintingPlatform.instance;
    final printer = _PrintPlatform();
    PrintingPlatform.instance = printer;
    addTearDown(() => PrintingPlatform.instance = oldPlatform);
    final guestName = List.filled(80, 'G').join();
    final houseName = List.filled(80, 'H').join();
    final address = List.filled(50, 'Road').join(' ');
    controller.booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'name': guestName,
    });
    await pumpHome(tester, houseName: houseName, houseAddress: address);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reprint receipt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to print receipt'), findsNothing);
    expect(printer.printed, isNotNull);
    expect(_pdfText(printer.printed!), contains('GGGGGGGG'));
  });

  testWidgets('booking details remain usable on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();

    expect(find.text('Guest & stay'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Payment summary'), findsOneWidget);
    expect(find.byTooltip('Record payment'), findsOneWidget);
    expect(find.byTooltip('Reprint receipt'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('Reprint receipt')).dx,
      greaterThan(tester.getTopLeft(find.byTooltip('Record payment')).dx),
    );
    expect(find.byTooltip('Modify'), findsOneWidget);
    expect(find.byTooltip('Cancel booking'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Payment summary'));
    await tester.pumpAndSettle();
    expect(find.text('Advance paid:'), findsOneWidget);
    expect(find.text('Remaining:'), findsOneWidget);
    await tester.tap(find.byTooltip('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Save payment'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'records partial and full payments without changing the advance',
    (tester) async {
      await pumpHome(tester);
      final bookingTile = find.ancestor(
        of: find.byIcon(Icons.person_outline),
        matching: find.byType(ListTile),
      );
      await tester.scrollUntilVisible(
        bookingTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(bookingTile);
      await tester.pumpAndSettle();
      await tester.tap(bookingTile);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(controller.booking.advancePaid, 1000);
      expect(controller.booking.balancePaid, 500);
      expect(controller.booking.remainingAmount, 1500);
      final report = controller.getMonthlyReport(
        booking.checkIn.year,
        booking.checkIn.month,
      );
      expect(report.revenue, 1500);
      expect(report.net, 1000);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Rs 1500.00'),
        ),
        findsOneWidget,
      );
      expect(find.text('Balance paid:'), findsOneWidget);

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();
      expect(find.text('1500.00'), findsOneWidget);
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(controller.booking.balancePaid, 2000);
      expect(controller.booking.remainingAmount, 0);
      expect(find.text('Paid in full'), findsOneWidget);
      expect(find.byTooltip('Record payment'), findsOneWidget);
    },
  );

  testWidgets('rejects invalid and excess payments and shows save errors', (
    tester,
  ) async {
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record payment'));
    await tester.pumpAndSettle();

    for (final amount in ['', '0', '-1', '2000.01', '1.234', 'NaN']) {
      await tester.enterText(find.byType(TextFormField), amount);
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
    }
    expect(controller.paymentCalls, 0);
    expect(controller.booking.remainingAmount, 2000);

    controller.failPayment = true;
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to record payment'), findsOneWidget);
    expect(controller.booking.remainingAmount, 2000);
    expect(find.text('Save payment'), findsOneWidget);
  });

  test('booking payment persists and legacy bookings default to zero', () {
    final legacy = booking.toMap()
      ..remove('balancePaid')
      ..remove('isCancelled')
      ..remove('refundedAmount');
    final restored = Booking.fromMap(booking.id, legacy);
    expect(restored.balancePaid, 0);
    expect(restored.isCancelled, false);
    expect(restored.refundedAmount, 0);
    expect(restored.remainingAmount, 2000);

    final paid = Booking.fromMap(booking.id, {...legacy, 'balancePaid': 600});
    final roundTrip = Booking.fromMap(paid.id, paid.toMap());
    expect(roundTrip.advancePaid, 1000);
    expect(roundTrip.balancePaid, 600);
    expect(roundTrip.collectedAmount, 1600);
    expect(roundTrip.remainingAmount, 1400);
  });

  test('payment is due on check-in day and after until fully paid', () {
    final today = DateUtils.dateOnly(DateTime.now());
    expect(
      booking.isPaymentDueOn(DateTime(today.year, today.month, today.day - 1)),
      false,
    );
    expect(booking.isPaymentDueOn(today), true);
    expect(
      booking.isPaymentDueOn(DateTime(today.year, today.month, today.day + 30)),
      true,
    );
    final partial = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'balancePaid': 500,
    });
    expect(partial.isPaymentDueOn(today), true);
    final paid = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'balancePaid': 2000,
    });
    expect(paid.isPaymentDueOn(today), false);
    final cancelled = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'isCancelled': true,
    });
    expect(cancelled.isPaymentDueOn(today), false);
  });

  testWidgets('past unpaid bookings are red and clear after full payment', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final past = DateTime(today.year, today.month, today.day - 4);
    controller.booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'checkIn': past,
      'checkOut': DateTime(today.year, today.month, today.day - 3),
    });
    await pumpHome(tester);
    final dueIcon = find.byIcon(Icons.payment_outlined);
    await tester.scrollUntilVisible(
      dueIcon,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(dueIcon);
    await tester.pumpAndSettle();
    expect(find.text('Payments due'), findsOneWidget);
    final dueTile = find.ancestor(of: dueIcon, matching: find.byType(ListTile));
    final amount = tester.widget<Text>(
      find.descendant(of: dueTile, matching: find.text('Rs 2000.00')),
    );
    expect(amount.style?.color, AppColors.expenseDark);
    await tester.tap(dueTile);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: dialog, matching: find.text('Rs 2000.00')),
          )
          .style
          ?.color,
      AppColors.expenseDark,
    );
    expect(find.textContaining('Payment due on'), findsOneWidget);
    await tester.tap(find.byTooltip('Record payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.descendant(of: dialog, matching: find.text('Rs 1500.00')),
          )
          .style
          ?.color,
      AppColors.expenseDark,
    );
    await tester.tap(find.byTooltip('Record payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(find.text('Paid in full'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Payments due'), findsNothing);
  });

  testWidgets(
    'calendar marks due stays red but not future or cancelled stays',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final dateKey = ValueKey(
        'calendar-date-${today.year}-${today.month}-${today.day}',
      );
      Color? cellColor() {
        final cell = find.byKey(dateKey);
        final containers = find.descendant(
          of: cell,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        );
        final container = tester.widget<Container>(containers.first);
        return (container.decoration! as BoxDecoration).color;
      }

      await pumpHome(tester);
      expect(cellColor(), AppColors.expenseDark);
      controller.booking = Booking.fromMap(booking.id, {
        ...booking.toMap(),
        'balancePaid': 2000,
      });
      await pumpHome(tester);
      expect(cellColor(), AppColors.brandPrimary);
      expect(find.text('Payments due'), findsNothing);
      controller.booking = Booking.fromMap(booking.id, {
        ...booking.toMap(),
        'isCancelled': true,
      });
      await pumpHome(tester);
      expect(cellColor(), AppColors.revenueSoft);
      expect(find.text('Payments due'), findsNothing);

      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      controller.booking = Booking.fromMap(booking.id, {
        ...booking.toMap(),
        'checkIn': tomorrow,
        'checkOut': DateTime(today.year, today.month, today.day + 2),
      });
      await pumpHome(tester);
      expect(find.text('Payments due'), findsNothing);
    },
  );

  testWidgets('modifies a booking from Home', (tester) async {
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modify'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Updated Guest',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.booking.name, 'Updated Guest');
    expect(controller.booking.advancePaid, 1000);
  });

  testWidgets('cancels without refund, then records a full refund later', (
    tester,
  ) async {
    controller.booking = Booking.fromMap(booking.id, {
      ...booking.toMap(),
      'balancePaid': 500,
    });
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();

    expect(controller.booking.isCancelled, true);
    expect(controller.booking.advancePaid, 1000);
    expect(controller.booking.balancePaid, 500);
    expect(controller.booking.refundedAmount, 0);
    expect(
      controller
          .getMonthlyReport(booking.checkIn.year, booking.checkIn.month)
          .revenue,
      1500,
    );
    expect(find.text('Cancelled booking'), findsOneWidget);
    expect(find.byTooltip('Record payment'), findsOneWidget);
    expect(find.byTooltip('Modify'), findsOneWidget);

    await tester.tap(find.byTooltip('Record full refund'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not transfer money'), findsOneWidget);
    await tester.tap(find.text('Confirm refund'));
    await tester.pumpAndSettle();
    expect(controller.booking.refundedAmount, 1500);
    expect(controller.booking.advancePaid, 1000);
    expect(
      controller
          .getMonthlyReport(booking.checkIn.year, booking.checkIn.month)
          .revenue,
      0,
    );
    expect(find.byTooltip('Record full refund'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('No guest stays on this date.'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsNothing);
  });

  testWidgets('shows errors when cancellation or refund cannot be saved', (
    tester,
  ) async {
    await pumpHome(tester);
    final bookingTile = find.ancestor(
      of: find.byIcon(Icons.person_outline),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      bookingTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(bookingTile);
    await tester.pumpAndSettle();
    await tester.tap(bookingTile);
    await tester.pumpAndSettle();
    controller.failCancellation = true;
    await tester.tap(find.byTooltip('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to cancel booking'), findsOneWidget);
    expect(controller.booking.isCancelled, false);
    controller.failCancellation = false;
    await tester.tap(find.byTooltip('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    controller.failRefund = true;
    await tester.tap(find.byTooltip('Record full refund'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm refund'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to record refund'), findsOneWidget);
    expect(controller.booking.refundedAmount, 0);
  });
}
