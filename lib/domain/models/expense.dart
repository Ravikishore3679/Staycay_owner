import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.description,
    required this.date,
  });

  final String id;
  final String title;
  final double amount;
  final String description;
  final DateTime date;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
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

    return Expense(
      id: id,
      title: (map['title'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      description: (map['description'] ?? '').toString(),
      date: parseDate(map['date']),
    );
  }
}
