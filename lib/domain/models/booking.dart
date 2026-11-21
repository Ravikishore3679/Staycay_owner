import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Booking {
  Booking({
    required this.id,
    required this.name,
    required this.phone,
    required this.aadhaar,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.totalAmount,
    required this.advancePaid,
    this.balancePaid = 0,
    this.isCancelled = false,
    this.refundedAmount = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String aadhaar;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double totalAmount;
  final double advancePaid;
  final double balancePaid;
  final bool isCancelled;
  final double refundedAmount;

  double get grossPaid => math.max(advancePaid + balancePaid, 0.0);

  double get collectedAmount =>
      (grossPaid - refundedAmount).clamp(0.0, math.max(totalAmount, 0.0));

  double get remainingAmount {
    if (isCancelled) return 0;
    final remaining = totalAmount - grossPaid;
    return remaining < 0.000001 ? 0.0 : math.max(remaining, 0.0);
  }

  bool isPaymentDueOn(DateTime date) =>
      !isCancelled &&
      remainingAmount > 0 &&
      !DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(checkIn));

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'aadhaar': aadhaar,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'guests': guests,
      'totalAmount': totalAmount,
      'advancePaid': advancePaid,
      'balancePaid': balancePaid,
      'isCancelled': isCancelled,
      'refundedAmount': refundedAmount,
    };
  }

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    return Booking(
      id: id,
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      aadhaar: (map['aadhaar'] ?? '').toString(),
      checkIn: parseDate(map['checkIn']),
      checkOut: parseDate(map['checkOut']),
      guests: (map['guests'] as num?)?.toInt() ?? 0,
      totalAmount: parseDouble(map['totalAmount']),
      advancePaid: parseDouble(map['advancePaid']),
      balancePaid: parseDouble(map['balancePaid']),
      isCancelled: map['isCancelled'] == true,
      refundedAmount: parseDouble(map['refundedAmount']),
    );
  }
}
