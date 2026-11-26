import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';

abstract class RegistryRepository {
  Stream<List<Booking>> watchBookings();
  Stream<List<Expense>> watchExpenses();
  Future<void> addBooking(Booking booking);
  Future<void> updateBooking(Booking booking);
  Future<Booking> recordBookingPayment(String bookingId, double amount);
  Future<Booking> cancelBooking(String bookingId);
  Future<Booking> refundBooking(String bookingId);
  Future<void> addExpense(Expense expense);
  Future<void> deleteExpense(String expenseId);
  Stream<String> watchHouseRules();
  Future<void> saveHouseRules(String houseRules);
}
