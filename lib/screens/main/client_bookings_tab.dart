import 'package:flutter/material.dart';

import '../../models/booking.dart';

/// The "Client Booking" tab (turf-admin/manager view of bookings across
/// their turfs, by date). Purely presentational — all mutable state
/// (selected date/filter/turf, fetched list) is owned by [MainScreen];
/// every interaction that changes state or triggers a refetch is routed
/// back up via callback.
class ClientBookingsTab extends StatelessWidget {
  final List<dynamic> manageableTurfs;
  final int? clientBookingSelectedTurfId;
  final String clientBookingFilter;
  final DateTime clientBookingSelectedDate;
  final bool clientBookingsLoading;
  final List<Booking> clientBookings;
  final ValueChanged<int?> onTurfFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext context, Booking booking) onShowBookingDetails;

  const ClientBookingsTab({
    super.key,
    required this.manageableTurfs,
    required this.clientBookingSelectedTurfId,
    required this.clientBookingFilter,
    required this.clientBookingSelectedDate,
    required this.clientBookingsLoading,
    required this.clientBookings,
    required this.onTurfFilterChanged,
    required this.onStatusFilterChanged,
    required this.onDateChanged,
    required this.onRefresh,
    required this.onShowBookingDetails,
  });

  Widget _buildPriceColumn(String label, dynamic value, Color valueColor) {
    final amt = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          "₹${amt.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateStr = "${clientBookingSelectedDate.day} ${[
      "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ][clientBookingSelectedDate.month]} ${clientBookingSelectedDate.year}";

    final dayOfWeek = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ][clientBookingSelectedDate.weekday - 1];

    return Column(
      children: [
        // Turf selector dropdown
        if (manageableTurfs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
            child: Card(
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
                          value: clientBookingSelectedTurfId,
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
                            ...manageableTurfs.map<DropdownMenuItem<int?>>((t) {
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
          ),
        ],

        // All / Upcoming / Past Filter Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (clientBookingFilter != 'all') {
                        onStatusFilterChanged('all');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: clientBookingFilter == 'all'
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: clientBookingFilter == 'all'
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'All',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: clientBookingFilter == 'all'
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (clientBookingFilter != 'upcoming') {
                        onStatusFilterChanged('upcoming');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: clientBookingFilter == 'upcoming'
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: clientBookingFilter == 'upcoming'
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Upcoming',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: clientBookingFilter == 'upcoming'
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (clientBookingFilter != 'past') {
                        onStatusFilterChanged('past');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: clientBookingFilter == 'past'
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: clientBookingFilter == 'past'
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Past',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: clientBookingFilter == 'past'
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Date Selector Header Strip
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withAlpha(20)),
            ),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: theme.colorScheme.primary),
                    onPressed: () {
                      onDateChanged(clientBookingSelectedDate.subtract(const Duration(days: 1)));
                    },
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: clientBookingSelectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          onDateChanged(picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayOfWeek,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                    onPressed: () {
                      onDateChanged(clientBookingSelectedDate.add(const Duration(days: 1)));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bookings List
        Expanded(
          child: clientBookingsLoading
              ? const Center(child: CircularProgressIndicator())
              : clientBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No bookings for this date",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: clientBookings.length,
                        itemBuilder: (ctx, idx) {
                          final bDate = clientBookings[idx];
                          final isCancelled = bDate.isCancelled;
                          final status = isCancelled ? 'Cancelled' : bDate.datePaymentStatus;
                          final isPast = bDate.isPast();

                          Color badgeColor = Colors.red;
                          if (isCancelled) {
                            badgeColor = Colors.red;
                          } else if (status == 'Paid') {
                            badgeColor = const Color(0xFF10B981);
                          } else if (status == 'Partially Paid') {
                            badgeColor = Colors.orange;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: isPast
                                ? (isDark ? const Color(0xFF1E2022) : const Color(0xFFF3F4F6))
                                : (isDark ? const Color(0xFF26292B) : Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isPast
                                    ? Colors.blueGrey.withValues(alpha: 0.2)
                                    : theme.colorScheme.primary.withValues(alpha: 0.25),
                                width: isPast ? 1 : 1.5,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => onShowBookingDetails(context, bDate),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                bDate.turfName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isPast ? Colors.grey[600] : null,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                bDate.bookingNumber != null && bDate.bookingNumber!.isNotEmpty
                                                    ? bDate.bookingNumber!
                                                    : 'Booking #${bDate.bookingId}',
                                                style: TextStyle(
                                                  color: isPast ? Colors.grey[500] : Colors.grey[600],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Upcoming vs Past Color-Coded Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPast
                                                ? Colors.blueGrey.withValues(alpha: 0.12)
                                                : Colors.teal.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isPast
                                                  ? Colors.blueGrey.withValues(alpha: 0.3)
                                                  : Colors.teal.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPast ? Icons.history : Icons.schedule,
                                                size: 12,
                                                color: isPast ? Colors.blueGrey : Colors.teal,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isPast ? 'Past' : 'Upcoming',
                                                style: TextStyle(
                                                  color: isPast ? Colors.blueGrey : Colors.teal,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: badgeColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Text(
                                          bDate.customerName ?? 'N/A',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        if (bDate.customerMobile != 'N/A') ...[
                                          Text(
                                            ' (${bDate.customerMobile})',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            bDate.summaryText ?? '',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildPriceColumn('Total', bDate.amount, Colors.grey[600]!),
                                        _buildPriceColumn('Paid', bDate.datePaidAmount, const Color(0xFF10B981)),
                                        _buildPriceColumn('Balance', bDate.dateBalanceAmount, Colors.red),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
