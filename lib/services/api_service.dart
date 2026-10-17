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
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      timeRange: json['time_range']?.toString() ?? '',
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

  factory ReschedulePreview.fromJson(Map<String, dynamic> json) {
    return ReschedulePreview(
      oldDate: json['old_date']?.toString() ?? '',
      newDate: json['new_date']?.toString() ?? '',
      oldSlotCount: json['old_slot_count'] is num ? (json['old_slot_count'] as num).toInt() : 0,
      newSlotCount: json['new_slot_count'] is num ? (json['new_slot_count'] as num).toInt() : 0,
      oldAmount: json['old_amount'] is num ? (json['old_amount'] as num).toDouble() : double.tryParse(json['old_amount']?.toString() ?? '0') ?? 0.0,
      newAmount: json['new_amount'] is num ? (json['new_amount'] as num).toDouble() : double.tryParse(json['new_amount']?.toString() ?? '0') ?? 0.0,
      difference: json['difference'] is num ? (json['difference'] as num).toDouble() : double.tryParse(json['difference']?.toString() ?? '0') ?? 0.0,
      direction: json['direction']?.toString() ?? 'equal',
      refundChannel: json['refund_channel']?.toString(),
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
    final uri = Uri.parse('${ApiClient.baseUrl}/booking-dates/$bookingDateId/reschedule-slots?date=$date');
    final response = await ApiClient.get(uri, headers: ApiClient.authHeaders(authToken));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final List rawSlots = data['slots'] ?? [];
      final slots = rawSlots.map((s) => RescheduleSlot.fromJson(s as Map<String, dynamic>)).toList();
      return {
        'success': true,
        'slots': slots,
        'is_same_date': data['is_same_date'] == true,
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
    final uri = Uri.parse('${ApiClient.baseUrl}/booking-dates/$bookingDateId/reschedule-preview');
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
      final previewData = data['preview'] is Map<String, dynamic> ? data['preview'] : data;
      return {
        'success': true,
        'preview': ReschedulePreview.fromJson(previewData as Map<String, dynamic>),
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
