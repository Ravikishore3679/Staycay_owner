import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import 'registry_repository.dart';

class FirestoreRegistryRepository implements RegistryRepository {
  FirestoreRegistryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _currentUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('No authenticated user found.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _bookingsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('bookings');

  CollectionReference<Map<String, dynamic>> _expensesCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('expenses');

  @override
  Stream<List<Booking>> watchBookings() {
    final uid = _currentUid();
    return _bookingsCollection(uid)
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Booking.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Expense>> watchExpenses() {
    final uid = _currentUid();
    return _expensesCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Expense.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> addBooking(Booking booking) async {
    final uid = _currentUid();
    await _bookingsCollection(uid).doc(booking.id).set(booking.toMap());
  }

  @override
  Future<void> updateBooking(Booking booking) async {
    final ref = _bookingsCollection(_currentUid()).doc(booking.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('This booking no longer exists.');
      }
      final current = Booking.fromMap(snapshot.id, data);
      if (current.isCancelled) {
        throw StateError('Cancelled bookings cannot be modified.');
      }
      if (booking.advancePaid + current.balancePaid - booking.totalAmount >
          0.000001) {
        throw StateError('Payments exceed the updated booking total.');
      }
      final updates = booking.toMap()
        ..remove('balancePaid')
        ..remove('isCancelled')
        ..remove('refundedAmount');
      transaction.update(ref, updates);
    });
  }

  @override
  Future<Booking> recordBookingPayment(String bookingId, double amount) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Payment must be greater than zero.');
    }

    final ref = _bookingsCollection(_currentUid()).doc(bookingId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('This booking no longer exists.');
      }
      final booking = Booking.fromMap(snapshot.id, data);
      if (booking.isCancelled) {
        throw StateError('Cannot record a payment for a cancelled booking.');
      }
      if (amount - booking.remainingAmount > 0.000001) {
        throw StateError('Payment exceeds the current remaining balance.');
      }
      final updatedBalancePaid = booking.balancePaid + amount;
      transaction.update(ref, {'balancePaid': updatedBalancePaid});
      return Booking.fromMap(snapshot.id, {
        ...data,
        'balancePaid': updatedBalancePaid,
      });
    });
  }

  @override
  Future<Booking> cancelBooking(String bookingId) async {
    final ref = _bookingsCollection(_currentUid()).doc(bookingId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) throw StateError('This booking no longer exists.');
      final booking = Booking.fromMap(snapshot.id, data);
      if (booking.isCancelled) {
        throw StateError('Booking is already cancelled.');
      }
      transaction.update(ref, {'isCancelled': true});
      return Booking.fromMap(snapshot.id, {...data, 'isCancelled': true});
    });
  }

  @override
  Future<Booking> refundBooking(String bookingId) async {
    final ref = _bookingsCollection(_currentUid()).doc(bookingId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) throw StateError('This booking no longer exists.');
      final booking = Booking.fromMap(snapshot.id, data);
      if (!booking.isCancelled) {
        throw StateError('Cancel the booking before recording a refund.');
      }
      if (booking.refundedAmount > 0 || booking.grossPaid <= 0) {
        throw StateError('There is no payment available to refund.');
      }
      transaction.update(ref, {'refundedAmount': booking.grossPaid});
      return Booking.fromMap(snapshot.id, {
        ...data,
        'refundedAmount': booking.grossPaid,
      });
    });
  }

  @override
  Future<void> addExpense(Expense expense) async {
    final uid = _currentUid();
    await _expensesCollection(uid).doc(expense.id).set(expense.toMap());
  }

}
