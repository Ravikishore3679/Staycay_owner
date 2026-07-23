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
            subtitle: 'Overall financial snapshot',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DashboardMetricCard(
                  label: 'Revenue',
                  value: _currency(revenue),
                  icon: Icons.trending_up,
                  color: AppColors.dashboardAccent,
                  cardColor: const Color.fromARGB(255, 20, 85, 45),
                  textColor: AppColors.dashboardText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardMetricCard(
                  label: 'Expenditure',
                  value: _currency(expense),
                  icon: Icons.trending_down,
                  color: AppColors.dashboardAccent,
                  cardColor: const Color.fromARGB(255, 197, 53, 34),
                  textColor: AppColors.dashboardText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: AppColors.dashboardCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FinancialSummaryBar(
                    label: 'Revenue',
                    value: revenue,
                    max: progressMax,
                    color: const Color.fromARGB(255, 36, 162, 84),
                    textColor: AppColors.dashboardText,
                  ),
                  const SizedBox(height: 12),
                  _FinancialSummaryBar(
                    label: 'Expenditure',
                    value: expense,
                    max: progressMax,
                    color: const Color.fromARGB(255, 197, 53, 34),
                    textColor: AppColors.dashboardText,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 46, 46, 79),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(255, 200, 230, 211)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          net >= 0
                              ? Icons.savings_outlined
                              : Icons.warning_amber_rounded,
                          color: AppColors.dashboardAccent,
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
                color: AppColors.dashboardCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    color: AppColors.dashboardText.withValues(alpha: 0.8),
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
                color: AppColors.dashboardCard,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.dashboardAccent.withValues(
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
                    '${_formatDate(booking.checkIn)}  ->  ${_formatDate(booking.checkOut)}',
                    style: TextStyle(
                      color: AppColors.dashboardText.withValues(alpha: 0.8),
                    ),
                  ),
                  trailing: Text(
                    _currency(booking.totalAmount),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.dashboardAccent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
