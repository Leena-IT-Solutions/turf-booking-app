/// A slot snapshot as it appears nested inside a [Booking] record
/// (read-only display — not the same shape as the slot-selection data
/// used when creating a new booking in TurfBookingScreen).
class BookedSlot {
  final String? timeRange;
  final String? fromTime;
  final String? toTime;

  const BookedSlot({this.timeRange, this.fromTime, this.toTime});

  factory BookedSlot.fromJson(Map<String, dynamic> json) {
    return BookedSlot(
      timeRange: json['time_range']?.toString(),
      fromTime: json['from_time']?.toString(),
      toTime: json['to_time']?.toString(),
    );
  }
}

/// A single payment entry within a [Booking]'s payment history.
class BookingPayment {
  final String paymentMethod;
  final double amount;
  final String? paidAt;

  const BookingPayment({required this.paymentMethod, required this.amount, this.paidAt});

  factory BookingPayment.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'];
    return BookingPayment(
      paymentMethod: json['payment_method']?.toString() ?? '',
      amount: amt is num ? amt.toDouble() : double.tryParse(amt.toString()) ?? 0.0,
      paidAt: json['paid_at']?.toString(),
    );
  }
}

/// A booking-date record — the shape returned by `/bookings` and used
/// throughout the customer "My Bookings" tab, the turf-admin "Client
/// Bookings" tab, and the shared booking-details bottom sheet. Note this
/// is deliberately NOT used for the Dashboard tab's "recent bookings"
/// list, which the API returns in a distinct, smaller shape
/// (`date`/`payment_status` instead of `date_raw`/`date_payment_status`)
/// — forcing both into one model would hide that real backend
/// inconsistency rather than represent it honestly.
class Booking {
  final int id;
  final int bookingId;
  final String? turfId;
  final String turfName;
  final String? customerName;
  final String? customerMobile;
  final String? customerEmail;
  final String status;
  final String datePaymentStatus;
  final String bookingType;
  final String bookingDate;
  final String? dateRaw;
  final String? dateOfBooking;
  final String? bookingNumber;
  final double taxableAmount;
  final double turfGstRate;
  final String? turfGstType;
  final double turfGstAmount;
  final double platformFee;
  final double platformFeeGst;
  final String? customerGstin;
  final String? customerCompanyName;
  final String? refundMethod;
  final double amount;
  final double datePaidAmount;
  final double dateBalanceAmount;
  final String? summaryText;
  final List<BookedSlot> slots;
  final List<BookingPayment> payments;
  final bool isCancellationActive;
  final int cancellationHours;
  final double cancellationFee;
  final String? cancelledAt;
  final double cancellationFeeApplied;
  final double refundAmount;
  final String? refundStatus;
  final String? refundedAt;
  final String? shareMessageTemplate;

  const Booking({
    required this.id,
    required this.bookingId,
    this.bookingNumber,
    this.turfId,
    required this.turfName,
    this.customerName,
    this.customerMobile,
    this.customerEmail,
    this.customerGstin,
    this.customerCompanyName,
    required this.status,
    required this.datePaymentStatus,
    required this.bookingType,
    required this.bookingDate,
    this.dateRaw,
    this.dateOfBooking,
    this.taxableAmount = 0.0,
    this.turfGstRate = 0.0,
    this.turfGstType,
    this.turfGstAmount = 0.0,
    this.platformFee = 0.0,
    this.platformFeeGst = 0.0,
    this.amount = 0.0,
    this.datePaidAmount = 0.0,
    this.dateBalanceAmount = 0.0,
    this.summaryText,
    this.slots = const [],
    this.payments = const [],
    this.isCancellationActive = false,
    this.cancellationHours = 0,
    this.cancellationFee = 0.0,
    this.cancelledAt,
    this.cancellationFeeApplied = 0.0,
    this.refundAmount = 0.0,
    this.refundStatus,
    this.refundMethod,
    this.refundedAt,
    this.shareMessageTemplate,
  });

