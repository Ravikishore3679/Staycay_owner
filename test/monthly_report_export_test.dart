import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heavenrock_registry/data/repositories/registry_repository.dart';
import 'package:heavenrock_registry/domain/models/booking.dart';
import 'package:heavenrock_registry/domain/models/expense.dart';
import 'package:heavenrock_registry/domain/models/monthly_report.dart';
import 'package:heavenrock_registry/presentation/viewmodels/registry_view_model.dart';
import 'package:heavenrock_registry/presentation/views/registry_home_page.dart';

class _UnusedRepository implements RegistryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReportViewModel extends RegistryViewModel {
  _ReportViewModel(this.allBookings, this.allExpenses)
    : super(repository: _UnusedRepository());

  final List<Booking> allBookings;
  final List<Expense> allExpenses;

  @override
  List<Booking> bookingsForMonth(int year, int month) => allBookings
      .where(
        (booking) =>
            booking.checkIn.year == year && booking.checkIn.month == month,
      )
      .toList();

  @override
  List<Expense> expensesForMonth(int year, int month) => allExpenses
      .where(
        (expense) => expense.date.year == year && expense.date.month == month,
      )
      .toList();
}

Booking _booking(
  String name,
  DateTime date, {
  bool cancelled = false,
  double refund = 0,
}) => Booking(
  id: name,
  name: name,
  phone: '1234567890',
  aadhaar: '',
  checkIn: date,
  checkOut: date.add(const Duration(days: 1)),
  guests: 2,
  totalAmount: 3000,
  advancePaid: 1000,
  balancePaid: 500,
  isCancelled: cancelled,
  refundedAmount: refund,
);

String _pdfContents(Uint8List bytes) {
  final file = latin1.decode(bytes);
  final streams = RegExp(r'stream\r?\n').allMatches(file);
  final output = StringBuffer();
  for (final stream in streams) {
    final end = file.indexOf('endstream', stream.end);
    if (end < 0) continue;
    try {
      final decoded = ZLibDecoder().convert(bytes.sublist(stream.end, end));
      final content = latin1.decode(decoded);
      for (final match in RegExp(
        r'\[\(((?:\\.|[^\\)])*)\)\]TJ',
      ).allMatches(content)) {
        output.write(
          '${match.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')').replaceAll(r'\\', r'\')} ',
        );
      }
    } on FormatException {
      // Some streams are binary resources rather than compressed page content.
    }
  }
  return output.toString();
}

