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
      } catch (_) {
        _bookings = [];
        _expenses = [];
      }

      _bookingsSub = bookingsStream.listen(
        (bookings) {
          _bookings = bookings;
          _errorMessage = null;
          notifyListeners();
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
          _expenses = expenses;
          _errorMessage = null;
          notifyListeners();
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

  List<Booking> get bookings {
    final sorted = [..._bookings]..sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return sorted;
  }

  List<Expense> get expenses {
    final sorted = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  List<Booking> get topUpcomingBookings {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = _bookings
        .where((b) =>
            DateUtils.dateOnly(b.checkIn).isAfter(today) ||
            DateUtils.isSameDay(b.checkIn, today))
        .toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    return upcoming.take(3).toList();
  }

  List<Booking> bookingsForMonth(int year, int month) {
    return _bookings
        .where((b) => b.checkIn.year == year && b.checkIn.month == month)
        .toList()
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
  }

  List<Expense> expensesForMonth(int year, int month) {
    return _expenses
        .where((e) => e.date.year == year && e.date.month == month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get totalRevenue =>
      _bookings.fold(0.0, (total, booking) => total + booking.totalAmount);

  double get totalExpenditure =>
      _expenses.fold(0.0, (total, exp) => total + exp.amount);

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

  MonthlyReport getMonthlyReport(int year, int month) {
    final monthlyRevenue = _bookings.fold<double>(0.0, (total, b) {
      if (b.checkIn.year == year && b.checkIn.month == month) {
        return total + b.totalAmount;
      }
      return total;
    });

    final monthlyExpenses = _expenses.fold<double>(0.0, (total, e) {
      if (e.date.year == year && e.date.month == month) {
        return total + e.amount;
      }
      return total;
    });

    return MonthlyReport(
      year: year,
      month: month,
      revenue: monthlyRevenue,
      expenses: monthlyExpenses,
    );
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _expensesSub?.cancel();
    super.dispose();
  }
}
