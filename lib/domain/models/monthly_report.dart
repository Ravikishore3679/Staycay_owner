class MonthlyReport {
  MonthlyReport({
    required this.year,
    required this.month,
    required this.revenue,
    required this.expenses,
  });

  final int year;
  final int month;
  final double revenue;
  final double expenses;

  double get net => revenue - expenses;
}
