import 'package:flutter/material.dart';

/// The turf-admin "Dashboard" tab: today's stats + recent bookings.
/// Purely presentational — all state (stats payload, selected turf
/// filter) is owned by [MainScreen]; tapping a recent booking jumps to
/// the Client Bookings tab for that date via callback.
class DashboardTab extends StatelessWidget {
  final bool dashboardStatsLoading;
  final Map<String, dynamic>? dashboardStats;
  final int? dashboardSelectedTurfId;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final ValueChanged<int?> onTurfFilterChanged;
  final ValueChanged<DateTime> onViewBookingsForDate;

  const DashboardTab({
    super.key,
    required this.dashboardStatsLoading,
    required this.dashboardStats,
    required this.dashboardSelectedTurfId,
    required this.onRetry,
    required this.onRefresh,
    required this.onTurfFilterChanged,
    required this.onViewBookingsForDate,
  });

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withAlpha(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (dashboardStatsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dashboardStats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry loading stats'),
            ),
          ],
        ),
      );
    }

    final stats = dashboardStats!;
    final totalBookings = stats['total_bookings_today'] ?? 0;
    final totalRevenue = stats['total_revenue_today'] ?? 0.0;
    final activeTurfs = stats['active_turfs_count'] ?? 0;
    final activeCoupons = stats['active_coupons_count'] ?? 0;
    final recentBookings = List<dynamic>.from(stats['recent_bookings'] ?? []);
    final List<dynamic> turfsList = stats['turfs'] ?? [];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Turf selector dropdown
            if (turfsList.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                color: theme.colorScheme.primary.withValues(alpha: 0.02),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Turf:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: dashboardSelectedTurfId,
                            isExpanded: true,
                            hint: const Text('All Turfs'),
                            icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'All Turfs',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...turfsList.map<DropdownMenuItem<int?>>((t) {
                                return DropdownMenuItem<int?>(
                                  value: t['id'] as int,
                                  child: Text(
                                    t['name'] ?? 'Unknown Turf',
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: onTurfFilterChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Grid of Metrics
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  title: "Today's Bookings",
                  value: "$totalBookings",
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: "Today's Revenue",
                  value: "₹${(totalRevenue as num).toStringAsFixed(0)}",
                  icon: Icons.currency_rupee,
                  color: const Color(0xFF10B981),
                ),
                _buildStatCard(
                  title: "Active Turfs",
                  value: "$activeTurfs",
                  icon: Icons.sports_soccer,
                  color: Colors.purple,
                ),
                _buildStatCard(
                  title: "Active Coupons",
                  value: "$activeCoupons",
                  icon: Icons.local_offer_outlined,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Bookings Header
            const Text(
              'Recent Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (recentBookings.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withAlpha(20)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No recent bookings found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentBookings.length,
                itemBuilder: (ctx, idx) {
                  final b = recentBookings[idx];
                  final status = b['payment_status'] ?? 'Unpaid';
                  Color statusColor = Colors.red;
                  if (status == 'Paid') {
                    statusColor = const Color(0xFF10B981);
                  } else if (status == 'Partially Paid') {
                    statusColor = Colors.orange;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withAlpha(20)),
                    ),
                    child: ListTile(
                      onTap: () => onViewBookingsForDate(DateTime.parse(b['date'])),
                      title: Text(
                        b['turf_name'] ?? 'Unknown Turf',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${b['customer_name']} • ${b['date']}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${(b['amount'] as num).toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
