import 'package:flutter/material.dart';

import '../../models/booking.dart';

/// The "My Bookings" tab (customer view of their own bookings, paginated
/// upcoming/past). Purely presentational — all state (filter, fetched
/// list, pagination) is owned by [MainScreen]; tapping a card opens the
/// shared booking-details bottom sheet via callback (also used by
/// [ClientBookingsTab] — kept in MainScreen rather than duplicated).
class BookingsTab extends StatelessWidget {
  final String bookingsFilter;
  final bool bookingsLoading;
  final List<Booking> bookings;
  final bool hasMoreBookings;
  final ScrollController bookingsScrollController;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext context, Booking booking) onShowBookingDetails;

  const BookingsTab({
    super.key,
    required this.bookingsFilter,
    required this.bookingsLoading,
    required this.bookings,
    required this.hasMoreBookings,
    required this.bookingsScrollController,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onShowBookingDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget filterTabs = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (bookingsFilter != 'upcoming') {
                    onFilterChanged('upcoming');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bookingsFilter == 'upcoming'
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Upcoming',
                    style: TextStyle(
                      color: bookingsFilter == 'upcoming'
                          ? Colors.white
                          : (theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[700]),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (bookingsFilter != 'past') {
                    onFilterChanged('past');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bookingsFilter == 'past'
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Past',
                    style: TextStyle(
                      color: bookingsFilter == 'past'
                          ? Colors.white
                          : (theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[700]),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (bookingsFilter != 'cancelled') {
                    onFilterChanged('cancelled');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bookingsFilter == 'cancelled'
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancelled',
                    style: TextStyle(
                      color: bookingsFilter == 'cancelled'
                          ? Colors.white
                          : (theme.brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[700]),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget body;
    if (bookingsLoading && bookings.isEmpty) {
      body = const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (bookings.isEmpty) {
      String emptyTitle = 'No Bookings Found';
      String emptySubtitle = '';
      IconData emptyIcon = Icons.calendar_month;

      if (bookingsFilter == 'upcoming') {
        emptyTitle = 'No Upcoming Bookings';
        emptySubtitle = 'You don\'t have any future turf bookings. Book a slot to get started!';
        emptyIcon = Icons.calendar_today_outlined;
      } else if (bookingsFilter == 'past') {
        emptyTitle = 'No Past Bookings';
        emptySubtitle = 'Your past bookings history is empty.';
        emptyIcon = Icons.history;
      } else if (bookingsFilter == 'cancelled') {
        emptyTitle = 'No Cancelled Bookings';
        emptySubtitle = 'You don\'t have any cancelled bookings.';
        emptyIcon = Icons.cancel_outlined;
      }

      body = Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    emptyIcon,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      body = Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            controller: bookingsScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            itemCount: bookings.length + (hasMoreBookings ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == bookings.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final b = bookings[index];
              final isConfirmed = b.isConfirmed;
              final isCancelled = b.isCancelled;
              final isPaid = b.isPaid;
              final bookingType = b.bookingType;

              String formattedBookingType = 'Day Session';
              if (bookingType == 'long') {
                formattedBookingType = 'Long Session';
              } else if (bookingType == 'scattered') {
                formattedBookingType = 'Scattered Slots';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: InkWell(
                  onTap: () => onShowBookingDetails(context, b),
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
                                    b.turfName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    b.bookingNumber != null && b.bookingNumber!.isNotEmpty
                                        ? b.bookingNumber!
                                        : 'Booking #${b.bookingId}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : (isCancelled
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                b.status,
                                style: TextStyle(
                                  color: isConfirmed
                                      ? Colors.green
                                      : (isCancelled ? Colors.red : Colors.orange),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                formattedBookingType,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                b.datePaymentStatus,
                                style: TextStyle(
                                  color: isPaid ? Colors.blue : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(b.bookingDate,
                                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(b.formattedTimeRange(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Price',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              '₹${b.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Price Paid',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              '₹${b.datePaidAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Balance',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              '₹${b.dateBalanceAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: b.dateBalanceAmount > 0
                                    ? Colors.orange
                                    : Colors.grey[600],
                              ),
                            ),
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
      );
    }

    return Column(
      children: [
        filterTabs,
        body,
      ],
    );
  }
}
