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
    // Optimize: Order by checkIn descending and limit to 500 documents
    // This reduces initial load time and network bandwidth
    return _bookingsCollection(uid)
        .orderBy('checkIn', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Booking.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<Expense>> watchExpenses() {
    final uid = _currentUid();
    // Optimize: Order by date descending and limit to 500 documents
    // This reduces initial load time and network bandwidth
    return _expensesCollection(uid)
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Expense.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> addBooking(Booking booking) async {
    final uid = _currentUid();
    await _bookingsCollection(uid).doc(booking.id).set(booking.toMap());
  }

  @override
  Future<void> updateBooking(Booking booking) async {
    final uid = _currentUid();
    await _bookingsCollection(uid).doc(booking.id).set(booking.toMap());
  }

  @override
  Future<void> deleteBooking(String bookingId) async {
    final uid = _currentUid();
    await _bookingsCollection(uid).doc(bookingId).delete();
  }

  @override
  Future<void> addExpense(Expense expense) async {
    final uid = _currentUid();
    await _expensesCollection(uid).doc(expense.id).set(expense.toMap());
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final uid = _currentUid();
    await _expensesCollection(uid).doc(expense.id).set(expense.toMap());
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    final uid = _currentUid();
    await _expensesCollection(uid).doc(expenseId).delete();
  }
}