void main() {
  testWidgets('exports selected month records and reconciled totals', (
    tester,
  ) async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, 10);
    final otherMonth = DateTime(
      now.year,
      now.month == 12 ? 11 : now.month + 1,
      10,
    );
    final controller = _ReportViewModel(
      [
        _booking('Active Guest', date),
        _booking('Cancelled Refund Guest', date, cancelled: true, refund: 1500),
        _booking('Cancelled Retained Guest', date, cancelled: true),
        _booking('Other Month Guest', otherMonth),
      ],
      [
        Expense(
          id: '1',
          title: 'Cleaning Supplies',
          amount: 400,
          description: 'Room supplies',
          date: date,
        ),
        Expense(
          id: '2',
          title: 'Other Month Expense',
          amount: 900,
          description: '',
          date: otherMonth,
        ),
      ],
    );
    addTearDown(controller.dispose);
    Uint8List? shared;
    String? filename;
    const channel = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'sharePdf');
          final args = call.arguments as Map<dynamic, dynamic>;
          shared = args['doc'] as Uint8List;
          filename = args['name'] as String;
          return 1;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReportsScreen(controller: controller)),
      ),
    );
    await tester.tap(find.text('Export monthly P&L'));
    await tester.pumpAndSettle();
    expect(
      filename,
      'monthly_pl_${now.year}_${now.month.toString().padLeft(2, '0')}.pdf',
    );
    expect(shared, isNotNull);
    final content = _pdfContents(shared!);
    for (final value in [
      'Bookings (1)',
      'Active Guest',
      'Cancelled bookings (2)',
      'Cancelled Refund Guest',
      'Cancelled Retained Guest',
      'Expenses (1)',
      'Cleaning Supplies',
      'Room supplies',
      'Financial summary',
      'ACTIVE BOOKINGS',
      'GUESTS',
      'OUTSTANDING BALANCE',
      'Refunded: Rs 1500.00 | Revenue: Rs 0.00',
      'Refunded: Rs 0.00 | Revenue: Rs 1500.00',
      'Rs 3000.00',
      'Rs 1500.00',
      'Rs 400.00',
      'Rs 2600.00',
    ]) {
      expect(
        content,
        contains(value),
        reason: 'Missing $value in exported PDF',
      );
    }
    expect(content, isNot(contains('Other Month Guest')));
    expect(content, isNot(contains('Other Month Expense')));

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
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
    await tester.tap(find.text(months[otherMonth.month - 1]).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export monthly P&L'));
    await tester.pumpAndSettle();
    expect(
      filename,
      'monthly_pl_${now.year}_${otherMonth.month.toString().padLeft(2, '0')}.pdf',
    );
    final otherContent = _pdfContents(shared!);
    expect(otherContent, contains('Other Month Guest'));
    expect(otherContent, contains('Other Month Expense'));
    expect(otherContent, isNot(contains('Active Guest')));
    expect(otherContent, isNot(contains('Cleaning Supplies')));
  });

  test('exports empty sections', () async {
    final bytes = await buildMonthlyReportPdf(
      report: MonthlyReport(year: 2026, month: 1, revenue: 0, expenses: 0),
      bookings: [],
      expenses: [],
    );
    final content = _pdfContents(bytes);
    expect(content, contains('No active bookings this month.'));
    expect(content, contains('No cancelled bookings this month.'));
    expect(content, contains('No expenses this month.'));
  });

  test('exports each short expense as a single line', () async {
    final date = DateTime(2026, 1, 10);
    final bytes = await buildMonthlyReportPdf(
      report: MonthlyReport(year: 2026, month: 1, revenue: 0, expenses: 15),
      bookings: [],
      expenses: [
        Expense(
          id: '1',
          title: 'Cleaning',
          amount: 10,
          description: 'Room\nsupplies',
          date: date,
        ),
        Expense(
          id: '2',
          title: 'Electricity',
          amount: 5,
          description: '',
          date: date,
        ),
      ],
    );
    final content = _pdfContents(bytes);
    expect(
      content,
      contains(
        'Cleaning | 10 Jan 2026 | Rs 10.00 | Description: Room supplies',
      ),
    );
    expect(content, contains('Electricity | 10 Jan 2026 | Rs 5.00'));
  });

  test(
    'summarizes active bookings without counting cancelled guests or dues',
    () async {
      final date = DateTime(2026, 1, 10);
      final bytes = await buildMonthlyReportPdf(
        report: MonthlyReport(
          year: 2026,
          month: 1,
          revenue: 1500,
          expenses: 2000,
        ),
        bookings: [
          _booking('Active Guest', date),
          _booking('Cancelled Guest', date, cancelled: true, refund: 1500),
        ],
        expenses: [],
      );
      final content = _pdfContents(bytes);
      expect(content, contains('ACTIVE BOOKINGS 1'));
      expect(content, contains('GUESTS 2'));
      expect(content, contains('OUTSTANDING BALANCE Rs 1500.00'));
      expect(content, contains('Rs -500.00'));
      expect(content, contains('Cancelled bookings (1)'));
    },
  );

  test('exports every record over multiple pages', () async {
    final date = DateTime(2026, 1, 10);
    final bookings = List.generate(
      510,
      (index) => _booking('Guest ${index.toString().padLeft(3, '0')}', date),
    );
    final expenses = List.generate(
      510,
      (index) => Expense(
        id: '$index',
        title: 'Expense ${index.toString().padLeft(3, '0')}',
        amount: 1,
        description: '',
        date: date,
      ),
    );
    final bytes = await buildMonthlyReportPdf(
      report: MonthlyReport(
        year: 2026,
        month: 1,
        revenue: 765000,
        expenses: 510,
      ),
      bookings: bookings,
      expenses: expenses,
    );
    final content = _pdfContents(bytes);
    expect(content, contains('Bookings (510)'));
    for (var i = 0; i < 510; i++) {
      expect(content, contains('Guest ${i.toString().padLeft(3, '0')}'));
      expect(content, contains('Expense ${i.toString().padLeft(3, '0')}'));
    }
    expect(content, contains('Page 21'));
  });

  test(
    'exports long expense descriptions without losing later records',
    () async {
      final date = DateTime(2026, 1, 10);
      final bytes = await buildMonthlyReportPdf(
        report: MonthlyReport(year: 2026, month: 1, revenue: 0, expenses: 10),
        bookings: [],
        expenses: [
          Expense(
            id: '1',
            title: 'Long expense',
            amount: 5,
            description: List.filled(4000, 'line').join('\n'),
            date: date,
          ),
          Expense(
            id: '2',
            title: 'Next expense',
            amount: 5,
            description: '',
            date: date,
          ),
        ],
      );
      final content = _pdfContents(bytes);
      expect(content, contains('Next expense'));
      expect(RegExp(r'\bline\b').allMatches(content).length, 4000);
    },
  );
}