  bool get isConfirmed => status == 'Confirmed';
  bool get isCancelled => status == 'Cancelled';
  bool get isPaid => datePaymentStatus == 'Paid';

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      bookingNumber: json['booking_number']?.toString(),
      turfId: json['turf_id']?.toString(),
      turfName: json['turf_name'] ?? 'Unknown Turf',
      customerName: json['customer_name'],
      customerMobile: json['customer_mobile'],
      customerEmail: json['customer_email'],
      customerGstin: json['customer_gstin']?.toString(),
      customerCompanyName: json['customer_company_name']?.toString(),
      status: json['status'] ?? 'Pending',
      datePaymentStatus: json['date_payment_status'] ?? 'Unpaid',
      bookingType: json['booking_type'] ?? 'day',
      bookingDate: json['booking_date'] ?? '',
      dateRaw: json['date_raw'],
      dateOfBooking: json['date_of_booking'],
      taxableAmount: _toDouble(json['taxable_amount']),
      turfGstRate: _toDouble(json['turf_gst_rate']),
      turfGstType: json['turf_gst_type']?.toString(),
      turfGstAmount: _toDouble(json['turf_gst_amount']),
      platformFee: _toDouble(json['platform_fee']),
      platformFeeGst: _toDouble(json['platform_fee_gst']),
      amount: _toDouble(json['amount']),
      datePaidAmount: _toDouble(json['date_paid_amount']),
      dateBalanceAmount: _toDouble(json['date_balance_amount']),
      summaryText: json['summary_text'],
      slots: json['slots'] != null
          ? List<dynamic>.from(json['slots']).map((s) => BookedSlot.fromJson(s as Map<String, dynamic>)).toList()
          : const [],
      payments: json['payments'] != null
          ? List<dynamic>.from(json['payments']).map((p) => BookingPayment.fromJson(p as Map<String, dynamic>)).toList()
          : const [],
      isCancellationActive: json['is_cancellation_active'] == true || json['is_cancellation_active'] == 1,
      cancellationHours: json['cancellation_hours'] ?? 0,
      cancellationFee: _toDouble(json['cancellation_fee']),
      cancelledAt: json['cancelled_at'],
      cancellationFeeApplied: _toDouble(json['cancellation_fee_applied']),
      refundAmount: _toDouble(json['refund_amount']),
      refundStatus: json['refund_status'],
      refundMethod: json['refund_method'],
      refundedAt: json['refunded_at'],
      shareMessageTemplate: json['share_message_template'],
    );
  }

  /// Formatted "start - end" time range across all booked slots, falling
  /// back to [summaryText] when slot times aren't available in a usable
  /// shape. Moved here (from being duplicated per-tab) since every
  /// consumer needs the exact same fallback logic.
  String formattedTimeRange() {
    if (slots.isNotEmpty) {
      final first = slots.first;
      final last = slots.last;

      String? startTime;
      String? endTime;

      final firstRange = first.timeRange ?? '';
      if (firstRange.contains(' - ')) {
        startTime = firstRange.split(' - ').first.trim();
      } else if (first.fromTime != null && first.fromTime!.isNotEmpty) {
        startTime = first.fromTime;
      }

      final lastRange = last.timeRange ?? '';
      if (lastRange.contains(' - ')) {
        endTime = lastRange.split(' - ').last.trim();
      } else if (last.toTime != null && last.toTime!.isNotEmpty) {
        endTime = last.toTime;
      }

      if (startTime != null && endTime != null && startTime.isNotEmpty && endTime.isNotEmpty) {
        return '$startTime - $endTime';
      }
    }

    final summary = summaryText ?? '';
    if (summary.contains('slot') || summary.contains('slots')) {
      return 'N/A';
    }
    return summary.isNotEmpty ? summary : 'N/A';
  }

  /// Whether this booking-date is in the past (date already passed, or
  /// today but the first slot's start time has already elapsed).
  bool isPast() {
    final raw = dateRaw ?? '';
    if (raw.isEmpty) return false;
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (raw.compareTo(todayStr) < 0) return true;
    if (raw.compareTo(todayStr) > 0) return false;

    if (slots.isEmpty) return false;
    final fromTime = slots.first.fromTime ?? '';
    if (fromTime.isEmpty) return false;

    final currentTimeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    return fromTime.compareTo(currentTimeStr) < 0;
  }
}
