import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';

class InvoiceService {
  InvoiceService._();

  /// Downloads the PDF bill for [bookingId] and saves it locally in the temporary directory.
  /// Returns the local file path on success, or null on failure.
  static Future<String?> downloadBill(String authToken, int bookingId) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/bookings/$bookingId/invoice');
      final response = await ApiClient.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Bill_$bookingId.pdf');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        return file.path;
      } else {
        debugPrint('Failed to download invoice: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading invoice: $e');
      return null;
    }
  }
}
