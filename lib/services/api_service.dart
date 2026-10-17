import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class RescheduleSlot {
  final int id;
  final String startTime;
  final String endTime;
  final String timeRange;
  final double price;
  final bool isAvailable;
  final bool isCurrentSlot;

  const RescheduleSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.timeRange,
    required this.price,
    required this.isAvailable,
    required this.isCurrentSlot,
  });

  factory RescheduleSlot.fromJson(Map<String, dynamic> json) {
    return RescheduleSlot(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      // Field names follow GET /booking-dates/{id}/reschedule/slots (BookingRescheduleService::slots).
      startTime: json['from_time']?.toString() ?? '',
      endTime: json['to_time']?.toString() ?? '',
      timeRange: json['time_label']?.toString() ?? '',
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      isAvailable: json['is_available'] == true || json['is_available'] == 1,
      isCurrentSlot: json['is_current_slot'] == true || json['is_current_slot'] == 1,
    );
  }
}

class ReschedulePreview {
  final String oldDate;
  final String newDate;
  final int oldSlotCount;
  final int newSlotCount;
  final double oldAmount;
  final double newAmount;
  final double difference;
  final String direction; // 'equal', 'extra_charge', 'refund'
  final String? refundChannel; // 'gateway', 'cash', null
  final String message;

  const ReschedulePreview({
    required this.oldDate,
    required this.newDate,
    required this.oldSlotCount,
    required this.newSlotCount,
    required this.oldAmount,
    required this.newAmount,
    required this.difference,
    required this.direction,
    this.refundChannel,
    required this.message,
  });

  /// Parses POST /booking-dates/{id}/reschedule/preview (BookingRescheduleService::preview), which
  /// returns flat fields. [newSlotCount] is the number of slots the manager picked — the server
  /// doesn't echo it back.
  factory ReschedulePreview.fromJson(Map<String, dynamic> json, {required int newSlotCount}) {
    double toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    const directionBySettlement = {
      'none': 'equal',
      'balance_due': 'extra_charge',
      'refund': 'refund',
    };
    const channelByServer = {
      'online_gateway': 'gateway',
      'offline': 'cash',
    };

    return ReschedulePreview(
      oldDate: json['from_date']?.toString() ?? '',
      newDate: json['to_date']?.toString() ?? '',
      oldSlotCount: 0,
      newSlotCount: newSlotCount,
      oldAmount: toDouble(json['old_amount']),
      newAmount: toDouble(json['new_amount']),
      difference: toDouble(json['price_difference']),
      direction: directionBySettlement[json['settlement_type']?.toString()] ?? 'equal',
      refundChannel: channelByServer[json['refund_channel']?.toString()],
      message: json['message']?.toString() ?? '',
    );
  }
}

class ApiService {
  ApiService._();

  static Future<String?> _resolveToken(String? token) async {
    if (token != null && token.isNotEmpty) return token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Fetch slots for rescheduling a booking date
  static Future<Map<String, dynamic>> getRescheduleSlots(
    int bookingDateId,
    String date, {
    String? token,
  }) async {
    final authToken = await _resolveToken(token);
    final uri = Uri.parse('${ApiClient.baseUrl}/booking-dates/$bookingDateId/reschedule/slots?date=$date');
    final response = await ApiClient.get(uri, headers: ApiClient.authHeaders(authToken));

    final data = jsonDecode(response.body);
    // The slots endpoint returns {slots, reschedules_used, reschedules_allowed, is_reschedule_active}
    // with no 'success' flag, so a 200 is the success signal.
    if (response.statusCode == 200) {
      final List rawSlots = data['slots'] ?? [];
      final slots = rawSlots.map((s) => RescheduleSlot.fromJson(s as Map<String, dynamic>)).toList();
      return {
        'success': true,
        'slots': slots,
        'message': data['message'] ?? '',
      };
    } else {
      return {
        'success': false,
        'slots': <RescheduleSlot>[],
        'message': data['message'] ?? 'Failed to load available slots.',
      };
    }
  }

  /// Preview rescheduling price impact
  static Future<Map<String, dynamic>> previewReschedule(
    int bookingDateId,
    String date,
    List<int> slotIds, {
    String? token,
  }) async {
    final authToken = await _resolveToken(token);
    final uri = Uri.parse('${ApiClient.baseUrl}/booking-dates/$bookingDateId/reschedule/preview');
    final response = await ApiClient.post(
      uri,
      headers: ApiClient.authHeaders(authToken),
      body: jsonEncode({
        'date': date,
        'slot_ids': slotIds,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'success': true,
        'preview': ReschedulePreview.fromJson(data as Map<String, dynamic>, newSlotCount: slotIds.length),
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to calculate reschedule preview.',
      };
    }
  }

  /// Perform the session reschedule
  static Future<Map<String, dynamic>> rescheduleBooking(
    int bookingDateId,
    String date,
    List<int> slotIds, {
    String? reason,
    String? token,
  }) async {
    final authToken = await _resolveToken(token);
    final uri = Uri.parse('${ApiClient.baseUrl}/booking-dates/$bookingDateId/reschedule');
    final bodyMap = <String, dynamic>{
      'date': date,
      'slot_ids': slotIds,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      bodyMap['reason'] = reason.trim();
    }

    final response = await ApiClient.post(
      uri,
      headers: ApiClient.authHeaders(authToken),
      body: jsonEncode(bodyMap),
    );

    final data = jsonDecode(response.body);
    final isOk = (response.statusCode == 200 || response.statusCode == 201) && (data['success'] == true);
    return {
      'success': isOk,
      'message': data['message'] ?? (isOk ? 'Session rescheduled successfully!' : 'Failed to reschedule session.'),
      'data': data,
    };
  }
}
