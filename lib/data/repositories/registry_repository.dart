import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';

abstract class RegistryRepository {
  Stream<List<Booking>> watchBookings();
  Stream<List<Expense>> watchExpenses();
  Future<void> addBooking(Booking booking);
  Future<void> updateBooking(Booking booking);
  Future<void> deleteBooking(String bookingId);
  Future<void> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String expenseId);
}
