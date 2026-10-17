import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/booking.dart';

class RecordPaymentDialog extends StatefulWidget {
  final Booking bookingDate;
  final String? token;
  final VoidCallback? onSuccess;

  const RecordPaymentDialog({
    super.key,
    required this.bookingDate,
    this.token,
    this.onSuccess,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  String _method = 'Cash';
  late final TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.bookingDate.dateBalanceAmount > 0
          ? widget.bookingDate.dateBalanceAmount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/booking-dates/${widget.bookingDate.id}/payments'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'payment_method': _method,
          'amount': amt,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSuccess?.call();
      } else {
        if (!mounted) return;
        final msg = jsonDecode(response.body)['message'] ?? 'Failed to record payment.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Offline Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Payment Method:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _method,
              isExpanded: true,
              onChanged: _isLoading
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() {
                          _method = val;
                        });
                      }
                    },
              items: ['Cash', 'UPI', 'Other'].map((m) {
                return DropdownMenuItem<String>(
                  value: m,
                  child: Text(m),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount (₹)',
                hintText: 'Enter amount collected',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record'),
        ),
      ],
    );
  }
}
