import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/registry_repository.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/monthly_report.dart';

class RegistryViewModel extends ChangeNotifier {
  RegistryViewModel({required this.repository});

  final RegistryRepository repository;

  List<Booking> _bookings = [];
  List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Booking>>? _bookingsSub;
  StreamSubscription<List<Expense>>? _expensesSub;
  Timer? _debounceTimer;

  // Cache for computed values
  List<Booking>? _cachedSortedBookings;
  List<Expense>? _cachedSortedExpenses;
  List<Booking>? _cachedUpcomingBookings;
  double? _cachedTotalRevenue;
  double? _cachedTotalExpenditure;
  final Map<String, List<Booking>> _cachedBookingsByMonth = {};
  final Map<String, List<Expense>> _cachedExpensesByMonth = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingsSub?.cancel();
      await _expensesSub?.cancel();

      final bookingsStream = repository.watchBookings();
      final expensesStream = repository.watchExpenses();

      try {
        final initial = await Future.wait([
          bookingsStream.first,
          expensesStream.first,
        ]);

        _bookings = initial[0] as List<Booking>;
        _expenses = initial[1] as List<Expense>;
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
          if (e.toString().contains('permission-denied')) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Bookings sync failed: $e';
          }
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
          if (e.toString().contains('permission-denied')) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Expenses sync failed: $e';
          }
          notifyListeners();
        },
      );

      _errorMessage = null;
    } catch (e) {
      if (!e.toString().contains('permission-denied')) {
        _errorMessage = 'Failed to load Firebase data: $e';
      }
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
    _cachedTotalRevenue = null;
    _cachedTotalExpenditure = null;
    _cachedBookingsByMonth.clear();
    _cachedExpensesByMonth.clear();
  }

  List<Booking> get bookings {
    _cachedSortedBookings ??=
        ([..._bookings]..sort((a, b) => b.checkIn.compareTo(a.checkIn)));
    return _cachedSortedBookings!;
  }

  List<Expense> get expenses {
    _cachedSortedExpenses ??=
        ([..._expenses]..sort((a, b) => b.date.compareTo(a.date)));
    return _cachedSortedExpenses!;
  }

  List<Booking> get topUpcomingBookings {
    if (_cachedUpcomingBookings != null) {
      return _cachedUpcomingBookings!;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = _bookings
        .where((b) =>
            DateUtils.dateOnly(b.checkIn).isAfter(today) ||
            DateUtils.isSameDay(b.checkIn, today))
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

    final result = _bookings
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

    final result = _expenses
        .where((e) => e.date.year == year && e.date.month == month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _cachedExpensesByMonth[cacheKey] = result;
    return result;
  }

  double get totalRevenue {
    _cachedTotalRevenue ??=
        _bookings.fold(0.0, (total, booking) => total! + booking.totalAmount);
    return _cachedTotalRevenue!;
  }

  double get totalExpenditure {
    _cachedTotalExpenditure ??=
        _expenses.fold(0.0, (total, exp) => total! + exp.amount);
    return _cachedTotalExpenditure!;
  }

  MonthlyReport getMonthlyReport(int year, int month) {
    final monthBookings = bookingsForMonth(year, month);
    final monthExpenses = expensesForMonth(year, month);

    final revenue =
        monthBookings.fold(0.0, (total, booking) => total + booking.totalAmount);
    final expenses =
        monthExpenses.fold(0.0, (total, expense) => total + expense.amount);

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
      _errorMessage = 'Failed to add booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBooking(Booking booking) async {
    try {
      await repository.updateBooking(booking);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    try {
      await repository.deleteBooking(bookingId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete booking: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      await repository.addExpense(expense);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to add expense: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await repository.updateExpense(expense);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update expense: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await repository.deleteExpense(expenseId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete expense: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _expensesSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
