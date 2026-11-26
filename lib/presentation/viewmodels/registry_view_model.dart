import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/repositories/registry_repository.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/monthly_report.dart';

class RegistryViewModel extends ChangeNotifier {
  RegistryViewModel({required this.repository});

  final RegistryRepository repository;

  static const String defaultHouseRules =
      '''Please carry a valid government ID during the stay.
Check-in time is from 1:00 PM onwards, and check-out time is before 11:00 AM.
Check-out extensions are subject to room availability.
Any damage to property will be chargeable to the guest.
Loud music and disturbance are not allowed after 11:00 PM.
Outstanding balance must be cleared before check-in.
Please maintain cleanliness and hygiene in the rooms and living area.
Pets are allowed in the guest house premises only upon prior notice.
Smoking is strictly prohibited inside the rooms and common areas.
Guests are responsible for their personal belongings; the guest house is not liable for any loss.
Swimming pool discipline: Children must be supervised by an adult at all times. No diving or running around the pool area.
Penalty for vomiting in the rooms will be 1000.''';

  List<Booking> _bookings = [];
  List<Expense> _expenses = [];
  String _houseRules = defaultHouseRules;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Booking>>? _bookingsSub;
  StreamSubscription<List<Expense>>? _expensesSub;
  StreamSubscription<String>? _houseRulesSub;
  Timer? _debounceTimer;

  // Cache for computed values
  List<Booking>? _cachedSortedBookings;
  List<Expense>? _cachedSortedExpenses;
  List<Booking>? _cachedUpcomingBookings;
  final Map<String, List<Booking>> _cachedBookingsByMonth = {};
  final Map<String, List<Expense>> _cachedExpensesByMonth = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String _formatError(Object error, {required String prefix}) {
    if (error is FirebaseException) {
      final code = error.code.trim();
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '$prefix ($code): $message';
      }
      return '$prefix ($code).';
    }
    return '$prefix: $error';
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingsSub?.cancel();
      await _expensesSub?.cancel();
      await _houseRulesSub?.cancel();

      final bookingsStream = repository.watchBookings();
      final expensesStream = repository.watchExpenses();
      final houseRulesStream = repository.watchHouseRules();

      try {
        final initial = await Future.wait([
          bookingsStream.first,
          expensesStream.first,
          houseRulesStream.first,
        ]);

        _bookings = initial[0] as List<Booking>;
        _expenses = initial[1] as List<Expense>;
        final savedRules = initial[2] as String;
        _houseRules = savedRules.trim().isEmpty
            ? defaultHouseRules
            : savedRules;
        _invalidateAllCaches();
      } catch (_) {
        _bookings = [];
        _expenses = [];
        _invalidateAllCaches();
      }

      _bookingsSub = bookingsStream.listen(
        (bookings) {
          _debounceUpdate(() {
            _bookings = bookings;
            _invalidateAllCaches();
            _errorMessage = null;
            notifyListeners();
          });
        },
        onError: (Object e) {
          _errorMessage = _formatError(e, prefix: 'Bookings sync failed');
          notifyListeners();
        },
      );

      _expensesSub = expensesStream.listen(
        (expenses) {
          _debounceUpdate(() {
            _expenses = expenses;
            _invalidateAllCaches();
            _errorMessage = null;
            notifyListeners();
          });
        },
        onError: (Object e) {
          _errorMessage = _formatError(e, prefix: 'Expenses sync failed');
          notifyListeners();
        },
      );

