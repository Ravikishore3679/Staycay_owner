part of 'registry_home_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});

  final RegistryViewModel controller;

  @override
  Widget build(BuildContext context) {
    final upcoming = controller.topUpcomingBookings;
    final revenue = controller.totalRevenue;
    final expense = controller.totalExpenditure;
    final net = revenue - expense;
    final progressMax = math.max(revenue, expense) <= 0
        ? 1.0
        : math.max(revenue, expense);

    return Container(
      color: AppColors.dashboardCanvas,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DashboardSectionTitle(
            icon: Icons.insights,
            title: 'Revenue vs Expenditure',
            subtitle: 'Revenue reflects amount paid only',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DashboardMetricCard(
                  label: 'Revenue (Paid)',
                  value: _currency(revenue),
                  icon: Icons.trending_up,
                  color: const Color.fromARGB(255, 13, 56, 10),
                  cardColor: const Color.fromARGB(255, 26, 163, 63),
                  textColor: const Color.fromARGB(255, 13, 56, 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardMetricCard(
                  label: 'Expenditure',
                  value: _currency(expense),
                  icon: Icons.trending_down,
                  color: const Color.fromARGB(255, 57, 13, 8),
                  cardColor: const Color.fromARGB(255, 206, 36, 36),
                  textColor: const Color.fromARGB(255, 57, 13, 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Card(
            color: const Color(0xFF1B3F47),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FinancialSummaryBar(
                    label: 'Revenue (Paid)',
                    value: revenue,
                    max: progressMax,
                    color: const Color.fromARGB(255, 26, 163, 63),
                    textColor: AppColors.dashboardText,
                    
                  ),
                  const SizedBox(height: 13),
                  _FinancialSummaryBar(
                    label: 'Expenditure',
                    value: expense,
                    max: progressMax,
                    color:  const Color.fromARGB(255, 206, 36, 36),
                    textColor:AppColors.dashboardText,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dashboardCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.dashboardAccent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          net >= 0
                              ? Icons.savings_outlined
                              : Icons.warning_amber_rounded,
                          color:AppColors.dashboardText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Net: ${_currency(net)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dashboardText,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _DashboardSectionTitle(
            icon: Icons.event_available,
            title: 'Upcoming Bookings',
            subtitle: 'Nearest check-ins first',
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3F47),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    color: const Color.fromARGB(255, 193, 198, 206).withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No upcoming bookings yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.dashboardText,
                    ),
                  ),
                ],
              ),
            )
          else
            ...upcoming.map(
              (booking) => Card(
                color: const Color(0xFF1B3F47),
                child: ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(
                    backgroundColor: const Color.fromARGB(255, 63, 161, 183).withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      '${booking.guests}',
                      style: const TextStyle(color: AppColors.dashboardText),
                    ),
                  ),
                  title: Text(
                    booking.name,
                    style: const TextStyle(color: AppColors.dashboardText),
                  ),
                  subtitle: Text(
                    '${_formatDate(booking.checkIn)}  ->  ${_formatDate(booking.checkOut)}\nPaid: ${_currency(booking.collectedAmount)} | To Collect: ${_currency(booking.remainingAmount)}',
                    style: TextStyle(
                      color: AppColors.dashboardText.withValues(alpha: 0.8),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Collect',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.dashboardText.withValues(alpha: 0.8),
                            ),
                      ),
                      Text(
                        _currency(booking.remainingAmount),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.dashboardText,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit this booking in Bookings tab after collecting payment.'),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