      _houseRulesSub = houseRulesStream.listen(
        (rules) {
          _debounceUpdate(() {
            _houseRules = rules.trim().isEmpty ? defaultHouseRules : rules;
            _errorMessage = null;
            notifyListeners();
          });
        },
        onError: (Object e) {
          _errorMessage = _formatError(e, prefix: 'House rules sync failed');
          notifyListeners();
        },
      );

      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to load Firebase data');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Debounce rapid stream updates to reduce rebuild frequency
  void _debounceUpdate(VoidCallback update) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), update);
  }

  /// Invalidate all caches when data changes
  void _invalidateAllCaches() {
    _cachedSortedBookings = null;
    _cachedSortedExpenses = null;
    _cachedUpcomingBookings = null;
    _cachedBookingsByMonth.clear();
    _cachedExpensesByMonth.clear();
  }

  List<Booking> get bookings {
    _cachedSortedBookings ??= ([..._bookings]
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn)));
    return _cachedSortedBookings!;
  }

  List<Expense> get expenses {
    _cachedSortedExpenses ??= ([..._expenses]
      ..sort((a, b) => b.date.compareTo(a.date)));
    return _cachedSortedExpenses!;
  }

  String get houseRules => _houseRules;

  List<Booking> get topUpcomingBookings {
    if (_cachedUpcomingBookings != null) {
      return _cachedUpcomingBookings!;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming =
        _bookings
            .where(
              (b) =>
                  !b.isCancelled &&
                  (DateUtils.dateOnly(b.checkIn).isAfter(today) ||
                      DateUtils.isSameDay(b.checkIn, today)),
            )
            .toList()
          ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    _cachedUpcomingBookings = upcoming.take(3).toList();
    return _cachedUpcomingBookings!;
  }

  List<Booking> bookingsForMonth(int year, int month) {
    final cacheKey = '$year-$month';
    if (_cachedBookingsByMonth.containsKey(cacheKey)) {
      return _cachedBookingsByMonth[cacheKey]!;
    }

    final result =
        _bookings
            .where((b) => b.checkIn.year == year && b.checkIn.month == month)
            .toList()
          ..sort((a, b) => b.checkIn.compareTo(a.checkIn));

    _cachedBookingsByMonth[cacheKey] = result;
    return result;
  }

  List<Expense> expensesForMonth(int year, int month) {
    final cacheKey = '$year-$month';
    if (_cachedExpensesByMonth.containsKey(cacheKey)) {
      return _cachedExpensesByMonth[cacheKey]!;
    }

    final result =
        _expenses
            .where((e) => e.date.year == year && e.date.month == month)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    _cachedExpensesByMonth[cacheKey] = result;
    return result;
  }

  MonthlyReport getMonthlyReport(int year, int month) {
    final monthBookings = bookingsForMonth(year, month);
    final monthExpenses = expensesForMonth(year, month);

    final revenue = monthBookings.fold(
      0.0,
      (total, booking) => total + booking.collectedAmount,
    );
    final expenses = monthExpenses.fold(
      0.0,
      (total, expense) => total + expense.amount,
    );

    return MonthlyReport(
      year: year,
      month: month,
      revenue: revenue,
      expenses: expenses,
    );
  }

  Future<void> addBooking(Booking booking) async {
    try {
      await repository.addBooking(booking);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to add booking');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBooking(Booking booking) async {
    try {
      await repository.updateBooking(booking);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to update booking');
      notifyListeners();
      rethrow;
    }
  }

  Future<Booking> recordBookingPayment(String bookingId, double amount) async {
    try {
      final booking = await repository.recordBookingPayment(bookingId, amount);
      _errorMessage = null;
      return booking;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to record payment');
      notifyListeners();
      rethrow;
    }
  }

  Future<Booking> cancelBooking(String bookingId) async {
    try {
      final booking = await repository.cancelBooking(bookingId);
      _errorMessage = null;
      return booking;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to cancel booking');
      notifyListeners();
      rethrow;
    }
  }

  Future<Booking> refundBooking(String bookingId) async {
    try {
      final booking = await repository.refundBooking(bookingId);
      _errorMessage = null;
      return booking;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to record refund');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      await repository.addExpense(expense);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to add expense');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await repository.deleteExpense(expenseId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to delete expense');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveHouseRules(String houseRules) async {
    try {
      await repository.saveHouseRules(houseRules.trim());
      _houseRules = houseRules.trim();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = _formatError(e, prefix: 'Failed to save house rules');
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _expensesSub?.cancel();
    _houseRulesSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
